# Gmail自動化ワークフロー v5.0 実装計画書

> 作成日: 2026-02-18 | 作成者: Shogun
>
> cmd_137（v4.0コンテキスト注入計画書）をベースに、v5.0として再構成。
> 前回のMergeノード障害（cmd_176）の教訓を反映。

---

## 現状整理

### 現行v4.0の状態

| 項目 | 値 |
|------|-----|
| WF ID | `6HfrbcXoujQSfSQC` |
| ノード数 | 28 |
| Geminiモデル | `gemini-2.5-flash`（v1beta API） |
| 状態 | active、exec 3366以降安定稼働 |
| Mergeノード | **なし**（cmd_176でFields to Matchエラー→撤去済み） |

### cmd_137計画書の資産（再利用可能）

- ✅ Notion案件DB構造調査済み（案件DB ID: `1a4e8d62e4aa81c7bdb4c3c0ea47633a`）
- ✅ Google Driveフォルダ構造調査済み（43ファイル+2サブフォルダ）
- ✅ 名字→案件紐付けロジック設計済み（3段階フォールバック）
- ✅ ノード設計・プロンプトテンプレート・コスト見積もり完了
- ⚠️ Mergeノード: mode設定の誤り（Combine by Matching → 正: Combine by Position）

### 前回の失敗分析（cmd_176）

| 項目 | 内容 |
|------|------|
| 障害 | 「メール履歴+案件情報Merge」が "Fields to Match" エラーで5回連続失敗 |
| 根本原因 | Mergeノードの mode が Combine by Matching（フィールド一致が必要）で設定されていた |
| 正しい設定 | **Combine by Position**（位置ベース合流、両入力が揃うまで待機） |
| 教訓 | Phase 1再実装時は mode=combineMergeByPosition を明示的に指定すること |

---

## v5.0 フェーズ構成

| Phase | 内容 | 依存 | 優先度 | 見積もり |
|-------|------|------|--------|---------|
| **1** | Notion案件DB注入（cmd_137 Phase 1 再実装） | なし | 最高 | 実装2-3h、テスト1-2h |
| **2** | Google Drive連携追加 | Phase 1安定稼働後 | 高 | 実装1-2h、テスト1h |
| **3** | ダイジェスト通知WF改善（Telegram完全除去） | 独立 | 中 | 1h |
| **4** | Gemini APIモデル管理の環境変数化 + v1→v1安定版準備 | 独立 | 低 | 1h |

---

## Phase 1: Notion案件DB注入（最優先）

### 概要

送信者メールの名字から Notion 案件DBを検索し、関連案件情報を Gemini プロンプトに注入する。
これにより、案件の進捗状況を踏まえた返信案が生成される。

### 追加ノード（3つ）

#### Node A: Notion案件検索

| 項目 | 設計値 |
|------|--------|
| ノード名 | `Notion案件検索` |
| 種別 | `n8n-nodes-base.httpRequest` (typeVersion 4.2) |
| 配置 | 添付ファイル確認の output[0] に第3並列接続 |
| メソッド | POST |
| URL | `https://api.notion.com/v1/databases/${{ $env.NOTION_ANKEN_DB_ID }}/query` |
| 認証 | Header Auth: `Authorization: Bearer {{ $env.NOTION_INTEGRATION_TOKEN }}` |
| 追加ヘッダー | `Notion-Version: 2022-06-28`, `Content-Type: application/json` |
| continueOnFail | true |
| timeout | 10000 |

リクエストBody:

```json
{
  "filter": {
    "and": [
      {
        "property": "タイトル",
        "title": { "contains": "{{ $json.senderLastName }}" }
      },
      {
        "property": "ステータス",
        "status": { "does_not_equal": "完了" }
      },
      {
        "property": "ステータス",
        "status": { "does_not_equal": "欠損" }
      }
    ]
  },
  "page_size": 5
}
```

#### Node B: 案件情報整形

| 項目 | 設計値 |
|------|--------|
| ノード名 | `案件情報整形` |
| 種別 | `n8n-nodes-base.code` (typeVersion 2) |
| 配置 | Notion案件検索 → 案件情報整形 |
| 出力先 | Merge ノード（Input 2） |

コードロジック: cmd_137計画書 セクション2.1 Node B 参照

#### Node C: メール履歴+案件情報Merge

| 項目 | 設計値 |
|------|--------|
| ノード名 | `メール履歴+案件情報Merge` |
| 種別 | `n8n-nodes-base.merge` (typeVersion 3) |
| **モード** | **Combine by Position** ← 前回の失敗を修正 |
| Input 1 | 会話履歴整形 or 過去メール有無チェック(false) |
| Input 2 | 案件情報整形 |
| 出力先 | Gemini判断+要約準備 |
| includeBinary | false |

⚠️ **重要**: mode は必ず `combineMergeByPosition` を指定。`combineMergeByMatching` にしないこと（前回障害の再発防止）。

### 既存ノード変更（2つ）

#### 添付ファイル確認（No.2）— 名字抽出ロジック追加

