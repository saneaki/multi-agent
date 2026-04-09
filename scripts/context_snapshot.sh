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
TIMESTAMP=$(bash "${SHOGUN_ROOT}/scripts/jst_now.sh" --yaml)

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
                # No existing snapshot — create one, populating task metadata from task YAML
                # (parent_cmd 多段フォールバック: parent_cmd → cmd_id → task_id 推論)
                python3 -c "
import yaml, re, os

approach = '''${APPROACH}'''
progress_raw = '''${PROGRESS}'''
decisions_raw = '''${DECISIONS}'''
blockers_raw = '''${BLOCKERS}'''
agent_id = '${AGENT_ID}'
shogun_root = '${SHOGUN_ROOT}'

# Determine task file path per agent
task_file = ''
if agent_id == 'karo' or agent_id == 'shogun':
    task_file = shogun_root + '/queue/shogun_to_karo.yaml'
elif agent_id == 'gunshi':
    task_file = shogun_root + '/queue/tasks/gunshi.yaml'
elif agent_id.startswith('ashigaru'):
    task_file = shogun_root + '/queue/tasks/' + agent_id + '.yaml'

task_meta = {'task_id': '', 'parent_cmd': '', 'status': '', 'description': ''}
if task_file and os.path.isfile(task_file):
    try:
        with open(task_file) as f:
            td = yaml.safe_load(f) or {}
        nested = td.get('task', {}) if isinstance(td.get('task'), dict) else {}
        tid = nested.get('task_id') or td.get('task_id') or ''
        pc = (
            nested.get('parent_cmd') or td.get('parent_cmd') or
            nested.get('cmd_id') or td.get('cmd_id') or ''
        )
        if not pc:
            m = re.match(r'^(?:subtask|sub)_(\d+)', str(tid))
            if m:
                pc = 'cmd_' + m.group(1)
            elif str(tid).startswith('cmd_'):
                pc = str(tid)
        pc = str(pc).strip()
        if pc and not pc.startswith('cmd_'):
            m2 = re.match(r'^(\d+)', pc)
            if m2:
                pc = 'cmd_' + m2.group(1)
        task_meta['task_id'] = str(tid)
        task_meta['parent_cmd'] = pc
        task_meta['status'] = str(nested.get('status') or td.get('status') or '')
        # description 優先順位: nested.description → top.description → top.purpose →
        #                      top.command → top.task (文字列の場合) の先頭80文字
        desc = (
            nested.get('description') or td.get('description') or
            td.get('purpose') or td.get('command') or ''
        )
        if not desc and isinstance(td.get('task'), str):
            desc = td['task'].strip().split('\n')[0]
        task_meta['description'] = str(desc)[:80]
    except Exception:
        pass

d = {
    'agent_id': agent_id,
    'snapshot_at': '${TIMESTAMP}',
    'trigger': 'agent_write',
    'task': task_meta,
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
            # 鮮度チェック (cmd_475 A3): WARN/ERROR は stderr へ、本体は stdout へ
            # 鮮度 helper が失敗・不在の場合でも read は継続する
            bash "${SHOGUN_ROOT}/scripts/snapshot_freshness.sh" "$AGENT_ID" || true
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
