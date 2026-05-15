# cmd_729e macOS GHA report tests fix

| item | value |
|---|---|
| generated_at | 2026-05-15 16:30 JST |
| task | subtask_729e_macos_gha_fix |
| parent_cmd | cmd_729 |
| worker | ashigaru6 |

## Summary

GHA run `25905364431` / job `76137747342` の macOS Unit Tests failure を調査し、`python3` が repo-local `.venv` を使わず PyYAML を見失う構造を補修した。

Ubuntu は system Python 側に PyYAML が存在していたため通過していたが、macOS runner は `.venv/bin/pip install pyyaml` 後に PATH を切り替えていない。該当 Bats と helper scripts が `python3` を直呼びしていたため、macOS では `import yaml` 系の assertion がまとめて失敗していた。

## GHA Evidence

- run: `25905364431`
- job: `76137747342`
- workflow: `Multi-CLI Test Suite`
- head: `36fdbe7988fd4d79c3ae6ab8c8e68d3c21f77f62`
- result: ubuntu-latest success / macos-latest failure
- macOS runner: `macos-15-arm64`, shell `/opt/homebrew/bin/bash -e {0}`
- PyYAML setup: `.venv/bin/pip install --quiet pyyaml`

Failed tests from job log:

```text
not ok 211 gunshi_report schema has latest and history after migration
not ok 212 gunshi_report_append updates latest twice and preserves restored history in isolated copy
not ok 213 action_required_sync reads latest candidates and legacy top-level fallback
not ok 250 resolved dashboard tags are absent from active action_required but may remain archived
```

## Root Cause

The workflow installs PyYAML into `.venv`, but the failing tests and scripts invoked `python3` directly. On macOS, that direct `python3` resolved to the system/Homebrew interpreter rather than `.venv/bin/python3`, so YAML-dependent checks failed. Ubuntu passed by environment accident because `python3 -c 'import yaml'` succeeded there.

This is a Python path / PyYAML environment mismatch, not a Bats regex issue, fixture path issue, or GNU tool issue. Prior no-flock fixes still stand.

## Changes

- `tests/unit/test_gunshi_report_append.bats`
  - Add `PYTHON_BIN` setup that prefers `$PROJECT_ROOT/.venv/bin/python3`.
  - Use `PYTHON_BIN` for inline YAML checks.
  - Pass `PYTHON_BIN` into `action_required_sync.sh` subprocess tests.
- `tests/unit/test_report_reality_drift.bats`
  - Add the same `PYTHON_BIN` setup.
  - Use it for YAML and markdown assertion snippets.
- `scripts/gunshi_report_append.sh`
  - Resolve `PYTHON_BIN` once, preferring repo-local `.venv/bin/python3`.
  - Use it for YAML append logic.
- `scripts/action_required_sync.sh`
  - Resolve `PYTHON_BIN` once, preferring repo-local `.venv/bin/python3`.
  - Use it for sync logic, notification JSON parsing, notification dispatch Python, and dashboard renderer invocation.

## Verification

| check | command | result |
|---|---|---|
| gh auth | `gh auth status` | PASS: authenticated as `saneaki` with repo/workflow scope |
| GHA metadata | `gh run view 25905364431 --repo saneaki/multi-agent --json ...` | PASS: macOS job `76137747342` failed, Ubuntu job passed |
| GHA log | `gh run view 25905364431 --repo saneaki/multi-agent --job 76137747342 --log` | PASS: not ok 211/212/213/250 confirmed |
| preflight | `git status --short` | PASS: unrelated dirty files recorded and left untouched |
| dependency check | `command -v bats`; `python3 import yaml`; `.venv/bin/python3 import yaml` | PASS |
| shell syntax | `bash -n scripts/gunshi_report_append.sh scripts/action_required_sync.sh` | PASS |
| target unit tests | `bats tests/unit/test_gunshi_report_append.bats tests/unit/test_report_reality_drift.bats` | PASS: 4/4, SKIP=0 |

Test output:

```text
1..4
ok 1 gunshi_report schema has latest and history after migration
ok 2 gunshi_report_append updates latest twice and preserves restored history in isolated copy
ok 3 action_required_sync reads latest candidates and legacy top-level fallback
ok 4 resolved dashboard tags are absent from active action_required but may remain archived
```

## Git Preflight

Initial dirty worktree included unrelated files:

```text
M docs/dashboard_schema.json
M memory/global_context.md
M queue/external_inbox.yaml
M queue/reports/ashigaru1_report.yaml
M queue/reports/ashigaru4_report.yaml
M queue/reports/ashigaru6_report.yaml
M queue/reports/gunshi_report.yaml
M queue/suggestions.yaml
M queue/tasks/ashigaru4.yaml
M queue/tasks/ashigaru6.yaml
M scripts/shc.sh
M skills/shogun-silent-failure-audit-pattern/SKILL.md
```

Task-scoped changes were isolated to the two tests, two scripts, this output, and ashigaru6 task/report/inbox state.

## Commit

- pending until commit/amend step

## Residual Risk

- Local Linux cannot execute macOS runner directly; final macOS confirmation requires Karo push / GHA rerun.
- `.github/workflows/test.yml` still does not add `.venv/bin` to `GITHUB_PATH`, but the test/helper scripts no longer depend on workflow PATH activation.
