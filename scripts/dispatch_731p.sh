#!/usr/bin/env bash
# dispatch_731p.sh — subtask_731p_gamma2_cron_cycle_evidence を ash3 に配備する一回限りの dispatcher
# 21:05 JST (12:05 UTC) に cron から実行される想定

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$ROOT/queue/tmp/dispatch_731p.done"

if [[ -f "$LOCK_FILE" ]]; then
  echo "[dispatch_731p] already dispatched (lock exists). skip." >&2
  exit 0
fi

# Guard: 21:00 JST (12:00 UTC) 経過確認
current_utc_hour=$(date -u +%H)
current_utc_min=$(date -u +%M)
if [[ "$current_utc_hour" -lt 12 ]]; then
  echo "[dispatch_731p] too early (UTC $current_utc_hour:$current_utc_min). exit." >&2
  exit 1
fi

echo "[dispatch_731p] dispatching subtask_731p to ashigaru3..."

bash "$SCRIPT_DIR/inbox_write.sh" ashigaru3 \
  "【新任務 subtask_731p_gamma2_cron_cycle_evidence】cmd_731 γ-2 cron証跡採取。queue/tasks/ashigaru3.yaml を読み、subtask_731p_gamma2_cron_cycle_evidence を実行されたし。logs/kpi_observer.log (18:00 JST = 09:00 UTC 実走確認) + logs/reality_check.log (21:00 JST = 12:00 UTC 実走確認) を証跡化。P-1〜P-5 確認後 output/cmd_731p_gamma2_cron_cycle_evidence.md 作成し karo に完了報告。" \
  task_assigned karo

touch "$LOCK_FILE"
echo "[dispatch_731p] dispatched successfully. lock written."
