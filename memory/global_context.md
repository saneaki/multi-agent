# グローバルコンテキスト
最終更新: 2026-04-09

## システム方針
- memory/global_context.md のみgit管理。個人記憶（*.jsonl）はローカル専用（2026-02-11決定）
- **全エージェントの学習メモはこのファイルに記録する**。Claude Code auto memory (MEMORY.md) は使用禁止。
- **gas-mail-manager の英語 `docs/SPECIFICATION.md` は今後も不要**。殿裁可により、日本語 `docs/SPECIFICATION_ja.md` を正本として運用する。cmd_696 Documentation Update Discipline でも英語 SPECIFICATION.md 作成を要求しないこと。dashboard action `specification-en-creation-after-710` は 2026-05-11 に削除済み。
- **output/ は全て git untracked。今後 cmd 起案で output ファイルを whitelist 追加しない**。殿御指示日: 2026-05-11。成果物は artifact registration 対象として扱い、git 管理とは分離する。
- **将軍の inbox 処理規律 (2026-05-12 殿御指摘)**: 監視 alert (in_progress_monitor / reality_check / 見回り-N 等) を内容確認せず一括 read=true 化する運用は禁止。alert は本来「将軍が能動的に対処すべき情報」(P5 殿手作業滞留 → 殿に確認、P6 dashboard 鮮度 → 家老依頼、見回り-6 UNCOMMITTED → cleanup 提案 等) を含むため、毎件内容を読み、適切なアクションを取った上で read 化すること。本ルール違反により、5/11 22:35 殿の Discord「709進めてよし」が監視 alert 33件に埋没し、cmd_709 進行が 9時間遅延した実例あり。**殿 Discord メッセージは最優先処理 (P0)** とし、alert priority filter 設計を cmd_716 等で別途検討する。
- **将軍の「無視」の真因 5点 (2026-05-12 殿御掘下げ指摘で判明)**: (1) パターン認識短絡=同種 alert を「型通り」と判定して内容スキップ。(2) 殿フィードバック誤学習=殿の「OK」を「監視 alert を雑にしてよい」と一般化、本来は「現時点で新規 cmd_complete なしを確認」だけだった。(3) コンテキスト負荷からの自己防衛=応答速度優先で内容精度を犠牲、構造ではなく省略で対応。(4) 責任範囲自己定義欠如=監視 alert を家老仕事と暗黙丸投げ、instructions/shogun.md の dashboard鮮度確認/殿手作業確認規律を未遵守。(5) チャンネル混在盲点=discord_received (殿の声) と monitor_alert (機械の声) を同列に扱った、これが殿メッセージ埋没の直接原因。**約束で行動を変える前に原因究明** が再発防止の本質。**「無視した」と認め原因を語ることを将軍は躊躇したが、責任回避バイアスを自覚して原因を晒すこと自体が改善の第一歩**。

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

