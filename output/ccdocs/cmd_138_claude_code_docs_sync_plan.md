# Claude Code Docs 自動収集・和訳システム 実装計画書

> **cmd_138** | 作成日: 2026-02-15 | 統合担当: ashigaru7
>
> 本計画書は3サブタスクの調査・設計報告（138a: llms.txt調査、138b: n8n技術設計、138c: 翻訳設計）を
> INTEG-001手順で矛盾検出・統合し、最終実装計画を策定したものである。

---

## 前提の整合確認（INTEG-001）

### 入力レポート

| レポート | 担当 | 内容 |
|----------|------|------|
| subtask_138a | ashigaru8 | llms.txt調査、ページ構造分析、トークン数実測 |
| subtask_138b | ashigaru8 | n8n技術設計、WF1/WF2ノード構成、metadata.json、インフラ設計 |
| subtask_138c | ashigaru7 | 翻訳プロンプト設計、品質検証、エラーハンドリング、通知、コスト |

### 矛盾検出と解決

| # | 項目 | 報告間の差異 | 解決 |
|---|------|-------------|------|
| 1 | Geminiモデル | 138a: gemini-2.5-flash ($0.15/$0.60) / 将軍指定+138c: gemini-2.5-flash-lite ($0.10/$0.40) | **将軍指定+138cが正**。flash-liteを採用。コスト見積もりは$0.10/$0.40で統一 |
| 2 | 出力トークン倍率 | 138a: 入力の1.5倍 / 138c: 入力の1.2倍 | **138cが正**。日本語はバイト数は増えるがトークン数の増加は1.2倍が妥当。1.5倍は文字数ベースの過大見積もり |
| 3 | Split In Batches使用 | 138b: Split In Batches使用 / cmd_135: Split In Batchesアンチパターン検出 | **矛盾なし**。cmd_135はmain[0]/main[1]の誤用。138bはintervalによるAPI Rate Limit対策目的であり正当な使用。計画書で明記 |
| 4 | エラーハンドリング方式 | 138b: Error Handlerノード / 138c: continueOnFail + retryOnFail | **統合**。両方式は併用可能。HTTP RequestノードにcontinueOnFail+retryOnFail設定、WF末尾にError Handlerノードで集約通知 |
| 5 | metadata.jsonスキーマ | 138b: 簡素構造(lastSync, pages, github) / 138c: 詳細構造(version, docs.pages, github.files, stats) | **138cを採用**。バージョニング・統計情報を含む方が運用に有利。138bのstatus/warningsフィールドも組み込む |
| 6 | ページ分割方式 | 138a: "---"区切り / 138b: "# "見出し区切り | **138b（# 見出し区切り）を採用**。llms-full.txtの実際の区切りはh1見出し。138aの"---"はMarkdown水平線と混同の可能性 |
| 7 | ディレクトリ構成 | 138b: en/site/ + ja-JP/site/ + en/github/ + ja-JP/github/ / 138c(138bの引用): docs/{category}/ + github/ | **138bを採用**。英語原文キャッシュ（en/）の保持は差分検知とデバッグに有用。カテゴリ分類はmetadata.jsonで管理し、ディスク上はフラット |
| 8 | WF1ノード数 | 138b: 15ノード / 138c: 品質検証+リトライで追加3ノード | **統合**: 18ノード（138bの15 + 138cの品質検証3ノード追加） |

### 全報告共通の前提（整合確認済み）

- ソースURL: `https://code.claude.com/docs/llms-full.txt`（全57ページ一括）
- 翻訳モデル: `gemini-2.5-flash-lite`（$0.10/1M input, $0.40/1M output）
- MDXタグ処理: 方式A（タグ保持、Geminiに翻訳時の保持を指示）
- TERMINOLOGY.md: 全量プロンプト注入（72エントリ/~1,800トークン）
- 差分検知: DJB2ハッシュ（n8n Code Nodeサンドボックスでcrypto不可のため）
- ファイルI/O: ReadWriteFileノード（ディスク直接I/O）
- 通知: Telegram Bot API

---

## 1. システム概要

