# Gmail自動化ワークフロー v4.0 コンテキスト注入 実装計画書

> **cmd_137** | 作成日: 2026-02-14 | 統合担当: ashigaru8
>
> 本計画書は3足軽の調査報告（Notion案件DB調査・Google Drive構造調査・現行WF分析）を統合し、
> アプローチA（直接コンテキスト注入）の実装計画を策定したものである。

---

## 前提の整合確認（INTEG-001）

### 入力レポート

| レポート | 担当 | 内容 |
|----------|------|------|
| ashigaru5_report | ashigaru5 | Notion案件DBプロパティ構造調査 |
| ashigaru6_report | ashigaru6 | Google Driveフォルダ構造調査 |
| ashigaru7_report | ashigaru7 | 現行WF全28ノード詳細分析 |

### 矛盾検出と解決

| # | 項目 | 報告間の差異 | 解決 |
|---|------|-------------|------|
| 1 | DB ID | cmd_137原文: 案件DB=2a5e8d62...  / ashigaru5: 2a5e8d62...は旧メールDB | **ashigaru5が正**。実API確認済み。正しい案件DB ID = `1a4e8d62-e4aa-81c7-bdb4-c3c0ea47633a` |
| 2 | 紐付けロジック | ashigaru7: 「メールアドレスequalで検索」/ ashigaru5: 顧客DBメール欄は全件未入力(0件) | **ashigaru5が正**。メアド直接検索は不可。案件DBタイトル名字検索（候補1）を採用 |
| 3 | Geminiモデル | cmd_137原文: gemini-2.0-flash-exp廃止対応要 / ashigaru7: 既にgemini-2.5-flashに更新済み | **ashigaru7が正**。WF JSON確認済み。2.0-flash-exp廃止の影響なし |
| 4 | Drive検索方式 | ashigaru6: HTTP Requestノード推奨(Driveノードバグ) / ashigaru7: httpRequest型で設計 | **一致**。HTTP Requestノード + googleDriveOAuth2Api credential を採用 |

### 全報告共通の前提（整合確認済み）

- WF ID: `6HfrbcXoujQSfSQC`、全28ノード、active
- Geminiモデル: `gemini-2.5-flash`（v1beta API使用中）
- 挿入アーキテクチャ: 案1（並列ブランチ追加）推奨
- コスト増: 月額+$0.09〜$0.15（極めて軽微）

---

## 1. 現行フロー図と改善後フロー図

### 1.1 現行フロー（28ノード）

```
Gmail Trigger (毎分ポーリング)
  │
  v
添付ファイル確認 (Code: MIMEデコード, 送信者/件名/本文抽出)
  │
  ├─[並列1]─> 添付ファイル有無チェック (If)
  │              ├─[true]─> Split Attachments ─> Google Drive保存 [END]
  │              └─[false]─> (空)
  │
  └─[並列2]─> 過去メール検索 (Gmail API: 同一送信者max5件)
                 │
                 v
               メールID抽出 (Code)
                 │
                 v
               過去メール有無チェック (If)
                 ├─[true]──> 過去メール本文取得 ─> 会話履歴整形 ──┐
                 └─[false]─────────────────────────────────────────┘
                                                                    │
                                                                    v
                                     Gemini判断+要約準備 (Code: プロンプト組立)
                                                                    │
                                                                    v
                                     Gemini判断+要約 (HTTP: gemini-2.5-flash)
                                                                    │
                                                                    v
                                     AI判断結果パース (Code)
                                                                    │
                                                                    v
                                     Notion保存データ準備 ─> Notion DB保存 ─> Notion保存結果処理
                                                                                     │
                                     ┌──────[並列1]──────────────────────────────────┤
                                     │                                                │
                                     v                                          [並列2]
                                  返信必要チェック (If)                               │
                                     │                                                v
                                     │                                          緊急度チェック (If)
                                     │                                            ├─[high]─> Telegram通知 [END]
                                     │                                            └─[else]─> (空)
                                     │
                                     ├─[true: 返信必要]
                                     │    v
                                     │  返信案プロンプト準備 ─> Gemini返信案生成 ─> 返信案パース
                                     │  ─> Gmail下書き作成 ─> Notion更新データ準備 ─> Notion DB更新
                                     │  ─> データ復元 ─> 元メール既読化 [END]
                                     │
                                     └─[false: 返信不要]
                                          v
                                        元メール既読化（返信不要パス） [END]
```

