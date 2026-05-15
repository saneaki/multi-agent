#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# shc.sh — 陣形管理コマンド (Shogun Formation Controller)
#
# Usage:
#   shc deploy [formation_name]   Deploy a formation (default: hybrid)
#   shc status                    Show pane meta / settings.yaml / dashboard.yaml diff (3-way)
#   shc sync-meta                 Sync pane meta to dashboard.yaml formation_status (safe keys only)
#   shc restore                   Restore all ashigaru to all-sonnet
#   shc list                      List available formation presets
#
# Reads formations from config/settings.yaml → formations section.
# Applies CLI switches via scripts/switch_cli.sh.
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETTINGS_FILE="${PROJECT_ROOT}/config/settings.yaml"
DASHBOARD_FILE="${PROJECT_ROOT}/dashboard.yaml"
PYTHON="${PROJECT_ROOT}/.venv/bin/python3"

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Usage ───
usage() {
    echo -e "${BOLD}shc${NC} — Shogun Formation Controller"
    echo ""
    echo "Usage:"
    echo "  shc deploy [formation_name]   Deploy a formation (default: hybrid)"
    echo "  shc status                    Show pane meta / settings.yaml / dashboard.yaml diff (3-way)"
    echo "  shc sync-meta                 Sync pane meta to dashboard.yaml formation_status (safe keys only)"
    echo "  shc restore                   Restore all ashigaru to all-sonnet"
    echo "  shc list                      List available formation presets"
    echo ""
    echo "Examples:"
    echo "  shc deploy hybrid    # Apply hybrid formation"
    echo "  shc deploy           # Apply default (hybrid) formation"
    echo "  shc restore          # Reset all to all-sonnet"
    echo "  shc status           # 3-way diff: pane meta / settings.yaml / dashboard.yaml"
    echo "  shc sync-meta        # Write pane state to dashboard.yaml formation_status"
    exit 0
}

# ─── Validate prerequisites ───
check_prerequisites() {
    local require_tmux="${1:-true}"

    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo -e "${RED}ERROR:${NC} settings.yaml not found at ${SETTINGS_FILE}" >&2
        exit 1
    fi
    if [[ ! -x "$PYTHON" ]] && ! command -v "$PYTHON" &>/dev/null; then
        echo -e "${RED}ERROR:${NC} Python not found at ${PYTHON}" >&2
        exit 1
    fi
    if [[ "$require_tmux" == "true" ]] && ! tmux info &>/dev/null 2>&1; then
        echo -e "${RED}ERROR:${NC} tmux is not running" >&2
        exit 1
    fi
}

# ─── Read formation from settings.yaml ───
# Returns JSON: {"agents": {"ashigaru1": {"cli_type": "claude", "model": "..."}, ...}}
read_formation() {
    local formation_name="$1"
    "$PYTHON" -c "
import yaml, json, sys

with open('${SETTINGS_FILE}') as f:
    data = yaml.safe_load(f) or {}

formations = data.get('formations', {})
if not formations:
    print('ERROR:NO_FORMATIONS', file=sys.stderr)
    sys.exit(1)

formation = formations.get('${formation_name}')
if not formation:
    print('ERROR:NOT_FOUND', file=sys.stderr)
    # Print available formation names for error message
    print(json.dumps(list(formations.keys())))
    sys.exit(1)

print(json.dumps(formation))
" 2>/tmp/shc_formation_err
}

