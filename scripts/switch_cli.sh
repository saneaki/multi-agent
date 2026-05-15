#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# switch_cli.sh — エージェントのCLIセッションを安全に切り替える
#
# Usage:
#   bash scripts/switch_cli.sh <agent_id> [--type <cli_type>] [--model <model_name>]
#
# Examples:
#   # settings.yaml の現在値で再起動（CLI種別/モデル変更なし）
#   bash scripts/switch_cli.sh ashigaru3
#
#   # Codex Spark → Claude Sonnet に切替
#   bash scripts/switch_cli.sh ashigaru3 --type claude --model claude-sonnet-4-6
#
#   # 同一CLI内でモデルだけ変更（Sonnet → Opus）
#   bash scripts/switch_cli.sh ashigaru3 --model claude-opus-4-7
#
#   # 全足軽を一括切替
#   for i in $(seq 1 7); do bash scripts/switch_cli.sh ashigaru$i --type claude --model claude-sonnet-4-6; done
#
# Flow:
#   1. (Optional) settings.yaml を更新
#   2. 現在のCLIに /exit を送信
#   3. シェルプロンプトの復帰を待機
#   4. build_cli_command() で新CLIコマンドを構築
#   5. tmux send-keys で新CLIを起動
#   6. tmux pane metadata を更新（@agent_cli, @model_name）
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETTINGS_FILE="${PROJECT_ROOT}/config/settings.yaml"
LOG_FILE="${PROJECT_ROOT}/logs/switch_cli.log"

# cli_adapter.sh をロード
source "${PROJECT_ROOT}/lib/cli_adapter.sh"

# ─── ログ ───
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [switch_cli] $*"
    echo "$msg" >&2
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# ─── Usage ───
usage() {
    echo "Usage: $0 <agent_id> [--type <cli_type>] [--model <model_name>]"
    echo ""
    echo "  agent_id   shogun, karo, ashigaru1-7, gunshi"
    echo "  --type     claude | codex | copilot | kimi"
    echo "  --model    claude-sonnet-4-6 | claude-opus-4-7 | gpt-5.3-codex | etc."
    echo ""
    echo "If --type/--model omitted, uses current settings.yaml values."
    exit 1
}

# ─── Agent ID → tmux pane 解決 ───
# @agent_id メタデータから動的にペインを検索する（ペイン番号のズレに対応）
# フォールバック: メタデータが見つからない場合は従来の固定マッピングを使用
resolve_pane() {
    local agent_id="$1"

    # Phase 1: 将軍セッションの @agent_id メタデータから動的検索
    local pane_count
    pane_count=$(tmux list-panes -t "shogun:0" 2>/dev/null | wc -l || true)
    if [[ "$pane_count" -gt 0 ]]; then
        for i in $(seq 0 $((pane_count - 1))); do
            local aid
            aid=$(tmux display-message -t "shogun:0.$i" -p '#{@agent_id}' 2>/dev/null)
            if [[ "$aid" == "$agent_id" ]]; then
                echo "shogun:0.$i"
                return 0
            fi
        done
    fi

    # Phase 2: multiagent セッションの @agent_id メタデータから動的検索
    pane_count=$(tmux list-panes -t "multiagent:agents" 2>/dev/null | wc -l || true)
    if [[ "$pane_count" -gt 0 ]]; then
        for i in $(seq 0 $((pane_count - 1))); do
            local aid
            aid=$(tmux display-message -t "multiagent:agents.$i" -p '#{@agent_id}' 2>/dev/null)
            if [[ "$aid" == "$agent_id" ]]; then
                echo "multiagent:agents.$i"
                return 0
            fi
        done
        log "WARN: @agent_id=$agent_id not found in shogun/multiagent panes. Falling back to fixed mapping."
    fi

    # Phase 3: フォールバック（従来の固定マッピング）
    local pane_base
    pane_base=$(tmux show-options -t multiagent -v @pane_base 2>/dev/null || echo "0")

    case "$agent_id" in
        shogun)     echo "shogun:0.0" ;;
        karo)       echo "multiagent:agents.$((pane_base + 0))" ;;
        ashigaru1)  echo "multiagent:agents.$((pane_base + 1))" ;;
        ashigaru2)  echo "multiagent:agents.$((pane_base + 2))" ;;
        ashigaru3)  echo "multiagent:agents.$((pane_base + 3))" ;;
        ashigaru4)  echo "multiagent:agents.$((pane_base + 4))" ;;
        ashigaru5)  echo "multiagent:agents.$((pane_base + 5))" ;;
        ashigaru6)  echo "multiagent:agents.$((pane_base + 6))" ;;
        ashigaru7)  echo "multiagent:agents.$((pane_base + 7))" ;;
        gunshi)     echo "multiagent:agents.$((pane_base + 8))" ;;
        *)
            log "ERROR: Unknown agent_id: $agent_id"
            return 1
            ;;
    esac
}