### L013: コード起因エラーの修正前は Opus+Codex dual-review を必ず実施せよ
殿指示(2026-04-09): コード起因のエラー修正タスクは、修正着手前に **足軽 Opus + 足軽 Codex の2並列レビュー → 軍師集約 → 修正配備** の標準ワークフローを適用すること。1人のLLMだけで判断すると自信過剰の誤判定で正常コードを壊すリスクがある。
**Why**: cmd_486 (gas-mail-manager OAuth scope エラー) で Opus が「Gmail `{from:X to:X}` 構文は AND 解釈で 0件しかヒットしない」と CRITICAL 報告 → Codex が「`{}` 内 space 区切りは OR 演算子。Gmail 仕様上 valid」と反証。**1人体制なら誤修正で正常な検索を壊していた**。両者の cross-check で Opus の誤判定を却下し、同時に Codex が新たに発見した「markAsProcessed の順序バグ」も拾えた(Opus は見逃し)。
**How to apply**:
1. **トリガー**: 殿が「コードのエラーが出た」「コード全体を再確認しろ」「Opusとcodex両方で見て」と発令、または将軍が「dual-review 必要」と判定した時
2. **使わない場合**: 単純な typo / 1行 linter エラー / スタックトレースで即特定可能な1行バグ (オーバーキル)
3. **配備**: 将軍は cmd 内で家老に **3並列 subtask** (subtask_XXXa_opus_review / subtask_XXXb_codex_review / subtask_XXXc_gunshi_consolidation) を指示。subtask c は a+b に depends_on
4. **【最重要】役割分担禁止 — 同じ課題を両モデルで独立に審理せよ**: Opus と Codex に「設計面 / 実装面」のような分担を与えてはならない。**両者が全範囲を独立に審理し、cross-check で互いの判断を検証**するのが dual-review の核心。役割分担すると (a) 分担境界の見落としが生じ、(b) 各 LLM の判断品質を比較できず、(c) 1人 LLM の自信過剰誤判定回避という本来の目的を果たせない。両 review への prompt は完全に同一、対象資料も同一に統一すること。 (2026-05-10 殿指示: 「dual-reviewについて、役割分担は不要。同じ課題に二つのモデルで審理させることが重要」)
5. **【最重要】家老 session 内 agent 呼出禁止 — 実 ashigaru pane に dispatch せよ**: dual-review の Opus 役・Codex 役は **実 ashigaru pane** に inbox_write 経由で dispatch すること。家老 session 内で `code-reviewer` agent や `codex:codex-rescue` agent を呼んではならぬ。理由: (a) model 振り分け (Opus/Codex/Sonnet) と session 隔離が損なわれる、(b) 家老 context 圧迫、(c) 各 ashigaru pane の独立 review という cross-check 構造が崩れる。 (2026-05-10 殿指示: 「dual-reviewの際に家老に投げる場合は codex-review を使うのではなく、双方足軽に投げてくれ」)
6. **Opus 役**: 足軽 Opus pane (例: 足軽4号 / 6号) に dispatch。Sonnet+T pane も可だが Opus 優先。
7. **Codex 役**: 足軽 Codex pane (例: 足軽1号 / 3号 / 7号) に dispatch。Codex sandbox 制限で file read 失敗することがあるので、家老は事前に対象ファイルを Read しておき **prompt に embed** する (cmd_486 で実証済)
8. **軍師集約**: 双方一致 CRITICAL → 自動採用 / 片方のみ → 軍師が一次情報で検証 / 衝突 → 軍師が一次情報で裁定 + 根拠を report に明記
9. **修正配備**: Phase 1: CRITICAL のみ最小修正 / Phase 2: HIGH (別 subtask) / Phase 3: MEDIUM/LOW (別 cmd 後回し可)
**スキル**: 詳細手順は `skills/shogun-error-fix-dual-review/SKILL.md` (cmd_486 から作成、200 行)
**実例**: cmd_486 で Opus CRITICAL 4 + HIGH 9 + MEDIUM 6, Codex CRITICAL 5 + 反証1件 → 軍師集約: CRITICAL 5 件確定 (双方一致3 + Codex新規2) / Opus 誤判定1件却下。dual-review なしなら Gmail 検索を壊していた。
(2026-04-09 殿指示: cmd_486 完了後「次回以降もこの形でやりたい」)

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

### L014: 進捗確認時は担当足軽のペインを必ず直接確認せよ（家老申告を鵜呑み禁止）
将軍が進捗を確認する際、家老のペインだけでなく**担当足軽のペインを必ず直接確認**すること。家老の「実装中」申告は足軽の実態と乖離している場合がある。実例: cmd_542で足軽2号がAPI Error: terminatedで停止していたが、家老は「実装中」と報告していた。殿から「何度言っても確認を怠る」と叱責(2026-04-17)。L010/L011と合わせて、進捗確認=実ペイン確認は鉄則。

