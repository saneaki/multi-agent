#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# shp.sh — 番号指定一括出陣コマンド (Shogun Preset Launcher)
#
# Usage:
#   bash scripts/shp.sh                         # interactive
#   bash scripts/shp.sh --dry-run               # confirm only
#   bash scripts/shp.sh --preset <name>         # preset (skip interactive)
#   bash scripts/shp.sh --preset <name> --dry-run
#   bash scripts/shp.sh --help
#
# 番号体系:
#   1 = Sonnet+T  (claude-sonnet-4-6, thinking ON)
#   2 = Opus+T    (claude-opus-4-7, thinking ON)
#   3 = Codex     (gpt-5.5)
#
# プリセット:
#   current          現在の settings.yaml 値をそのまま使用
#   heavy-opus       全員 Opus+T
#   all-sonnet       全員 Sonnet+T
#   sonnet-codex-mix 将軍/家老/軍師=Sonnet+T, 足軽=交互(Sonnet/Codex)
# ═══════════════════════════════════════════════════════════════

# bash 機能使用 (連想配列, read -r, [[ ]])
# shellcheck shell=bash
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
NC='\033[0m'

# ─── 構成員 (prompt順: 固定) ───
MEMBER_IDS=(shogun karo ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7 gunshi)

member_label() {
    case "$1" in
        shogun)    echo "将軍" ;;
        karo)      echo "家老" ;;
        ashigaru1) echo "足軽1" ;;
        ashigaru2) echo "足軽2" ;;
        ashigaru3) echo "足軽3" ;;
        ashigaru4) echo "足軽4" ;;
        ashigaru5) echo "足軽5" ;;
        ashigaru6) echo "足軽6" ;;
        ashigaru7) echo "足軽7" ;;
        gunshi)    echo "軍師" ;;
        *)         echo "$1" ;;
    esac
}

num_label() {
    case "$1" in
        1) echo "Sonnet+T" ;;
        2) echo "Opus+T" ;;
        3) echo "Codex" ;;
        *) echo "?" ;;
    esac
}

num_cli_type() {
    case "$1" in
        1|2) echo "claude" ;;
        3)   echo "codex" ;;
        *)   echo "claude" ;;
    esac
}

num_model() {
    case "$1" in
        1) echo "claude-sonnet-4-6" ;;
        2) echo "claude-opus-4-7" ;;
        3) echo "gpt-5.5" ;;
        *) echo "claude-sonnet-4-6" ;;
    esac
}

# ─── Usage ───
usage() {
    echo -e "${BOLD}shp${NC} — 番号指定一括出陣コマンド"
    echo ""
    echo "Usage:"
    echo "  shp                          interactive (番号を順番に選択)"
    echo "  shp --dry-run                確認のみ (settings.yaml/pane変更なし)"
    echo "  shp --preset <name>          プリセット使用"
    echo "  shp --preset <name> --dry-run  プリセット確認のみ"
    echo "  shp --help                   このヘルプを表示"
    echo ""
    echo "番号体系:"
    echo -e "  ${CYAN}1${NC} = Sonnet+T  (claude-sonnet-4-6, thinking ON)"
    echo -e "  ${CYAN}2${NC} = Opus+T    (claude-opus-4-7, thinking ON)"
    echo -e "  ${CYAN}3${NC} = Codex     (gpt-5.5)"
    echo ""
    echo "プリセット:"
    echo "  current          現在の settings.yaml の値をそのまま使用"
    echo "  heavy-opus       全員 Opus+T"
    echo "  all-sonnet       全員 Sonnet+T"
    echo "  sonnet-codex-mix 将軍/家老/軍師=Sonnet+T, 足軽=交互(Sonnet/Codex)"
    echo ""
    echo "例:"
    echo "  shp                              # 全員インタラクティブに選択"
    echo "  shp --preset all-sonnet          # 全員 Sonnet+T で出陣"
    echo "  shp --preset heavy-opus --dry-run  # Opus 陣形の確認のみ"
    exit 0
}