# ─── settings.yaml 更新 (Python使用) ───
update_settings_yaml() {
    local agent_id="$1"
    local new_type="${2:-}"
    local new_model="${3:-}"

    if [[ -z "$new_type" && -z "$new_model" ]]; then
        return 0
    fi

    log "Updating settings.yaml: ${agent_id} → type=${new_type:-<unchanged>}, model=${new_model:-<unchanged>}"

    "${PROJECT_ROOT}/.venv/bin/python3" << PYEOF
import datetime

settings_path = "${SETTINGS_FILE}"
agent_id = "${agent_id}"
new_type = "${new_type}" or None
new_model = "${new_model}" or None

with open(settings_path, 'r', encoding='utf-8') as f:
    content = f.read()

timestamp = datetime.datetime.now().strftime('%Y-%m-%d')
comment = f"# {timestamp}: switch_cli.sh による切替"

# コメント保持のためライン単位で書き換える。
# formations等の他セクションを破壊しないため、
# in_cli_section / in_cli_agents フラグで cli.agents 配下のみ対象にする。
lines = content.split('\n')
new_lines = []
in_cli_section = False
in_cli_agents = False

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.lstrip()
    current_indent = len(line) - len(stripped) if stripped else -1

    # トップレベルセクション(indent==0)を追跡
    if current_indent == 0 and stripped and not stripped.startswith('#'):
        in_cli_section = stripped.startswith('cli:')
        if not in_cli_section:
            in_cli_agents = False

    # cli.agents セクション(indent==2, cli配下)を追跡
    if in_cli_section and current_indent == 2 and stripped and not stripped.startswith('#'):
        in_cli_agents = stripped.startswith('agents:')

    # cli.agents 配下のエージェントエントリのみ対象（formations等は無視）
    if in_cli_agents and stripped.startswith(f'{agent_id}:'):
        agent_indent = current_indent
        new_lines.append(line)
        inner_indent = ' ' * (agent_indent + 2)

        # 既存サブフィールドを収集（effort等を保持するため）
        i += 1
        existing_fields = {}
        field_order = []
        while i < len(lines):
            next_line = lines[i]
            next_stripped = next_line.lstrip()
            if not next_stripped or next_stripped.startswith('#'):
                # インデントがエージェントより深いコメントは読み飛ばす
                if next_stripped.startswith('#') and (len(next_line) - len(next_stripped)) > agent_indent:
                    i += 1
                    continue
                break
            next_indent = len(next_line) - len(next_stripped)
            if next_indent <= agent_indent:
                break  # 次のエージェントまたはセクション
            if ':' in next_stripped:
                key, _, val = next_stripped.partition(':')
                k = key.strip()
                existing_fields[k] = val.strip()
                field_order.append(k)
            i += 1

        # type / model を更新（未指定なら既存値を使用）
        final_type = new_type if new_type else existing_fields.get('type', existing_fields.get('cli_type', ''))
        final_model = new_model if new_model else existing_fields.get('model', '')

        if final_type:
            new_lines.append(f'{inner_indent}cli_type: {final_type}')
        if final_model:
            if new_model:
                new_lines.append(f'{inner_indent}model: {final_model}  {comment}')
            else:
                new_lines.append(f'{inner_indent}model: {final_model}')

        # type/cli_type/model 以外のフィールド（effort等）を保持
        for k in field_order:
            if k not in ('type', 'cli_type', 'model'):
                new_lines.append(f'{inner_indent}{k}: {existing_fields[k]}')

        continue
    else:
        new_lines.append(line)
    i += 1

with open(settings_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(new_lines))
    if content.endswith('\n') and not '\n'.join(new_lines).endswith('\n'):
        f.write('\n')

print("OK")
PYEOF
}

# ─── pane 存在確認 ───
pane_exists() {
    local pane="$1"
    tmux display-message -t "$pane" -p '#{pane_id}' &>/dev/null 2>&1
}