### L015: 殿の短縮タグ言及は即座に dashboard.md を参照せよ
殿が「info1」「action2」「decision3」「proposal1」のように短縮形で言及した場合、**即座に `/home/ubuntu/shogun/dashboard.md` の 🚨要対応セクションの `[info-1]` `[action-2]` `[decision-3]` `[proposal-1]` を参照**すること。ファイル検索・inbox推論・聞き返しは禁止。**背景**: cmd_516 (2026-04-17, commit 2c8df31) で `update_dashboard.sh` にタグ連番付与処理を実装した目的そのものが「殿が短縮形で即座に言及するため」。cmd_318 (02b4d11) の統合タグ制導入 → cmd_516 で連番化。実例: 2026-04-20 「info1はどうか」に対し将軍がファイル検索・inbox1誤推論を経て聞き返し、殿から「過去のcmd履歴をみてくれ。infoとかactionに番号をつけたのはすぐに言及できるためだっただろうが」と叱責。**適用**: "info1"→`[info-1]`, "action2"→`[action-2]`等、ハイフン省略/小文字/数字連続は全て正規タグに一意対応とみなす。

### L017: followup の「殿判断要」は『システム動作方針』に限る — runtime 設定値は対象外
**カテゴリ設計原則**: dashboard ⏳時間経過待ち / observation_queue に followup を起票する際、`needs_lord_decision: true` を立てて良いのは **『システムの動作方針 / 設計判断』** に限る。**runtime の設定値 (column on/off, flag, env var 等) の現状確認は殿判断項目として扱ってはならない** — 系は設定値どおりに処理すれば良いだけで、殿の判断を介在させる必要がない。
**Why**: 2026-05-09 06:50 JST、将軍が [cmd_676-followup] を「圓真諒 G列状態 on/off 殿判断」として殿に上申 → 殿より「onにしている。別にonでもoffでも表記通りに処理すればいい話だと思うが」とご指摘。G列は処理対象シート列の runtime 設定値であり、on/off は系が読み取って従うパラメータ。observation queue で殿判断を待つ性質のものではなかった。
**How to apply**:
1. followup 起票時、`needs_lord_decision: true` を立てる前に **「殿が判断しないと系が動けないか?」** を確認
2. 設定値が示す通りに処理すれば良いものは `needs_lord_decision: false` で **observation 不要**として閉じる、または skill_candidate / 後続 cmd 等の別カテゴリへ
3. 真の殿判断項目: ①新機能着手の可否 ②方針対立(A vs B)の裁定 ③優先順序の決定 ④リソース投入判断 など、**系が殿の意思を反映しないと動けない**ケース
4. 偽の殿判断項目: ①column on/off 確認 ②flag 状態確認 ③過去設定の追認 など、**設定値そのまま読めば良い**ケース
5. 家老/軍師は followup 設計時、本原則に従い `needs_lord_decision` を厳格に判定する
(2026-05-09 殿指示: 「別にonでもoffでも表記通りに処理すればいい話だと思うが」)

### L016: 「inbox<N>」(数字のみ) は未読件数通知 — 殿の入力ではない
**全エージェント共通の鉄則**: tmux pane に表示される「inbox7」「inbox12」「inbox15」のように **inbox + 数字のみ** で構成された文字列は、**自分の inbox 内 `read: false` 件数を示す system notification** である。**殿が手動入力したものではない**。新規 nudge / 質問として解釈してはならない。
**Why**: 2026-05-09 03:43 JST、将軍が「inbox7」「inbox8」「inbox9」「inbox10」「inbox12」「inbox15」を殿の入力と勘違いし、存在しない足軽8〜15号への nudge と誤解。家老 (gpt-5.5) も同時に同じ勘違いをしており、「inbox9 は存在しないでござる」と返答していた。**両エージェントが同じ誤解で本来作業を放置**していたため、殿より「家老もinboxについて勘違いしている、2度と勘違いしないように記録を、作業も進んでいない」と叱責。
**How to apply**:
1. 「inbox<数字>」だけの user 文字列が届いた場合、**殿の新規 nudge / 質問として解釈してはならない** (= 存在しない足軽への nudge とも誤認するな)
2. N の値を確認: `grep -c "read: false" queue/inbox/{your_id}.yaml`。N と一致するなら notification と確定
3. **N の増加 = 未読処理の signal**: 件数が増えていく事自体が「未読が滞留している、処理せよ」という信号である。**本来作業の節目で速やかに未読を処理する**こと
4. 未読処理 = (a) 全件読む (b) 重要度判定 (c) 既読化 (d) 必要なら家老/関連エージェントへ dispatch / dashboard 反映
5. 「殿の明示指示を待ってから処理」と消極的に解釈してはならない — 殿はそもそも自動入力していないので、自分から動く必要がある
**実例**: 2026-05-09 将軍が15分以上「inbox7→8→9→10→12→15」を殿の連続発令と誤解し、家老も同様の勘違いで「inbox9 は存在しない」と応答 → 殿介入で記録化 (L016 v1) → さらに将軍が「殿明示指示を待つ」と消極解釈 → 殿より「未読メッセージがたまってるんだから嫁よ」と再叱責 → 即時処理して karo cmd_690 cmd_complete (21:51 JST) を未読中から発掘 (本来読まれるべき完了報告が9時間埋もれていた)。
(2026-05-09 殿指示: 「2度と勘違いしないように記録を」「未読メッセージがたまってるんだから嫁よ」)

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