### 1.2 改善後フロー（案1: 並列ブランチ追加）

変更箇所を `【NEW】` で表示:

```
Gmail Trigger (毎分ポーリング)
  │
  v
添付ファイル確認 (Code: MIMEデコード, 送信者/件名/本文抽出)
  │
  ├─[並列1]─> 添付ファイル有無チェック (If)
  │              ├─[true]─> Split Attachments ─> Google Drive保存 [END]
  │              └─[false]─> (空)
  │
  ├─[並列2]─> 過去メール検索 (Gmail API: 同一送信者max5件)
  │              │
  │              v
  │            メールID抽出 (Code)
  │              │
  │              v
  │            過去メール有無チェック (If)
  │              ├─[true]──> 過去メール本文取得 ─> 会話履歴整形 ──┐
  │              └─[false]─────────────────────────────────────────┘
  │                                                                 │
  │                                                     ┌───────────┘
  │                                                     │
  │                                                     v
  │                         【NEW】Merge (Combine by Position)◄──────────────┐
  │                                                     │                     │
  │                                                     v                     │
  │                          Gemini判断+要約準備 (Code: プロンプト組立         │
  │                             ★案件情報セクション追加)                      │
  │                                                     │                     │
  │                                      （以下 現行と同一）                  │
  │                                                                           │
  └─【NEW 並列3】─> Notion案件検索 (HTTP: Notion API)                        │
                       │                                                      │
                       v                                                      │
                     【NEW】案件情報整形 (Code) ──────────────────────────────┘

--- Phase 2 追加分 ---

  ├─【NEW 並列4】─> Google Drive検索 (HTTP: Drive API) ─> Drive情報整形 (Code)
  │                     │
  │                     └──> Merge2 (Phase 2で追加。Merge出力にDrive情報を合流)
```

### 1.3 変更サマリ

| 項目 | Phase 1 | Phase 2 |
|------|---------|---------|
| 追加ノード数 | 3 (Notion案件検索, 案件情報整形, Merge) | +2 (Drive検索, Drive情報整形) |
| 変更接続数 | 2 (添付ファイル確認→Notion検索追加, 会話履歴→Merge経由に変更) | +1 (Merge拡張) |
| レイテンシ影響 | 0ms (過去メール検索より高速に完了) | 0ms (並列実行のため) |
| 既存ノード変更 | Gemini判断+要約準備(プロンプト変更), 返信案プロンプト準備(プロンプト変更) | 返信案プロンプト準備(Drive情報追加) |

---

## 2. 追加ノード設計

### 2.1 Phase 1: Notion案件情報の注入

#### Node A: Notion案件検索

| 項目 | 設計値 |
|------|--------|
| **ノード名** | `Notion案件検索` |
| **種別** | `n8n-nodes-base.httpRequest` (typeVersion 4.2) |
| **配置** | 添付ファイル確認の output[0] に第3並列接続 |
| **メソッド** | POST |
| **URL** | `https://api.notion.com/v1/databases/1a4e8d62e4aa81c7bdb4c3c0ea47633a/query` |
| **認証** | Header Auth: `Authorization: Bearer {{ $env.NOTION_INTEGRATION_TOKEN }}` |
| **追加ヘッダー** | `Notion-Version: 2022-06-28`, `Content-Type: application/json` |
| **Body (JSON)** | 下記参照 |
| **continueOnFail** | true |
| **timeout** | 10000 |

**リクエストBody:**

```json
{
  "filter": {
    "and": [
      {
        "property": "タイトル",
        "title": {
          "contains": "{{ $json.senderLastName }}"
        }
      },
      {
        "property": "ステータス",
        "status": {
          "does_not_equal": "完了"
        }
      },
      {
        "property": "ステータス",
        "status": {
          "does_not_equal": "欠損"
        }
      }
    ]
  },
  "page_size": 5
}
```