# ─── 前提チェック ───
check_prerequisites() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo -e "${RED}ERROR:${NC} settings.yaml が見つかりません: ${SETTINGS_FILE}" >&2
        exit 1
    fi
    if [[ ! -x "$PYTHON" ]]; then
        if command -v python3 &>/dev/null; then
            PYTHON="python3"
        else
            echo -e "${RED}ERROR:${NC} Python が見つかりません" >&2
            exit 1
        fi
    fi
    if ! tmux info &>/dev/null 2>&1; then
        echo -e "${YELLOW}WARN:${NC} tmux が起動していません。--dry-run モードのみ利用可能です。" >&2
    fi
}

# ─── エージェントの現在番号を取得 ───
get_current_number() {
    local agent_id="$1"
    "$PYTHON" -c "
import yaml, sys
try:
    with open('${SETTINGS_FILE}') as f:
        cfg = yaml.safe_load(f) or {}
    agent = cfg.get('cli', {}).get('agents', {}).get('${agent_id}', {})
    if not isinstance(agent, dict):
        print('1'); sys.exit(0)
    cli_type = agent.get('cli_type', agent.get('type', 'claude'))
    model = agent.get('model', '')
    if cli_type == 'codex':
        print('3')
    elif 'opus' in model:
        print('2')
    else:
        print('1')
except Exception:
    print('1')
" 2>/dev/null || echo "1"
}

# ─── バナー表示 ───
show_banner() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  shp — 番号指定一括出陣${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  番号体系:"
    echo -e "    ${CYAN}1${NC} = Sonnet+T  (claude-sonnet-4-6, thinking ON)"
    echo -e "    ${CYAN}2${NC} = Opus+T    (claude-opus-4-7, thinking ON)"
    echo -e "    ${CYAN}3${NC} = Codex     (gpt-5.5)"
    echo ""
    echo "  Enter のみ → 現在値維持"
    echo ""
}

# ─── インタラクティブ入力 ───
# 各構成員の番号を SELECTIONS 連想配列に格納する
interactive_select() {
    show_banner
    echo -e "${BOLD}  構成員 model 番号を選択:${NC}"
    echo ""

    local agent_id label current current_label input
    for agent_id in "${MEMBER_IDS[@]}"; do
        label=$(member_label "$agent_id")
        current=$(get_current_number "$agent_id")
        current_label=$(num_label "$current")

        while true; do
            printf "  [%s] model番号 (1/2/3) [現在: %s=%s]: " "$label" "$current" "$current_label"
            read -r input || true

            if [[ -z "$input" ]]; then
                SELECTIONS["$agent_id"]="$current"
                break
            elif [[ "$input" =~ ^[123]$ ]]; then
                SELECTIONS["$agent_id"]="$input"
                break
            else
                echo -e "  ${RED}無効な入力です${NC}。1, 2, 3 のいずれかを入力してください。"
            fi
        done
    done
}

# ─── プリセット適用 ───
apply_preset() {
    local preset_name="$1"
    local agent_id i

    case "$preset_name" in
        current)
            for agent_id in "${MEMBER_IDS[@]}"; do
                SELECTIONS["$agent_id"]=$(get_current_number "$agent_id")
            done
            ;;
        heavy-opus)
            for agent_id in "${MEMBER_IDS[@]}"; do
                SELECTIONS["$agent_id"]="2"
            done
            ;;
        all-sonnet)
            for agent_id in "${MEMBER_IDS[@]}"; do
                SELECTIONS["$agent_id"]="1"
            done
            ;;
        sonnet-codex-mix)
            # 将軍/家老/軍師 = Sonnet+T
            SELECTIONS[shogun]="1"
            SELECTIONS[karo]="1"
            SELECTIONS[gunshi]="1"
            # 足軽 = 交互 (奇数=Sonnet+T, 偶数=Codex)
            for i in 1 2 3 4 5 6 7; do
                if (( i % 2 == 1 )); then
                    SELECTIONS["ashigaru${i}"]="1"
                else
                    SELECTIONS["ashigaru${i}"]="3"
                fi
            done
            ;;
        *)
            echo -e "${RED}ERROR:${NC} 不明なプリセット: '${preset_name}'" >&2
            echo ""
            echo "利用可能なプリセット: current, heavy-opus, all-sonnet, sonnet-codex-mix"
            exit 1
            ;;
    esac
}

