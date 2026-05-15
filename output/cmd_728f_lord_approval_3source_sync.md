# cmd_728f: Lord Approval Skill 3-Source Sync

作成: 2026-05-15 16:13 JST  
担当: ashigaru7  
対象: `skills/shogun-lord-approval-request-pattern/SKILL.md`

## Summary

cmd_728 final follow-up として、軍師QC `verdict=go` 後に残っていた concern c1、すなわち `queue/skill_candidates.yaml` / `memory/skill_history.md` / `dashboard.md` + `dashboard.yaml` の3源同期を完了した。

対象 skill は実装済みとして登録済み:

- path: `skills/shogun-lord-approval-request-pattern/SKILL.md`
- source: `cmd_728`
- QC verdict: `go` (`queue/reports/gunshi_report.yaml`, `subtask_728d_gunshi_lord_approval_qc`)
- created_at: `2026-05-15T16:10:41+09:00`

## Changes

| Source | Result |
|---|---|
| `memory/skill_history.md` | `shogun-lord-approval-request-pattern` を ✅ 実装済みとして先頭に記録。source `cmd_728`、QC verdict `go`、path、created_at を明記。 |
| `queue/skill_candidates.yaml` | `SC-728-lord-approval-request-pattern` を `status: created` として追加。重複 entry は事前 grep で存在しないことを確認。 |
| `dashboard.md` | 承認待ちスキル候補欄に未処理候補として残っていないことを確認し、戦果欄へ `cmd_728f` 完了を記録。 |
| `dashboard.yaml` | `achievements.today` に `cmd_728f` 完了を追加し、`in_progress` から足軽7号の `cmd_728f` を除外。 |

## Gunshi Concerns

- c1: 3源同期待ち  
  - 解消済み。`skill_candidates.yaml` / `skill_history.md` / dashboard 系のすべてに実装済み状態を反映した。
- c2: cmd_716 Phase D後の gate registry 完全統合待ち  
  - 残件として分離。今回の task は skill 登録・履歴・dashboard 整合が範囲であり、cmd_716 Phase D後の完全統合は別 follow-up とする。

## Verification

実行予定および結果は report YAML にも記録する。

```text
rg -n "shogun-lord-approval-request-pattern|SC-728|cmd_728f|Lord Approval skill 3源同期" \
  queue/skill_candidates.yaml memory/skill_history.md dashboard.md dashboard.yaml
=> PASS
```

```text
python3 - <<'PY'
import yaml
for path in [
    "queue/skill_candidates.yaml",
    "dashboard.yaml",
    "queue/tasks/ashigaru7.yaml",
    "queue/inbox/ashigaru7.yaml",
]:
    with open(path, encoding="utf-8") as f:
        yaml.safe_load(f)
print("yaml ok")
PY
=> PASS
```

```text
python3 - <<'PY'
from pathlib import Path
for path in ["memory/skill_history.md", "dashboard.md", "output/cmd_728f_lord_approval_3source_sync.md"]:
    text = Path(path).read_text(encoding="utf-8")
    assert "shogun-lord-approval-request-pattern" in text or path == "dashboard.md"
print("markdown content ok")
PY
=> PASS
```

## Git Preflight

作業前 `git status --short` では、既存の unrelated dirty files が多数存在した。今回の task では以下の editable files のみを変更した。

- `queue/skill_candidates.yaml`
- `memory/skill_history.md`
- `dashboard.md`
- `dashboard.yaml`
- `output/cmd_728f_lord_approval_3source_sync.md`
- `queue/reports/ashigaru7_report.yaml`
- `queue/tasks/ashigaru7.yaml`
- `queue/inbox/ashigaru7.yaml`

commit/push は未実施。cmd_728 統合判断に委ねる。commit する場合は `Refs cmd_728` を含める。