**入力要件:** `senderLastName` は「添付ファイル確認」ノードで抽出する（セクション3参照）。

#### Node B: 案件情報整形

| 項目 | 設計値 |
|------|--------|
| **ノード名** | `案件情報整形` |
| **種別** | `n8n-nodes-base.code` (typeVersion 2) |
| **配置** | Notion案件検索 → 案件情報整形 |
| **出力先** | Merge ノード（Input 2） |

**コードロジック（疑似コード）:**

```javascript
// Notion APIレスポンスから案件情報を抽出・整形
const results = $input.first().json.results || [];

if (results.length === 0) {
  return [{
    json: {
      notionContext: "",
      hasAnkenInfo: false,
      ankenCount: 0
    }
  }];
}

const ankenList = results.map(page => {
  const props = page.properties;
  return {
    title: props["タイトル"]?.title?.[0]?.plain_text || "",
    status: props["ステータス"]?.status?.name || "",
    stage: props["段階"]?.select?.name || "",
    memo: props["現状メモ"]?.rich_text?.[0]?.plain_text || "",
    nextTask: props["次の作業内容"]?.formula?.string || "",
    nextDate: props["次の期日"]?.formula?.string || "",
    deadline: props["対外期限"]?.formula?.string || "",
    staff: (props["担当事務"]?.multi_select || []).map(s => s.name).join(", "),
    caseNumber: props["事件番号"]?.rich_text?.[0]?.plain_text || ""
  };
});

// テキスト整形
const contextLines = ankenList.map((a, i) => {
  const lines = [`案件${i + 1}: ${a.title}`];
  if (a.stage) lines.push(`  段階: ${a.stage}`);
  if (a.status) lines.push(`  ステータス: ${a.status}`);
  if (a.memo) lines.push(`  現状メモ: ${a.memo}`);
  if (a.nextTask) lines.push(`  次の作業: ${a.nextTask}`);
  if (a.nextDate) lines.push(`  次の期日: ${a.nextDate}`);
  if (a.deadline) lines.push(`  対外期限: ${a.deadline}`);
  if (a.staff) lines.push(`  担当事務: ${a.staff}`);
  if (a.caseNumber) lines.push(`  事件番号: ${a.caseNumber}`);
  return lines.join("\n");
});

return [{
  json: {
    notionContext: contextLines.join("\n\n"),
    hasAnkenInfo: true,
    ankenCount: ankenList.length,
    // 元データも保持（返信プロンプトで再利用可能）
    ankenRawData: ankenList
  }
}];
```

#### Node C: Merge

| 項目 | 設計値 |
|------|--------|
| **ノード名** | `メール履歴+案件情報Merge` |
| **種別** | `n8n-nodes-base.merge` (typeVersion 3) |
| **モード** | Combine → Combine by Position |
| **Input 1** | 会話履歴整形 or 過去メール有無チェック(false) |
| **Input 2** | 案件情報整形 |
| **出力先** | Gemini判断+要約準備 |
| **includeBinary** | false |

**注意:** Mergeノードの Combine by Position は両入力が揃うまで待機する。並列実行の合流点として適切。片方が空の場合でも他方のデータは維持される。

### 2.2 Phase 2: Google Drive情報の追加

#### Node D: Google Driveファイル検索

| 項目 | 設計値 |
|------|--------|
| **ノード名** | `Google Driveファイル検索` |
| **種別** | `n8n-nodes-base.httpRequest` (typeVersion 4.2) |
| **配置** | 添付ファイル確認の output[0] に第4並列接続 |
| **メソッド** | GET |
| **URL** | `https://www.googleapis.com/drive/v3/files` |
| **認証** | OAuth2 (credentialId: `thUqzJvuIHs0lopA`, type: `googleDriveOAuth2Api`) |
| **クエリパラメータ** | 下記参照 |
| **continueOnFail** | true |
| **timeout** | 10000 |

**クエリパラメータ:**

```
q: "'{{ $env.GOOGLE_DRIVE_CASE_FOLDER_ID }}' in parents and name contains '{{ $json.senderEmail }}'"
fields: "files(id,name,mimeType,createdTime,size)"
pageSize: 20
orderBy: "createdTime desc"
```

