# cmd_161: Claude Code公式ドキュメント自動収集・和訳・日次更新システム設計書

## 概要

Claude Code公式ドキュメント（約57ページ）を自動収集・体系整理・和訳し、1日1回更新する仕組みを設計する。
既存のECC日本語翻訳資産（147ファイル, 35,702行）との統合を前提とする。

**対象**: Claude Code公式ドキュメント（code.claude.com/docs）
**動作環境**: WSL2 (Ubuntu) + Python 3.10+
**更新頻度**: 1日1回（cron）

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
| **llms.txt + WebFetch** | 公式提供のインデックス、構造化済み、安定 | HTML→Markdownの変換品質に依存 | ★★★★★ |
| **GitHub API** | 構造化データ、レート制限内で安定 | ドキュメントサイトのコンテンツは含まない | ★★★★☆ |
| **Scrapy/BeautifulSoup** | 柔軟、全ページ取得可能 | メンテナンスコスト高、HTML構造変更に弱い | ★★★☆☆ |
| **Playwright** | JavaScript描画後のコンテンツ取得可能 | リソース消費大、速度遅 | ★★☆☆☆ |

### 2.2 推奨方式: ハイブリッド2層収集

```
Layer 1: llms.txt インデックス取得 (公式ドキュメント)
         ↓ ページURL一覧を取得
         ↓ 各ページを requests + markdownify で取得
         ↓ Markdown変換して保存

Layer 2: GitHub API (リポジトリドキュメント)
         ↓ gh api repos/anthropics/claude-code/contents
         ↓ README, CHANGELOG, plugins/ を取得
         ↓ Base64デコードして保存
```

### 2.3 変更差分検知

| 方式 | 対象 | 実装 |
|------|------|------|
| **コンテンツハッシュ** | 全ソース | SHA-256(本文) を metadata.json に記録。変更時のみ更新 |
| **HTTP ETag / Last-Modified** | Webページ | レスポンスヘッダーを保存。304 Not Modified で帯域節約 |
| **GitHub API commits** | GitHubファイル | 最新コミットSHAを比較。変更ファイルのみ再取得 |
| **llms.txt diff** | ページ一覧 | 前回取得分と比較。新規・削除ページを検知 |

### 2.4 技術スタック

```python
# 収集
requests          # HTTP クライアント
markdownify       # HTML → Markdown 変換
PyGithub          # GitHub API ラッパー（または gh CLI）

# 差分検知
hashlib           # SHA-256 ハッシュ
json              # メタデータ管理

# 翻訳
anthropic         # Claude API クライアント

# 自動化
cron              # スケジューリング（WSL2 systemd有効時）
```

---

## 3. フォルダ構成設計

### 3.1 ディレクトリ構造