# ─── pane busy 検出 ───
# Returns 0 (busy) if no recognizable prompt is visible at end of pane content.
# Returns 1 (not busy) if shell or CLI idle prompt is detected.
is_pane_busy() {
    local pane="$1"
    local content
    content=$(tmux capture-pane -t "$pane" -p 2>/dev/null)

    # Empty pane → fresh or just cleared → treat as safe
    if [[ -z "$(echo "$content" | tr -d '[:space:]')" ]]; then
        log "Pane ${pane} is empty - treating as not busy"
        return 1
    fi

    local last_line
    last_line=$(echo "$content" | grep -v '^$' | tail -1)

    # Prompt patterns: $, %, #, ❯, ► (shell or CLI idle)
    if echo "$last_line" | grep -qE '[\$%#❯►] *$'; then
        return 1  # Not busy - at a recognizable prompt
    fi

    return 0  # Busy - no prompt detected at end of content
}

# ─── 現在のCLI種別を取得（tmux metadata） ───
get_current_pane_cli() {
    local pane="$1"
    tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null | tr -d '[:space:]' || echo "claude"
}

# ─── /exit送信 ───
# All send-keys operations propagate failure — pane_exists() already verified before call.
send_exit() {
    local pane="$1"
    local current_cli="$2"

    log "Sending exit command to ${pane} (current CLI: ${current_cli})"

    case "$current_cli" in
        codex)
            tmux send-keys -t "$pane" Escape 2>/dev/null || { log "ERROR: Failed to send Escape to ${pane}"; return 1; }
            sleep 0.3
            tmux send-keys -t "$pane" C-c 2>/dev/null || { log "ERROR: Failed to send C-c to ${pane}"; return 1; }
            sleep 0.5
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || { log "ERROR: Failed to send /exit to ${pane}"; return 1; }
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || { log "ERROR: Failed to send Enter to ${pane}"; return 1; }
            ;;
        claude)
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || { log "ERROR: Failed to send /exit to ${pane}"; return 1; }
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || { log "ERROR: Failed to send Enter to ${pane}"; return 1; }
            ;;
        copilot|kimi)
            tmux send-keys -t "$pane" C-c 2>/dev/null || { log "ERROR: Failed to send C-c to ${pane}"; return 1; }
            sleep 0.5
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || { log "ERROR: Failed to send /exit to ${pane}"; return 1; }
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || { log "ERROR: Failed to send Enter to ${pane}"; return 1; }
            ;;
        *)
            tmux send-keys -t "$pane" "/exit" 2>/dev/null || { log "ERROR: Failed to send /exit to ${pane}"; return 1; }
            sleep 0.3
            tmux send-keys -t "$pane" Enter 2>/dev/null || { log "ERROR: Failed to send Enter to ${pane}"; return 1; }
            ;;
    esac
}

# ─── シェルプロンプト待ち（最大15秒） ───
wait_for_shell_prompt() {
    local pane="$1"
    local max_wait=15
    local waited=0

    log "Waiting for shell prompt on ${pane}..."

    while [ "$waited" -lt "$max_wait" ]; do
        sleep 1
        waited=$((waited + 1))

        local last_lines
        last_lines=$(tmux capture-pane -t "$pane" -p 2>/dev/null | grep -v '^$' | tail -3)

        # シェルプロンプトの検出パターン
        # PS1にはカスタムプロンプト（shutsujin由来）や標準的な$/%が含まれる
        if echo "$last_lines" | grep -qE '[\$%#❯►] *$'; then
            log "Shell prompt detected after ${waited}s"
            return 0
        fi

        # "exit" / "Bye" 等のCLI終了メッセージを検出
        if echo "$last_lines" | grep -qiE '(bye|goodbye|exiting|exit)'; then
            sleep 1  # 終了メッセージの後、プロンプトが出るまで少し待つ
            log "CLI exit message detected after ${waited}s"
            return 0
        fi
    done

    log "ERROR: Shell prompt not detected after ${max_wait}s. Aborting to prevent silent failure."
    return 1
}

# ─── モデル表示名の正規化（cli_adapter.sh の get_model_display_name を使用） ───
# get_model_display_name は cli_adapter.sh から source 済み

# ─── tmux pane metadata 更新 ───
update_pane_metadata() {
    local pane="$1"
    local new_cli_type="$2"
    local display_name="$3"

    log "Updating pane metadata: @agent_cli=${new_cli_type}, @model_name=${display_name}"

    tmux set-option -p -t "$pane" @agent_cli "$new_cli_type" 2>/dev/null || true
    tmux set-option -p -t "$pane" @model_name "$display_name" 2>/dev/null || true
    tmux select-pane -t "$pane" -T "$display_name" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════
# メイン処理
# ═══════════════════════════════════════════════════════════════

# 引数パース
if [ $# -lt 1 ]; then
    usage
fi

# --help が第1引数の場合
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
fi

AGENT_ID="$1"
shift

NEW_TYPE=""
NEW_MODEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --type)
            NEW_TYPE="$2"
            shift 2
            ;;
        --model)
            NEW_MODEL="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# バリデーション