**注意:** n8n Google DriveノードのfileFolder.list操作にrouter.tsバグがあるため（ashigaru6確認済み）、HTTP Requestノードを使用する。

#### Node E: Drive情報整形

| 項目 | 設計値 |
|------|--------|
| **ノード名** | `Drive情報整形` |
| **種別** | `n8n-nodes-base.code` (typeVersion 2) |
| **出力先** | Merge2（Phase 2用） |

**コードロジック（疑似コード）:**

```javascript
const files = $input.first().json.files || [];

if (files.length === 0) {
  return [{
    json: {
      driveContext: "",
      hasDriveFiles: false,
      fileCount: 0
    }
  }];
}

// ファイル名からメタデータを抽出（命名規則: YYYYMMDDHHMMSS_sender_email_originalName.ext）
const fileList = files.map(f => {
  const nameParts = f.name.split("_");
  const dateStr = nameParts[0] || "";
  const formattedDate = dateStr.length >= 8
    ? `${dateStr.slice(0,4)}-${dateStr.slice(4,6)}-${dateStr.slice(6,8)}`
    : "";
  // 元のファイル名部分を抽出（3つ目の_以降）
  const originalName = nameParts.slice(3).join("_") || f.name;
  const ext = f.mimeType.split("/").pop();
  return `- ${formattedDate}: ${originalName} (${ext})`;
});

return [{
  json: {
    driveContext: fileList.join("\n"),
    hasDriveFiles: true,
    fileCount: files.length
  }
}];
```

---

## 3. 送信者 → 案件の紐付けロジック

### 3.1 名字抽出（添付ファイル確認ノードへの追加コード）

現行の「添付ファイル確認」ノード（No.2）に以下のロジックを追加する:

```javascript
// === 名字抽出ロジック（追加コード） ===
// senderName は既存コードで抽出済み（例: "From: 児玉茉実" → "児玉茉実"）

const senderName = item.json.senderName || "";
let senderLastName = "";

if (senderName) {
  // "From: " プレフィクス除去
  const cleanName = senderName.replace(/^From:\s*/, "").trim();

  if (/[\u3000-\u9fff\uf900-\ufaff]/.test(cleanName)) {
    // 日本語名: スペースで分割して最初の要素が名字
    // "児玉 茉実" → "児玉"  /  "児玉茉実" → "児玉"（2-3文字）
    const parts = cleanName.split(/[\s　]+/);
    if (parts.length >= 2) {
      senderLastName = parts[0];
    } else {
      // スペースなし: 先頭2文字を名字として推定
      senderLastName = cleanName.slice(0, 2);
    }
  } else {
    // 英語名: スペースで分割して最後の要素が姓
    const parts = cleanName.split(/\s+/);
    senderLastName = parts.length >= 2 ? parts[parts.length - 1] : parts[0];
  }
}

item.json.senderLastName = senderLastName;
```

### 3.2 検索戦略（3段階フォールバック）

```
Step 1: 案件DBタイトル名字検索（主要・即時実装）
  ├─ 送信者名から名字抽出
  ├─ 案件DB タイトルで contains 検索
  ├─ ステータス ≠ 完了/欠損 でフィルタ（アクティブ案件のみ）
  └─ page_size: 5
       │
       ├─ 1件ヒット → その案件情報を使用
       ├─ 複数ヒット → 全件をコンテキストに含める（Geminiが判断）
       └─ 0件ヒット → Step 2へ

Step 2: 顧客DB経由検索（将来拡張・Phase 3以降）
  ├─ 顧客DB 顧客名で名字検索
  ├─ 注意: multi-data-source DB → Notion-Version: 2025-09-03 必要
  ├─ POST /v1/data_sources/1aae8d62-e4aa-809d-a2c6-000b658e92e9/query
  └─ ヒットした顧客の「案件」relation IDで案件ページ取得

Step 3: メールアドレス直接検索（将来の理想形）
  ├─ 条件: 顧客DBにメールアドレスが入力されること
  ├─ 顧客DB メールフィールドで equals 検索
  └─ 現状: 全件未入力(0件)のため使用不可
```

