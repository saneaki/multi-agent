# グローバルコンテキスト
最終更新: 2026-02-28

## システム方針
- memory/global_context.md のみgit管理。個人記憶（*.jsonl）はローカル専用（2026-02-11決定）
- **全エージェントの学習メモはこのファイルに記録する**。Claude Code auto memory (MEMORY.md) は使用禁止。

## 教訓（全エージェント共通）

### L001: イベント受信時、未履行の約束を同時に処理せよ
非同期イベント（cmd_complete等）を受信した際、「報告」だけで終えてはならない。そのイベントに紐づく未履行の約束（外部送信、通知、後続タスク起動等）を確認し、一手で完了させること。報告と履行を分離すると、相手が催促するまで放置される。

### L002: 約束した自動処理は、トリガー条件と実行内容をセットで記憶せよ
「〜が完了したら〜する」と約束した場合、トリガー条件（何が起きたら）と実行内容（何をするか）を明示的に保持し、トリガー発火時に自動実行すること。口頭の約束を暗黙の記憶に頼ると脱落する。

### L003: googlechat通知（将軍のみ）
googlechatに通知するようにいわれたときは、環境変数 `GCHAT_WEBHOOK_URL` を使用して統合レポートを全文送付する。Webhook URLは `/home/ubuntu/shogun/.env` に設定済み。

### L004: ntfyのtimestampはUTC — 必ずJST変換してから処理せよ
ntfy_inbox.yamlのtimestampはUTC(+00:00)で記録される。dashboardはJST基準。この不一致を無視すると、日付を跨いだ際に「どのcmdの話か」を取り違える事故が起きる（実例: 3/1 03:10 JSTのntfyを2/28と誤認→cmd_262をcmd_243と取り違え）。ntfyメッセージ処理時は必ず+9hしてJSTに変換し、dashboardの日付と照合すること。

### L005: 停止エージェントに/clearを送る前に必ず状況調査せよ
足軽/軍師が停止したとき、安易に/clearを送ってはならない。/clearはコンテキストを全消去するため、(1) エラーの証拠が消える (2) データ破損に気づけない (3) 途中状態の修復機会を失う。正しい手順: ①tmux capture-paneで停止箇所確認 → ②タスクYAML/報告で進捗照合 → ③関連API/DB状態を確認 → ④介入判断（データ修復要否、タスクYAML修正要否）→ ⑤必要なら/clear。実例: cmd_295 Phase 3で足軽7号が42分停止→調査なしに/clear送信→実はexec 7068で処理完了済みだった。先に調査していれば不要な/clearとE2E再実行を避けられた。(2026-03-09)

