# cmd_681 dashboard observation queue split

## Summary

dashboard の `ACTION_REQUIRED` を即時消化対象に限定し、時間経過待ち / 観察継続は `OBSERVATION_QUEUE` として分離した。

## Classification Policy

`dashboard.yaml.action_required` に残した即時消化対象:

- `[HIGH-2]` cmd_648 scope 再定義要請
- `[decision-1]` cmd_661 保留中: Z案 Verified Completion Gate
- `[cmd_674-followup]` skill_candidate 状態整理 + 3ヶ月以上遡及スキャン
- `[cmd_673-followup]` 検出運用課題 5件の後続 cmd 化
- `[cmd_677-followup]` Tier2/Tier3 sh残課題の後続 cmd 化
- `[cmd_678-followup]` red検知時の家老運用フロー文書化

`dashboard.yaml.observation_queue` へ移した時間経過待ち / 観察継続:

- `[observe-3]` cmd_655 C-2 24h 連続 success 未達
- `[observe-5]` cmd_657 B-3 23:00 cron 未来時刻
- `[observe-6]` cmd_658 Phase 1 P1-4 24h dual 観測
- `[pending-2]` cmd_658 Phase 3 (server-side 削除) 未着手
- `[info-3]` fork-upstream 関係整理
- `[cmd_675b-followup]` 2026-06-08 観察期限後の cmd_676b 起票 + §2 gate強制化

## Changed Files

- `dashboard.md`: `ACTION_REQUIRED` 境界内を即時消化対象 6件へ限定し、直後に `OBSERVATION_QUEUE` 境界つきセクションを追加。
- `dashboard.yaml`: `action_required` 6件 / `observation_queue` 6件へ分離。
- `scripts/generate_dashboard_md.py`: partial mode で `ACTION_REQUIRED` と `OBSERVATION_QUEUE` の両方を render。古い `dashboard.md` に `OBSERVATION_QUEUE` 境界が無い場合は `ACTION_REQUIRED:END` 直後へ安全挿入。
- `tests/dashboard_pipeline_test.sh`: observation_queue render、古い md への境界挿入、rotate 後保持を検証。multi-document `gunshi_report.yaml` の既存形式に合わせて schema check を `safe_load_all` 化。

## Test Results

- `python3 scripts/generate_dashboard_md.py --input dashboard.yaml --output dashboard.md --mode partial`: PASS
- `python3 scripts/generate_dashboard_md.py --input dashboard.yaml --output /tmp/dashboard_cmd681_check.md --mode full && rg ...`: PASS
- `bash tests/dashboard_pipeline_test.sh`: PASS (`PASS=42 FAIL=0`)

## Notes

- `generate_dashboard_md.py` 実行時、既存 `dashboard.yaml.in_progress` が `owner/task` 形式であるため `assignee/content` 欠落 warning が出る。今回の対象外で、partial render とテスト結果には影響なし。
- unrelated dirty files (`config/settings.yaml`, `queue/external_inbox.yaml`, other reports) は未変更。