**Phase 1ではStep 1のみ実装する。** Step 2/3は顧客DBのデータ充実後に検討。

### 3.3 複数案件ヒット時の処理

- **全件をコンテキストに含める**（最大5件）
- Geminiが送信メール内容と案件情報を照合し、最も関連性の高い案件を判断
- 判断精度はGemini側の処理に委ねる（人間の判断が必要なケースでもGeminiの要約・整理が有効）

### 3.4 組織名・弁護士名への対応

| 送信者パターン | 名字抽出結果 | 案件ヒット可能性 |
|----------------|-------------|-----------------|
| 個人名（児玉茉実） | 児玉 | 高 |
| 弁護士名（高田@grace-law） | 高田 | 低（相手方弁護士名は案件タイトルに含まれない） |
| 組織名（株式会社XX） | 株式 | 極低 |
| noreply系 | (空) | 検索スキップ |

**対策:** 名字が空 or 1文字以下の場合、Notion検索をスキップして案件なしとして処理する。

---

## 4. Geminiプロンプトの拡張テンプレート

### 4.1 「Gemini判断+要約準備」プロンプト改善版

現行プロンプトに `【関連案件情報】` セクションを追加する。
挿入位置: 「過去の会話履歴」と「現在のメール情報」の間。

```
あなたはメール対応の専門家です。以下のメールを分析し、返信が必要かどうかを判断し、
メールの要約を作成してください。

【過去の会話履歴（同一送信者の直近メール）】
${conversationHistory || "なし（初めての送信者、または過去メールが見つかりませんでした）"}

【関連案件情報（Notion案件DB）】                    ← NEW
${notionContext || "関連する案件情報は見つかりませんでした。"}  ← NEW

【現在のメール情報】
送信者: ${senderName} <${senderEmail}>
件名: ${subject}
本文:
${body.slice(0, 1000)}
添付ファイル: ${hasAttachments ? `あり(${attachmentCount}件)` : "なし"}

【判断基準】
以下の場合は返信が必要:
- 質問や問い合わせが含まれている
- アクションや確認が求められている
- ビジネス上の重要な連絡
- 緊急性のある内容
- 既知の案件に関連し、案件の進捗を踏まえた対応が必要    ← NEW

以下の場合は返信不要:
- 自動送信メール（noreply等）
- メールマガジンや通知
- 既に対応済みの内容
- 情報共有のみ
- @grace-law.jpドメイン（同僚）

回答は以下のJSON形式で:
{
  "needsReply": boolean,
  "reason": "判断理由",
  "urgency": "high/medium/low",
  "category": "問い合わせ/依頼/確認/通知/その他",
  "summary": "メール要約（100-200文字）"
}
```

### 4.2 「返信案プロンプト準備」プロンプト改善版

現行プロンプトに `【関連案件情報】` と `【関連書類】`（Phase 2）セクションを追加する。
挿入位置: 「AI分析結果」と「返信作成の指示」の間。

```
あなたはプロフェッショナルなビジネスメール返信の専門家です。
以下のメールに対する返信文を作成してください。

【過去の会話履歴（同一送信者の直近メール）】
${conversationHistory || "なし"}

【受信メール情報】
送信者: ${senderName} <${senderEmail}>
件名: ${subject}
本文:
${body.slice(0, 1000)}
添付ファイル: ${hasAttachments ? `あり(${attachmentCount}件)` : "なし"}

【AI分析結果】
返信理由: ${reason}
緊急度: ${urgency}
カテゴリ: ${category}

【関連案件情報】                                                     ← NEW
${notionContext || "関連する案件情報はありません。一般的な返信を作成してください。"}

【関連書類（Google Drive）】                                          ← NEW (Phase 2)
${driveContext || "関連する書類はありません。"}

【返信作成の指示】
- 丁寧で分かりやすい日本語のビジネスメールを作成
- 質問や依頼に適切に応答する
- 添付ファイルがある場合は確認した旨を記載
- 具体的なアクションを明示する
- 過去の会話の文脈を踏まえる
- 案件の進捗状況を踏まえた的確な返信にする                           ← NEW
- 関連書類がある場合は必要に応じて言及する                           ← NEW (Phase 2)
- 適度な長さにまとめる

回答は以下のJSON形式で:
{
  "subject": "Re: 件名",
  "body": "返信本文"
}

本文の構成:
1. 挨拶
2. メール受領の確認と感謝
3. 主要な回答内容
4. 添付ファイルへの言及（該当する場合）
5. 結びの文
※ 署名は不要（自動追加されます）
```