```javascript
// 名字抽出ロジック（追加コード）
const senderName = item.json.senderName || "";
let senderLastName = "";

if (senderName) {
  const cleanName = senderName.replace(/^From:\s*/, "").trim();
  if (/[\u3000-\u9fff\uf900-\ufaff]/.test(cleanName)) {
    const parts = cleanName.split(/[\s　]+/);
    senderLastName = parts.length >= 2 ? parts[0] : cleanName.slice(0, 2);
  } else {
    const parts = cleanName.split(/\s+/);
    senderLastName = parts.length >= 2 ? parts[parts.length - 1] : parts[0];
  }
}
item.json.senderLastName = senderLastName;
```

名字が空 or 1文字以下の場合、Notion検索をスキップ。

#### Gemini判断+要約準備 / 返信案プロンプト準備 — プロンプト拡張

`【関連案件情報（Notion案件DB）】` セクションを追加。
詳細テンプレート: cmd_137計画書 セクション4.1, 4.2 参照

### エラーハンドリング

| エラー | 対応 |
|--------|------|
| 案件0件ヒット | コンテキストなしで現行動作を維持（退行なし） |
| Notion API Rate Limit (429) | リトライ1回、失敗時スキップ |
| Timeout (10秒超過) | スキップして案件なしで続行 |
| 認証エラー (401/403) | スキップ + ログ出力 |
| Merge片方入力なし | 他方のデータのみでGeminiに渡す |

### 検証方法

1. 既知顧客のテストメール送信 → 案件情報がGeminiに渡り返信案に反映
2. 未知送信者のメール → 現行と同等の返信品質（退行なし）
3. Notion API障害時 → 現行と同等動作（graceful degradation）

### 成功基準

- Mergeノードがエラーなく通過する（exec logで確認）
- 既知顧客メール → 返信案に案件文脈が反映される
- 未知送信者メール → 現行品質維持（退行なし）
- 24時間のcron実行でエラー0

---

## Phase 2: Google Drive連携追加

### 追加ノード（2つ）

- `Google Driveファイル検索` — HTTP Request（Drive API GET）
- `Drive情報整形` — Code Node

詳細設計: cmd_137計画書 セクション2.2 参照

### 前提

- Phase 1安定稼働確認後に着手
- OAuth2認証: n8n credential (ID: thUqzJvuIHs0lopA) 設定済み

---

## Phase 3: ダイジェスト通知WF改善

- WF ID: `XgI1VYV2oDZyGKhf`
- cmd_152でTelegram→Google Chat移行済み
- cmd_168でTelegram送信エラー10回連続発生歴あり
- Google Chat通知の安定性を最終確認
- Telegramノードを完全除去してWFをクリーンアップ

---

## Phase 4: Gemini APIモデル管理

- 現行: `gemini-2.5-flash` をURL直書き（v1beta API）
- 改善: `.env` の `GEMINI_MODEL` 環境変数に外出し
- WF内で `{{ $env.GEMINI_MODEL }}` を参照する形に変更
- v1beta → v1 安定版API移行: Google側アナウンス次第

---

## コスト見積もり

| 構成 | 月額 | 現行比 |
|------|------|--------|
| 現行 v4.0 | $0.66 | — |
| v5.0 Phase 1 (Notion) | $0.75 | +$0.09 (+14%) |
| v5.0 Phase 2 (Notion + Drive) | $0.81 | +$0.15 (+23%) |
| 追加インフラコスト | $0 | — |

---

## .env 追加変数

| 変数名 | 値 | Phase |
|--------|-----|-------|
| `NOTION_ANKEN_DB_ID` | `1a4e8d62e4aa81c7bdb4c3c0ea47633a` | 1 |
| `GOOGLE_DRIVE_CASE_FOLDER_ID` | `15NCGQZYb6y0op-SOCV7Djt_mzM-lTwJz` | 2 |

---

## 参照資料

| 資料 | パス |
|------|------|
| cmd_137 計画書 | `output/cmd_137_gmail_v4_context_injection_plan.md` |
| 現行WF JSON | `/home/ubuntu/.n8n-mcp/n8n/gmail-auto/Gmail自動化ワークフロー_v4.0_current.json` |
| Notion案件DB | ID: `1a4e8d62-e4aa-81c7-bdb4-c3c0ea47633a` |
| Google Driveフォルダ | ID: `15NCGQZYb6y0op-SOCV7Djt_mzM-lTwJz` |
| n8n API | `http://localhost:5678`, KEY: `/home/ubuntu/.n8n-mcp/n8n/.env` |

## 付録: DB ID一覧

| DB名 | ID | 用途 |
|------|-----|------|
| 案件DB | `1a4e8d62-e4aa-81c7-bdb4-c3c0ea47633a` | ★本計画で検索対象 |
| 案件タスクDB | `1a4e8d62-e4aa-81f1-8ede-c239ea53299b` | 案件に紐づくタスク管理 |
| 顧客DB | `1aae8d62-e4aa-80c2-8220-fa31da7870e9` | 顧客情報（Phase 3以降） |
| 新メールDB | `306e8d62-e4aa-80f5-b61b-cd2a398225e7` | Gmail v4.0の受信メール保存先 |