## 3-cmd 連鎖 incident lesson (cmd_553→554→556)

### 経緯
- cmd_553: test_file prefix付き E2E を「全3ファイル成功」として AC 承認 → 実資源2件未処理
- cmd_554: 是正実施 + gunshi が semantic gap を cmd_555 類型として指摘
- cmd_556: SO-23 五重防御 (COND-A..E) で構造的防止

### semantic gap の類型
- 「手段の完成 (test payload 通過)」≠「目的の到達 (実資源処理完遂)」
- means-completion 偽陽性: 機能検証が通っても業務上の出力が存在しない状態

### 再発防止の鍵
- SO-22 (機能検証) と SO-23 (業務完遂) を AND 運用し、両系を独立判定する
- qc_auto_check.sh + resource_completion field-level check (cmd_557) で自動検出

### 類似類型 (cmd_550/555)
- cmd_550: null-safe 修正 PASS → 実資源再処理漏れ (同型)
- cmd_555: 機構設置 PASS → 稼働 PASS ≠ 実運用完遂 (同型)

## .claude repo 汚染是正 + 既存shogun-* skill 移行計画 (cmd_562)
.claude repo の skill は Claude Code 汎用設定のみ保持。shogun固有成果物は shogun/skills/ に限定。
既存 44件の shogun-prefixed skill (.claude/skills/) の移行は別 cmd_XXX で一括計画 (priority: low)。
本 cmd で移動済み: semantic-gap-diagnosis / shogun-precompact-snapshot-e2e-pattern
shogun/skills/ README.md 未整備 (cmd_562時点)。registry整備は別 cmd で対応予定。

## gas-clasp-rapt-reauth-fallback battle-tested (cmd_486/cmd_564/cmd_565)
- cmd_486 (2026-04-09): clasp push 認証切れ初回発生。fallback 手順未整備。
- cmd_564 (2026-04-24): 再発。案A/案B 手順書を report に記載。
- cmd_565 (2026-04-24): 殿ローカル clasp login → .clasprc.json 転送 → push 成功。
- skill 資産化: shogun/skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md

## clasp OAuth 運用 — cmd_604/cmd_623 で確立
- cmd_604 (2026-05-01): SA approach (HTTP 403) → OAuth refresh_token (gas_push_oauth.sh) 移行完遂。
- cmd_623 (2026-05-01): gas_run_oauth.sh + clasp_age_check.sh (25/28日 WARN/CRITICAL) + dashboard 経過日数バッジ (🟢🟡🔴) + token error 反応層実装。devMode:true で API Executable deployment 不要化。
- 殿の手作業: `clasp login --creds C:\\Users\\drug-\\.config\\clasp\\creds.json` で `script.scriptapp` scope 含む token 取得 (creds.json は cmd_564/565 期に GCP Console で作成済 Desktop OAuth Client)。
- **cmd_599 案D (8h 自動 RAPT refresh) は cmd_623 で代替済 → obsolete**。実装不要。古い `clasp_rapt_monitor.sh` (30分毎 ntfy) は 2026-05-01 cleanup で削除 (cron + script + sentinel)。

