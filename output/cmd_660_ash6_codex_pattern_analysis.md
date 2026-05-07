# cmd_660 Scope A-4: cmd_657-659 共通真因パターン分析 (Codex 独立視点)

**task_id**: subtask_660_scope_a4_codex_pattern_analysis  
**parent_cmd**: cmd_660  
**author**: ashigaru6 (Codex)  
**created_at**: 2026-05-08 03:44 JST  
**scope**: 調査・方針提案のみ。実装なし。

---

## Executive Summary

cmd_657 / cmd_658 / cmd_659 の共通真因は、個々の担当者の注意不足ではなく、**完了イベントが単一の検証済み状態遷移として扱われず、複数の永続化先へ手動で伝播していること**である。各 cmd は作業成果そのものは相当程度達成していたが、完遂の定義が「成果物作成」「report」「dashboard」「git commit/push」「将軍通知」「Discord通知」「QC履歴保持」に分裂していた。そのため一つの sink が漏れると、全体としては「完了宣言済みだが運用上未完了」という状態になる。cmd_658 / cmd_659 で implementation-verifier が PARTIAL_PASS を返した事実は、検証自体の有効性を示す一方、検証の発動が手動・事後・不定である限り再発防止には不十分であることも示している。#40 は役割集中の問題だが、単純な人員分散だけでは防げない。必要なのは「家老が判断する」工程と「状態を反映する」工程の分離である。#45 は Phase 3 の自動 hook 化を優先すべきだが、verifier だけで semantic な指示解釈ミスや append-only 違反を完全には検出できないため、Completion Pipeline と append-only report history を併用すべきである。

---

## 1. Evidence Base

本分析は、次の一次情報をもとにした。cmd_660 の独立視点を保つため、他足軽の cmd_660 レポートは参照していない。

- `queue/shogun_to_karo.yaml` の cmd_657 / cmd_658 / cmd_659 / cmd_660 エントリ
- `queue/tasks/ashigaru6.yaml` に記載された本 Scope A-4 の問題事象
- `output/cmd_657_obsidian_cancelled_fix.md`
- `output/cmd_658_phase01_report.md`
- `output/cmd_659_implementation_report.md`
- `dashboard.md` の 2026-05-08 03:39 JST 時点の表示
- GitHub issue #40 / #45 の 2026-05-08 03:35 JST 追記
- `logs/daily/2026-05-08.md` の IR-1 記録
- `output/cmd_660_completion_pipeline_risk_plan.md`

この evidence から見ると、3 事象は「成果物が存在しない」という単純な未実装ではない。むしろ逆で、実装や修復はかなり進んでいた。問題は、**完了を外部に対して成立させるための残り作業が、各担当の記憶と手順書読解に依存していた**点にある。

---

## 2. 事象比較表

| 観点 | cmd_657 | cmd_658 | cmd_659 |
|---|---|---|---|
| 主対象 | saneaki/obsidian Daily Notion Sync cancelled 修復 | ntfy -> Discord outbound Phase 0/1 | Action Required Pipeline 構造化 |
| 実作業の達成度 | PR merge、手動 trigger success、報告書あり | notify.sh / discord_notify.py / 11 scripts 置換、E2E DM PASS | yaml SoT、renderer、sync script、test 36/36、gunshi QC Go |
| 完了宣言と実態のズレ | Scope 完遂後に commit/push 漏れが確認されたと記録 | Phase 0/1 完遂後、12 ファイルが working tree のみで未 commit | QC Go 後、dashboard 反映漏れ、gunshi_report 上書き、成果物未 commit |
| Type A: git 操作省略 | 発生。外部 repo 反映はされたが shogun 側の完遂記録/commit 境界にズレ | 重大。新規・変更ファイルが未 commit。`.gitignore` whitelist 問題も含む | 重大。新規 script/test と modified instructions/dashboard 系が未 commit |
| Type B: dashboard 反映漏れ | 比較的軽微。dashboard には戦果行が後に存在 | 発生。🏆🏆書込、SO-19、完遂通知が漏れた | 重大。進行中残存、gunshi 稼働表示、戦果未追加 |
| Type C: 指示解釈ミス | 主因ではない | 主因ではないが Phase 1/2/3/4 の段階境界が残リスク | 重大。`cmd_651 上書き禁止` と report YAML 履歴保持の意味を取り違え |
| verifier で検出可能だったもの | git / report / status 系は検出可能 | PARTIAL_PASS で永続化漏れを検出 | PARTIAL_PASS で commit漏れ、dashboard漏れ、report上書きを検出 |
| verifier だけでは弱いもの | runner queue starvation の根本運用判断 | Discord 到達後の user-visible 成功、Phase 2 未着手判断 | append-only semantics、責務違反の意図解釈、dashboard 表示の人間向け妥当性 |

