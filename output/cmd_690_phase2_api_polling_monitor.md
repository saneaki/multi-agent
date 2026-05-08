# cmd_690 Phase2: GHA API polling監視基盤

作業日時: 2026-05-09 03:44 JST  
担当: ashigaru3

## 実装概要

- `scripts/gha_failure_check.sh` を新設し、`gh api` で 9 repo の GitHub Actions workflow/run を取得して JSON 出力するよう実装した。
- `config/gha_monitor_targets.yaml` を新設し、監視対象 9 repo を登録した。
- `scripts/repo_health_check.sh` に GHA monitor を統合し、既存 `repo-health-check.timer` の hourly 実行経路で GHA も定期確認されるようにした。
- `dashboard.md` の `REPO_HEALTH` ブロックへ GHA summary / red detail / 9 repo 一覧を描画するようにした。
- GHA red 検知時は `dashboard.yaml.action_required` に stable `issue_id` で upsert し、`scripts/generate_dashboard_md.py --mode partial` で ACTION_REQUIRED 欄へ反映する経路を追加した。
- `.gitignore` に新規 config/script/output の whitelist を追加した。

## Filter設計

主判定は以下に限定した。

| filter | 実装 |
|---|---|
| active workflow only | `/actions/workflows` の `state == active` workflow id の run だけを判定 |
| period | `created=>=YYYY-MM-DD` で直近30日 run を取得 |
| event | `schedule` + `push` を primary event として red 判定 |
| workflow_dispatch | manual event として別集計。red 判定から除外 |
| historical-only failure | primary event の過去 failure 数は記録するが、red は「最新 primary run が failure/timed_out/action_required」の場合のみ |

このため Phase1 で解消済みの shogun/multi-agent、gas-mail-manager、googledrive-to-markdown、pdfmerged の過去 failure は red にならない。claude_everythingclaudecode の historical-only AgentShield failure も active workflow + latest primary success 判定により green。

## 検証結果

| 検証 | 結果 | 証跡 |
|---|---|---|
| GHA JSON出力 | PASS | `bash scripts/gha_failure_check.sh --output logs/gha_failure_status.json` |
| 9 repo登録 | PASS | config targets = 9 |
| repo-health統合 | PASS | `bash scripts/repo_health_check.sh --no-fetch` |
| dashboard GHA表示 | PASS | `dashboard.md` REPO_HEALTH に GHA summary + 9 repo table 表示 |
| red→ACTION_REQUIRED upsert | PASS | `[cmd_690-gha-red-gmail-to-markdown]` / `[cmd_690-gha-red-multi-agent]` を `dashboard.yaml` / `dashboard.md` に upsert |
| timer | PASS | `repo-health-check.timer` active + enabled。service ExecStart は `/home/ubuntu/shogun/scripts/repo_health_check.sh` |
| 構文 | PASS | `bash -n scripts/gha_failure_check.sh && bash -n scripts/repo_health_check.sh` |
| dashboard regression | PASS | `bash tests/dashboard_pipeline_test.sh` → PASS=43 / FAIL=0 / SKIPなし |

実行時点の GHA summary:

- green: 6
- yellow: 1
- red: 2
- error: 0

red は `multi-agent` の最新 push run failure と `gmail-to-markdown` の最新 schedule run failure。workflow_dispatch は red 判定対象外。

## 残リスク

- GitHub API rate limit / network failure 時は status `error` として dashboard summary に出るが、今回は error=0。
- `repo_health_targets.yaml` の git sync 対象は既存どおり 2 repo のまま。GHA 監視対象 9 repo は `config/gha_monitor_targets.yaml` が authoritative。
- red の自動解決・archive 移動は未実装。今回の scope は red upsert 経路まで。
