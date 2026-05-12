#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# shc.sh — 陣形管理コマンド (Shogun Formation Controller)
#
# Usage:
#   shc deploy [formation_name]   Deploy a formation (default: hybrid)
#   shc status                    Show current agent CLI/model status
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
    echo "  shc status                    Show current agent CLI/model status"
    echo "  shc restore                   Restore all ashigaru to all-sonnet"
    echo "  shc list                      List available formation presets"
    echo ""
    echo "Examples:"
    echo "  shc deploy hybrid    # Apply hybrid formation"
    echo "  shc deploy           # Apply default (hybrid) formation"
    echo "  shc restore          # Reset all to all-sonnet"
    exit 0
}

# ─── Validate prerequisites ───
check_prerequisites() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo -e "${RED}ERROR:${NC} settings.yaml not found at ${SETTINGS_FILE}" >&2
        exit 1
    fi
    if [[ ! -x "$PYTHON" ]] && ! command -v "$PYTHON" &>/dev/null; then
        echo -e "${RED}ERROR:${NC} Python not found at ${PYTHON}" >&2
        exit 1
    fi
    if ! tmux info &>/dev/null 2>&1; then
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

# ─── Status ───
cmd_status() {
    check_prerequisites

    echo -e "${BOLD}Agent Status:${NC}"
    echo ""
    printf "  ${BOLD}%-6s %-12s %-8s %-25s %-6s${NC}\n" "pane" "agent_id" "cli" "model" "effort"
    printf "  %-6s %-12s %-8s %-25s %-6s\n" "------" "------------" "--------" "-------------------------" "------"

    local pane_count
    pane_count=$(tmux list-panes -t "multiagent:agents" 2>/dev/null | wc -l)
    if [[ "$pane_count" -eq 0 ]]; then
        echo -e "  ${YELLOW}(no panes found in multiagent:agents)${NC}"
        return 0
    fi

    for i in $(seq 0 $((pane_count - 1))); do
        local pane_target="multiagent:agents.$i"
        local agent_id cli_type model_name effort

        agent_id=$(tmux display-message -t "$pane_target" -p '#{@agent_id}' 2>/dev/null || echo "?")
        cli_type=$(tmux display-message -t "$pane_target" -p '#{@agent_cli}' 2>/dev/null || echo "?")
        model_name=$(tmux display-message -t "$pane_target" -p '#{@model_name}' 2>/dev/null || echo "?")
        effort=$(tmux display-message -t "$pane_target" -p '#{@effort}' 2>/dev/null || echo "?")

        # Clean up empty values
        [[ -z "$agent_id" ]] && agent_id="?"
        [[ -z "$cli_type" ]] && cli_type="?"
        [[ -z "$model_name" ]] && model_name="?"
        [[ -z "$effort" ]] && effort="?"

        printf "  %-6s %-12s %-8s %-25s %-6s\n" "0.$i" "$agent_id" "$cli_type" "$model_name" "$effort"
    done
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

    check_prerequisites

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