---

## 3. 共通真因: 完了イベントの「非原子的 fan-out」

3 事象を一つの型に圧縮すると、次の流れになる。

1. 実作業担当が AC の多くを満たす。
2. report または task YAML が done になり、局所的には完了に見える。
3. しかし、完了イベントが git、dashboard、inbox、Discord、report history、daily log、GitHub issue などへ個別に伝播する必要がある。
4. その伝播は単一 dispatcher ではなく、家老・足軽・軍師・将軍の手順記憶に分散している。
5. どれか一つが漏れると、利用者から見た完了状態は崩れる。

ここで重要なのは、漏れた sink の種類が毎回異なることだ。cmd_658 では git 永続化が目立ち、cmd_659 では dashboard と report history が目立った。表面上のエラーモードは違うが、根は同じである。**「完了」と呼ばれる state transition が、システム内で一つの transaction として扱われていない。**

このため、「次から気をつける」「チェックリストを読む」だけでは弱い。チェックリストは担当者が実行して初めて効く。今回のように context pressure、並列 cmd、dashboard rotate 事故、Discord 移行、QC 後処理が重なると、チェックリストは最初に落ちる。構造的対策は、完了を event として捕捉し、その event から各 sink を独立 best-effort で発火させる形でなければならない。

---

## 4. Error Mode Taxonomy

### Type A: Git Persistence Gap

Type A は「作業ディレクトリには成果物があるが、repository history に存在しない」状態である。これは最も検出しやすいが、最も危険でもある。VPS 再起動、別作業の git add、conflict 解消、手動 cleanup により成果物が失われたり、別 cmd に混入したりする。

cmd_658 の 12 ファイル未 commit は典型である。`notify.sh`、`discord_notify.py`、`.gitignore` whitelist、複数 script 置換、report が一体でなければ Phase 0/1 の意味が崩れる。cmd_659 の未 commit も同型で、`action_required_sync.sh` と `tests/dashboard_pipeline_test.sh` が untracked のままなら、yaml SoT 化は作業端末上の一時状態にすぎない。

対策は、完了報告前の `git diff --name-status` / `git status --short` / `git log origin/main..HEAD` を標準化するだけでは不十分である。**task 完了イベントに紐づく commit boundary check** を dispatcher か verifier に組み込み、未追跡ファイルも含めて failure にする必要がある。特に `.gitignore` whitelist 方式の repository では、「ファイルを作ったが git add できない」状態を別 category として扱うべきである。

### Type B: State Visibility Gap

Type B は「primary YAML では進んでいるが、人間が見る dashboard や通知に反映されない」状態である。cmd_659 の dashboard 3 箇所漏れはこの典型である。進行中テーブル残存、gunshi 稼働表示、戦果未追加は、実装成果とは別の user-visible truth を壊す。

dashboard は二次情報とされるが、殿にとっては主要 UI である。primary YAML が正しくても dashboard が古ければ、運用判断は誤る。逆に dashboard を唯一の SoT にすると rotate 事故や md 直編集で壊れる。したがって cmd_659 の yaml SoT + md render artifact は方向として正しい。ただし今回の漏れは、**renderer が完成しても「完了時に renderer を呼ぶ event」が漏れれば同じ事故が起きる**ことを示した。

### Type C: Instruction Semantics Gap

Type C は機械検査が苦手な領域である。`gunshi_report.yaml` の「cmd_651 上書き禁止」は、単に YAML が valid かどうかではなく、履歴保持の意味を理解する必要がある。上書き後の YAML が構文的に正しく、現在 cmd の必要情報を含んでいても、過去 cmd の記録を消していれば governance violation である。

この型は、file existence、grep、status check だけでは検出が難しい。append-only file には明示的な storage contract が必要である。たとえば `queue/reports/gunshi_report.yaml` は multi-document append-only、過去 document count が減ったら FAIL、既存 document の hash が変わったら FAIL、という不変条件を持たせるべきである。自然言語の「上書き禁止」に頼るより、append-only invariant を testable にする方が強い。

---

## 5. #40 家老役割集中との関連

#40 の核心は「家老が多すぎる作業を抱えている」ことだが、今回の事象から見ると、問題は単なる workload 過多ではない。家老の責務には少なくとも三種類が混在している。

1. 判断責務: どの cmd を完了扱いにするか、どの issue を上げるか、次に何を dispatch するか。
2. 状態反映責務: dashboard、queue、daily log、report、GitHub issue、Discord へ反映する。
3. 検証責務: AC、git、push、dashboard、QC report、外部到達を確認する。

役割分散で防げるのは、主に判断責務の過負荷と検証責務の見落としである。一方、状態反映責務は人に分散しても漏れ方が変わるだけである。A さんは dashboard を更新し、B さんは git を忘れ、C さんは issue を忘れる、という形になる。したがって #40 への示唆は、**家老の作業を別 agent に移す前に、状態反映を人間責務から system responsibility に移すべき**というものだ。