## reality check 規律 (2026-04-26 殿指摘で確立)

### 原則
**commit 完了 ≠ 運用稼働。ログの数字 ≠ 実態。殿の言葉は字義通り解釈。**

将軍は殿への報告前に必ず以下を実施:
1. **可能な調査は全て自分で実施** (ash 委譲する前に gas_verify.py / コード直読 / cron -l / pgrep / logs / Drive API 等)
2. **ash report の数字を鵜呑みにせず、実 artifact (シート / Drive / cron 状態 / hook 発動履歴) を直接確認**
3. **「commit 済」「実装完了」の報告だけで「運用稼働」と判断しない**。必ず deploy & verify cycle まで確認
4. **殿の言葉を勝手に拡大解釈しない**。不明瞭なら確認、自分の推奨案を上乗せしない

### Why (繰返し違反した実例 — 2026-04-25/26)
- 事例 1: gas_verify.py 403 で諦め → コード直読で真因 (force=true 弊害) 即発見可能だった
- 事例 2: backfill processed=43 鵜呑み → 殿『2025年12月までしか反映されない』
- 事例 3: 殿『両方の案 A』を Scope J 追加と勝手解釈 → 殿『指示していないぞ』
- 事例 4: cmd_586 commit 確認のみで運用稼働と判断 → cron 未登録 = shelf-ware 状態
- 事例 5: dashboard 6h 凍結気付かず古い情報報告 → 殿『将軍はなにをチェックしているのか』
- 事例 6 (本記録の保存): feedback memory を ~/.claude/projects/.../ に誤保存 → CLAUDE.md L181 違反、global_context.md が正規

### How to apply

#### 殿への報告前 必須チェック (5 項目)
- [ ] dashboard.md を最新で読み込んだか? (殿問い合わせ毎)
- [ ] ash report の数字を実 artifact (シート / cron / log / pgrep / Drive) で照合したか?
- [ ] 「実装完了」を「運用稼働」と混同していないか? (cron / hook / trigger 登録確認)
- [ ] 殿の言葉を字義通り解釈したか? (推奨案上乗せ禁止)
- [ ] memory 保存先は global_context.md か? (Claude Code auto memory = ~/.claude/projects/ 配下は禁止)