### 4.3 案件情報がない場合のフォールバック

| 状態 | notionContext の値 | 動作 |
|------|-------------------|------|
| 案件1件ヒット | 案件情報テキスト | 案件文脈を踏まえた判断・返信 |
| 複数件ヒット | 全件の案件情報テキスト | Geminiが関連案件を判断 |
| 0件ヒット | "関連する案件情報は見つかりませんでした。" | 現行と同等の判断・返信（退行なし） |
| Notion APIエラー | "関連する案件情報は見つかりませんでした。" | 現行と同等の判断・返信（退行なし） |

**重要:** 案件情報なしの場合、プロンプトの `notionContext` 部分にフォールバック文言を入れるだけで、プロンプト構造自体は変更しない。これにより、案件情報がなくても現行品質を維持する。

---

## 5. Phase分割

### Phase 1: Notion案件情報の注入（最小構成）

| 項目 | 内容 |
|------|------|
| **スコープ** | 案件DBタイトル名字検索 → 案件情報をGeminiコンテキストに注入 |
| **追加ノード** | 3個（Notion案件検索, 案件情報整形, Merge） |
| **既存ノード変更** | 2個（添付ファイル確認: 名字抽出追加, Gemini判断+要約準備: プロンプト変更, 返信案プロンプト準備: プロンプト変更） |
| **検証方法** | テストメール送信 → WF実行 → Notion案件検索ログ確認 → 返信案に案件文脈が反映されているか確認 |
| **所要時間見積もり** | 実装2-3時間、テスト1-2時間 |
| **成功基準** | 既知顧客のメール → 案件情報がGeminiに渡り、返信案に案件文脈が反映される |
| **退行テスト** | 未知送信者のメール → 現行と同等の返信品質が維持される |

### Phase 2: Google Drive連携の追加

| 項目 | 内容 |
|------|------|
| **スコープ** | Driveファイル検索 → ファイル一覧をGeminiコンテキストに追加 |
| **追加ノード** | 2個（Google Driveファイル検索, Drive情報整形） |
| **既存ノード変更** | 1個（返信案プロンプト準備: Driveコンテキスト追加） |
| **前提** | Phase 1完了・安定稼働 |
| **検証方法** | 添付ファイル付きメール送信 → Drive保存済みファイルが返信案で言及されるか確認 |
| **所要時間見積もり** | 実装1-2時間、テスト1時間 |
| **成功基準** | Driveにファイルがある案件 → 返信案に関連書類情報が含まれる |
| **退行テスト** | Driveにファイルなし → Phase 1と同等の動作 |

### Phase 3（将来構想）: 紐付け精度向上

| 項目 | 内容 |
|------|------|
| **スコープ** | 顧客DB経由2段階検索、メールアドレス直接検索 |
| **前提** | 顧客DBにメールアドレスが入力される運用の開始 |
| **優先度** | 低（Phase 1の名字検索で十分な精度が出る場合は不要） |

---

## 6. エラーハンドリング

### 6.1 Notion API エラー

| エラー | 対応 | 実装方法 |
|--------|------|----------|
| 案件が見つからない (0件) | コンテキストなしで現行動作を維持 | 案件情報整形ノードで空文字列を出力 |
| Rate Limit (429) | リトライ1回、失敗時スキップ | httpRequestノードの `retry` 設定 (maxRetries: 1, retryDelay: 1000) |
| Timeout (10秒超過) | スキップしてNotion情報なしで続行 | `continueOnFail: true` + timeout: 10000 |
| 認証エラー (401/403) | スキップ + ログ出力 | `continueOnFail: true`。エラー時は空配列を返す |
| 不正なレスポンス | フォールバック | 案件情報整形ノードで `results` が配列でない場合は空配列扱い |

