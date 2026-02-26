# グローバルコンテキスト
最終更新: 2026-02-16

## システム方針
- memory/global_context.md のみgit管理。個人記憶（*.jsonl）はローカル専用（2026-02-11決定）
- **全エージェントの学習メモはこのファイルに記録する**。Claude Code auto memory (MEMORY.md) は使用禁止。

## 教訓（全エージェント共通）

### L001: イベント受信時、未履行の約束を同時に処理せよ
非同期イベント（cmd_complete等）を受信した際、「報告」だけで終えてはならない。そのイベントに紐づく未履行の約束（外部送信、通知、後続タスク起動等）を確認し、一手で完了させること。報告と履行を分離すると、相手が催促するまで放置される。

### L002: 約束した自動処理は、トリガー条件と実行内容をセットで記憶せよ
「〜が完了したら〜する」と約束した場合、トリガー条件（何が起きたら）と実行内容（何をするか）を明示的に保持し、トリガー発火時に自動実行すること。口頭の約束を暗黙の記憶に頼ると脱落する。

### L003: googlechat通知（将軍のみ）
googlechatに通知するようにいわれたときは、環境変数 `GCHAT_WEBHOOK_URL` を使用して統合レポートを全文送付する

## 運用原則

### Dispatch-and-Move (cmd_150で制定)
- 家老はdispatch（指示出し）と judgment（判断）に徹する
- capture-pane張り付き監視は禁止
- タスクを足軽に振ったら即座に次のdispatchへ進む
- 足軽は自分で完了判定し、inbox報告で返す
- 監視が必要な場合は別の空き足軽にモニタータスクとして委任

### 30分ルール (cmd_150 08:18で制定)
- 足軽が30分以上作業中の場合、家老は自発的に:
  1. 状況確認（report YAML or 単発capture-pane）
  2. 問題引き取り
  3. タスク細分化して再割当

### エラー修正時のGitHub Issue運用 (2026-02-24 殿決定)
- バグ修正着手時に、関連リポジトリにGitHub Issueを作成する
- 調査結果・修正内容をIssueコメントに経過記録する
- 解決したらクローズ（解決方法をコメントに残す）
- n8nに限らず全プロジェクト共通ルール
- 家老がタスク分解時にIssue作成を手順に含めること

## n8n技術メモ

### ReadWriteFile ノードパラメータ (cmd_149で判明)
- Read: `fileSelector` (NOT filePath)
- Write: `fileName` + `dataPropertyName` (NOT filePath/fileContent)
- 計画書のパラメータ名が不正確だった → タスクYAMLに正しい名前を明記すること

### Gmailダイジェスト通知WF (XgI1VYV2oDZyGKhf)
- 正しいプロパティ: "通知済み"（NOT "対応済み"）
- cmd_141で"対応済み"に変更したのは意味的に誤り → cmd_150で修正
- 3層問題パターン: $envブロック → プロパティ名誤変更 → DB側リネーム

### n8n Code Node sandbox制限 (cmd_149で判明)
- n8n 2.7.5のJS Task Runnerではrequire('fs')がデフォルト禁止
- 解決: docker-compose.ymlに NODE_FUNCTION_ALLOW_BUILTIN=fs,path,crypto,... 追加
- ReadWriteFile writeはテキスト直接書き込み不可 → Code nodeでrequire('fs')使用

### n8n並列入力の制限 (cmd_149で判明)
- 2ノードから同一input indexへの接続はOR条件（両方の完了を待たない）
- 解決: フローを直列化

### n8n内部REST API (cmd_149で判明)
- 手動実行: POST /rest/workflows/{id}/run (triggerToStartFrom必須)
- アクティベーション: POST /rest/workflows/{id}/activate (versionId必須)
- 公開API v1にはworkflow実行エンドポイントなし

### n8n expression {{ }} terminator衝突 (cmd_184で判明)
- `={{ JSON.stringify({...nested...}) }}` でJS内の `}}` がn8n式終了と誤判定される
- 症状: curlは成功するのにn8nで "invalid syntax" → expression評価エラー
- 回避策: JSON.stringifyをやめ、JSONリテラルに `{{ $json.field }}` を埋め込む
- 例: `{"filter":{"property":"名前","title":{"contains":"{{ $json.name }}"}}}` (= prefix不要)

### n8n Merge node v2→v3 モード名変更 (cmd_183で判明)
- v2: `mode: "combineMergeByPosition"` / v3: `mode: "combine"` + `combineBy: "combineByPosition"`
- v3に旧モード名を使うと `Cannot read properties of undefined (reading 'execute')`

### n8n HTTP Request credential空参照 (cmd_183で判明)
- `authentication: "genericCredentialType"` に `credentials` フィールドなし → "Credentials not found"
- 手動ヘッダーで認証する場合は `authentication: "none"` を使う

## 運用ルール追加 (2026-02-24決定)

### Notion APIバージョン統一 (2026-02-24決定)
- 全WF・スクリプトをNotion API 2025-09-03に統一する（原則）
- 新規構築は即時適用、既存WFは順次移行
- 主な変更点: data_source_id必須、Search APIフィルタ値変更(database→data_source)
- 参考: https://developers.notion.com/docs/upgrade-guide-2025-09-03

### 【重要例外】インラインDB（is_inline=True）は 2022-06-28 必須 (2026-02-27確認)
- 成果物DB(fd6ab508-...)は `is_inline=True` のインラインDB
- Notion API **2025-09-03** では is_inline DB を **multi-source 扱い**:
  - GET /databases/{id} → properties: []（空）
  - POST /databases/{id}/query → **400 invalid_request_url**
- **必ず 2022-06-28 を使用すること**（notion_session_log.sh L461 参照）
- 代替案: data_sources EP (ds_id: d718bbe4-312d-4e4d-8111-70bd571ac4a2) + 2025-09-03 への移行も可
- 根拠: cmd_242 軍師QC (subtask_242a_qc) で実地確認

### GitHub Issue運用（バグ修正時必須）
- バグ修正cmdでは、修正着手時に関連リポジトリにGitHub Issueを作成する
- 対応経過をコメントで記録し、解決後にクローズする
- n8nに限らず全プロジェクト共通ルール（殿承認済み）
- 適用: 全エージェント（バグ修正タスク担当時）
