# cmd_161: Claude Code公式ドキュメント自動収集・和訳・日次更新システム設計書

**改訂版 v2** — 翻訳エンジンを Gemini 2.5 Flash (Free Tier) に変更、自動化を n8n ワークフローに統合。

## 概要

Claude Code公式ドキュメント（約57ページ）を自動収集・体系整理・和訳し、1日1回更新する仕組みを設計する。
既存のECC日本語翻訳資産（147ファイル, 35,702行）との統合を前提とする。

**対象**: Claude Code公式ドキュメント（code.claude.com/docs）
**動作環境**: WSL2 (Ubuntu) + n8n (self-hosted) + Gemini API
**更新頻度**: 1日1回（n8n Schedule Trigger）
**翻訳コスト**: $0/月（Gemini 2.5 Flash Free Tier）

---

## 1. ドキュメントソースの特定

### 1.1 主要ソース一覧

| ソース | URL | ページ数 | 更新頻度 | 形式 |
|--------|-----|----------|----------|------|
| **公式ドキュメントサイト** | code.claude.com/docs/en/ | 57ページ | 週1-2回 | HTML (Markdown生成) |
| **LLM向けインデックス** | code.claude.com/docs/llms.txt | 1ファイル | サイト更新と同期 | テキスト |
| **GitHubリポジトリ** | github.com/anthropics/claude-code | 5-10ファイル | 日次1-5コミット | Markdown |
| **CHANGELOG** | github.com/anthropics/claude-code/blob/main/CHANGELOG.md | 1ファイル | リリースごと | Markdown |
| **プラグインドキュメント** | github.com/anthropics/claude-code/tree/main/plugins/ | 10+ファイル | 不定期 | Markdown |

### 1.2 公式ドキュメントサイトのカテゴリ構成

```
code.claude.com/docs/en/
├── 入門・基本操作 (8ページ)
│   ├── overview, quickstart, setup, how-claude-code-works
│   ├── authentication, best-practices
│   └── common-workflows, troubleshooting
├── 環境別ガイド (7ページ)
│   ├── terminal, vs-code, jetbrains, desktop
│   └── desktop-quickstart, web, chrome
├── カスタマイズ・拡張 (13ページ)
│   ├── settings, memory, skills, hooks, hooks-guide
│   ├── plugins, plugins-reference, discover-plugins, plugin-marketplaces
│   └── mcp, sub-agents, agent-teams
├── 開発者向け・高度機能 (12ページ)
│   ├── cli-reference, headless, interactive-mode
│   ├── permissions, sandboxing, security
│   ├── devcontainer, fast-mode, checkpointing
│   └── output-styles, keybindings, statusline
├── CI/CD・チャット連携 (4ページ)
│   └── github-actions, gitlab-ci-cd, slack, features-overview
├── エンタープライズ (8ページ)
│   ├── third-party-integrations, amazon-bedrock, google-vertex-ai
│   ├── microsoft-foundry, llm-gateway
│   └── model-config, network-config, server-managed-settings
└── 運用・その他 (5ページ)
    ├── analytics, monitoring-usage, costs, terminal-config
    └── legal-and-compliance, data-usage, changelog
```

### 1.3 GitHubリポジトリのドキュメント

