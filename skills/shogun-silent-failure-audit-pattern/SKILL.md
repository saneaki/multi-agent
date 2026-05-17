---
name: shogun-silent-failure-audit-pattern
description: >
  [English] Use when shell scripts (shx/shp/scripts/*.sh) hide critical control-plane failures
  behind `2>/dev/null || true`, `|| log_info`, or `|| :` and you need to convert them into
  halt-or-explicit-log behavior. Combines (1) an audit script that auto-detects + classifies
  suppression sites (remediation_required / review_required / allowed_with_comment),
  (2) SO-17 north_star outcome E2E enforcement so unit AC alone cannot mark cmd complete,
  and (3) isolated tmux session smoke tests that prove halt actually fires.
  [日本語] shx/shp/scripts/*.sh の `2>/dev/null \|\| log_info` / `\|\| true` 型 suppression を
  audit script で自動検出 + 分類し、SO-17 outcome E2E 必須化と隔離 tmux session での halt 動作実測の
  3段予防で再発防止する時に使用。子 script 修正 (cmd_705/706) + 親 script 修正 (cmd_717a) +
  audit/規律追加 (cmd_717b/c) の再発・拡張から抽出。既存 shogun-shc-switch-silent-failure と相補。
tags: [shogun, silent-failure, audit, north-star, outcome-evidence, halt, shell-scripts]
created: 2026-05-15
source_cmd: cmd_717c (gunshi autonomous extraction) → cmd_726c (skill 化)
related_cmds: [cmd_705, cmd_706, cmd_717a, cmd_717b, cmd_717c, cmd_718]
---

# shogun-silent-failure-audit-pattern

shell script (shx/shp/scripts/lib) において、`2>/dev/null || true` 型の suppression が
critical control-plane action (tmux send-keys / pkill / notify / activation) を覆い隠し、
unit AC 全 PASS なのに north_star outcome が観測されない silent failure を構造的に防ぐ 3段 pattern。

## Use when

- shutsujin_departure.sh / shc.sh / shp.sh / switch_cli.sh / inbox_watcher.sh など、
  control-plane な shell script で suppression パターンが疑われる
- cmd の unit AC が全 PASS でも runtime で agent 同士が連携停止する症状を扱っている
- 子 script を直しても親 script に同種の suppression が連鎖して残っていそう (cmd_705→cmd_717 のパターン)
- 「動いているはずなのに inbox 配送が止まる」「`active` 化したのに反映されない」「notify が黙って消える」
- 軍師が cmd QC で SO-17 alignment は OK だが outcome 証跡が unit AC 止まりだと判定した

## Do NOT use for

- dashboard.yaml ↔ dashboard.md 同期固有の silent failure
  → `shogun-dashboard-sync-silent-failure-pattern` を使う
- 単一 script 内の 1 箇所限定の suppression 修正
  → `shogun-shc-switch-silent-failure` のような script 個別 skill で足りる
- n8n WF の `continueOnFail=true` 型 silent failure
  → `n8n-pipeline-cut-guard` を使う
- アプリケーションロジック内部のエラーハンドリング設計
  (本 pattern は shell control-plane に閉じる)

## Problem Statement

```
症状: unit AC は全 PASS。だが本番 runtime で:
  - tmux send-keys が黙って失敗 → ash agent が nudge 受け取れない
  - pkill -f "watcher" が無効 (process 別名) → 旧 daemon 残留
  - notify failure → Lord/karo に届かず誤 GREEN
  - shutsujin_departure 親で子 script return 1 を握り潰し → 部分構築完了表示

根因 (3層):
  L1 [子 script]   : `2>/dev/null || true` で stderr もろとも握り潰し
  L2 [親 script]   : 子の exit code を `|| log_info "続行"` で吸収
  L3 [規律 / QC]   : unit AC は「script が exit 0 で返る」までしか見ない
                     SO-17 alignment はあるが outcome E2E 証跡が無い
```

cmd_705 で子 script (switch_cli.sh / shc.sh) を直しても、cmd_717 で親
shutsujin_departure.sh / shp.sh に同種 suppression が 42件残存 (cmd_717b audit 結果)。
場当たり修正では「次の親階層」で再発する。

## Core Pattern (3段予防)

### Stage 1: audit script による自動検出 + 分類

`scripts/audit_silent_failure.sh` 相当の grep + 分類 logic を用意し、suppression パターンを
3段階に分類する。

```bash
# 検出パターン (cmd_717b で実証)
PATTERN='(2>/dev/null|>/dev/null 2>&1)[[:space:]]*\|\|[[:space:]]*(true|:|log_(info|warn|error))'

# 分類ルール (cmd_717b output §Classification Policy より)
classify() {
  local line="$1" context="$2"
  case "$line" in
    *tmux\ send-keys*|*pkill*|*systemctl*restart*|*activate*)
      echo "remediation_required"  # control-plane → halt or 明示ログ化必須
      ;;
    *notify*|*notification*)
      echo "review_required"  # fallback/log 証跡があれば許容
      ;;
    *mkdir\ -p*|*rm\ -f*|*touch*|*cp*backup*|*resize-pane*|*set-option*)
      echo "allowed_with_comment"  # cleanup/probe/cosmetic は近傍コメント必須
      ;;
    *)
      echo "review_required"
      ;;
  esac
}
```

| classification | 意味 | 必須対応 |
|---|---|---|
| `remediation_required` | control-plane action が握り潰されている | halt (`set -e` + 明示 `exit`) または明示 log (`log_warn`/`log_error` + content/destination/timestamp) |
| `review_required` | best-effort 動作だが outcome を log で surface すべき | 近傍に justification コメント + log emit |
| `allowed_with_comment` | probe/cleanup/cosmetic — 失敗無害 | 近傍コメントで意図明示 (`# best-effort: ...`) |

実装テンプレ: cmd_717b output `output/cmd_717b_silent_failure_audit_so17_hardening.md` を参照。
audit script は **read-only** (bulk-fix しない) で、owners に分類別の判断責任を委ねる。

### Stage 2: SO-17 north_star outcome E2E enforcement

`instructions/common/north_star_outcome_check.md` で SO-17 を **alignment + evidence** の二重 gate
に拡張する。unit AC pass だけでは cmd complete を許可しない。

```yaml
# Gunshi QC report に必須追加
north_star_outcome_evidence:
  status: pass | fail | manual_required | not_applicable
  evidence_type: dry_run | e2e | manual_gate | none
  command_or_artifact: "実コマンド / 実行 id / log path / manual gate"
  reason: "なぜこれが outcome を証明するか"
```

判定規律:

1. control-plane (shx/shp/script) を変更する cmd は **dry_run か e2e か manual_gate** を必須
2. `manual_required` で Lord 介入なき場合 → karo は cmd_complete マーク禁止
3. final user runtime (例: Japanese Windows) を狙う tool は、 final user runtime での
   dry-run/E2E が必要。Linux VPS 単独 evidence では不十分

### Stage 3: 隔離 tmux session smoke で halt を実測

active multiagent / shogun pane で実行すると runtime を壊すため、必ず隔離 tmux session
(`test_<cmd>_isolation` 等) を起動して halt を実測する。

```bash
# 隔離 tmux session で halt 動作検証 (cmd_718 で実証)
tmux new-session -d -s test_<cmd>_isolation -x 200 -y 50
tmux send-keys -t test_<cmd>_isolation:0 \
  "bash scripts/<target>.sh <failing args>; echo EXIT=\$?" Enter
sleep 5
tmux capture-pane -t test_<cmd>_isolation:0 -p | tail -20
# 期待値: "EXIT=1" (halt 成功) または "log_error: <reason>" (明示ログ化)
tmux kill-session -t test_<cmd>_isolation
```

active runtime と隔離 runtime は最低限以下を一致させる:

- 同一 shell (bash 同一 minor version 以上)
- 同一 dependent script の絶対 path
- 環境変数の最小セット (HOME / TMUX_PANE / AGENT_ID は隔離で上書きせず実環境近似)

## Battle-Tested Examples

| cmd | 状況 | 結果 |
|---|---|---|
| cmd_705 | 子 script `switch_cli.sh` の silent failure 修正 | hybrid 構造解析 + busy pane 検出 + timeout failure を実装 (子 script 単独) |
| cmd_706 | 子 script `shc.sh` switch_cli の silent failure 修正 | switch_cli + shc 子経路で halt 化。だが親 shutsujin への伝播は cmd_717 で発覚 |
| cmd_717a | 親 script `shutsujin_departure.sh` の halt 化 (L759-771) | `\|\| { log_warn ...; exit 1; }` で親階層でも握り潰さない構造に |
| cmd_717b | `audit_silent_failure.sh` で 92 件検出 → 分類 (remediation 42 / review 34 / allowed 16) | Stage 1 audit pattern 実証 + `output/cmd_717b_silent_failure_audit_so17_hardening.md` |
| cmd_717c | SO-17 outcome E2E 必須化 (`north_star_outcome_check.md`) | Stage 2 確立 — unit AC + outcome evidence の二重 gate |
| cmd_718 | 隔離 `test_718_isolation` での E2E (preset immutability corrective) | Stage 3 実証 — 隔離 tmux で `shc.sh deploy hybrid --settings-only` の片方向適用 + halt 動作確認 |
| cmd_725a | `shu`/`shk` startup smoke guard 追加 | shutsujin_departure 起動経路の noninteractive smoke (Stage 3 拡張) |
| cmd_727 (進行中) | `inbox_watcher.sh` 28件 (#9-#41) の cascading silent failure 経路 halt 化 | Stage 1 audit fixture を一次根拠とした 28件 remediation (cmd_717b → cmd_727 への follow-up 連鎖) |

## Diagnostic Checklist

新しい control-plane 変更 cmd を受け取った時、以下を順に確認:

1. **Stage 1**: 対象 script に `audit_silent_failure.sh` を実行したか?
   - 未実行 → audit を先行し、`remediation_required` を解消してから fix に入る
2. **Stage 1**: 親 script への伝播確認
   - 子 fix だけで完了させていないか? `grep -rn "<child_script>" shutsujin_departure.sh shc.sh shp.sh`
3. **Stage 2**: Gunshi report に `north_star_outcome_evidence` ブロックがあるか?
   - 無し / `evidence_type: none` → cmd_complete 不可。manual_gate でも dashboard Action Required 要
4. **Stage 3**: 隔離 tmux session での halt/明示ログ動作証跡があるか?
   - active runtime での実証は禁止 (戦況崩壊リスク)
5. **横展開**: 同じ suppression パターンが類似 script に残っていないか?
   - cmd_727 が follow-up している `inbox_watcher.sh` 28件 のように、関連 script に audit 適用

## Related Skills

- `shogun-shc-switch-silent-failure` — 子 script `switch_cli.sh` + `shc.sh` の限定スコープ silent failure (本 pattern Stage 1/3 の事例の 1 つ)
- `shogun-dashboard-sync-silent-failure-pattern` — dashboard 同期固有の silent failure (別ドメインのため相互参照)
- `shogun-preset-immutability-discipline` — cmd_717/718 の corrective で同時に確立した相補規律 (preset 書換禁止 + silent failure halt 化)
- `shift-left-validation-pattern` — pre-gate (audit script の警告多め) と true-gate (manual cmd_complete) の二段構成と整合
- `verification-loop` — Stage 1-4 (Commit / Deploy / Registration / Execution Log) の deploy & verify cycle に Stage 3 隔離 smoke を組合せる
- `shogun-tmux-busy-aware-send-keys` — tmux send-keys 系の suppression 修正で必要になる busy-aware パターン

## Anti-patterns

- ❌ 子 script だけ修正して親 script を放置 (cmd_705→cmd_717 の再発パターン)
- ❌ unit AC を pass させて即 cmd_complete (SO-17 outcome evidence 未取得)
- ❌ active multiagent / shogun pane で smoke test (戦況崩壊リスク)
- ❌ `2>/dev/null || true` を一律削除 (probe/cleanup/cosmetic は許容 — 分類が必要)
- ❌ audit script で bulk-fix (owner の判断責任を奪う → 誤分類で 2 次 silent failure)

## Source

- cmd_717c: 軍師 autonomous extraction (gunshi report) — 子 cmd_705/706 + 親 cmd_717a + audit cmd_717b の 3段から pattern 抽出
- cmd_726c: skill 化 (本 SKILL.md 作成 — γ subtask ashigaru4)
- cmd_727: Stage 1 audit fixture を follow-up cmd の一次根拠として活用 (inbox_watcher 28件 cascading)
- cmd_729 (2026-05-15): gunshi_report.yaml の単一文書 overwrite + report-reality drift の 4 incident pattern を追加 (本 SKILL.md §Report Drift Patterns を新設)

## Report Drift Patterns (cmd_729 追補)

`scripts/*.sh` の suppression とは別系統の silent failure として、**report yaml 系の構造欠陥** と
**dashboard 報告実態乖離** が cmd_729 で確認された。本 pattern §Core Pattern (3段予防) と並列して、
report 系の 4 incident pattern を観察対象とする。

### Incident #1: gunshi_report 単一文書 overwrite (cmd_725b / 727b / 726f 中間版消失)

**症状**: gunshi が QC を 4 件連続実施した結果、最後の cmd_726f だけが残り、cmd_723 補完 /
cmd_725 γ / cmd_727 β / 中間 cmd_726f が `Write/Edit` ツールの全文上書きで消失。

**根因 (cmd_729a A-3 RC-1)**: gunshi_report.yaml schema が単一 task の field set のみで
`history:` 配列を持たず、append/history schema 不在 (構造欠陥)。

**修正 (cmd_729b)**:
- schema 移行: `worker_id / latest / history[]` へ。`latest` = 最新、`history` = 過去 append-only
- helper 新設: `scripts/gunshi_report_append.sh` (`flock` + atomic write + schema validate)
- protocol 改訂: `instructions/gunshi.md` を append helper 経由に書換
- init template: `shutsujin_departure.sh --clean` の reset template を new schema に整合
- downstream: `scripts/action_required_sync.sh` を `latest.result.action_required_candidates` 優先
  + 旧 schema fallback (互換維持)
- 復元: cmd_723 + cmd_725 γ + cmd_727 β + cmd_726f を `history[]` に append (post-hoc
  `reconstructed_from` / `source_evidence` / `reconstructed_at` 明示)

**Diagnostic**:
- `python3 -c "import yaml; d=yaml.safe_load(open('queue/reports/gunshi_report.yaml')); assert 'latest' in d and 'history' in d"`
- helper 経由以外の編集を gunshi がしていないか `git log -p` で確認

### Incident #2: append-only report 構造の非対称 (gunshi vs ashigaru)

**症状**: ashigaru report は `worker_id / latest / history` の二段構成で過去 entry を維持する
のに対し、gunshi report のみ単一文書のままで非対称になっていた (`grep -c "^history:"
queue/reports/*.yaml` 結果)。

**根因**: report schema を統一する規律不在。ashigaru で先行採用された append-only パターンが
gunshi に horizontal 横展開されないまま運用されていた。

**修正 (cmd_729b)**:
- schema 統一: gunshi_report を ashigaru report と同じ append-only 構造へ移行
- regression test: `tests/unit/test_gunshi_report_append.bats` (隔離 smoke で latest 更新 +
  history append + 復元 entry 保持を assertion)

**Diagnostic**:
- `bats tests/unit/test_gunshi_report_append.bats` (SKIP=0 必須)
- 隔離 staging で 2 回連続 append → latest が 2 回目に更新 + history に 1 回目 entry が残る

### Incident #3: report-reality semantic drift (YomiToku close vs deleted)

**症状**: 殿削除指示後の dashboard 状態を「削除済」と報告したが、実態は dashboard.yaml SoT で
`status: closed` として archived 保持 (render から除外されるが SoT には残存)。報告語彙と
実体の semantic gap が drift を生む。

**根因 (cmd_729a A-4b)**:
- SO-24 三点照合の (b) artifact 確認を dashboard.md (render) のみで終え、dashboard.yaml (SoT)
  を直読 grep せず。
- 「削除」「close」「archive」「retire」の用語が報告と SoT で混在し semantic clarification 不在。

**修正 (cmd_729a F10-F13, cmd_729c)**:
- `tests/unit/test_report_reality_drift.bats`: 削除済 tag が active `dashboard.yaml.action_required`
  と dashboard.md `ACTION_REQUIRED` block から消えていることを assertion。archive / observation
  archive に残ることは許容。
- gunshi QC checklist に dashboard.yaml 直読 grep PASS を必須項目化 (F12)
- 用語表整備 (F11): `instructions/common/dashboard_responsibility_matrix.md` に「削除」/
  「close」/「archive」/「retire」の semantic を明文化 (followup 候補)
- runtime drift detector (F13): `scripts/dashboard_drift_check.sh` で render 不在 / SoT 残存
  entry を自動検出 (任意 followup)

**Diagnostic**:
- `grep -in 'yomitoku' dashboard.{md,yaml}` で両方を確認。md 0 件 + yaml `status: closed` retained = 正常
- `bats tests/unit/test_report_reality_drift.bats` (SKIP=0 必須)

### Incident #4: dashboard physical grep 不足 (SO-24 b 項の SoT 検証不徹底)

**症状**: dashboard 反映確認を render 側 (dashboard.md) のみで完了させ、SoT (dashboard.yaml)
への反映を grep で確認していなかった。Incident #3 と同根。

**根因**: SO-24 (b) artifact 確認の検証手段が render only と暗黙運用。SoT 直読 grep が必須化
されていなかった。

**修正 (cmd_729a F10, cmd_729c)**:
- gunshi QC checklist 強化 (F12): dashboard.yaml SoT 直読 grep を必須項目化
- `scripts/so24_verify.sh` の (b) artifact 確認に dashboard.yaml SoT 直読 grep を追加候補 (F10)

**Diagnostic**:
- dashboard 変更を伴う cmd の QC では `grep -n '<tag>' dashboard.{md,yaml}` 両方を実行
- closed entry retain は許容、active section から消えていることを必須化

### Incident #5: .gitignore drift による skill / artifact commit 漏れ (cmd_728)

**症状**: skill 配置または artifact 生成は完了しているが、whitelist 型 `.gitignore` に追跡許可が
無いため `git status` では `!!` ignored として扱われ、commit / squash / publish 対象から
漏れる。作業者 report では「作成済み」と記録されるが、repository reality では未追跡のまま残り、
後続 verifier が `git ls-files <path>` で確認すると存在しない。

**実例 (cmd_728 lord approval skill whitelist 漏れ)**:
- `skills/shogun-lord-approval-request-pattern/SKILL.md` は作成・3源同期まで進んだ。
- しかし whitelist `.gitignore` に `skills/shogun-lord-approval-request-pattern/` 系の許可が無く、
  publish 対象に入らない drift が発生した。
- これは report と filesystem の完了状態だけを見て、git index / ignored state を
  Stage 5 前に確認しなかったことが根因。

**検出**:
- `git ls-files <skill-or-artifact-path>` が空なら commit 対象外。
- `git status --short --ignored <path>` が `!! <path>` なら whitelist 漏れ。
- whitelist 型 repo では `rg` が `.gitignore` glob parse warning を出す場合があるため、
  `.gitignore` 自体の確認は `grep -n` / `sed -n` でも補完する。

**防止 (skill-creation-workflow §5 前段 gate)**:
skill 作成・共有・登録 workflow の Stage 5 (commit / publish / registry sync) に入る前に、
以下を必須 preflight とする。

```bash
git ls-files <new-skill-or-artifact-path>
git status --short --ignored <new-skill-or-artifact-path>
grep -n '<new-skill-or-artifact-slug>' .gitignore
```

判定規律:
- `git ls-files` が空、かつ `git status --ignored` が `!!` の場合は **.gitignore drift**。
- whitelist 追記が必要な path を task/report に明記し、editable_files に `.gitignore` が無ければ
  家老へ即報告して whitelist 追記 task を切る。
- `.gitignore` 追記後は `git ls-files <path>` で index 登録を確認してから Stage 5 に進む。
- output deliverables は artifact registration targets であり、現行方針では原則 git 追跡対象にしない。
  skill / scripts / docs など repository asset と混同しない。

### Incident #6: clasp push / deploy 系 remote 反映ゼロ silent failure (cmd_712)

**症状**: ash3 が `clasp push` を実行し `Skipping push.` 出力を取得。`clasp status` で `Tracked files: <list>` を確認し「local 完遂」として完了報告。**remote (GAS) には 0 byte も反映されないまま 4 日間 SLA 超過**。殿の手作業 (`clasp pull` 後 remote ≠ local 検出) で初発覚。

**誤読 pattern**:

| clasp output 文言 | 誤解釈 | 正しい意味 |
|------------------|--------|-----------|
| `Skipping push.` | "成功 push" / "差分無し OK" | local と remote が一致 or push 抑制状態。**新規 push 成功証跡ではない** |
| `Tracked files: <list>` | "remote に反映済 file 一覧" | local 追跡対象一覧 (.claspignore 通過後の push 候補)。**remote 反映証跡ではない** |
| `Pushed N files.` (≠ "Skipping") | — | これが**真の push 成功証跡** |

**根因 (4 段同根)**:
- 段 1 (ash): clasp CLI 出力文言の意味を **誤解釈**
- 段 2 (gunshi): local 完遂証跡のみで QC PASS。**remote 実態確認手順 (clasp pull diff) を AC として必須要求していない**
- 段 3 (karo): gunshi QC PASS を信用し中継。**reality verify 無い QC を疑わなかった**
- 段 4 (shogun): karo 中継を信用し殿に「完了」と報告。**F007 (unverified_report) 違反**

cmd_712 は §Incident #1-5 (子/親 script の `2>/dev/null` 系 suppression) とは物理動作が異なる。**外部 CLI tool の出力文言誤読** という新しい root cause 系統で、shell script suppression と並ぶ silent failure の主要 family である。

**防止 (cmd_732 で構造化)**:

| layer | 場所 | 内容 |
|-------|------|------|
| 規律 | `instructions/gunshi.md §L022` | 軍師 QC で local 完遂証跡のみによる PASS を禁止。Forbidden Evidence Patterns (Skipping push. / Tracked files / Everything up-to-date 等) を明示 |
| 規律 | `instructions/shogun.md F007` | 将軍が殿に「完了」報告する前の reality verify 必須化。L022 と双方向 cross-ref |
| カタログ | `instructions/common/silent_failure_pattern.md §Incident #001` | cmd_712 事案を 1 entry 形式で正式登録 |
| Template | `instructions/common/cmd_template_reality_verify.md` | deploy/push 系 cmd template に reality_verify_step を default 内蔵 |

**Golden Verify 手順 (clasp 系)**:

```bash
# ❌ NG: local 完遂証跡のみ
clasp push     # → "Skipping push." を成功と誤読
clasp status   # → "Tracked files: <list>" を remote 反映証跡と誤読

# ✅ OK: remote reality 直接確認 (3 段)
clasp push                                      # 必ず "Pushed N files." を確認
clasp pull --rootDir /tmp/clasp_verify_$$       # remote → local 取得
diff -r src/ /tmp/clasp_verify_$$/              # diff=0 で remote 反映確認
clasp versions | head -3                        # remote 履歴 increment 確認

# ✅ OK: GAS Editor 目視 (殿または gunshi)
# https://script.google.com/u/0/home/projects/<SCRIPT_ID>/edit
# 該当 file タブ → 最終更新日時 + 行数 を確認
```

**Diagnostic (QC 時に必須実行)**:

```bash
# ash 報告 evidence に Forbidden Pattern が含まれるか自動検出
grep -E "Skipping push\.|Tracked files|Everything up-to-date" \
  queue/reports/ashigaru*_report.yaml

# 該当行が evidence として記録されている場合 → L022 違反疑い
# gunshi は ash に reality verify 証跡 (clasp pull diff / clasp versions) を要求
```

**Related Patterns** (同 family の他 tool 出力):

- `git push origin <branch>` → `Everything up-to-date` 単独は新規 push 証跡ではない。`git ls-remote origin <branch>` で sha 一致確認必須
- n8n WF activate → 200 OK 単独は実行成功証跡ではない。`GET /api/v1/executions/{id}?includeData=true` で `finished: true, status: success` 確認必須
- Notion API page create → 200 OK + `id` 返却単独は反映証跡。但し DB view 反映は別途 `GET /v1/databases/{id}/query` で確認推奨
- cron crontab 追加 → `crontab -l` 一致は登録 means。実発火 ends は log file 時刻別行で確認必須 (Stage 4)

### Common Root Cause: Report ↔ Reality 整合確認手順の不徹底

6 incident に通底する根因は「report と reality の整合確認手順が不十分」。
本 SKILL.md §Core Pattern (3段予防) で扱う `2>/dev/null || true` 型の silent failure
(L1-L3 子/親/規律) とは物理動作が異なるが、**「unit AC pass だが outcome 観測されない」**
構造は共通。SO-17 outcome E2E 強化 + 直読 grep + history 化 + git index/ignored state 確認が
並行防御として有効。

### Battle-Tested (cmd_729 系列)

| cmd | 状況 | 結果 |
|-----|------|------|
| cmd_729a | gunshi_report.yaml 書込経路監査 (ash4) → 2 経路のみ確定 + RC-1〜RC-5 確定 | 構造欠陥を audit で確定、α 完了 |
| cmd_729b | append-only schema 移行 + helper 新設 + 復元 entry 3 件 (ash7) | commit 4a5bea2、bats 3/3 PASS、β 完了 |
| cmd_729c | append regression smoke + report-reality drift fixture test (ash6) | commit 269c4fb + 36fdbe7、bats 4/4 local PASS、γ 完了。GHA macOS は CI 環境依存 (PyYAML 等) で依然 fail |
| cmd_729d | 本 SKILL.md §Report Drift Patterns 追記 + 全 QC (本 gunshi) | δ 完遂 |
| cmd_729f | verifier PARTIAL_PASS 補修: .gitignore drift family 追加 + 4a5bea2 scope 証跡化 (ash7) | skill-creation-workflow §5 前段 gate を明文化。4a5bea2 の `shutsujin_departure.sh` 変更は B-4 scope 内と判定 |
| cmd_712  | ash3 `clasp push → Skipping push.` 誤読により remote 反映ゼロ 4 日 SLA 超過。殿手作業で初発覚 | external CLI tool 出力誤読 family (本 SKILL §Incident #6) として正式登録。L022 (gunshi reality verify) で再発防止 |
| cmd_732  | L022 + silent_failure_pattern.md + clasp push pattern (Incident #6) を gunshi.md / common / SKILL に整備 | 段 2 (gunshi QC) reality verify 必須化により cmd_712 同型事案を構造的に防止。F007 (shogun) と双方向 cross-ref |