### 6.2 Google Drive API エラー（Phase 2）

| エラー | 対応 | 実装方法 |
|--------|------|----------|
| ファイルが見つからない (0件) | "関連ファイルなし"として処理 | Drive情報整形ノードで空文字列を出力 |
| Rate Limit (403) | リトライ1回、失敗時スキップ | `retry` 設定 |
| OAuth2トークン期限切れ | スキップ + ログ出力 | `continueOnFail: true` |
| 空のフォルダ | 「関連ファイルなし」として処理 | Drive情報整形ノードで空配列チェック |

### 6.3 Merge ノードのエラーハンドリング

| 状態 | 挙動 |
|------|------|
| 両入力あり | 正常マージ |
| Input 1のみ（Notion検索失敗） | 会話履歴のみでGeminiに渡す（現行と同等） |
| Input 2のみ（過去メール検索失敗） | 案件情報のみでGeminiに渡す |
| 両方失敗 | Gemini判断+要約準備に空データで渡す → 現行と同等動作 |

**原則:** 全てのエラーケースで「現行動作を維持する」（退行なし）。追加情報が取得できない場合は、追加情報なしで処理を続行する。

---

## 7. コスト見積もり

### 7.1 Gemini 2.5 Flash 料金

| 項目 | 単価 |
|------|------|
| 入力 | $0.15 / 1Mトークン |
| 出力 | $0.60 / 1Mトークン |

### 7.2 現行コスト

| 項目 | トークン数 |
|------|-----------|
| 判断プロンプト 平均入力 | 1,400 tokens |
| 判断プロンプト 出力 | 150 tokens |
| 返信プロンプト 平均入力 | 1,500 tokens |
| 返信プロンプト 出力 | 350 tokens |
| **1メール(返信なし)** | **$0.000300** |
| **1メール(返信あり)** | **$0.000735** |

前提: 1日50通受信、30%に返信 → **$0.022/日 = $0.66/月**

### 7.3 Phase 1 追加コスト（Notion案件情報）

| 項目 | 追加トークン数 |
|------|--------------|
| 案件情報コンテキスト（1案件） | 150-200 tokens |
| 案件情報コンテキスト（3案件） | 400-500 tokens |
| 平均追加 | 350 tokens |

| 項目 | コスト |
|------|--------|
| 1メール(返信なし) | $0.000353 (+$0.000053) |
| 1メール(返信あり) | $0.000840 (+$0.000105) |
| 1日(50通, 30%返信) | $0.025/日 |
| **月額** | **$0.75/月 (+$0.09)** |

### 7.4 Phase 2 追加コスト（Notion + Drive）

| 項目 | 追加トークン数 |
|------|--------------|
| Drive情報コンテキスト（10ファイル） | 300-500 tokens |
| 平均追加（Phase 1含む合計） | 600 tokens |

| 項目 | コスト |
|------|--------|
| 1メール(返信なし) | $0.000390 (+$0.000090) |
| 1メール(返信あり) | $0.000915 (+$0.000180) |
| 1日(50通, 30%返信) | $0.027/日 |
| **月額** | **$0.81/月 (+$0.15)** |

### 7.5 外部API コスト

| API | コスト |
|-----|--------|
| Notion API | 無料（ワークスペース内部利用） |
| Google Drive API | 無料枠内（1日10,000クエリ、50通/日なら余裕） |
| **追加インフラコスト** | **$0** |

### 7.6 コストサマリ

| 構成 | 月額 | 現行比 |
|------|------|--------|
| 現行 | $0.66 | - |
| Phase 1 (Notion) | $0.75 | +$0.09 (+14%) |
| Phase 2 (Notion + Drive) | $0.81 | +$0.15 (+23%) |

**結論:** 月額+$0.09〜$0.15の増加は極めて軽微。追加インフラコストもゼロ。

---

## 8. .env の追加変数

### 8.1 必須追加変数

