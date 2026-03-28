#!/usr/bin/env bash
# ============================================================
# Context Snapshot: Agent-callable context save/clear/read
#
# Usage:
#   bash scripts/context_snapshot.sh write <agent_id> "<approach>" "<progress>" "<decisions>" "<blockers>"
#   bash scripts/context_snapshot.sh clear <agent_id>
#   bash scripts/context_snapshot.sh read  <agent_id>
#
# progress/decisions/blockers: pipe-separated values (e.g., "item1|item2|item3")
# ============================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
SNAPSHOT_DIR="${SHOGUN_ROOT}/queue/snapshots"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

mkdir -p "$SNAPSHOT_DIR"

ACTION="${1:-}"
AGENT_ID="${2:-}"

if [ -z "$ACTION" ] || [ -z "$AGENT_ID" ]; then
    echo "Usage: context_snapshot.sh {write|clear|read} <agent_id> [args...]" >&2
    exit 1
fi

SNAPSHOT_FILE="${SNAPSHOT_DIR}/${AGENT_ID}_snapshot.yaml"
LOCKFILE="/tmp/context_snapshot_${AGENT_ID}.lock"

case "$ACTION" in
    write)
        APPROACH="${3:-}"
        PROGRESS="${4:-}"
        DECISIONS="${5:-}"
        BLOCKERS="${6:-}"

        # Truncate approach to 200 chars
        APPROACH="${APPROACH:0:200}"

        (
            flock -w 5 200 || exit 0

            # Read existing snapshot to preserve task metadata
            EXISTING=""
            if [ -f "$SNAPSHOT_FILE" ]; then
                EXISTING=$(cat "$SNAPSHOT_FILE")
            fi

            # If existing snapshot has task metadata, preserve it
            if [ -n "$EXISTING" ]; then
                python3 -c "
import yaml, sys

approach = '''${APPROACH}'''
progress_raw = '''${PROGRESS}'''
decisions_raw = '''${DECISIONS}'''
blockers_raw = '''${BLOCKERS}'''

try:
    with open('${SNAPSHOT_FILE}') as f:
        d = yaml.safe_load(f) or {}
except Exception:
    d = {}

d['snapshot_at'] = '${TIMESTAMP}'
d['trigger'] = 'agent_write'
if 'agent_id' not in d:
    d['agent_id'] = '${AGENT_ID}'

ctx = d.get('agent_context', {})
if approach:
    ctx['approach'] = approach
if progress_raw:
    ctx['progress'] = [x.strip() for x in progress_raw.split('|') if x.strip()][:10]
if decisions_raw:
    ctx['decisions'] = [x.strip() for x in decisions_raw.split('|') if x.strip()][:5]
if blockers_raw:
    ctx['blockers'] = [x.strip() for x in blockers_raw.split('|') if x.strip()][:3]
d['agent_context'] = ctx

with open('${SNAPSHOT_FILE}.tmp', 'w') as f:
    yaml.safe_dump(d, f, default_flow_style=False, allow_unicode=True)
" 2>/dev/null
            else
                # No existing snapshot — create minimal one
                python3 -c "
import yaml

approach = '''${APPROACH}'''
progress_raw = '''${PROGRESS}'''
decisions_raw = '''${DECISIONS}'''
blockers_raw = '''${BLOCKERS}'''

d = {
    'agent_id': '${AGENT_ID}',
    'snapshot_at': '${TIMESTAMP}',
    'trigger': 'agent_write',
    'task': {'task_id': '', 'parent_cmd': '', 'status': '', 'description': ''},
    'uncommitted_files': [],
    'agent_context': {
        'approach': approach[:200] if approach else '',
        'progress': [x.strip() for x in progress_raw.split('|') if x.strip()][:10],
        'decisions': [x.strip() for x in decisions_raw.split('|') if x.strip()][:5],
        'blockers': [x.strip() for x in blockers_raw.split('|') if x.strip()][:3],
    }
}

with open('${SNAPSHOT_FILE}.tmp', 'w') as f:
    yaml.safe_dump(d, f, default_flow_style=False, allow_unicode=True)
" 2>/dev/null
            fi

            [ -f "${SNAPSHOT_FILE}.tmp" ] && mv "${SNAPSHOT_FILE}.tmp" "$SNAPSHOT_FILE"

        ) 200>"$LOCKFILE"

        echo "snapshot saved: ${SNAPSHOT_FILE}"
        ;;

    clear)
        rm -f "$SNAPSHOT_FILE"
        echo "snapshot cleared: ${AGENT_ID}"
        ;;

    read)
        if [ -f "$SNAPSHOT_FILE" ]; then
            cat "$SNAPSHOT_FILE"
        else
            echo "no snapshot found for ${AGENT_ID}"
        fi
        ;;

    *)
        echo "Unknown action: $ACTION (use write|clear|read)" >&2
        exit 1
        ;;
esac

exit 0
