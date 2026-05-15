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