```
~/.claude/docs/
├── sync/                          # 自動収集システム
│   ├── config.yaml                # 設定ファイル
│   ├── metadata.json              # ハッシュ・更新日時・翻訳ステータス
│   ├── sync_docs.py               # メインスクリプト
│   ├── translate.py               # 翻訳スクリプト
│   ├── notify.py                  # 通知スクリプト
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

### 4.1 翻訳方式の比較

| 方式 | 品質 | コスト | 速度 | 一貫性 |
|------|------|--------|------|--------|
| **Claude API (Haiku 4.5)** | 高 | 低 ($0.25/100万入力) | 高速 | 高（プロンプトで制御） |
| **Claude API (Sonnet 4.5)** | 最高 | 中 ($3/100万入力) | 中 | 最高 |
| **足軽による手動翻訳** | 最高 | 高（エージェント時間） | 低 | 用語集依存 |
| **Google Translate API** | 中 | 低 | 最速 | 低 |

### 4.2 推奨方式: Claude API (Haiku 4.5) + 用語集注入

```python
TRANSLATION_PROMPT = """
あなたは技術ドキュメントの日英翻訳者です。以下のルールに従って翻訳してください。

## 用語集（必ず準拠）
{terminology_content}

## 翻訳ルール
1. 技術用語・プロダクト名・略語は英語のまま
2. コードブロック・コマンド例は翻訳しない
3. Markdownの書式（見出し、リスト、テーブル等）を維持
4. 文体は「です・ます」調
5. 原文の情報を一切省略しない
6. URLは変更しない

## 原文
{source_content}
"""
```

### 4.3 差分翻訳フロー

```
1. metadata.json の content_hash を前回値と比較
2. 変更があったページのみ翻訳対象
3. 翻訳結果を ja-JP/site/ に保存
4. translation_hash を更新
5. TRANSLATION_STATUS.md を自動更新
```

### 4.4 翻訳品質管理

- **用語統一**: TERMINOLOGY.md を翻訳プロンプトに注入
- **フォーマット検証**: markdownlint で翻訳後のMDを検証
- **文字化け検知**: 翻訳結果にASCII外の制御文字がないことを確認
- **長さ検証**: 翻訳結果が原文の80%-150%の範囲内であることを確認

---

## 5. 自動更新の仕組み

### 5.1 実行フロー

```
┌──────────────────────────────────────────┐
│         日次cron (毎朝 06:00 JST)          │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Step 1: llms.txt 取得                    │
│  - ページ一覧の差分チェック               │
│  - 新規ページ検知 / 削除ページ検知         │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Step 2: 変更ページ取得                    │
│  - HTTP GET + ETag 比較                   │
│  - HTML → Markdown 変換                   │
│  - content_hash 計算・比較                 │
│  - 変更のあったページのみ en/ に保存        │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Step 3: GitHub API 取得                   │
│  - README, CHANGELOG のコミットSHA比較     │
│  - 変更ファイルのみ取得・保存              │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Step 4: 差分翻訳                          │
│  - content_hash が変化したページのみ        │
│  - Claude API (Haiku 4.5) で翻訳          │
│  - 翻訳結果を ja-JP/site/ に保存           │
│  - TRANSLATION_STATUS.md 更新              │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Step 5: 通知                              │
│  - 変更サマリーを生成                      │
│  - Google Chat Webhook 送信                │
│  - 実行ログを logs/ に保存                 │
└──────────────────────────────────────────┘
```

### 5.2 スケジューリング

```bash
# crontab -e
0 6 * * * /home/saneaki/.claude/docs/sync/sync_docs.py >> /home/saneaki/.claude/docs/sync/logs/cron.log 2>&1
```

代替案（WSL2でcronが不安定な場合）:
- **n8n ワークフロー**: HTTP Request → Code Node (Python) → Google Chat
- **systemd timer**: WSL2でsystemd有効化済みの場合

### 5.3 エラーハンドリング

| エラー | 対策 |
|--------|------|
| HTTP 429 (Rate Limit) | 指数バックオフ（初回30秒、最大5分、3回リトライ） |
| HTTP 5xx | 30秒後リトライ、3回失敗で該当ページスキップ |
| Claude API エラー | 5回リトライ、失敗ページは `pending` ステータスのまま次回に持ち越し |
| ネットワーク断 | 全体をスキップ、次回実行時に全差分を処理 |
| llms.txt 取得失敗 | 前回のページ一覧を使用（新規ページ検知のみスキップ） |

### 5.4 通知テンプレート（Google Chat）

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
💰 翻訳コスト: $0.012
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

### 6.2 全量翻訳コスト（初回）

| モデル | 入力単価 | 出力単価 | 入力コスト | 出力コスト | 合計 |
|--------|----------|----------|-----------|-----------|------|
| **Haiku 4.5** | $0.80/1M | $4.00/1M | $0.14 | $1.08 | **$1.22** |
| **Sonnet 4.5** | $3.00/1M | $15.00/1M | $0.54 | $4.05 | **$4.59** |
| **Opus 4.5** | $15.00/1M | $75.00/1M | $2.70 | $20.25 | **$22.95** |

### 6.3 差分翻訳コスト（日次）

| 想定 | 変更ページ数 | Haiku月額 | Sonnet月額 |
|------|-------------|----------|-----------|
| **少ない変更** (週1-2ページ) | 2ページ/週 | **$0.14/月** | **$0.52/月** |
| **中程度の変更** (週5ページ) | 5ページ/週 | **$0.34/月** | **$1.30/月** |
| **大規模更新** (週10ページ) | 10ページ/週 | **$0.69/月** | **$2.61/月** |

### 6.4 年間コスト概算

| プラン | 初回 | 月額 | 年額 |
|--------|------|------|------|
| **Haiku (推奨)** | $1.22 | $0.14 - $0.69 | **$2.90 - $9.50** |
| **Sonnet** | $4.59 | $0.52 - $2.61 | **$10.83 - $35.91** |

### 6.5 コスト最適化戦略

1. **差分翻訳**: 変更ページのみ翻訳（最大95%のコスト削減）
2. **Haiku 4.5使用**: Sonnet比で1/4のコスト（品質は技術翻訳に十分）
3. **バッチ処理**: 小変更は蓄積して週1回まとめて翻訳（API呼び出し削減）
4. **キャッシュ**: 翻訳結果をハッシュで管理し、同一内容の再翻訳を防止
5. **プロンプトキャッシュ**: 用語集+翻訳ルール部分をキャッシュ（入力トークン90%削減）

---

## 7. 実装スケジュール（参考）

| Phase | 内容 | 見積もり |
|-------|------|---------|
| Phase 1 | 収集スクリプト（llms.txt + GitHub API） | 足軽1名 |
| Phase 2 | 差分検知 + メタデータ管理 | 足軽1名 |
| Phase 3 | 翻訳スクリプト（Claude API） | 足軽1名 |
| Phase 4 | 通知 + cron設定 + 統合テスト | 足軽1名 |

Phase 1-3は独立して並列実行可能。Phase 4は全Phase完了後。

---

## 8. リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| code.claude.com のHTML構造変更 | 収集失敗 | llms.txt ベースで影響最小化、markdownifyのフォールバック |
| llms.txt の廃止・URL変更 | ページ一覧取得不可 | sitemap.xml へのフォールバック、手動URL登録 |
| Claude API のレート制限 | 翻訳遅延 | バッチ処理、指数バックオフ、翌日持ち越し |
| 翻訳品質の劣化 | 誤訳 | TERMINOLOGY.md による用語統一、文長検証、手動レビュー |
| WSL2でのcron不安定 | 実行漏れ | n8n ワークフローへの代替、systemd timer |
| ドキュメント大規模改変 | 全量再翻訳 | ハッシュベースで変更ページのみ翻訳、コスト上限設定 |