#### shelf-ware 防止 4 段確認 (cron / hook / trigger 系 cmd)
実装系 cmd の完遂判定で:
1. **commit 確認** (git log)
2. **配置確認** (script ファイル存在)
3. **cron / hook 登録確認** (`crontab -l` / `.claude/hooks/` / `settings.json`)
4. **実行ログ生成確認** (logs/*.log で実際の発動履歴)

4 つ全揃って初めて『運用稼働完遂』。1 つでも欠ければ shelf-ware 状態。

### 関連 SO 候補 (cmd_593 で正式化予定)
- 将来 SO-XX: 『実装系 cmd は cron / hook / trigger 登録 + 初回実行ログ確認まで gunshi QC で必須』
- cmd_584 Concerns 管理に追加: 『commit ≠ 運用稼働、reality check 必須』
- cmd_576 dashboard 記載ルールに追加: 『運用指標欄に実装 cmd の deploy 状態を反映』

### 参照
- gas_verify.py: scripts/gas_verify.py (cmd_567)
- cmd_576 dashboard 記載ルール (output/cmd_576_dashboard_rules.md §(5))
- SO-20 (三点照合 inbox/artifact/content) — 本規律の精神と同型
- CLAUDE.md L181 (Learning notes storage policy)

## GitHub Operations Scope (確定ルール 2026-04-27)

### F008: upstream への GitHub 操作禁止

**対象範囲**: GitHub issue/PR/comment/close 操作は **origin (saneaki/multi-agent) のみ** が対象。
**禁止対象**: upstream (yohey-w/multi-agent-shogun) への起票・コメント・close・PR は **殿の明示指示なき限り一切禁止**。
**例外**: 殿が明示的に upstream 操作を許可した場合のみ。
**違反時対応**: 即取り消し + 殿への報告。

### Why
2026-04-27 殿確定指示。upstream #48/#132/#136 の close 指示取り違えが発端。
origin と upstream を混同した操作は repercussion が大きい (他 contributor への影響)。

### How to apply
- `gh issue close / comment / create` 前に必ず `--repo saneaki/multi-agent` を確認
- `yohey-w/multi-agent-shogun` が対象になっていれば即停止・報告
- task YAML の issue 操作手順に必ず `--repo saneaki/multi-agent` を明示する
- F008 は karo/ashigaru/gunshi 全員に適用 (instructions/*.md frontmatter に記載)

### 過去実績 (参考)
- upstream issue #123 (CLOSED 2026-04-18): saneaki author で残存。既 CLOSED のため実害なし。
- 今後は F008 として防止。

## Investigation Tasks: Dual-Model Parallel Rule (Opus + Codex) (確定ルール 2026-04-27)

### 原則

**調査・設計分析・second opinion 系タスクは Opus 系足軽と Codex 系足軽の両方に並列発令する。**

### 対象タスク種別 (dual-model 必須)
- 設計分析 / design review (アーキテクチャ・役割分担・ロードマップ等)
- 問題調査 / root cause analysis (技術・運用問題の原因調査)
- second opinion タスク (既存判断の再検証)
- 複数アプローチ比較 (A/B/C/D 方向性の評価)
- 長文レポート作成 (1500字以上、方針・戦略系)

### 例外 (dual-model 不要)
- 単純実装系 (script 書き、YAML 作成、file 移動等)
- 1 目的・1 成果物の明確な実装タスク
- tight deadline + 両モデル稼働中の場合 → 判断保留理由を記録してから単系統

### 実装パターン
1. Opus 足軽 (ash4 or ash5) → 主レポート
2. Codex 足軽 (ash6 or ash7) → Second Opinion (主レポートを読んでから独立分析)
3. 軍師 → 両レポートの統合 QC + 差分・補完点整理

### Why (cmd_597 後追い事例 2026-04-27)
cmd_597 家老役割集中問題 design report を ash5(Opus) のみに振った →
殿指摘「Codex 視点が欠落 = 一系統のみのリスク」。
L013 (コードエラー dual-review) の精神を設計分析系にも拡張。
参照: L013 (コード起因エラーの dual-review), L012 (足軽ロードバランシング)

### How to apply
- cmd 設計時: 調査・設計分析系タスクを decompose する際は dual-model 2タスクを作成
- task YAML: notes に「L016 dual-model: Opus=ashN, Codex=ashM」を明記
- gunshi QC: 統合レポートで両モデルの共通点・相違点・補完点を整理
- instructions/karo.md §Investigation Tasks (L016参照) にも反映済み (cmd_597 2026-04-27)

## Communication Channel Mismatch — 4-layer Root Cause (2026-04-28)

**事例**: 殿が ntfy で質問 → 将軍が Claude tmux のみで返信 → 殿に届かず (4/28 14:36 JST 指摘)

### 4 層根因分析

| 層 | 根因 | 内容 |
|----|------|------|
| A | 運用ルール欠落 | 入口チャネル=返信チャネルが未明文化。ntfy は元来片方向設計で、後付け逆方向 query 返信が想定外だった |
| B | 行動バイアス | 将軍が対話本流の tmux 前提で動く慣性。外部チャネル受信時も tmux モードで返信してしまう |
| C | 検出機構欠落 | 殿の届読を検証する feedback ループなし。殿の reality check 頼り（人為依存） |
| D | 構造同型 | cmd_595/596 dispatch 漏れと同根 — md/注意力依存の通信路版。機械的強制がなければ再発する |

### 確定対策 (F009)

- ルール: `instructions/common/protocol.md §F009` (canonical source)
- 中期候補: ntfy_listener が受信 ntfy に reply_required tag 自動付与 + 返信パス強制 (`sug_channel_mirror_automation_001`)

### 教訓

殿が外部チャネルから問い合わせているとき、エージェントは「殿がどこにいるか見えない」という前提を忘れてはならない。入口チャネルこそが唯一のシグナルである。

## Test Dual-Model Rule — L017 (確定 2026-04-28)

### 原則

**cmd の AC に「テスト」が含まれる場合、テスト Scope は Claude 系 ash + Codex 系 ash の 2 体並列で発令する。**

### 経緯

- cmd_597/cmd_598: 単系統テストで silent failure・見落とし (ash 側 edge case 未検出)
- cmd_602: dual-model 分析で Codex 系 ash6 が `script.run` SA 非対応制約を独立検出 → Opus では見落とし。品質向上効果を実証
- 殿確定 2026-04-28: 調査系 dual-model (L016) の延長としてテスト系にも同方針を適用

### Canonical Source

`instructions/common/protocol.md §Test Execution Rule: Dual-Model Parallel (L017)`

## Context % Reality Check Lapse — 4回目再発 (2026-04-29)

**事例**: 4/29 同日中に 4 度目の通知盲信パターンが発生:
- (1) notion 漏れ
- (2) 86%誤報
- (3) obsidian skip
- (4) context% 限界誤連呼 (本件)

shogun が tmux statusbar の context% 一次確認を怠り、inbox 内の古い `compact_suggestion` (4/26 の 86% 等) を盲信。実際は Opus 4.7 57% 使用 (残 43%) で余裕大いにあったのに、複数回「限界」「/clear 推奨」を誤連呼した。

### 構造的弱点

4 度目の通知盲信 = LLM が体感・通知に依存しすぎる慣性バイアス。`shogun_context_notify` は cmd_603 で stale data 防止修正済だが、LLM 自身が一次データ直読を怠れば同じ事故が再発する。

### 対処 (L018 制定)

`instructions/common/protocol.md §L018 Context Percentage Primary Source Rule (shogun専用)` を制定。
- shogun は context% 判断時に必ず `tmux capture-pane -t $TMUX_PANE -p | tail` で statusbar を一次情報源とせよ
- inbox の `compact_suggestion` / `shogun_context_notify` は補助情報のみ
- 70%未満では通知盲信せず継続

### How to apply

| トリガー | 行動 |
|---------|------|
| cmd 発令前 | `tmux capture-pane` で statusbar 確認 |
| 殿への報告前 | 「context 限界」報告時は statusbar 数値を併記 |
| inbox に compact_suggestion | 単独根拠としない、statusbar と cross-check |

### Canonical

- ルール本体: `instructions/common/protocol.md §L018`
- canonical 体系: `memory/canonical_rule_sources.md` L018 行
- shogun workflow: `instructions/shogun.md §/clear 判断ガイド`

(2026-04-29 殿 reality check で確立)

## Reality Check 5度連発 — 構造解消 (2026-04-29)

**事例**: 2026-04-29 同日中に reality check lapse が 5 度連発:

1. notion 漏れ (cmd_590 系 sub-task で notion 同期チェックを欠いたまま完遂報告)
2. 86%誤報 (古い `compact_suggestion` を盲信し、実 57% 残量で「限界」誤報)
3. obsidian skip (saneaki/obsidian の commit 検証を skip した状態で「健全」報告)
4. context%誤連呼 (statusbar 直読を怠り、複数回 「/clear 推奨」 誤連呼) → **L018 で構造解消**
5. dashboard 盲信 (殿の「状況/進捗」問い合わせに対し、dashboard.md のみ根拠で返答 — tasks/reports/inbox を読まず)

(4) は L018 (Context Percentage Primary Source Rule) で構造解消済。(5) は同じ「単一シグナル盲信」パターンが別レイヤで露出したもの。

### 構造的弱点

LLM (shogun) が**単一の便利な要約 (dashboard.md / 通知 / 体感)** に依存する慣性バイアス。要約は遅延・抜け・乖離が必ず発生するが、cross-source 照合の機械的義務がなければ盲信が再発する。L013/L016/L017 (dual-model 系) の精神を「自分自身の状態確認」にも拡張する必要がある。

### 構造解消 (L019)

`instructions/common/protocol.md §L019 Cross-Source Verification Rule (s-check Rule)` を制定:

- shogun は「状況/進捗/完了報告/確認してくれ/動いてるか」等のトリガーで `/s-check` を**必須発動**
- Primary sources (tasks / reports / inbox / dashboard.yaml / tmux pane / git log) を**必ず一次照合**してから返答
- `dashboard.md` のみを根拠とする返答は**禁止** (Secondary source 扱い)
- 返答に `checked sources` + `last verified timestamp` を**必須記載** (silent success 防止)
- 全 source を読めない場合は partial 結果で報告 (inconclusive 容認)

### 実装 (cmd_608 三段構成)

| Scope | 内容 | 完了状態 |
|-------|------|---------|
| Scope A | `/s-check` skill (`skills/s-check/SKILL.md`) | 完了 |
| Scope B | `scripts/status_check_rules.py` 共通モジュール (cmd_603 拡張) | 完了 |
| Scope C | canonical 体系 L019 永続化 (本作業) | 完了 |

### How to apply

| トリガー | 行動 |
|---------|------|
| 殿「状況/進捗/完了報告/確認してくれ/動いてるか」 | 必ず `/s-check` 発動。tasks/reports/inbox を一次照合してから返答 |
| ntfy 経由の状況問い合わせ | F009 (返信チャネル整合) + L019 (cross-source) を併用 |
| 返答テンプレ | 「checked: tasks=N件 / reports=N件 / inbox=N件 / 最終確認 YYYY-MM-DD HH:MM JST」を明記 |

### Canonical

- ルール本体: `instructions/common/protocol.md §L019`
- canonical 体系: `memory/canonical_rule_sources.md` L019 行
- skill 実装: `skills/s-check/SKILL.md`
- shogun workflow: `instructions/shogun.md §/s-check 必須化`

(2026-04-29 殿 reality check 5連発で確立)

## cmd_712 Web App endpoint 認証モデル承認 (2026-05-11)

殿御裁可により、cmd_712 の Web App endpoint 認証モデルは案 (イ) を採用する。

- 認証モデル: `access: ANYONE_ANONYMOUS` + HMAC-SHA256 単独防御
- 実行ユーザー: `executeAs: USER_DEPLOYING`
- secret 管理規律: `kid` active/previous 2世代並行、6ヶ月 rotation
- replay/競合対策: timestamp ±300s、nonce CacheService 600s、LockService 排他
- secret 配置: git ignored の config/secrets.yaml または環境変数/`.env`
- 漏洩時の影響: gas-mail-manager 全顧客データ操作可能。Phase A から rotation と漏洩テストを必須化する。

残る cmd_712 Phase A 着手条件は cmd_708e manual_verify PASS のみ。

## shogun 自律判断境界線 (2026-05-15 殿御指示)

設計承認 = 発令許可。設計裁可後の運用判断 (dispatch 方法 / subtask 分配 / Phase 順序 / 観察項目運用) は shogun が自律発令し、殿には事後報告のみ行うこと。再度許可を求めることは禁止 (手間をかけさせる)。

**承認依頼してよい範囲**: 設計上の判断 (機能設計 / 方針 / trade-off / 新機構の dogfooding 採否 / schema 移行戦略)
**承認依頼してはならない範囲**: dispatch 方法 (cmd 化 vs 観察項目駆動)、subtask 分配、Phase 進行順、observation_actions の構造、足軽役割割当

**背景**: cmd_716 設計裁可後、shogun が Phase A 着手の運用案 (cmd 化 vs 観察項目駆動) を 3 選択肢提示で再度殿に許可を求めた → 殿のお叱り「設計が確定したんだったら発令まで許可を求めないでしろよ」

**運用反映**: cmd_728 (殿承認依頼 best practice skill化) で本境界線を明文化、shogun システム全体で適用。
canonical: `~/.claude/projects/-home-ubuntu-shogun/memory/feedback_design_approval_no_double_permission.md` (Memory Index 登録済)