# ─── サマリー表示 ───
show_summary() {
    local agent_id label num nl

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  出陣設定サマリー${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    for agent_id in "${MEMBER_IDS[@]}"; do
        label=$(member_label "$agent_id")
        num="${SELECTIONS[$agent_id]:-1}"
        nl=$(num_label "$num")
        printf "  %-6s : %s ${CYAN}(%s)${NC}\n" "$label" "$num" "$nl"
    done

    echo ""
}

# ─── settings.yaml 一括更新 (Python inline) ───
update_settings_batch() {
    # JSON 形式で selections を渡す
    local sel_json="{"
    local first=1
    local agent_id
    for agent_id in "${MEMBER_IDS[@]}"; do
        local num="${SELECTIONS[$agent_id]:-1}"
        [[ $first -eq 0 ]] && sel_json+=", "
        sel_json+="\"${agent_id}\": ${num}"
        first=0
    done
    sel_json+="}"

    "$PYTHON" << PYEOF
import yaml, sys, json

settings_path = "${SETTINGS_FILE}"
selections = json.loads('''${sel_json}''')

NUMBER_MAP = {
    1: {"cli_type": "claude", "model": "claude-sonnet-4-6"},
    2: {"cli_type": "claude", "model": "claude-opus-4-7"},
    3: {"cli_type": "codex",  "model": "gpt-5.5"},
}

with open(settings_path) as f:
    content = f.read()

lines = content.split('\n')
new_lines = []
in_cli_section = False
in_cli_agents = False
i = 0

while i < len(lines):
    line = lines[i]
    stripped = line.lstrip()
    current_indent = len(line) - len(stripped) if stripped else -1

    # トップレベルセクション追跡
    if current_indent == 0 and stripped and not stripped.startswith('#'):
        in_cli_section = stripped.startswith('cli:')
        if not in_cli_section:
            in_cli_agents = False

    # cli.agents セクション追跡
    if in_cli_section and current_indent == 2 and stripped and not stripped.startswith('#'):
        in_cli_agents = stripped.startswith('agents:')

    # 対象エージェントの確認 (cli.agents 配下 indent=4)
    matched_agent = None
    if in_cli_agents and current_indent == 4 and stripped and not stripped.startswith('#'):
        for agent_id in selections:
            if stripped.startswith(f'{agent_id}:'):
                matched_agent = agent_id
                break

    if matched_agent is not None:
        agent_indent = current_indent
        inner_indent = ' ' * (agent_indent + 2)
        new_lines.append(line)

        num = selections[matched_agent]
        cfg = NUMBER_MAP.get(num, NUMBER_MAP[1])

        # 既存サブフィールドを読み飛ばしつつ保持すべき値 (effort等) を収集
        i += 1
        extra_fields = {}
        field_order = []
        while i < len(lines):
            next_line = lines[i]
            next_stripped = next_line.lstrip()
            if not next_stripped:
                break
            if next_stripped.startswith('#'):
                if (len(next_line) - len(next_stripped)) > agent_indent:
                    i += 1
                    continue
                break
            next_indent = len(next_line) - len(next_stripped)
            if next_indent <= agent_indent:
                break
            if ':' in next_stripped:
                key = next_stripped.split(':')[0].strip()
                val = ':'.join(next_stripped.split(':')[1:]).strip()
                if key not in ('cli_type', 'type', 'model', 'thinking'):
                    extra_fields[key] = val
                    field_order.append(key)
            i += 1

        # 新しいフィールドを書き出し (thinking は書かない → デフォルトON)
        new_lines.append(f'{inner_indent}cli_type: {cfg["cli_type"]}')
        new_lines.append(f'{inner_indent}model: {cfg["model"]}')
        for k in field_order:
            new_lines.append(f'{inner_indent}{k}: {extra_fields[k]}')
        continue
    else:
        new_lines.append(line)

    i += 1

result = '\n'.join(new_lines)
if content.endswith('\n') and not result.endswith('\n'):
    result += '\n'

with open(settings_path, 'w') as f:
    f.write(result)

print("OK")
PYEOF
}

# ─── 出陣実行 ───
execute_deploy() {
    local dry_run="${1:-false}"
    local total=0 success=0 failed=0
    local agent_id label num nl

    echo ""
    if [[ "$dry_run" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} 実行シミュレーション (settings.yaml/pane 変更なし)"
    else
        echo -ne "  settings.yaml 更新中..."
        if update_settings_batch; then
            echo -e " ${GREEN}OK${NC}"
        else
            echo -e " ${RED}FAILED${NC}"
            echo -e "${RED}ERROR:${NC} settings.yaml の更新に失敗しました" >&2
            exit 1
        fi
    fi

    echo ""

    for agent_id in "${MEMBER_IDS[@]}"; do
        label=$(member_label "$agent_id")
        num="${SELECTIONS[$agent_id]:-1}"
        nl=$(num_label "$num")

        if [[ "$agent_id" == "shogun" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                echo -e "  [DRY-RUN] ${label} → ${num}(${nl})  ${YELLOW}(手動再起動)${NC}"
            else
                echo -e "  ${YELLOW}SKIP${NC}   ${label} (shogun) → ${num}(${nl})  ※手動再起動が必要"
            fi
            continue
        fi

        total=$((total + 1))

        if [[ "$dry_run" == "true" ]]; then
            echo -e "  [DRY-RUN] ${label} (${agent_id}) → ${num}(${nl})"
        else
            echo -ne "  切替: ${label} (${agent_id}) → ${num}(${nl}) ... "
            if bash "${SCRIPT_DIR}/switch_cli.sh" "$agent_id" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
                success=$((success + 1))
            else
                echo -e "${RED}FAILED${NC}"
                failed=$((failed + 1))
            fi
        fi
    done

    if [[ "$dry_run" != "true" ]]; then
        echo ""
        echo -e "${BOLD}結果:${NC} ${GREEN}${success} success${NC}, ${RED}${failed} failed${NC} (${total} total)"
        if [[ $failed -gt 0 ]]; then
            echo -e "${YELLOW}WARN:${NC} 失敗した構成員は手動で switch_cli.sh を実行してください"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════
# メイン処理
# ═══════════════════════════════════════════════════════════════

# 引数パース
DRY_RUN=false
PRESET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --preset)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}ERROR:${NC} --preset にはプリセット名が必要です" >&2
                echo "利用可能: current, heavy-opus, all-sonnet, sonnet-codex-mix"
                exit 1
            fi
            PRESET="$2"
            shift 2
            ;;
        --help|-h|help)
            usage
            ;;
        *)
            echo -e "${RED}ERROR:${NC} 不明なオプション: '$1'" >&2
            echo ""
            usage
            ;;
    esac
done

check_prerequisites

# 連想配列宣言 (bash 4.0+)
declare -A SELECTIONS

if [[ -n "$PRESET" ]]; then
    echo ""
    echo -e "${BOLD}プリセット '${PRESET}' を適用します...${NC}"
    apply_preset "$PRESET"
else
    interactive_select
fi

show_summary

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${YELLOW}[DRY-RUN モード]${NC} settings.yaml/pane 変更は行われません。"
fi

printf "  出陣しますか? (y/N): "
read -r CONFIRM || CONFIRM=""
echo ""

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    execute_deploy "$DRY_RUN"
    if [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        echo -e "${GREEN}出陣完了！${NC}"
        shogun_num="${SELECTIONS[shogun]:-1}"
        shogun_nl=$(num_label "$shogun_num")
        echo -e "${YELLOW}将軍 (shogun) は手動で再起動してください → ${shogun_num}(${shogun_nl})${NC}"
    else
        echo ""
        echo -e "  ${YELLOW}[DRY-RUN]${NC} 上記が実際の出陣設定になります。"
        echo "  実際に出陣するには --dry-run なしで実行してください。"
    fi
else
    echo "  出陣を中止しました。"
fi

echo ""