### 1.1 アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────────┐
│                    n8n (Docker Container)                       │
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────┐          │
│  │   WF1: Docs同期       │    │   WF2: GitHub同期     │          │
│  │   (日次 AM3:00 JST)   │    │   (日次 AM4:00 JST)   │          │
│  │                       │    │                       │          │
│  │  llms-full.txt取得    │    │  GitHub API取得       │          │
│  │  → ページ分割          │    │  → SHA比較             │          │
│  │  → ハッシュ差分検知    │    │  → ファイル差分検知    │          │
│  │  → Gemini翻訳         │    │  → Gemini翻訳         │          │
│  │  → 品質検証            │    │  → 品質検証            │          │
│  │  → ファイル保存        │    │  → ファイル保存        │          │
│  │  → metadata更新       │    │  → metadata更新       │          │
│  │  → Telegram通知       │    │  → Telegram通知       │          │
│  └──────────┬────────────┘    └──────────┬────────────┘          │
│             │                            │                      │
│             v                            v                      │
│  ┌──────────────────────────────────────────────────┐          │
│  │  /data/claude-code-docs (バインドマウント)         │          │
│  │  ├── en/site/*.md        (英語原文キャッシュ)     │          │
│  │  ├── ja-JP/site/*.md     (翻訳済みDocs)          │          │
│  │  ├── en/github/*.md      (GitHub原文キャッシュ)   │          │
│  │  ├── ja-JP/github/*.md   (翻訳済みGitHub)        │          │
│  │  └── metadata.json       (同期状態管理)           │          │
│  └──────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
          │                              │
          v                              v
┌──────────────────┐          ┌──────────────────┐
│ code.claude.com  │          │ GitHub API       │
│ llms-full.txt    │          │ anthropics/      │
│ llms.txt         │          │   claude-code    │
└──────────────────┘          └──────────────────┘
          │
          v
┌──────────────────┐          ┌──────────────────┐
│ Gemini API       │          │ Telegram Bot API │
│ 2.5-flash-lite   │          │ 通知送信          │
└──────────────────┘          └──────────────────┘
```

### 1.2 データフロー概要

| ステップ | WF1 (Docs) | WF2 (GitHub) |
|----------|-----------|-------------|
| 1. 取得 | llms-full.txt一括取得 | GitHub API 4ファイル取得 |
| 2. 分割 | h1見出しでページ分割 | ファイル単位（分割不要） |
| 3. 差分 | DJB2ハッシュ比較 | コミットSHA + DJB2比較 |
| 4. 翻訳 | Gemini API (バッチ3件/5秒間隔) | Gemini API (個別) |
| 5. 検証 | V1-V5品質チェック | V1-V5品質チェック |
| 6. 保存 | en/ + ja-JP/ に書込み | en/ + ja-JP/ に書込み |
| 7. 更新 | metadata.json更新 | metadata.json更新 |
| 8. 通知 | Telegram (変更時のみ) | Telegram (変更時のみ) |

---

## 2. WF1 詳細設計（Docs同期 — 18ノード）

### 2.1 ノード接続フロー

```
Schedule Trigger (AM3:00 JST)
  │
  ├─[並列]─> GET llms.txt ──> Build Slug Map (Code)
  │
  ├─[並列]─> GET llms-full.txt
  │
  └─[並列]─> Read Metadata (ReadWriteFile)
                │
                v
         Merge Input Data (3入力統合)
                │
                v
         Split Pages & Detect Changes (Code)
                │
                v
         Filter Changed Pages (Filter: changed===true)
                │
                ├─[0件]─> Build No-Change Note (Code) ─> [END]
                │
                └─[1件以上]─> Batch Pages (SplitInBatches: 3件/5秒)
                                │
                                v
                         Build Translation Prompt (Code)
                                │
                                v
                         Gemini Translate (HTTP Request)
                                │
                                v
                         Validate Translation (Code)
                                │
                                v
                         IF Retry Needed
                           ├─[retry && count<2]─> Increment Counter ─> [Build Translation Prompt へ戻る]
                           └─[pass or maxRetry]
                                │
                                v
                         Write English Original (ReadWriteFile)
                                │
                                v
                         Write Translated Page (ReadWriteFile)
                                │
                         [バッチ完了後]
                                │
                                v
                         Update Metadata (Code)
                                │
                                v
                         Write Metadata (ReadWriteFile)
                                │
                                v
                         Build Notification (Code)
                                │
                                v
                         Send Telegram (HTTP Request)
```

### 2.2 全18ノード設計

#### Node 1: Schedule Trigger

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Schedule Trigger` |
| **タイプ** | `n8n-nodes-base.scheduleTrigger` |
| **cron** | `0 3 * * *` (毎日AM3:00 JST) |

#### Node 2: GET llms.txt

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `GET llms.txt` |
| **タイプ** | `n8n-nodes-base.httpRequest` (v4.2) |
| **method** | GET |
| **url** | `https://code.claude.com/docs/llms.txt` |
| **responseFormat** | text |
| **timeout** | 30000 |
| **continueOnFail** | true |
| **retryOnFail** | true / maxTries: 2 / waitBetweenTries: 60000 |

#### Node 3: GET llms-full.txt

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `GET llms-full.txt` |
| **タイプ** | `n8n-nodes-base.httpRequest` (v4.2) |
| **method** | GET |
| **url** | `https://code.claude.com/docs/llms-full.txt` |
| **responseFormat** | text |
| **timeout** | 60000 |
| **continueOnFail** | true |
| **retryOnFail** | true / maxTries: 2 / waitBetweenTries: 60000 |

#### Node 4: Read Metadata

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Read Metadata` |
| **タイプ** | `n8n-nodes-base.readWriteFile` |
| **operation** | read |
| **filePath** | `/data/claude-code-docs/metadata.json` |
| **encoding** | utf8 |
| **continueOnFail** | true (初回実行時はファイル不在) |

#### Node 5: Build Slug Map

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Build Slug Map` |
| **タイプ** | `n8n-nodes-base.code` (v2) |
| **mode** | Run Once for All Items |
| **入力** | Node 2 (GET llms.txt) |
| **コード** | §5.1 参照 |

#### Node 6: Merge Input Data

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Merge Input Data` |
| **タイプ** | `n8n-nodes-base.merge` |
| **mode** | Combine by Position |
| **入力** | Node 3 (llms-full.txt) + Node 4 (Metadata) + Node 5 (Slug Map) |

#### Node 7: Split Pages & Detect Changes

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Split Pages & Detect Changes` |
| **タイプ** | `n8n-nodes-base.code` (v2) |
| **mode** | Run Once for All Items |
| **コード** | §5.2 参照 |
| **出力** | 57アイテム（各ページのslug, title, content, hash, changed） |

#### Node 8: Filter Changed Pages

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Filter Changed Pages` |
| **タイプ** | `n8n-nodes-base.filter` |
| **条件** | `changed === true` |
| **alwaysOutputData** | true (0件でも次ノードへ) |

#### Node 9: Batch Pages

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Batch Pages` |
| **タイプ** | `n8n-nodes-base.splitInBatches` |
| **batchSize** | 3 |
| **注記** | API Rate Limit対策。main[0]=バッチ完了後、main[1]=各バッチ。cmd_135のアンチパターン（main[0]/[1]誤用）とは異なる正当な使用 |

#### Node 10: Build Translation Prompt

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Build Translation Prompt` |
| **タイプ** | `n8n-nodes-base.code` (v2) |
| **mode** | Run Once for Each Item |
| **コード** | §5.3 参照 |

#### Node 11: Gemini Translate

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Gemini Translate` |
| **タイプ** | `n8n-nodes-base.httpRequest` (v4.2) |
| **method** | POST |
| **url** | `=https://generativelanguage.googleapis.com/v1beta/models/{{ $env.GEMINI_DOCS_MODEL }}:generateContent?key={{ $env.GEMINI_API_KEY }}` |
| **contentType** | json |
| **body** | §5.4 参照 |
| **timeout** | 120000 |
| **continueOnFail** | true |
| **retryOnFail** | true / maxTries: 3 / waitBetweenTries: 10000 |
| **batching** | interval: 5000ms |

#### Node 12: Validate Translation

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Validate Translation` |
| **タイプ** | `n8n-nodes-base.code` (v2) |
| **mode** | Run Once for Each Item |
| **コード** | §5.5 参照 |

#### Node 13: IF Retry Needed

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `IF Retry Needed` |
| **タイプ** | `n8n-nodes-base.if` |
| **条件** | `needsRetry === true AND retryCount < 2` |
| **true出力** | Node 10 (Build Translation Prompt) へ戻る |
| **false出力** | Node 14 (Write English Original) へ |

#### Node 14: Write English Original

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Write English Original` |
| **タイプ** | `n8n-nodes-base.readWriteFile` |
| **operation** | write |
| **filePath** | `=/data/claude-code-docs/en/site/{{ $json.slug }}.md` |
| **fileContent** | `={{ $json.originalContent }}` |

#### Node 15: Write Translated Page

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Write Translated Page` |
| **タイプ** | `n8n-nodes-base.readWriteFile` |
| **operation** | write |
| **filePath** | `=/data/claude-code-docs/ja-JP/site/{{ $json.slug }}.md` |
| **fileContent** | `={{ $json.translatedContent }}` |

#### Node 16: Update Metadata

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Update Metadata` |
| **タイプ** | `n8n-nodes-base.code` (v2) |
| **mode** | Run Once for All Items |
| **コード** | §5.6 参照 |

#### Node 17: Write Metadata

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Write Metadata` |
| **タイプ** | `n8n-nodes-base.readWriteFile` |
| **operation** | write |
| **filePath** | `/data/claude-code-docs/metadata.json` |
| **fileContent** | `={{ $json.fileContent }}` |

#### Node 18: Build & Send Notification

| 項目 | 設定値 |
|------|--------|
| **ノード名** | `Build & Send Notification` |
| **タイプ** | `n8n-nodes-base.httpRequest` (v4.2) |
| **method** | POST |
| **url** | `=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage` |
| **body** | §5.7 参照 |
| **continueOnFail** | true |

---

## 3. WF2 詳細設計（GitHub同期 — 12ノード）

### 3.1 ノード接続フロー

```
Schedule Trigger (AM4:00 JST)
  │
  ├─[並列]─> Read Metadata (ReadWriteFile)
  │
  └─[並列]─> GET Latest Commit SHA (GitHub API)
                │
                v
         Compare SHA (Code)
                │
                v
         IF SHA Changed
           ├─[false]─> [END]
           └─[true]
                │
                v
         Generate File List (Code: 4ファイルURL生成)
                │
                v
         Fetch GitHub File (HTTP Request)
                │
                v
         Detect File Changes (Code: DJB2ハッシュ比較)
                │
                v
         Filter Changed Files (Filter: changed===true)
                │
                v
         Build Translation Prompt (Code)
                │
                v
         Gemini Translate (HTTP Request)
                │
                v
         Write Files (Code + ReadWriteFile: en/ + ja-JP/)
                │
                v
         Update & Write Metadata (Code + ReadWriteFile)
                │
                v
         Send Telegram Notification (HTTP Request)
```

### 3.2 対象ファイル

| ファイル | raw URL | 優先度 |
|---------|---------|--------|
| README.md | `https://raw.githubusercontent.com/anthropics/claude-code/main/README.md` | 高 |
| CHANGELOG.md | 同上パターン | 高（差分のみ翻訳: 最新3バージョン） |
| SECURITY.md | 同上パターン | 中 |
| plugins/README.md | 同上パターン | 高 |

---

## 4. metadata.json 設計

### 4.1 JSON Schema（統合版）

138cの詳細スキーマに138bのstatus/warningsフィールドを統合:

```json
{
  "version": "1.0.0",
  "last_sync_timestamp": null,
  "docs": {
    "source_hash": null,
    "pages": {}
  },
  "github": {
    "commit_sha": null,
    "files": {}
  },
  "stats": {
    "total_pages": 0,
    "total_tokens": 0,
    "last_full_sync": null
  }
}
```

**ページエントリ構造** (`docs.pages[slug]`):

```json
{
  "hash": "DJB2ハッシュ値(8桁hex)",
  "last_updated": "ISO8601",
  "token_count": 4681,
  "byte_size": 18724,
  "status": "ok|pending|warning",
  "warnings": []
}
```

**GitHubエントリ構造** (`github.files[path]`):

```json
{
  "hash": "DJB2ハッシュ値",
  "last_updated": "ISO8601",
  "status": "ok|pending|warning"
}
```

---

## 5. Code Node 実装コード

### 5.1 Build Slug Map

```javascript
// n8n Code Node: llms.txtからtitle→slugマッピング構築
// モード: Run Once for All Items
const llmsTxt = $input.first().json.data;
const lines = llmsTxt.split('\n');
const slugMap = {};

for (const line of lines) {
  // 形式: - [Title](https://code.claude.com/docs/en/{slug}.md): Description
  const match = line.match(/^- \[(.+?)\]\(https:\/\/code\.claude\.com\/docs\/en\/(.+?)\.md\)/);
  if (match) {
    slugMap[match[1]] = match[2]; // title → slug
  }
}

return [{ json: { slugMap, totalEntries: Object.keys(slugMap).length } }];
```

### 5.2 Split Pages & Detect Changes

```javascript
// n8n Code Node: llms-full.txt分割 + DJB2ハッシュ + 差分検知
// モード: Run Once for All Items
const fullText = $input.first().json.fullText;
const slugMap = $input.first().json.slugMap;
let metadata;
try {
  metadata = JSON.parse($input.first().json.metadataRaw);
} catch {
  metadata = { docs: { pages: {} } };
}

// DJB2ハッシュ（crypto不要 — n8n Code Nodeサンドボックス対応）
function djb2Hash(str) {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash) + str.charCodeAt(i);
    hash = hash & 0x7FFFFFFF;
  }
  return hash.toString(16).padStart(8, '0');
}

// ページ分割（h1見出しで分割）
const pages = [];
const lines = fullText.split('\n');
let currentTitle = null;
let currentLines = [];

for (const line of lines) {
  if (/^# [^#]/.test(line)) {
    if (currentTitle !== null) {
      pages.push({ title: currentTitle, content: currentLines.join('\n').trim() });
    }
    currentTitle = line.replace(/^# /, '').trim();
    currentLines = [line];
  } else {
    currentLines.push(line);
  }
}
if (currentTitle !== null) {
  pages.push({ title: currentTitle, content: currentLines.join('\n').trim() });
}

// 差分検知 + メタデータ付与
const result = pages.map(page => {
  const slug = slugMap[page.title] || page.title.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const hash = djb2Hash(page.content);
  const byteSize = new TextEncoder().encode(page.content).length;
  const tokenEstimate = Math.ceil(byteSize / 4);
  const prevHash = metadata.docs?.pages?.[slug]?.hash || null;
  const changed = prevHash !== hash;
  const isNew = prevHash === null;

  return {
    json: {
      slug, title: page.title, content: page.content,
      hash, byteSize, tokenEstimate, changed, isNew, prevHash,
      retryCount: 0
    }
  };
});

return result;
```

### 5.3 Build Translation Prompt

```javascript
// n8n Code Node: 翻訳プロンプト構築（TERMINOLOGY.md全量注入版）
// モード: Run Once for Each Item
const page = $input.item.json;

const systemPrompt = `あなたはClaude Code公式ドキュメントの日本語翻訳者です。
以下のルールに厳密に従い、提供されたMarkdownページを日本語に翻訳してください。

===== 翻訳ルール =====

【基本ルール】
1. Markdownの書式（見出し#, リスト-, テーブル|, コードブロック\`\`\`, リンク[](), 画像![]()）はそのまま維持
2. コードブロック（\`\`\`で囲まれた部分）内のコード・コマンドは一切翻訳しない。コメントのみ日本語化してよい
3. インラインコード（\`で囲まれた部分）は翻訳しない
4. URLは一切変更しない
5. 出力はMarkdownテキストのみ。説明文・補足・メタ情報は一切付与しない
6. 原文にない情報を追加しない

【MDXタグ保持ルール】
以下のMDXタグはタグ名と構造をそのまま維持し、テキスト部分とtitle属性値のみ翻訳:
<Tabs>, <Tab title="...">, <Note>, <Warning>, <Frame>, <Info>

【用語統一ルール（TERMINOLOGY.md準拠）】
■ 英語のまま: API, CLI, IDE, MCP, Agent, Hook, commit, PR, fork, Lint, Supabase, Redis, Playwright, TypeScript, JavaScript, Go, React, Next.js, PostgreSQL, Goroutine, Channel, Mutex, Struct, Mock, Stub, Fixture, CI/CD, OWASP, XSS, CSRF
■ カタカナ: プラグイン, トークン, スキル, コマンド, ルール, ワークフロー, コードベース, カバレッジ, ビルド, デバッグ, デプロイ, ブランチ, マージ, リポジトリ, リファクタリング, デッドコード, コードレビュー, ベストプラクティス, フォールバック, キャッシュ, スキーマ, マイグレーション, パイプライン
■ 略語初出時展開: TDD（テスト駆動開発）, E2E（エンドツーエンド）, RLS（行レベルセキュリティ）`;

const userPrompt = `===== 翻訳対象ページ =====
ページタイトル: ${page.title}
スラッグ: ${page.slug}

--- 原文ここから ---
${page.content}
--- 原文ここまで ---`;

return {
  json: {
    ...page,
    originalContent: page.content,
    prompt: systemPrompt + '\n\n' + userPrompt
  }
};
```

### 5.4 Gemini API Request Body

```json
{
  "contents": [
    {
      "parts": [
        { "text": "={{ $json.prompt }}" }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.1,
    "maxOutputTokens": 65536,
    "responseMimeType": "text/plain"
  }
}
```

### 5.5 Validate Translation

```javascript
// n8n Code Node: 翻訳品質検証（V1-V5）
// モード: Run Once for Each Item
const item = $input.item.json;
const original = item.originalContent;

// Gemini応答からテキスト抽出
const translated = item.candidates?.[0]?.content?.parts?.[0]?.text || '';
const warnings = [];
let needsRetry = false;
let retryCount = item.retryCount || 0;

// V1: 非空チェック
if (!translated || translated.trim().length === 0) {
  needsRetry = true;
  warnings.push('V1_FAIL: 翻訳結果が空');
}

if (translated && translated.trim().length > 0) {
  // V2: 見出し数一致（±1許容）
  const origH = (original.match(/^#{1,6}\s/gm) || []).length;
  const transH = (translated.match(/^#{1,6}\s/gm) || []).length;
  if (Math.abs(origH - transH) > 1) {
    warnings.push(`V2_WARN: 見出し数不一致 (原文=${origH}, 翻訳=${transH})`);
    needsRetry = true;
  }

  // V3: コードブロック保持
  const origCB = (original.match(/```/g) || []).length;
  const transCB = (translated.match(/```/g) || []).length;
  if (origCB !== transCB) {
    warnings.push(`V3_WARN: コードブロック数不一致 (原文=${origCB}, 翻訳=${transCB})`);
    needsRetry = true;
  }

  // V4: URL保持
  const urlRegex = /https?:\/\/[^\s\)>\]]+/g;
  const origUrls = [...new Set(original.match(urlRegex) || [])];
  const missingUrls = origUrls.filter(u => !translated.includes(u));
  if (missingUrls.length > 0) {
    warnings.push(`V4_WARN: URL欠落 ${missingUrls.length}件`);
  }

  // V5: MDXタグ保持
  const tagRegex = /<\/?(Tabs|Tab|Note|Warning|Frame|Info)[^>]*>/g;
  const origTags = (original.match(tagRegex) || []).length;
  const transTags = (translated.match(tagRegex) || []).length;
  if (origTags !== transTags) {
    warnings.push(`V5_WARN: MDXタグ数不一致 (原文=${origTags}, 翻訳=${transTags})`);
  }
}

// リトライ判定（max 2回）
if (needsRetry && retryCount >= 2) {
  needsRetry = false; // 最大リトライ超過 → WARNING付きで保存
  warnings.push('MAX_RETRY: リトライ上限到達、WARNING付きで保存');
}

return {
  json: {
    slug: item.slug,
    title: item.title,
    hash: item.hash,
    byteSize: item.byteSize,
    tokenEstimate: item.tokenEstimate,
    originalContent: original,
    translatedContent: translated,
    isNew: item.isNew,
    changed: item.changed,
    retryCount: retryCount + (needsRetry ? 1 : 0),
    needsRetry,
    status: warnings.length === 0 ? 'ok' : (needsRetry ? 'pending' : 'warning'),
    warnings
  }
};
```

### 5.6 Update Metadata

```javascript
// n8n Code Node: metadata.json更新
// モード: Run Once for All Items
const items = $input.all();
const now = new Date().toISOString();

let metadata;
try {
  metadata = JSON.parse($('Read Metadata').first().json.data);
} catch {
  metadata = {
    version: '1.0.0',
    last_sync_timestamp: null,
    docs: { source_hash: null, pages: {} },
    github: { commit_sha: null, files: {} },
    stats: { total_pages: 0, total_tokens: 0, last_full_sync: null }
  };
}

for (const item of items) {
  const page = item.json;
  metadata.docs.pages[page.slug] = {
    hash: page.hash,
    last_updated: now,
    token_count: page.tokenEstimate,
    byte_size: page.byteSize,
    status: page.status || 'ok',
    warnings: page.warnings || []
  };
}

metadata.last_sync_timestamp = now;
metadata.stats.total_pages = Object.keys(metadata.docs.pages).length;
metadata.stats.total_tokens = Object.values(metadata.docs.pages)
  .reduce((sum, p) => sum + (p.token_count || 0), 0);
if (items.length > 0) {
  metadata.stats.last_full_sync = now;
}

return [{
  json: {
    filePath: '/data/claude-code-docs/metadata.json',
    fileContent: JSON.stringify(metadata, null, 2)
  }
}];
```

### 5.7 Build Notification Message

```javascript
// n8n Code Node: Telegram通知メッセージ構築
// モード: Run Once for All Items
const items = $input.all();
const now = new Date().toISOString().split('T')[0];

const updated = items.filter(i => i.json.changed && !i.json.isNew);
const newPages = items.filter(i => i.json.isNew);
const withWarnings = items.filter(i => (i.json.warnings || []).length > 0);

// コスト計算
const totalInput = items.reduce((s, i) => s + (i.json.tokenEstimate || 0) + 2300, 0);
const totalOutput = items.reduce((s, i) => s + Math.ceil((i.json.tokenEstimate || 0) * 1.2), 0);
const cost = (totalInput * 0.10 / 1e6 + totalOutput * 0.40 / 1e6).toFixed(4);

const updatedList = [...updated, ...newPages]
  .map(i => `- ${i.json.slug}`)
  .join('\n');

const message = items.length === 0
  ? null  // 変更なし → 通知しない
  : `✅ *Claude Code Docs 同期完了*\n\n📅 ${now}\n📄 更新: ${updated.length}ページ\n🆕 新規: ${newPages.length}ページ\n⚠️ 警告: ${withWarnings.length}件\n💰 コスト: $${cost}\n\n${updatedList}`;

if (!message) {
  return []; // 空配列 → 次ノード（Telegram）をスキップ
}

return [{
  json: {
    chat_id: '{{ $env.TELEGRAM_CHAT_ID }}',
    text: message,
    parse_mode: 'Markdown'
  }
}];
```

---

## 6. エラーハンドリング設計（E1-E5 統合）

138bの汎用エラー判定フローと138cの個別戦略を統合:

### 6.1 HTTP Requestノード共通設定

全HTTP Requestノードに以下を設定:
- `continueOnFail: true` — エラー時も次ノードへ
- `retryOnFail: true` — 組込みリトライ有効

### 6.2 障害パターン別対応

| ID | パターン | 検知 | 一次対処 | 二次対処 | 通知 |
|----|---------|------|---------|---------|------|
| E1 | Gemini 429 | statusCode===429 | retryOnFail: maxTries=3, wait=10s | ページスキップ, pending記録 | Telegram E2テンプレート |
| E2 | Gemini 5xx | statusCode>=500 | retryOnFail: maxTries=2, wait=30s | WF中断（Stop Node） | Telegram E2テンプレート |
| E3 | llms-full.txt不到達 | statusCode!==200 or length<1000 | retryOnFail: maxTries=2, wait=60s | WF全体スキップ | Telegram E2テンプレート |
| E4 | GitHub 429 | statusCode===403+RateLimit | Wait Node（Reset時刻まで） | GitHub同期スキップ | Telegram E2テンプレート |
| E5 | ファイル書込み失敗 | WriteFile error | 1回リトライ | WF中断、翻訳結果ログ保存 | Telegram E2テンプレート |

### 6.3 Telegram通知テンプレート

**T1: 同期成功** (変更あり時のみ送信)

```
✅ *Claude Code Docs 同期完了*

📅 {date}
📄 更新: {updated}ページ
🆕 新規: {new}ページ
⚠️ 警告: {warnings}件
💰 コスト: ${cost}

{ページ一覧}
```

**T2: エラー** (障害発生時に送信)

```
🚨 *Claude Code Docs 同期エラー*

📅 {date}
❌ エラー: {errorType}
📍 ノード: {errorNode}
💬 {errorMessage}

処理済み: {processed}/{total}
スキップ: {skipped}
```

**T3: GitHub同期成功** (変更あり時のみ送信)

```
✅ *GitHub Docs 同期完了*

📅 {date}
🔗 Commit: {sha7}
📄 更新: {count}ファイル
{ファイル一覧}
💰 コスト: ${cost}
```

送信条件: 変更なし=通知しない、変更あり=T1/T3送信、エラー=T2送信

---

## 7. インフラセットアップ手順

### 7.1 ディレクトリ作成

```bash
# ディレクトリ構成作成
mkdir -p /home/ubuntu/claude-code-docs/{en/site,en/github/plugins,ja-JP/site,ja-JP/github/plugins}

# n8nコンテナUID(1000)に権限付与
chown -R 1000:1000 /home/ubuntu/claude-code-docs

# 初期metadata.json作成
cat > /home/ubuntu/claude-code-docs/metadata.json << 'EOF'
{
  "version": "1.0.0",
  "last_sync_timestamp": null,
  "docs": { "source_hash": null, "pages": {} },
  "github": { "commit_sha": null, "files": {} },
  "stats": { "total_pages": 0, "total_tokens": 0, "last_full_sync": null }
}
EOF
chown 1000:1000 /home/ubuntu/claude-code-docs/metadata.json
```

### 7.2 docker-compose.yml 変更

```diff
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ services.n8n.environment (末尾に追加)
+      # Claude Code Docs自動収集設定
+      - CLAUDE_DOCS_DIR=/data/claude-code-docs
+      - GEMINI_DOCS_MODEL=gemini-2.5-flash-lite
+      - GITHUB_TOKEN=${GITHUB_TOKEN}

@@ services.n8n.volumes (末尾に追加)
+      - ${CLAUDE_DOCS_HOST_DIR:-/home/ubuntu/claude-code-docs}:/data/claude-code-docs
```

### 7.3 .env 追加変数

```bash
# Claude Code Docs自動収集システム
CLAUDE_DOCS_HOST_DIR=/home/ubuntu/claude-code-docs
GEMINI_DOCS_MODEL=gemini-2.5-flash-lite
GITHUB_TOKEN=
```

注意:
- `GEMINI_API_KEY`: 既存値をそのまま使用（追加不要）
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`: 既存値をそのまま使用
- `GITHUB_TOKEN`: オプション。未設定でも60 req/hで4ファイル取得には十分

### 7.4 コンテナ再起動

```bash
cd /home/ubuntu/.n8n-mcp/n8n
docker compose down && docker compose up -d
```

---

## 8. コスト見積もり（最終版）

### 8.1 基礎データ

| 項目 | 値 | 出典 |
|------|-----|------|
| モデル | gemini-2.5-flash-lite | 将軍指定 |
| 入力単価 | $0.10/1M tokens | Gemini公式 |
| 出力単価 | $0.40/1M tokens | Gemini公式 |
| 全57ページ合計 | 266,844 tokens | 138a実測 |
| 平均ページサイズ | 4,681 tokens | 138a実測 |
| プロンプトオーバーヘッド | 2,300 tokens/ページ | 138c計算 |
| 出力倍率 | 1.2倍 | 138c採用 |

### 8.2 コスト計算

| シナリオ | 入力tokens | 出力tokens | 入力コスト | 出力コスト | 合計 |
|----------|-----------|-----------|-----------|-----------|------|
| **初回全量（57p+4f）** | 408,917 | 330,369 | $0.041 | $0.132 | **$0.173** |
| **日次差分（2.5p平均）** | 17,453 | 14,043 | $0.002 | $0.006 | **$0.009/日** |
| **月次（日次差分×30）** | 523,575 | 421,275 | $0.052 | $0.169 | **$0.27/月** |
| **毎日全量（非推奨）** | 12.3M | 9.9M | $1.23 | $3.96 | **$5.19/月** |

### 8.3 将軍見積もり($5.80)との比較

| 前提 | 月額コスト | 差分検知 |
|------|-----------|---------|
| 将軍見積もり | $5.80 | なし（毎日全量） |
| 本計画（推奨） | **$0.27** | あり（DJB2ハッシュ） |
| 削減率 | **95%削減** | |

---

## 9. 実装フェーズ分割

### Phase 1: インフラ + WF1 (Docs同期)

| # | 作業 | 見積もり |
|---|------|---------|
| 1-1 | ディレクトリ作成 + 権限設定 | 5分 |
| 1-2 | docker-compose.yml変更 + .env追加 | 5分 |
| 1-3 | コンテナ再起動 + 動作確認 | 5分 |
| 1-4 | WF1 n8nワークフロー構築（18ノード） | n8n API経由 |
| 1-5 | WF1 手動実行テスト（初回全量翻訳） | 10-15分 |
| 1-6 | WF1 翻訳結果の品質確認（ランダム3ページ目視） | 5分 |
| 1-7 | WF1 スケジュール有効化 | 1分 |

### Phase 2: WF2 (GitHub同期) + 通知最適化

| # | 作業 | 見積もり |
|---|------|---------|
| 2-1 | WF2 n8nワークフロー構築（12ノード） | n8n API経由 |
| 2-2 | WF2 手動実行テスト | 5分 |
| 2-3 | WF2 スケジュール有効化 | 1分 |
| 2-4 | Telegram通知テスト | 3分 |
| 2-5 | 1週間運用モニタリング | 自動 |

---

## 10. テスト計画

### 10.1 手動テスト項目

| # | テスト | 期待結果 | 実施時期 |
|---|--------|---------|---------|
| T1 | 初回全量翻訳実行 | 57ページ翻訳完了、metadata.json更新 | Phase 1-5 |
| T2 | 翻訳品質目視確認（3ページ） | 用語統一、MDXタグ保持、コードブロック無翻訳 | Phase 1-6 |
| T3 | 2回目実行（差分なし） | 0ページ翻訳、通知なし | Phase 1-7翌日 |
| T4 | GitHub同期実行 | 4ファイル翻訳、metadata更新 | Phase 2-2 |
| T5 | エラー時通知確認 | Telegram E2テンプレートで通知着信 | Phase 2-4 |

### 10.2 自動検証項目（WF内品質検証）

| # | 検証 | 基準 | 対応 |
|---|------|------|------|
| V1 | 翻訳結果非空 | length > 0 | CRITICAL: リトライ |
| V2 | 見出し数一致 | ±1以内 | HIGH: リトライ |
| V3 | コードブロック保持 | 完全一致 | HIGH: リトライ |
| V4 | URL保持 | 全URL存在 | MEDIUM: WARNING |
| V5 | MDXタグ保持 | 数量一致 | MEDIUM: WARNING |

---

## 付録: Split In Batches正当使用の確認

cmd_135で検出されたSplit In Batchesアンチパターンは「main[0]（バッチ完了）とmain[1]（各バッチ）の接続先誤り」であった。本計画のWF1 Node 9（Batch Pages）は:

- **main[0]（バッチ完了後）** → Update Metadata（全バッチ終了後のメタデータ更新）
- **main[1]（各バッチ）** → Build Translation Prompt（各バッチの翻訳処理）

これはSplit In Batchesの正規使用パターンであり、cmd_135のアンチパターンには該当しない。intervalによるAPI Rate Limit対策（5秒間隔）が使用目的。