具体的には、Karo は completion decision owner であり続けてよい。しかし、Karo が `cmd_complete` event を発行した後の fan-out は dispatcher が行うべきである。これは案 D 的な役割分離というより、案 C 的な critical transition 機械化である。人間的判断は残し、失敗時の blast radius が大きい state mutation だけを機械化する。

---

## 6. #45 Verification 自動化との関連

#45 は今回、かなり強い evidence を得た。implementation-verifier は cmd_658 / cmd_659 で PARTIAL_PASS を返し、実害のある未 commit / dashboard 漏れを検出した。これは Phase 2 が有効であることを示す。

しかし同時に、Phase 2 の限界も明らかである。verifier がいくら優秀でも、起動されなければ検出しない。今回の issue #45 追記にある通り、Phase 3 hook の欠落が残っている。したがって優先順位は次の通りである。

1. 完了報告または task status done を契機に verifier を自動起動する。
2. verifier の結果が PARTIAL_PASS / FAIL の場合、cmd を done にしない gate を置く。
3. git persistence、dashboard visibility、report history の三つを必須 layer にする。
4. verifier result 自体を dashboard / inbox / issue に残す。

ただし、verifier で検出できない、または検出が難しい種類もある。

- Discord DM が殿の実端末で読める状態か。
- Phase 1 完了後に Phase 2 / Phase 3 / Phase 4 をいつ dispatch すべきかという運用判断。
- `上書き禁止` のような自然言語制約の semantic violation。
- dashboard の人間向け説明が十分か、殿の意思決定に足るか。
- 外部サービス側の遅延や queue starvation のような platform condition。

したがって #45 は「verification を万能化する」方向ではなく、「mechanical invariants は verifier / tests に寄せ、semantic decision は Karo / Gunshi / Shogun に残す」方向が現実的である。

---

## 7. Structural Prevention Proposal

### Proposal 1: Completion Pipeline を最優先で実装する

cmd 完了時に、次の sink を一つの event から fan-out する。

- Karo / Shogun inbox への完遂通知
- Discord `notify.sh` 経由の cmd_complete 通知
- dashboard.yaml 更新と renderer 実行
- daily log 追記
- report YAML append-only history
- implementation-verifier 自動起動
- git persistence check

この pipeline は polling ではなく event-driven であるべきで、`queue/tasks/*.yaml` の status transition、または Karo の明示 `cmd_complete` emission を起点にする。重要なのは、全 sink が同じ event id を共有し、idempotent に処理されることだ。二重通知よりも漏れの方が高リスクなので、最初は best-effort + state file で十分である。

### Proposal 2: Completion Definition を AC から分離する

現在の AC は実装内容を主に見る。しかし運用上の完了には、implementation AC とは別に completion AC が必要である。

- `C-GIT`: `git status --short` が許容リスト以外 clean。
- `C-PUSH`: 必要な repo で origin/main または target branch に反映済み。
- `C-DASHBOARD`: in_progress から消え、achievement または action_required に反映済み。
- `C-REPORT`: report path が存在し、append-only contract を満たす。
- `C-NOTIFY`: required notification sink に記録がある。
- `C-VERIFY`: verifier PASS または明示的な accepted risk が残る。

これを各 cmd の acceptance_criteria に毎回手で書くのではなく、共通 completion gate として扱う。

### Proposal 3: Append-only Contracts をファイルごとに定義する

`gunshi_report.yaml` や `queue/reports/*` は、単一最新状態ファイルなのか、履歴ファイルなのかが曖昧だと上書き事故が起きる。次を明文化する。

- latest-state file: 上書き可。ただし previous snapshot は archive へ。
- append-history file: document append のみ。既存 document hash 変更禁止。
- generated artifact: 手動編集禁止。source YAML から render。
- task assignment file: Karo のみ編集、Ashigaru は自分の report のみ編集。

この contract は docs だけでなく testable にする。append-history file は before/after の document count と hash を verifier が見る。

### Proposal 4: #40 は「人員追加」より「mutation authority 分離」を先にする

新 agent を増やすより、Karo の state mutation を helper / dispatcher に寄せる方が再発防止効果が高い。Karo は判断し、dispatcher が mutation する。Gunshi は QC と semantic risk を見る。Shogun は issue / final verification / Lord decision material を見る。Ashigaru は scoped deliverable を作る。この分離なら、家老の認知負荷と mutation 漏れを同時に減らせる。

### Proposal 5: #45 Phase 3 hook は Completion Pipeline と統合する