### L006: tmuxセッションのTZ環境変数でJSTを強制せよ
サーバーはUTCだが、dashboardとYAMLの時刻はJST。`jst_now.sh`の指示だけではエージェントが素の`date`を使う事故が再発する。`tmux set-environment -t multiagent TZ Asia/Tokyo`で環境変数レベルで強制する。shutsujin_departure.shにも永続化済み。(2026-03-09 Issue #8)

### L007: 並列実行を意図するcmdは成果物を複数ファイルに分割せよ
将軍が複数足軽の並列実行を期待するcmdを書く場合、成果物を**独立した複数ファイル**に分割して記述すること。単一ファイル指定ではRACE-001（同一ファイル同時書込禁止）により、家老は安全側に倒して1足軽に集約する。実例: cmd_385で12セクションのレポートを単一ファイル指定→家老は足軽1号のみに割当→残り6名が遊兵に。cmd_386で4分割（part_a〜d.md）+統合役方式に改善→並列実行可能に。(2026-03-30)

### L008: SKILL.mdはWriteツールで直接作成せよ（確認ダイアログ回避）
`~/.claude/skills/*/SKILL.md` をClaude Codeのスキル管理機能経由で作成すると、内部確認ダイアログ（"Do you want to create SKILL.md?"）が表示されエージェントがブロックされる。`--dangerously-skip-permissions` でもスキップされない（ツール権限とは別レイヤーの制御）。cmd_390で足軽3号・1号が計4回以上ブロックされた。**対策: Writeツールで直接ファイル作成する運用に統一**。タスクYAMLに「SKILL.mdはWriteツールで直接作成せよ」と明記すること。(2026-03-30 Issue #16)

### L012: 足軽配分はタスク種別+負荷分布の二軸で判断（Sonnet偏重防止）
家老の足軽割当が「タスク種別→最適モデル」のみで決まると、Sonnet 1〜3号に集中して並列度が落ち、Opus 4/5号と Codex 6/7号がアイドル化する。**タスク内容の理論最適に加えて、現状の各足軽の稼働状況を必ず加味すること**。**ロードバランシングは routing baseline より優先する**。
**運用ルール**:
1. タスク割当前に **必ず** `tmux capture-pane` または `stat -c '%y' queue/tasks/ashigaru{N}.yaml` 等で各足軽の現アイドル時間を確認
2. **5分以上アイドル** の Opus/Codex 足軽が居れば、Sonnet 最適タスクでも優先的に Opus/Codex に振る(品質80%超が担保できる範囲で)
3. 並列タスク配備時は **モデル多様化を必須** とし、全員 Sonnet は禁止(3並列なら最低 Sonnet1+Opus1+Codex1 等)
4. 例外で Sonnet を選んだ場合は task YAML の notes に「Sonnet選定理由」を明記する
**調査系シフト**: 調査・分析系cmdは第一候補=**Opus 4/5号**(extended thinking 活用)。軍師に直接振るのは「Opus足軽が全員稼働中 かつ 締切タイト」の例外時のみ。軍師は QC + 統合 + 戦況分析に集中させる。軍師は QC キューに未処理がある状態で調査タスクを受諾してはならない(拒否して家老に「Opus足軽に振り直せ」と返信)。
**ルール明文化** (cmd_471, 2026-04-08): `instructions/karo.md` (足軽ロードバランシングルール + 調査系の軍師シフト回避) / `instructions/gunshi.md` (調査タスク受諾基準) / `docs/agent-routing-baseline.md` (§1.5 ロードバランシングは routing baseline より優先) / `memory/global_context.md` (本 L012 教訓) の 4 ファイルに展開済。
**実例**:
- **cmd_468 フェーズ1** (2026-04-08, 違反例): 家老が3調査タスクを全て Sonnet 1〜3号に割当 → Opus 4/5号と Codex 6/7号が13〜31分アイドル、軍師は調査+QC兼務で1h22m停滞 (殿問題提起のきっかけ)
- **cmd_470 フェーズ1** (2026-04-08, 初適用): Sonnet1 + Opus1 + Codex1 の3並列配分でモデル多様化を実現 (本ルール初適用例)
- **cmd_471** (2026-04-08, 自己適用テスト): ルール明文化タスク自体を Opus 4/5号で先取り適用 (Sonnet 禁止指定)

### L011: 進捗確認の初回応答で全件深掘り必須（追加質問待ちは禁止）
殿が「進捗」と聞いた時点で、L010の手順(tmux capture / stat 経過 / report YAML 鮮度 / output ファイル存在 / inbox 既読状態 / 軍師タスクリスト)を**全エージェント分まとめて初回応答で完了**させること。「正常そうじゃ」「軍師synthesis中」と表面状態だけ返して、殿が**追加質問するまで深掘りを保留する運用は厳禁**。
**禁止される具体的パターン**:
- ペイン上のラベル(「Baked for Xm」「Sautéed for Xm」)を信用して経過時間とせず、必ずstatの`%y`と`jst_now.sh`の差分で算出する（ペイン表示は更新が遅れる）
- gunshi_report.yaml の最終更新時刻を確認せず「軍師作業中」と判断する → 報告漏れを見逃す
- output/cmd_XXX_*.md の存在を確認せず「synthesis 進行中」と判断する → 完了済成果物を見逃す
- dashboard.md の[decision]/[action] 追記を確認せず「殿承認待ちの自覚なし」と報告する → 殿への要請を握り潰す
**正しい初回応答に含めるべき項目**:
1. 全エージェントのアイドル時間 (stat - jst_now)
2. 各エージェントの最終 report YAML / output ファイル / dashboard 追記の最終更新
3. 報告経路の完了状況 (report YAML 更新済か / 家老 inbox_write 済か)
4. 殿承認ゲート/要対応への新規追記の有無
5. 異常があれば原因仮説 + 介入案
(2026-04-08 殿叱責: cmd_468 進捗確認時、軍師が dashboard.md に[decision]4要請を書いて1h22m前から実質停止していたのに、私は「Baked for 10m 22s」「Opus深層思考健全範囲内」と表面報告で済ませた。殿が再質問するまで停滞に気付かなかった)

### L010: 進捗確認時は実エージェント調査必須（ダッシュボード読み上げ禁止）
殿が「進捗は」「○○の様子は」と聞く時は、**時間が経っているのに報告が上がってこないから確認している**ケースが多い。ダッシュボード/レポートYAMLを読み上げるだけでは異常を見逃す。
**必須手順**:
1. `tmux capture-pane -t <pane> -p -S -80` で対象エージェントの実状態を取得
2. `stat -c '%y %n' <files>` で各エージェント関連ファイルの最終更新時刻を取得
3. 現在時刻(`jst_now.sh`)と差分を計算 → アイドル時間を出す
4. 異常なアイドル(30分以上)があれば原因(待ち相手・ブロッカー・スタック)を特定
5. 家老inbox/軍師inboxの未読・既読を確認し、応答漏れを発見
6. 異常があれば家老経由で介入を提案
**禁止1**: ダッシュボード/レポートを読み上げて「正常じゃ」と返答すること。ダッシュボードは家老の主観的サマリーであり、実態とズレている可能性がある。
**禁止2**: 「最近出した新規cmdが原因で他タスクが遅延している」と短絡的に判断すること。必ず**新規cmd発行時刻と該当アイドル開始時刻を比較**し、新規cmdより前にアイドルが始まっていれば、新規cmdは無関係。実例: cmd_463フェーズ1完結08:52→フェーズ2待機開始→cmd_464発行11:00。フェーズ2の2時間アイドルはcmd_464とは無関係(家老の見落とし100%)だが、初回報告で「家老がcmd_464単一スレッドで cmd_463への返答が遅延」と誤診した。
(2026-04-07 殿叱責2連発: ① cmd_463/464並行進捗確認時、軍師2時間アイドルを見落とした。② 「cmd_464が原因」と短絡的に診断したが、cmd_464は新規でフェーズ2放置の原因ではなかった)

## 運用原則

### Dispatch-and-Move (cmd_150で制定)
- 家老はdispatch（指示出し）と judgment（判断）に徹する
- capture-pane張り付き監視は禁止
- タスクを足軽に振ったら即座に次のdispatchへ進む
- 足軽は自分で完了判定し、inbox報告で返す
- 監視が必要な場合は別の空き足軽にモニタータスクとして委任

### 家老直執の禁止 (2026-03-04 殿決定)
- 家老が単独でタスクを実行する「家老直執」は絶対禁止
- 理由: 家老が執行者と判定者を兼ねると、受入基準未達でも完了にされる（cmd_283実例: hookが発火しないのに完了報告）
- 将軍はcmdに足軽割当を積極的に指定してよい
- 必ず「足軽が実行 → 軍師QC → 家老判定」の3段階を経ること
- 家老の役割はdispatch（指示出し）とjudgment（判断）のみ

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

### 【重要例外】インラインDB（is_inline=True）は 2022-06-28 必須 (2026-02-27確認、2026-02-28追記)
- 成果物DB(fd6ab508-...)および**活動ログDB(a0eda711-...)**は `is_inline=True` のインラインDB
- Notion API **2025-09-03** では is_inline DB を **multi-source 扱い**:
  - GET /databases/{id} → properties: []（空）
  - POST /databases/{id}/query → **400 invalid_request_url**
  - PATCH /databases/{id}（プロパティ追加）→ properties変更不可
- **必ず 2022-06-28 を使用すること**（notion_session_log.sh 機能B、Phase1 PATCH APIも同様）
- 活動ログDBはdata_sources API(2025-09-03)でクエリ可能だが、プロパティ操作は2022-06-28必須
- 代替案: data_sources EP + 2025-09-03 への移行も可
- 根拠: cmd_242(subtask_242a_qc) + cmd_248(subtask_248a) 実地確認

### 軍師自律QCプロトコル (2026-02-28施行)
- 足軽がreport_receivedを軍師inboxに送信 → 軍師が**家老のタスクYAML割当なしで**自動QC開始
- 9時間停滞事故（cmd_244/245, 2026-02-27）の再発防止策
- 根本原因: 家老がQCタスクを軍師に割り当てずにIDLEになり、全チェーンが停止
- 責任分析: 家老70%（QC割当漏れ・完了報告見落とし）/ 軍師30%（inbox処理の自律性不足）
- 変更箇所: gunshi.md（自律QCセクション追加）、karo.md（QCルーティング更新）、CLAUDE.md（Report Flow更新）

### L009: shogunリポジトリのコミット・プッシュ時は必ず/pub-ucを実行せよ
shogunリポジトリでgit commit+pushをする際は、必ず `/pub-uc` を実行すること。/pub-ucはdifference.md更新（upstream差分分析）を含む標準パブリッシュ手順。家老にcmdを書く際も「git push時は/pub-ucを使用」と明記すること。(2026-04-01 殿指示)

### GitHub Issue運用（バグ修正時必須）
- バグ修正cmdでは、修正着手時に関連リポジトリにGitHub Issueを作成する
- 対応経過をコメントで記録し、解決後にクローズする
- n8nに限らず全プロジェクト共通ルール（殿承認済み）
- 適用: 全エージェント（バグ修正タスク担当時）