if [[ -n "$NEW_TYPE" ]] && ! _cli_adapter_is_valid_cli "$NEW_TYPE"; then
    log "ERROR: Invalid CLI type: ${NEW_TYPE}. Allowed: ${CLI_ADAPTER_ALLOWED_CLIS}"
    exit 1
fi

# Step 0: pane解決
PANE_TARGET=$(resolve_pane "$AGENT_ID")
if [ -z "$PANE_TARGET" ]; then
    exit 1
fi
log "=== Starting CLI switch for ${AGENT_ID} (pane: ${PANE_TARGET}) ==="

# Step 0.1: pane 存在確認
if ! pane_exists "$PANE_TARGET"; then
    log "ERROR: Pane ${PANE_TARGET} for agent ${AGENT_ID} does not exist"
    exit 1
fi

# Step 0.5: --model指定時に--type未指定なら、モデル名からCLI種別を自動推定
if [[ -n "$NEW_MODEL" && -z "$NEW_TYPE" ]]; then
    case "$NEW_MODEL" in
        gpt-5.3-codex*|gpt-5-codex*)
            NEW_TYPE="codex"
            log "Auto-inferred type=codex from model=${NEW_MODEL}"
            ;;
        claude-*)
            NEW_TYPE="claude"
            log "Auto-inferred type=claude from model=${NEW_MODEL}"
            ;;
    esac
fi

# Step 1: settings.yaml 更新（--type/--model 指定時のみ）
if [[ -n "$NEW_TYPE" || -n "$NEW_MODEL" ]]; then
    update_settings_yaml "$AGENT_ID" "$NEW_TYPE" "$NEW_MODEL"
fi

# Step 2: 切替後のCLI情報を取得（settings.yaml反映後）
TARGET_CLI_TYPE=$(get_cli_type "$AGENT_ID")
TARGET_MODEL=$(get_agent_model "$AGENT_ID")
TARGET_CMD=$(build_cli_command "$AGENT_ID")

log "Target: cli=${TARGET_CLI_TYPE}, model=${TARGET_MODEL}, cmd=${TARGET_CMD}"

# Step 2.5: busy 検出 (send_exit 前)
if is_pane_busy "$PANE_TARGET"; then
    log "ERROR: Pane ${PANE_TARGET} (${AGENT_ID}) appears busy — no shell/CLI prompt detected."
    log "ERROR: Refusing to switch CLI to prevent silent failure. Verify agent state first."
    exit 1
fi

# Step 3: 現在のCLIを /exit で終了
CURRENT_CLI=$(get_current_pane_cli "$PANE_TARGET")
log "Current CLI: ${CURRENT_CLI}"
send_exit "$PANE_TARGET" "$CURRENT_CLI"

# Step 4: シェルプロンプトを待つ（タイムアウト時は exit 1）
if ! wait_for_shell_prompt "$PANE_TARGET"; then
    log "ERROR: CLI switch failed for ${AGENT_ID}: shell prompt not detected after exit attempt."
    log "ERROR: Pane ${PANE_TARGET} may be busy or stuck. Aborting to prevent silent failure."
    exit 1
fi

# Step 5: 新しいCLIコマンドを送信（失敗は伝播させる）
log "Launching new CLI: ${TARGET_CMD}"
if ! tmux send-keys -t "$PANE_TARGET" "$TARGET_CMD"; then
    log "ERROR: Failed to send CLI command to pane ${PANE_TARGET}"
    exit 1
fi
sleep 0.3
if ! tmux send-keys -t "$PANE_TARGET" Enter; then
    log "ERROR: Failed to send Enter to pane ${PANE_TARGET}"
    exit 1
fi

# Step 6: tmux pane metadata 更新（CLI 起動成功後のみ）
DISPLAY_NAME=$(get_model_display_name "$AGENT_ID")
update_pane_metadata "$PANE_TARGET" "$TARGET_CLI_TYPE" "$DISPLAY_NAME"

log "=== CLI switch complete: ${AGENT_ID} → ${TARGET_CLI_TYPE}/${TARGET_MODEL} (${DISPLAY_NAME}) ==="
echo "OK: ${AGENT_ID} → ${TARGET_CLI_TYPE}/${TARGET_MODEL}"