# ─── List formations ───
cmd_list() {
    check_prerequisites

    local output
    output=$("$PYTHON" -c "
import yaml, json, sys

with open('${SETTINGS_FILE}') as f:
    data = yaml.safe_load(f) or {}

formations = data.get('formations', {})
if not formations:
    print('NO_FORMATIONS')
    sys.exit(0)

for name, cfg in formations.items():
    desc = cfg.get('description', '(no description)')
    print(f'{name}|{desc}')
" 2>/dev/null)

    if [[ "$output" == "NO_FORMATIONS" || -z "$output" ]]; then
        echo -e "${YELLOW}WARN:${NC} No formations defined in settings.yaml"
        echo "Add a 'formations:' section to config/settings.yaml"
        return 0
    fi

    echo -e "${BOLD}Available Formations:${NC}"
    echo ""
    while IFS='|' read -r name desc; do
        printf "  ${CYAN}%-15s${NC} — %s\n" "$name" "$desc"
    done <<< "$output"
}

# ─── agent_id からペインを検索 ───
find_pane_by_agent() {
    local agent_id="$1"
    local pane_count
    pane_count=$(tmux list-panes -t "multiagent:agents" 2>/dev/null | wc -l)
    if [[ "$pane_count" -eq 0 ]]; then
        echo ""
        return 1
    fi
    for i in $(seq 0 $((pane_count - 1))); do
        local pane_target="multiagent:agents.$i"
        local aid
        aid=$(tmux display-message -t "$pane_target" -p '#{@agent_id}' 2>/dev/null || echo "")
        if [[ "$aid" == "$agent_id" ]]; then
            echo "$pane_target"
            return 0
        fi
    done
    echo ""
    return 1
}

# ─── デプロイ後の実態検証 ───
# AC-B1: 各 pane の @agent_cli と settings.yaml cli.agents を照合
# AC-B2: 乖離時は warn/error 表示 + 失敗 agent_id 列挙 + 非0終了
verify_formation_deploy() {
    local agents_data="$1"  # pipe-delimited: agent_id|cli_type|model

    echo ""
    echo -e "${BOLD}Post-deploy verification:${NC}"
    echo ""

    local mismatch_agents=()
    local not_found_agents=()

    while IFS='|' read -r agent_id cli_type model; do
        [[ "$agent_id" == "karo" || "$agent_id" == "gunshi" ]] && continue

        local pane_target
        pane_target=$(find_pane_by_agent "$agent_id")

        if [[ -z "$pane_target" ]]; then
            printf "  ${YELLOW}NOT_FOUND${NC} %-12s: pane not found in multiagent:agents\n" "$agent_id"
            not_found_agents+=("$agent_id")
            continue
        fi

        local actual_cli
        actual_cli=$(tmux display-message -t "$pane_target" -p '#{@agent_cli}' 2>/dev/null | tr -d '[:space:]' || echo "unknown")
        [[ -z "$actual_cli" ]] && actual_cli="unknown"

        if [[ "$actual_cli" == "$cli_type" ]]; then
            printf "  ${GREEN}OK${NC}        %-12s: %s\n" "$agent_id" "$cli_type"
        else
            printf "  ${RED}MISMATCH${NC}  %-12s: expected=%s actual=%s\n" "$agent_id" "$cli_type" "$actual_cli"
            mismatch_agents+=("$agent_id")
        fi
    done <<< "$agents_data"

    echo ""

    local has_error=false

    if [[ ${#mismatch_agents[@]} -gt 0 ]]; then
        echo -e "${RED}ERROR: CLI metadata mismatch detected for:${NC} ${mismatch_agents[*]}"
        echo -e "  These agents may still be on the old CLI (silent failure in switch)."
        has_error=true
    fi

    if [[ ${#not_found_agents[@]} -gt 0 ]]; then
        echo -e "${YELLOW}WARN: Pane not found for:${NC} ${not_found_agents[*]}"
    fi

    if ! $has_error; then
        echo -e "${GREEN}All verified agents match expected CLI configuration.${NC}"
    fi

    $has_error && return 1 || return 0
}

# ─── Status (3-way: pane meta / settings.yaml / dashboard.yaml) ───
cmd_status() {
    check_prerequisites

    local tmp_pane
    tmp_pane=$(mktemp /tmp/shc_pane_XXXXXX)
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_pane}'" RETURN

    # ── [1] Pane Meta ──
    echo -e "${BOLD}[1] Pane Meta${NC}"
    echo ""
    printf "  ${BOLD}%-6s %-12s %-8s %-25s %-6s${NC}\n" "pane" "agent_id" "cli" "model" "effort"
    printf "  %-6s %-12s %-8s %-25s %-6s\n" "------" "------------" "--------" "-------------------------" "------"

    local pane_count
    pane_count=$(tmux list-panes -t "multiagent:agents" 2>/dev/null | wc -l)
    if [[ "$pane_count" -eq 0 ]]; then
        echo -e "  ${YELLOW}(no panes found in multiagent:agents)${NC}"
    else
        for i in $(seq 0 $((pane_count - 1))); do
            local pane_target="multiagent:agents.$i"
            local agent_id cli_type model_name effort

            agent_id=$(tmux display-message -t "$pane_target" -p '#{@agent_id}' 2>/dev/null || echo "")
            cli_type=$(tmux display-message -t "$pane_target" -p '#{@agent_cli}' 2>/dev/null || echo "")
            model_name=$(tmux display-message -t "$pane_target" -p '#{@model_name}' 2>/dev/null || echo "")
            effort=$(tmux display-message -t "$pane_target" -p '#{@effort}' 2>/dev/null || echo "")

            [[ -z "$agent_id" ]] && agent_id="?"
            [[ -z "$cli_type" ]] && cli_type="?"
            [[ -z "$model_name" ]] && model_name="?"
            [[ -z "$effort" ]] && effort="?"

            printf "  %-6s %-12s %-8s %-25s %-6s\n" "0.$i" "$agent_id" "$cli_type" "$model_name" "$effort"
            printf '%s|%s|%s|%s\n' "$agent_id" "$cli_type" "$model_name" "$effort" >> "$tmp_pane"
        done
    fi

    echo ""

    # ── [2] settings.yaml baseline vs pane diff ──
    echo -e "${BOLD}[2] settings.yaml baseline vs pane diff${NC}"
    echo ""

    "$PYTHON" - "${tmp_pane}" "${SETTINGS_FILE}" <<'PYEOF' || echo -e "  ${YELLOW}WARN: diff comparison failed${NC}"
import yaml, sys

pane_path, settings_path = sys.argv[1], sys.argv[2]

pane_map = {}
try:
    with open(pane_path) as f:
        for line in f:
            parts = line.rstrip('\n').split('|')
            if len(parts) >= 3 and parts[0] not in ('', '?'):
                pane_map[parts[0]] = {'cli': parts[1], 'model': parts[2]}
except Exception:
    pass

try:
    with open(settings_path) as f:
        data = yaml.safe_load(f) or {}
except Exception as e:
    print(f'  WARN: Cannot read settings.yaml: {e}')
    sys.exit(0)

cli_agents = data.get('cli', {}).get('agents', {})
if not cli_agents:
    print('  (no cli.agents in settings.yaml)')
    sys.exit(0)

GREEN  = '\033[0;32m'
YELLOW = '\033[0;33m'
RED    = '\033[0;31m'
NC     = '\033[0m'

print(f"  {'agent':<12} {'s.yaml-cli':<10} {'s.yaml-model':<26} pane-diff")
print(f"  {'------------':<12} {'----------':<10} {'--------------------------':<26} ----------")

for aid in sorted(cli_agents.keys()):
    cfg = cli_agents[aid]
    if isinstance(cfg, dict):
        scli  = cfg.get('cli_type', 'claude')
        smodel = cfg.get('model', 'claude-sonnet-4-6')
    else:
        scli  = 'claude'
        smodel = 'claude-sonnet-4-6'

    if aid not in pane_map:
        diff = f'{YELLOW}NO_PANE{NC}'
    elif pane_map[aid]['cli'] == scli:
        diff = f'{GREEN}OK{NC}'
    else:
        diff = f'{RED}MISMATCH{NC}(pane={pane_map[aid]["cli"]})'

    print(f"  {aid:<12} {scli:<10} {smodel:<26} {diff}")
PYEOF

    echo ""

    # ── [3] dashboard.yaml status ──
    echo -e "${BOLD}[3] dashboard.yaml status${NC}"
    echo ""

    if [[ ! -f "${DASHBOARD_FILE}" ]]; then
        echo -e "  ${YELLOW}dashboard.yaml not found${NC}"
        return 0
    fi

    "$PYTHON" - "${DASHBOARD_FILE}" <<'PYEOF' || echo -e "  ${YELLOW}WARN: Failed to parse dashboard.yaml${NC}"
import yaml, sys

with open(sys.argv[1]) as f:
    d = yaml.safe_load(f) or {}

meta = d.get('metadata', {})
print(f'  last_updated : {meta.get("last_updated", "(none)")}')
print(f'  streak       : {meta.get("streak", "(none)")}')

in_prog = d.get('in_progress', [])
print()
if in_prog:
    print('  in_progress:')
    for e in in_prog:
        print(f'    [{e.get("cmd","?")}] {e.get("assignee","?")} — {e.get("status","?")}')
else:
    print('  in_progress  : (none)')

fs = d.get('formation_status')
print()
if fs:
    print(f'  formation_status.last_sync : {fs.get("last_sync","(none)")}')
    for aid, info in (fs.get('agents') or {}).items():
        print(f'    [{aid}] cli={info.get("cli","?")} model={info.get("model","?")}')
else:
    print('  formation_status : (not yet synced — run "shc sync-meta" to populate)')
PYEOF
}

# ─── Sync pane meta → dashboard.yaml formation_status (safe keys only) ───
# DELTA-A3/A4: Only writes to formation_status key.
# NEVER touches: action_required, action_required_archive, achievements,
#   in_progress, gate_registry, observation_queue, observation_queue_archive,
#   skill_candidates, metrics, documentation_rules, frog, idle_members, metadata
cmd_sync_meta() {
    check_prerequisites

    echo -e "${BOLD}Syncing pane meta → dashboard.yaml formation_status${NC}"
    echo ""

    if [[ ! -f "${DASHBOARD_FILE}" ]]; then
        echo -e "${RED}ERROR:${NC} dashboard.yaml not found at ${DASHBOARD_FILE}" >&2
        exit 1
    fi

    local tmp_pane
    tmp_pane=$(mktemp /tmp/shc_pane_XXXXXX)
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_pane}'" RETURN

    local pane_count
    pane_count=$(tmux list-panes -t "multiagent:agents" 2>/dev/null | wc -l)
    if [[ "$pane_count" -eq 0 ]]; then
        echo -e "  ${YELLOW}WARN:${NC} No panes in multiagent:agents — writing empty agents map"
    else
        for i in $(seq 0 $((pane_count - 1))); do
            local pane_target="multiagent:agents.$i"
            local agent_id cli_type model_name

            agent_id=$(tmux display-message -t "$pane_target" -p '#{@agent_id}' 2>/dev/null || echo "")
            cli_type=$(tmux display-message -t "$pane_target" -p '#{@agent_cli}' 2>/dev/null || echo "")
            model_name=$(tmux display-message -t "$pane_target" -p '#{@model_name}' 2>/dev/null || echo "")

            [[ -n "$agent_id" && "$agent_id" != "?" ]] && \
                printf '%s|%s|%s\n' "$agent_id" "${cli_type:-?}" "${model_name:-?}" >> "$tmp_pane"
        done
    fi

    "$PYTHON" - "${tmp_pane}" "${DASHBOARD_FILE}" <<'PYEOF' || { echo -e "  ${RED}ERROR: sync failed${NC}" >&2; exit 1; }
import yaml, sys
from datetime import datetime, timezone, timedelta

pane_path, dashboard_path = sys.argv[1], sys.argv[2]

# Keys that this command is NEVER allowed to modify
FORBIDDEN_KEYS = {
    'action_required', 'action_required_archive', 'achievements',
    'in_progress', 'gate_registry', 'observation_queue',
    'observation_queue_archive', 'skill_candidates', 'metrics',
    'documentation_rules', 'frog', 'idle_members', 'metadata',
}

agents = {}
try:
    with open(pane_path) as f:
        for line in f:
            parts = line.rstrip('\n').split('|')
            if len(parts) >= 3 and parts[0] not in ('', '?'):
                agents[parts[0]] = {'cli': parts[1], 'model': parts[2]}
except Exception:
    pass

with open(dashboard_path) as f:
    d = yaml.safe_load(f) or {}

# Snapshot forbidden keys before write
forbidden_before = {k: d.get(k) for k in FORBIDDEN_KEYS if k in d}

JST = timezone(timedelta(hours=9))
now_jst = datetime.now(JST).strftime('%Y-%m-%dT%H:%M:%S+09:00')

# Write ONLY to formation_status
d['formation_status'] = {
    'last_sync': now_jst,
    'agents': agents,
}

# Verify forbidden keys are unchanged
for k, before_val in forbidden_before.items():
    if d.get(k) != before_val:
        print(f'ABORT: forbidden key "{k}" was modified — refusing to write', file=sys.stderr)
        sys.exit(1)

with open(dashboard_path, 'w') as f:
    yaml.dump(d, f, allow_unicode=True, default_flow_style=False, sort_keys=True)

print(f'  last_sync : {now_jst}')
print(f'  agents    : {sorted(agents.keys())}')
PYEOF

    echo -e "${GREEN}Done.${NC} Run 'shc status' to verify."
}

# ─── Deploy ───
cmd_deploy() {
    local formation_name="${1:-hybrid}"
    local settings_only=false

    # Parse optional flags (--settings-only: update settings.yaml only, skip switch_cli)
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --settings-only) settings_only=true ;;
        esac
        shift
    done

    if $settings_only; then
        # DEPRECATED (cmd_730β): shu/shk/shx no longer call --settings-only.
        # This flag is retained for safety but will be removed in a future release.
        echo -e "${YELLOW}DEPRECATED:${NC} --settings-only was removed from shu/shk/shx in cmd_730β."
        echo -e "  Use runtime overlay (shutsujin_departure.sh) instead."
        echo ""
        check_prerequisites false
    else
        check_prerequisites true
    fi

    echo -e "${BOLD}Deploying formation:${NC} ${CYAN}${formation_name}${NC}"
    echo ""

    # Read formation config
    local formation_json
    local err_output
    err_output=$(cat /tmp/shc_formation_err 2>/dev/null || true)

    if ! formation_json=$(read_formation "$formation_name"); then
        if [[ -f /tmp/shc_formation_err ]]; then
            err_output=$(cat /tmp/shc_formation_err)
        fi
        if echo "$err_output" | grep -q "ERROR:NO_FORMATIONS"; then
            echo -e "${RED}ERROR:${NC} No formations section in settings.yaml" >&2
            echo "Add formations to config/settings.yaml first." >&2
            exit 1
        fi
        if echo "$err_output" | grep -q "ERROR:NOT_FOUND"; then
            echo -e "${RED}ERROR:${NC} Formation '${formation_name}' not found." >&2
            echo ""
            echo "Available formations:"
            # formation_json contains the list of available names on NOT_FOUND
            echo "$formation_json" | "$PYTHON" -c "
import json, sys
names = json.load(sys.stdin)
for n in names:
    print(f'  - {n}')
" 2>/dev/null || true
            exit 1
        fi
        echo -e "${RED}ERROR:${NC} Failed to read formation '${formation_name}'" >&2
        exit 1
    fi

    # Clean up temp file
    rm -f /tmp/shc_formation_err

    # Step 1: Update cli.agents section in settings.yaml to match formation
    # This avoids switch_cli.sh's update_settings_yaml() which corrupts formations section
    echo -e "  Updating cli.agents in settings.yaml..."
    if ! echo "$formation_json" | "$PYTHON" -c "
import yaml, json, sys

formation = json.load(sys.stdin)
agents = formation.get('agents', {})

with open('${SETTINGS_FILE}') as f:
    data = yaml.safe_load(f) or {}

cli = data.setdefault('cli', {})
cli_agents = cli.setdefault('agents', {})

for agent_id, cfg in agents.items():
    cli_type = cfg.get('type') or cfg.get('cli_type', 'claude')
    model = cfg.get('model', 'claude-sonnet-4-6')
    effort = cfg.get('effort', 'max')
    if agent_id not in cli_agents or not isinstance(cli_agents[agent_id], dict):
        cli_agents[agent_id] = {}
    cli_agents[agent_id]['cli_type'] = cli_type
    cli_agents[agent_id]['model'] = model
    cli_agents[agent_id]['effort'] = effort

# Preserve formations section by using round-trip approach:
# Read original file, find cli.agents block, replace only that part
import re

with open('${SETTINGS_FILE}') as f:
    original = f.read()

# Build replacement cli.agents block
lines = ['  agents:']
for aid in sorted(cli_agents.keys()):
    acfg = cli_agents[aid]
    if isinstance(acfg, dict):
        lines.append(f'    {aid}:')
        for k, v in acfg.items():
            lines.append(f'      {k}: {v}')
    else:
        lines.append(f'    {aid}:')
        lines.append(f'      effort: {acfg}')
new_agents_block = '\n'.join(lines)

# Find and replace the agents: block under cli:
# Match from '  agents:' to the next top-level key or formations section
pattern = r'(  agents:\n(?:    .*\n)*)'
match = re.search(pattern, original)
if match:
    result = original[:match.start()] + new_agents_block + '\n' + original[match.end():]
    with open('${SETTINGS_FILE}', 'w') as f:
        f.write(result)
    print('OK')
else:
    print('WARN: agents block not found, skipping settings update')
" 2>/dev/null; then
        echo -e "  ${YELLOW}WARN:${NC} Failed to update cli.agents (non-fatal)"
    fi

    # --settings-only: skip CLI switching (used pre-start when agents aren't running yet)
    if $settings_only; then
        echo -e "${GREEN}settings.yaml updated.${NC} (--settings-only: switch_cli skipped)"
        return 0
    fi

    # Step 2: Parse formation agents and call switch_cli.sh WITHOUT --type/--model
    # switch_cli.sh will read from the just-updated cli.agents section
    local total=0
    local success=0
    local failed=0

    local agents_data
    agents_data=$(echo "$formation_json" | "$PYTHON" -c "
import json, sys
formation = json.load(sys.stdin)
agents = formation.get('agents', {})
for agent_id, cfg in agents.items():
    cli_type = cfg.get('type') or cfg.get('cli_type', 'claude')
    model = cfg.get('model', 'claude-sonnet-4-6')
    print(f'{agent_id}|{cli_type}|{model}')
" 2>/dev/null)

    if [[ -z "$agents_data" ]]; then
        echo -e "${YELLOW}WARN:${NC} No agents defined in formation '${formation_name}'"
        return 0
    fi

    while IFS='|' read -r agent_id cli_type model; do
        # Skip karo and gunshi (fixed placement)
        if [[ "$agent_id" == "karo" || "$agent_id" == "gunshi" ]]; then
            echo -e "  ${YELLOW}SKIP${NC}  ${agent_id} (fixed placement)"
            continue
        fi

        total=$((total + 1))
        echo -ne "  Switching ${agent_id} → ${cli_type}/${model} ... "

        # Call switch_cli.sh WITHOUT --type/--model to avoid formations corruption
        if bash "${PROJECT_ROOT}/scripts/switch_cli.sh" "$agent_id" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
            success=$((success + 1))
        else
            echo -e "${RED}FAILED${NC}"
            failed=$((failed + 1))
        fi
    done <<< "$agents_data"

    echo ""
    echo -e "${BOLD}Result:${NC} ${GREEN}${success} success${NC}, ${RED}${failed} failed${NC} (${total} total)"

    # Post-deploy verification (AC-B1/B2)
    if [[ "$total" -gt 0 ]]; then
        if ! verify_formation_deploy "$agents_data"; then
            echo ""
            echo -e "${RED}WARN: Deploy completed with verification failures.${NC}"
            echo "Some agents may still be running the old CLI (metadata mismatch)."
            echo "Run 'shc status' to see current state, or re-run 'shc deploy ${formation_name}'."
            exit 1
        fi
    fi
}

# ─── Restore ───
cmd_restore() {
    echo -e "${BOLD}Restoring to all-sonnet formation...${NC}"
    cmd_deploy "all-sonnet"
}

# ═══════════════════════════════════════════════════════════════
# Main entry point
# ═══════════════════════════════════════════════════════════════

if [[ $# -lt 1 ]]; then
    usage
fi

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
    deploy)
        cmd_deploy "$@"
        ;;
    status)
        cmd_status
        ;;
    sync-meta)
        cmd_sync_meta
        ;;
    restore)
        cmd_restore
        ;;
    list)
        cmd_list
        ;;
    --help|-h|help)
        usage
        ;;
    *)
        echo -e "${RED}ERROR:${NC} Unknown subcommand '${SUBCOMMAND}'" >&2
        echo ""
        usage
        ;;
esac