verifier hook を単独で作ると、「verifier は走ったが dashboard は更新されない」など別の partial completion が残る。Phase 3 hook は Completion Pipeline の sink の一つとして実装するべきである。つまり `cmd_complete` event が発火したら、dashboard、Discord、report history、verifier が同じ event id で走る。これにより、検証だけが孤立せず、検証結果も他 sink と同じ扱いで残る。

---

## 8. Recommended Priority

優先順位は次の通り。

| Priority | Action | Reason |
|---|---|---|
| P0 | Completion Pipeline の event id / state file / sink interface を定義 | 3 事象の共通根に直撃する |
| P0 | git persistence gate を completion AC 化 | cmd_658/659 の致命的未 commit を防ぐ |
| P0 | dashboard in_progress -> achievement/action_required の自動移行 | SO-19 漏れを防ぐ |
| P1 | implementation-verifier Phase 3 hook を pipeline sink として実装 | #45 の残課題を解消 |
| P1 | gunshi_report / worker report の append-only contract | Type C を機械検出可能にする |
| P2 | Karo 責務再配分の詳細設計 | pipeline 実装後の残負荷を見て調整 |

---

## 9. Detection Boundary and Ownership Matrix

再発防止を設計するとき、すべてを verifier に寄せると別の blind spot が生まれる。以下のように、detectable invariant と human judgment を分けるべきである。

| Failure class | Best detector | Owner after detection | Automation level |
|---|---|---|---|
| untracked files / modified files after done | implementation-verifier + git status gate | Karo, then task owner | hard FAIL |
| unpushed commits | implementation-verifier + remote comparison | Karo | hard FAIL unless local-only is explicit |
| dashboard in_progress stale | dashboard renderer / completion dispatcher | Karo | automatic fix + warning |
| missing achievement row | completion dispatcher | Karo | automatic write |
| report overwrite | append-only invariant test | Gunshi/Karo | hard FAIL |
| Discord delivery failed | notify.sh log + delivery status | Karo | warning + retry policy |
| Lord actually saw message | cannot be fully automated | Shogun/Karo | human confirmation only when critical |
| semantic scope drift | Gunshi QC / Shogun review | Gunshi/Shogun | assisted review |
| external platform incident | domain-specific logs | task owner + Gunshi | evidence-based judgment |

この matrix から見えるのは、今回の事故の大半は hard invariant に落とせるという点である。git clean、remote push、append-only、dashboard stale は人間判断を待つ必要がない。むしろ人間判断を待つから漏れる。一方、Discord を殿が実際に読めたか、Phase 2 をいつ始めるか、外部 platform incident をどう評価するかは、自動化だけでは誤判定しやすい。そこは Karo / Gunshi / Shogun の判断領域として残す。

もう一つの重要点は、ownership を「発見者」と「修正者」に分けることである。verifier が失敗を発見しても、verifier 自身が勝手に commit / dashboard / report を修正すると RACE-001 や責務逸脱を起こす。発見は自動、修正は owner に戻す。ただし dashboard の generated area や completion dispatcher の idempotent write のように、安全な mutation が定義されている sink だけは自動修正してよい。この区別がないと、自動化は governance を強化するどころか、別の上書き事故を生む。

Completion Pipeline の実装では、sink ごとに policy を持たせるべきである。

- `enforce`: 失敗したら cmd done を止める。例: git persistence, report append-only.
- `repair`: 安全に自動修復できる。例: generated dashboard section.
- `notify`: 修復せず通知する。例: Discord delivery failure, external API anomaly.
- `record`: 監査証跡として残す。例: verifier result, event id, sink status.

この policy 分離により、#40 の役割集中を悪化させずに #45 の verification 自動化を進められる。単に verifier を強くするのではなく、verifier result を completion state machine に接続することが肝要である。

---

## 10. Conclusion

cmd_657 / cmd_658 / cmd_659 は、三つの別事故ではなく、同じ completion architecture failure の三つの投影である。実装品質、QC、dashboard、git、通知、issue がすべて重要になった現在の shogun では、「作業完了」と「運用完了」を同じ言葉で扱うこと自体が危険になっている。

Codex 視点の結論は、#40 と #45 を別々に解くのではなく、**Completion Pipeline を中核にして統合する**ことである。#40 は Karo から state mutation を剥がす。#45 は verifier を completion event に接続する。cmd_659 の yaml SoT は dashboard の一部を解いたが、完了イベント全体の fan-out はまだ残っている。次の構造改善は、dashboard の SoT 化ではなく、completion event の SoT 化である。

短く言えば、再発防止の最小十分条件は次である。

> `done` を人間の宣言ではなく、検証済み event として扱い、その event から git / dashboard / report / notification / verifier を一括発火させる。

この形になれば、家老が忙しい、足軽が commit を忘れる、軍師 report が上書きされる、将軍 notification が漏れる、といった個別の人間系リスクは、少なくとも single point of failure ではなくなる。