| 変数名 | 値 | 用途 |
|--------|-----|------|
| `NOTION_ANKEN_DB_ID` | `1a4e8d62e4aa81c7bdb4c3c0ea47633a` | 案件DB ID（タイトル名字検索対象） |
| `GOOGLE_DRIVE_CASE_FOLDER_ID` | `15NCGQZYb6y0op-SOCV7Djt_mzM-lTwJz` | 事件記録フォルダID（Phase 2で使用） |

### 8.2 既存変数の確認

| 変数名 | 現状 | 変更要否 |
|--------|------|---------|
| `NOTION_INTEGRATION_TOKEN` | 設定済み | 変更不要 |
| `GEMINI_API_KEY` | 設定済み | 変更不要 |
| `GEMINI_MODEL` | (未使用: WF内でgemini-2.5-flashをハードコード) | 変更不要（※将来v1安定版移行時に環境変数化を検討） |
| `GOOGLE_DRIVE_FOLDER_ID` | 設定済み（添付ファイル保存用） | 変更不要 |

### 8.3 モデル更新に関する注記

- 現行WFは `gemini-2.5-flash` をURLに直接記述している（v1beta API）
- `gemini-2.0-flash-exp` は2026/3/31廃止だが、既にgemini-2.5-flashに更新済みのため**影響なし**
- 将来の改善: モデル名を `.env` 変数 `GEMINI_MODEL` に外出しし、WF内で `$env.GEMINI_MODEL` を参照する形に変更すると、モデル切替が容易になる
- v1beta → v1 安定版API移行: 現時点で緊急性なし。Google側のアナウンスに注視

---

## 付録A: 参照DB ID一覧

| DB名 | ID | 用途 |
|------|-----|------|
| 案件DB | `1a4e8d62-e4aa-81c7-bdb4-c3c0ea47633a` | 案件管理の中核DB（★本計画で検索対象） |
| 案件タスクDB | `1a4e8d62-e4aa-81f1-8ede-c239ea53299b` | 案件に紐づくタスク管理 |
| 顧客DB | `1aae8d62-e4aa-80c2-8220-fa31da7870e9` | 顧客情報（multi-data-source） |
| 顧客DB data_source_id | `1aae8d62-e4aa-809d-a2c6-000b658e92e9` | 顧客DBクエリ用（Phase 3以降） |
| 新メールDB | `306e8d62-e4aa-80f5-b61b-cd2a398225e7` | Gmail v4.0の受信メール保存先 |
| 旧メールDB | `2a5e8d62-e4aa-8045-8fd4-f72ed3a0c222` | 旧メール管理（参考用・本計画では使用しない） |

## 付録B: 案件DBプロパティ → コンテキスト用途マッピング

| プロパティ | 型 | コンテキストでの用途 | Phase |
|-----------|-----|---------------------|-------|
| タイトル | title | 案件名の把握・名字検索キー | 1 |
| 段階 | select | 手続きの現在段階（協議/訴訟等） | 1 |
| ステータス | status | 案件の作業状態 | 1 |
| 現状メモ | rich_text | 直近の状況・進捗 | 1 |
| 次の作業内容 | formula | 今後の予定作業 | 1 |
| 次の期日 | formula | 直近の期日 | 1 |
| 対外期限 | formula | 裁判所等への提出期限 | 1 |
| 担当事務 | multi_select | 担当事務員 | 1 |
| 事件番号 | rich_text | 事件番号（あれば） | 1 |

## 付録C: Google Drive フォルダ構造

```
事件記録フォルダ (15NCGQZYb6y0op-SOCV7Djt_mzM-lTwJz)
├── [35 files] Gmail v4.0自動保存の添付ファイル
│   命名規則: YYYYMMDDHHMMSS_senderPrefix_senderEmail_originalName.ext
└── scansnap/ (1Us81ij37-rKoWpUBrYM90f_rbpNcDJVS)
    ├── [7 PDF files] ScanSnap手動スキャン文書
    └── お知らせ/ (1VeS3EhK4EVgkJZcj06ca712dQxy01bWc)
        └── [1 PDF file] 行政通知文書

合計: 43ファイル + 2サブフォルダ (約29MB)
```