| ファイル | 内容 | 優先度 |
|---------|------|--------|
| README.md | インストール・基本概要 | 高 |
| CHANGELOG.md | バージョン履歴・変更点 | 高 |
| SECURITY.md | セキュリティポリシー | 中 |
| plugins/README.md | プラグイン開発ガイド | 高 |
| 各plugins/*/README.md | 個別プラグインドキュメント | 中 |

### 1.4 URL体系

- **標準パス**: `https://code.claude.com/docs/en/<page-name>`
- **旧URL**: `https://docs.anthropic.com/en/docs/claude-code/*` → 301リダイレクト
- **機械可読インデックス**: `https://code.claude.com/docs/llms.txt`
- **GitHub API**: `https://api.github.com/repos/anthropics/claude-code/contents/`

---

## 2. 収集方法の技術選定

### 2.1 方式比較

| 方式 | メリット | デメリット | 推奨度 |
|------|----------|-----------|--------|
| **llms.txt + HTTP Request** | 公式提供のインデックス、構造化済み、安定 | HTML→Markdownの変換品質に依存 | ★★★★★ |
| **GitHub API** | 構造化データ、レート制限内で安定 | ドキュメントサイトのコンテンツは含まない | ★★★★☆ |
| **Scrapy/BeautifulSoup** | 柔軟、全ページ取得可能 | メンテナンスコスト高、HTML構造変更に弱い | ★★★☆☆ |

### 2.2 推奨方式: n8n HTTP Request ノードによるハイブリッド2層収集

```
Layer 1: llms.txt インデックス取得 (公式ドキュメント)
         ↓ HTTP Request ノードでページURL一覧を取得
         ↓ SplitInBatches → 各ページを HTTP Request で取得
         ↓ Code ノードで HTML → Markdown 変換
         ↓ ファイル保存

Layer 2: GitHub API (リポジトリドキュメント)
         ↓ HTTP Request ノード (GitHub API)
         ↓ README, CHANGELOG, plugins/ を取得
         ↓ Code ノードで Base64デコード
         ↓ ファイル保存
```

### 2.3 変更差分検知

| 方式 | 対象 | 実装 |
|------|------|------|
| **コンテンツハッシュ** | 全ソース | SHA-256(本文) を metadata.json に記録。変更時のみ更新 |
| **HTTP ETag / Last-Modified** | Webページ | レスポンスヘッダーを保存。304 Not Modified で帯域節約 |
| **GitHub API commits** | GitHubファイル | 最新コミットSHAを比較。変更ファイルのみ再取得 |
| **llms.txt diff** | ページ一覧 | 前回取得分と比較。新規・削除ページを検知 |

### 2.4 技術スタック

| コンポーネント | 技術 | 役割 |
|---------------|------|------|
| **オーケストレーション** | n8n (self-hosted) | ワークフロー管理、スケジューリング |
| **収集** | n8n HTTP Request ノード | Web/API からのデータ取得 |
| **変換・差分検知** | n8n Code ノード (JavaScript) | HTML→Markdown変換、SHA-256ハッシュ計算 |
| **翻訳** | Gemini 2.5 Flash API (n8n HTTP Request) | 英→日翻訳 |
| **ファイル操作** | n8n Execute Command ノード | ファイル読み書き |
| **通知** | n8n HTTP Request ノード | Google Chat Webhook |
| **メタデータ管理** | metadata.json (ローカルファイル) | ハッシュ・ステータス管理 |

---

## 3. フォルダ構成設計

### 3.1 ディレクトリ構造

```
~/.claude/docs/
├── sync/                          # 自動収集システム
│   ├── config.yaml                # 設定ファイル
│   ├── metadata.json              # ハッシュ・更新日時・翻訳ステータス
│   └── logs/                      # 実行ログ
│       └── sync_YYYYMMDD.log
│
├── en/                            # 原文（英語）
│   ├── site/                      # 公式ドキュメントサイト
│   │   ├── getting-started/       # 入門
│   │   │   ├── overview.md
│   │   │   ├── quickstart.md
│   │   │   └── ...
│   │   ├── customization/         # カスタマイズ
│   │   ├── developer/             # 開発者向け
│   │   ├── enterprise/            # エンタープライズ
│   │   ├── integrations/          # 連携
│   │   └── operations/            # 運用
│   └── github/                    # GitHubリポジトリ
│       ├── README.md
│       ├── CHANGELOG.md
│       └── plugins/
│
├── ja-JP/                         # 和訳（既存ECC翻訳 + 自動翻訳）
│   ├── site/                      # 公式ドキュメント和訳
│   │   ├── getting-started/
│   │   ├── customization/
│   │   ├── developer/
│   │   ├── enterprise/
│   │   ├── integrations/
│   │   └── operations/
│   ├── github/                    # GitHubドキュメント和訳
│   │   ├── README.md
│   │   └── CHANGELOG.md
│   │
│   │   # ── 既存ECC翻訳（変更なし・共存） ──
│   ├── agents/                    # 既存: 13ファイル
│   ├── commands/                  # 既存: 35ファイル
│   ├── contexts/                  # 既存: 3ファイル
│   ├── rules/                     # 既存: 32ファイル
│   ├── skills/                    # 既存: 52ディレクトリ
│   ├── TERMINOLOGY.md             # 既存: 用語対照表
│   └── TRANSLATION_STATUS.md      # 既存 → 自動更新対象に拡張
│
└── README.md                      # システム説明
```

### 3.2 既存ECC翻訳との関係整理

| 資産 | 場所 | 管理方式 |
|------|------|----------|
| **ECC翻訳（プラグイン資産）** | `ja-JP/agents/`, `commands/`, `rules/`, `skills/` | 手動管理（変更なし） |
| **公式ドキュメント和訳（新規）** | `ja-JP/site/`, `ja-JP/github/` | 自動翻訳（日次更新） |
| **用語集** | `ja-JP/TERMINOLOGY.md` | 共有（ECC + 自動翻訳の両方が準拠） |

**方針**: 既存ディレクトリは一切変更しない。新規の `site/` と `github/` サブディレクトリに自動翻訳を配置。

### 3.3 メタデータ管理 (metadata.json)

```json
{
  "last_sync": "2026-02-15T06:00:00+09:00",
  "pages": {
    "site/getting-started/overview.md": {
      "source_url": "https://code.claude.com/docs/en/overview",
      "content_hash": "sha256:abcd1234...",
      "last_fetched": "2026-02-15T06:00:00+09:00",
      "last_modified": "2026-02-14T10:00:00Z",
      "translation_status": "translated",
      "translation_hash": "sha256:ef567890...",
      "translated_at": "2026-02-15T06:05:00+09:00"
    }
  },
  "stats": {
    "total_pages": 57,
    "translated": 57,
    "pending": 0,
    "changed_since_last_sync": 3
  }
}
```

---

## 4. 和訳の仕組み

### 4.1 翻訳エンジン比較

| 方式 | 品質 | コスト | 速度 | コンテキスト | 推奨度 |
|------|------|--------|------|-------------|--------|
| **Gemini 2.5 Flash (Free Tier)** | 高 | **$0** | 高速 | 1Mトークン | ★★★★★ |
| **Gemini 2.5 Flash (Paid)** | 高 | $0.30/1M入力, $2.50/1M出力 | 高速 | 1Mトークン | ★★★★☆ |
| Claude API (Haiku 4.5) | 高 | $0.80/1M入力, $4.00/1M出力 | 高速 | 200Kトークン | ★★★☆☆ |
| Claude API (Sonnet 4.5) | 最高 | $3.00/1M入力, $15.00/1M出力 | 中 | 200Kトークン | ★★☆☆☆ |

### 4.2 推奨方式: Gemini 2.5 Flash (Free Tier) + 用語集注入

**選定理由:**

1. **コスト$0**: Free Tierで完全に無料運用可能
2. **十分な制限**: 10 RPM / 250 RPD / 250K TPM — 日次57ページ翻訳に十分
3. **1Mトークンコンテキスト**: 長文ドキュメントも分割不要
4. **思考機能搭載**: 翻訳品質向上に寄与
5. **n8n統合容易**: HTTP RequestノードでREST API直接呼び出し

**Gemini 2.5 Flash Free Tier 制限:**

| 制限項目 | 数値 | 日次同期での使用量 |
|---------|------|------------------|
| RPM (リクエスト/分) | 10 | 最大10（6秒間隔で十分） |
| RPD (リクエスト/日) | 250 | 最大72（57サイト + 15 GitHub） |
| TPM (トークン/分) | 250,000 | 1ページ平均5,000トークン → 余裕 |
| コンテキスト | 1,000,000トークン | 1ページ最大10,000トークン → 余裕 |

### 4.3 n8nからGemini APIを呼ぶノード構成

```
[HTTP Request ノード: Gemini API]
  Method: POST
  URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent
  Authentication: Generic Credential (Header Auth)
    Header Name: x-goog-api-key
    Header Value: {{ $credentials.geminiApiKey }}
  Body (JSON):
  {
    "contents": [{
      "parts": [{
        "text": "{{ $json.translationPrompt }}"
      }]
    }],
    "generationConfig": {
      "temperature": 0.3,
      "maxOutputTokens": 65536
    }
  }
```

**n8n Credentials 設定:**
- Type: Header Auth
- Name: `Gemini API Key`
- Header Name: `x-goog-api-key`
- Header Value: (Google AI Studio で取得した API Key)

### 4.4 翻訳プロンプト

```
あなたは技術ドキュメントの英日翻訳者です。以下のルールに従って翻訳してください。

## 用語集（必ず準拠）
{terminology_content}

## 翻訳ルール
1. 技術用語・プロダクト名・略語は英語のまま（Claude Code, MCP, API, CLI等）
2. コードブロック・コマンド例は翻訳しない
3. Markdownの書式（見出し、リスト、テーブル等）を維持
4. 文体は「です・ます」調
5. 原文の情報を一切省略しない
6. URLは変更しない
7. 出力はMarkdownのみ（説明や注釈は不要）

## 原文
{source_content}
```

### 4.5 差分翻訳フロー

```
1. metadata.json の content_hash を前回値と比較
2. 変更があったページのみ翻訳対象（IF ノードで分岐）
3. Gemini API で翻訳（6秒間隔でレート制限回避）
4. 翻訳結果を ja-JP/site/ に保存
5. translation_hash を更新
6. TRANSLATION_STATUS.md を自動更新
```

### 4.6 翻訳品質管理

- **用語統一**: TERMINOLOGY.md を翻訳プロンプトに注入
- **フォーマット検証**: Code ノードで Markdown 構造チェック
- **文長検証**: 翻訳結果が原文の80%-150%の範囲内であることを確認
- **Paid Tier フォールバック**: Free Tier制限超過時は Paid Tier ($0.30/1M) に自動切替

---

## 5. 自動更新の仕組み（n8n ワークフロー）

### 5.1 n8n ワークフロー全体構成

```
[Schedule Trigger]
  毎日 06:00 JST
      │
      ▼
[HTTP Request: llms.txt取得]
  URL: https://code.claude.com/docs/llms.txt
  Method: GET
      │
      ▼
[Code: ページURL一覧パース]
  llms.txt からURL一覧を抽出
  metadata.json と比較して変更/新規を検知
      │
      ▼
[IF: 変更あり？]
  ├── Yes ──────────────────────────────────┐
  │                                         │
  │   [SplitInBatches: ページ取得]           │
  │     Batch Size: 5                       │
  │         │                               │
  │         ▼                               │
  │   [HTTP Request: ページ取得]             │
  │     URL: {{ $json.pageUrl }}            │
  │     Method: GET                         │
  │         │                               │
  │         ▼                               │
  │   [Code: HTML→Markdown変換 + ハッシュ]   │
  │     markdownify相当の変換               │
  │     SHA-256 ハッシュ計算                 │
  │     metadata.json 更新                  │
  │         │                               │
  │         ▼                               │
  │   [IF: ハッシュ変更あり？]               │
  │     ├── Yes: en/site/ に保存            │
  │     │        翻訳キューに追加            │
  │     └── No: スキップ                    │
  │                                         │
  │   [Merge: 翻訳キュー集約]               │
  │         │                               │
  │         ▼                               │
  │   [SplitInBatches: 翻訳実行]            │
  │     Batch Size: 1                       │
  │     Wait Between: 6000ms (10RPM制限)    │
  │         │                               │
  │         ▼                               │
  │   [Code: プロンプト生成]                 │
  │     TERMINOLOGY.md + 翻訳ルール注入     │
  │         │                               │
  │         ▼                               │
  │   [HTTP Request: Gemini API]            │
  │     POST gemini-2.5-flash              │
  │     Body: 翻訳プロンプト                │
  │         │                               │
  │         ▼                               │
  │   [Code: 翻訳結果処理]                  │
  │     ja-JP/site/ に保存                  │
  │     metadata.json 翻訳ステータス更新    │
  │         │                               │
  │         ▼                               │
  │   [Merge: 結果集約]                     │
  │                                         │
  ├── No ──────────────────────────────────┐│
  │   (変更なし → 通知のみ)                ││
  │                                        ││
  └────────────────────────────────────────┘│
      │                                     │
      ▼                                     │
[Code: レポート生成]  ◄─────────────────────┘
  更新サマリー作成
  metadata.json 最終更新
      │
      ▼
[HTTP Request: Google Chat通知]
  URL: {{ $env.GOOGLE_CHAT_WEBHOOK }}
  Method: POST
  Body: { "text": "{{ $json.report }}" }
      │
      ▼
[NoOp: 完了]
```

### 5.2 主要ノードの設定詳細

#### Schedule Trigger
```json
{
  "rule": {
    "interval": [{"field": "cronExpression", "expression": "0 6 * * *"}]
  }
}
```

#### HTTP Request (llms.txt取得)
```json
{
  "method": "GET",
  "url": "https://code.claude.com/docs/llms.txt",
  "options": {
    "timeout": 30000,
    "response": { "response": { "fullResponse": true } }
  }
}
```

#### Code (ページURL一覧パース)
```javascript
// llms.txt からURLを抽出
const body = $input.first().json.body;
const urls = body.match(/https:\/\/code\.claude\.com\/docs\/en\/[\w-]+/g) || [];

// metadata.json を読み込み（Execute Command で事前に読み込み済み）
const metadata = JSON.parse($('Read Metadata').first().json.stdout || '{}');

const pages = urls.map(url => {
  const slug = url.split('/').pop();
  const existing = metadata.pages?.[`site/${slug}.md`];
  return {
    url,
    slug,
    previousHash: existing?.content_hash || null,
    isNew: !existing
  };
});

return pages.map(p => ({ json: p }));
```

#### HTTP Request (Gemini API)
```json
{
  "method": "POST",
  "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpHeaderAuth",
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "={{ JSON.stringify({ contents: [{ parts: [{ text: $json.translationPrompt }] }], generationConfig: { temperature: 0.3, maxOutputTokens: 65536 } }) }}"
}
```

#### HTTP Request (Google Chat通知)
```json
{
  "method": "POST",
  "url": "={{ $env.GOOGLE_CHAT_WEBHOOK }}",
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "={{ JSON.stringify({ text: $json.report }) }}"
}
```

### 5.3 n8n環境変数・Credentials

| 種別 | 名前 | 値 |
|------|------|-----|
| **Environment Variable** | `GOOGLE_CHAT_WEBHOOK` | Google Chat Webhook URL |
| **Environment Variable** | `DOCS_BASE_PATH` | `~/.claude/docs` |
| **n8n Credential** | `Gemini API Key` | Header Auth (x-goog-api-key) |
| **n8n Credential** | `GitHub API Token` | Header Auth (Authorization: Bearer) |

### 5.4 エラーハンドリング

| エラー | n8nでの対策 |
|--------|-----------|
| HTTP 429 (Rate Limit) | SplitInBatches の Wait Between を 6000ms→12000ms に動的増加。Error Workflow でリトライ |
| HTTP 5xx | Retry on Fail: true, Max Retries: 3, Wait: 30000ms |
| Gemini API エラー | Error Workflow → 該当ページを `pending` ステータスで記録 → 翌日リトライ |
| ネットワーク断 | Error Workflow → Google Chat にエラー通知 → 翌日全差分処理 |
| llms.txt 取得失敗 | IF ノードで分岐 → 前回のページ一覧を使用 |
| Free Tier制限超過 | IF (statusCode === 429) → 残りページを翌日に持ち越し |

### 5.5 n8n MCP サーバーとの連携

既存の n8n MCP サーバー（`.mcp.json` に設定済み）を活用:

- **ワークフロー管理**: n8n MCP の `workflow_get` / `workflow_update` でワークフロー設定を動的変更
- **実行監視**: `execution_get` で日次実行の成否を確認
- **足軽からの操作**: 家老/足軽が n8n MCP ツール経由でワークフローの有効/無効を制御可能

### 5.6 通知テンプレート（Google Chat）

```
📚 Claude Code ドキュメント日次更新レポート
━━━━━━━━━━━━━━━━━━━━━━━
📅 2026-02-15 06:05 JST

📊 更新サマリー
  更新ページ: 3件
  新規ページ: 0件
  削除ページ: 0件
  翻訳完了: 3/3件

📝 更新内容
  - settings.md: 設定スコープの説明更新
  - agent-teams.md: 新規セクション追加
  - changelog.md: v2.1.42 リリースノート

⏱ 実行時間: 2分34秒
💰 翻訳コスト: $0 (Free Tier)
📡 Gemini API: 3/250 RPD使用
```

---

## 6. コスト試算

### 6.1 ドキュメント規模の推定

| 項目 | 数値 |
|------|------|
| 総ページ数 | 57ページ（サイト） + 15ファイル（GitHub） = 72件 |
| 1ページ平均文字数 | 約10,000文字（英語） |
| 総文字数 | 約720,000文字 |
| 推定トークン数（入力） | 約180,000トークン（1文字≒0.25トークン） |
| 推定トークン数（出力） | 約270,000トークン（日本語は英語の1.5倍） |

### 6.2 Gemini 2.5 Flash Free Tier での運用シミュレーション

#### 初回全量翻訳

| 項目 | 数値 | Free Tier制限 | 判定 |
|------|------|-------------|------|
| 総リクエスト数 | 72回 | 250 RPD | OK (29%使用) |
| 総入力トークン | 180,000 | 250,000 TPM | OK (72%/分 — ただし分散実行) |
| 所要時間 | 72回 × 6秒 = 約7.2分 | — | OK |
| **コスト** | **$0** | Free Tier | **完全無料** |

#### 日次差分翻訳

| 想定 | 変更ページ数 | リクエスト/日 | Free Tier使用率 | コスト |
|------|-------------|-------------|----------------|--------|
| **変更なし** | 0ページ | 1 (llms.txt確認のみ) | 0.4% | $0 |
| **少ない変更** | 2-3ページ/日 | 4-7 | 1.6-2.8% | $0 |
| **中程度** | 5ページ/日 | 11 | 4.4% | $0 |
| **大規模更新** | 10ページ/日 | 21 | 8.4% | $0 |
| **全量再翻訳** | 72ページ/日 | 73 | 29.2% | $0 |

### 6.3 年間コスト概算

| プラン | 初回 | 月額 | 年額 |
|--------|------|------|------|
| **Gemini Free Tier (推奨)** | $0 | $0 | **$0** |
| Gemini Paid (フォールバック時) | $0.50 | $0.01-$0.05 | $0.62-$1.10 |
| n8n self-hosted | $0 | $0 | $0 |
| **合計** | **$0** | **$0** | **$0** |

### 6.4 Free Tier vs Paid Tier 比較

| 項目 | Free Tier | Paid Tier |
|------|-----------|-----------|
| 入力コスト | $0 | $0.30/1Mトークン |
| 出力コスト | $0 | $2.50/1Mトークン |
| RPM | 10 | 2,000 |
| RPD | 250 | 無制限 |
| TPM | 250,000 | 1,000,000 |
| コンテキストキャッシュ | 不可 | 可（$0.03/1Mトークン） |
| **日次同期に十分か** | **はい** | はい |
| **推奨** | **通常運用** | Free Tier超過時のフォールバック |

### 6.5 コスト最適化戦略

1. **Free Tier最大活用**: 日次250 RPDのうち最大72しか使わない（29%）
2. **差分翻訳**: 変更ページのみ翻訳（通常は日次5ページ以下 = 2%使用）
3. **6秒間隔**: SplitInBatches の Wait Between で10 RPM制限を確実に回避
4. **Paid自動切替**: Free Tier 429エラー検知時のみ Paid Tier にフォールバック
5. **バッチ翻訳**: 1ページ1リクエスト（1Mコンテキストで分割不要）

---

## 7. 実装スケジュール（参考）

| Phase | 内容 | 詳細 |
|-------|------|------|
| Phase 1 | **n8nワークフロー基盤** | Schedule Trigger + llms.txt取得 + ページ一覧パース + 差分検知 |
| Phase 2 | **収集パイプライン** | HTTP Request ループ + HTML→Markdown変換 + en/保存 + metadata.json管理 |
| Phase 3 | **翻訳パイプライン** | Gemini API呼び出し + 翻訳結果保存 + ja-JP/保存 + 品質チェック |
| Phase 4 | **GitHub API連携** | README/CHANGELOG取得 + Base64デコード + 差分検知 + 翻訳 |
| Phase 5 | **通知 + 統合テスト** | Google Chat通知 + Error Workflow + 全体テスト + n8n MCP連携 |

Phase 1-4は独立して並列実行可能。Phase 5は全Phase完了後。

---

## 8. リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| **Gemini Free Tier制限変更** | 翻訳不可 | Paid Tier自動フォールバック（$0.30/1M）、月額上限$1設定 |
| **Gemini Free Tier廃止** | 翻訳コスト発生 | Paid Tier ($0.50/月程度)、またはClaude API Haikuに切替 |
| code.claude.com HTML構造変更 | 収集失敗 | llms.txt ベースで影響最小化 |
| llms.txt の廃止・URL変更 | ページ一覧取得不可 | sitemap.xml へのフォールバック、手動URL登録 |
| **n8n サーバー停止** | 日次更新停止 | systemd による自動再起動、Error通知で検知 |
| **n8n ワークフロー障害** | 部分的失敗 | Error Workflow で障害ページを特定 → 翌日リトライ |
| 翻訳品質の劣化 | 誤訳 | TERMINOLOGY.md、文長検証、temperature=0.3で安定性確保 |
| ドキュメント大規模改変 | 全量再翻訳 | Free Tier内で72ページ翻訳可能（29%使用）、問題なし |
| GitHub API レート制限 | 取得失敗 | 認証トークン使用（5,000 RPH）、差分取得で呼び出し最小化 |
