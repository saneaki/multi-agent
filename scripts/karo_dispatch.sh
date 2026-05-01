#!/usr/bin/env bash
# karo_dispatch.sh — karo が ashigaru/gunshi にタスクを dispatch する際の一括ヘルパー
#
# 機能:
#   1. task YAML の存在確認 + status: assigned 確認
#   2. dashboard.yaml に in_progress エントリを追加
#   3. python3 scripts/generate_dashboard_md.py を実行
#   4. bash scripts/inbox_write.sh でエージェントに通知
#   5. 完了ログ出力
#
# 使用例:
#   bash scripts/karo_dispatch.sh \
#     --agent ashigaru3 \
#     --task-yaml queue/tasks/ashigaru3.yaml \
#     --cmd cmd_620 \
#     --content "[Scope C] round-trip test 実装" \
#     --assignee "足軽3号(Sonnet+T)"
#
#   # dry-run モード:
#   bash scripts/karo_dispatch.sh \
#     --agent ashigaru3 \
#     --task-yaml queue/tasks/ashigaru3.yaml \
#     --cmd cmd_620 \
#     --content "[Scope C] round-trip test 実装" \
#     --assignee "足軽3号(Sonnet+T)" \
#     --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── デフォルト値 ──────────────────────────────────────────────
AGENT=""
TASK_YAML=""
CMD_ID=""
CONTENT=""
ASSIGNEE=""
DRY_RUN=false
INBOX_MSG=""  # オプション: カスタムメッセージ (省略時は自動生成)

# ── 引数パース ────────────────────────────────────────────────
usage() {
    cat >&2 <<EOF
Usage: bash scripts/karo_dispatch.sh \\
    --agent <name> \\
    --task-yaml <path> \\
    --cmd <cmd_id> \\
    --content <description> \\
    --assignee <label> \\
    [--message <inbox_message>] \\
    [--dry-run]

必須引数:
  --agent     対象 agent (ashigaru1-8, gunshi)
  --task-yaml task YAML のパス (既に書込み済み前提)
  --cmd       cmd 番号 (例: cmd_620)
  --content   in_progress に表示する作業内容
  --assignee  担当者表示ラベル (例: 足軽3号(Sonnet+T))

オプション:
  --message   inbox に送る本文 (省略時は task YAML の title から自動生成)
  --dry-run   実際には何もせず、実行予定の処理を表示
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)     AGENT="$2";     shift 2 ;;
        --task-yaml) TASK_YAML="$2"; shift 2 ;;
        --cmd)       CMD_ID="$2";    shift 2 ;;
        --content)   CONTENT="$2";   shift 2 ;;
        --assignee)  ASSIGNEE="$2";  shift 2 ;;
        --message)   INBOX_MSG="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=true;   shift   ;;
        --help|-h)   usage ;;
        *)
            echo "[ERROR] Unknown argument: $1" >&2
            usage
            ;;
    esac
done

# ── 必須引数チェック ─────────────────────────────────────────
for var_name in AGENT TASK_YAML CMD_ID CONTENT ASSIGNEE; do
    if [[ -z "${!var_name}" ]]; then
        echo "[ERROR] --${var_name,,} is required" >&2
        usage
    fi
done

# ── パス解決 ─────────────────────────────────────────────────
# task-yaml が相対パスの場合は SCRIPT_DIR (repo root) からの相対として解決
if [[ "$TASK_YAML" != /* ]]; then
    TASK_YAML="$SCRIPT_DIR/$TASK_YAML"
fi

DASHBOARD_YAML="$SCRIPT_DIR/dashboard.yaml"
GENERATE_SCRIPT="$SCRIPT_DIR/scripts/generate_dashboard_md.py"
INBOX_SCRIPT="$SCRIPT_DIR/scripts/inbox_write.sh"
PYTHON="$SCRIPT_DIR/.venv/bin/python3"

# python3 フォールバック
if [[ ! -x "$PYTHON" ]]; then
    PYTHON="python3"
fi

# ── ヘルパー: dry-run 対応コマンド実行 ──────────────────────
run_cmd() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  karo_dispatch.sh${DRY_RUN:+ [DRY-RUN MODE]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  agent     : $AGENT"
echo "  task-yaml : $TASK_YAML"
echo "  cmd       : $CMD_ID"
echo "  content   : $CONTENT"
echo "  assignee  : $ASSIGNEE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Step 1: task YAML 存在確認 + status 確認 ─────────────────
echo ""
echo "[Step 1] task YAML 確認: $TASK_YAML"

if [[ ! -f "$TASK_YAML" ]]; then
    echo "[ERROR] task YAML が存在しません: $TASK_YAML" >&2
    exit 1
fi

TASK_STATUS=$("$PYTHON" -c "
import yaml, sys
with open('$TASK_YAML') as f:
    d = yaml.safe_load(f)
print(d.get('status', ''))
" 2>/dev/null || echo "")

TASK_ID=$("$PYTHON" -c "
import yaml, sys
with open('$TASK_YAML') as f:
    d = yaml.safe_load(f)
print(d.get('task_id', ''))
" 2>/dev/null || echo "")

TASK_TITLE=$("$PYTHON" -c "
import yaml, sys
with open('$TASK_YAML') as f:
    d = yaml.safe_load(f)
print(d.get('title', ''))
" 2>/dev/null || echo "")

echo "  task_id : $TASK_ID"
echo "  status  : $TASK_STATUS"
echo "  title   : $TASK_TITLE"

if [[ "$TASK_STATUS" != "assigned" ]]; then
    echo "[WARNING] task YAML の status が 'assigned' ではありません (現在: '$TASK_STATUS')。続行します。" >&2
else
    echo "  → status: assigned 確認 OK"
fi

# ── Step 2: dashboard.yaml に in_progress エントリを追加 ─────
echo ""
echo "[Step 2] dashboard.yaml に in_progress エントリを追加"
echo "  追加内容: cmd=$CMD_ID, content=$CONTENT, assignee=$ASSIGNEE"

if $DRY_RUN; then
    echo "[DRY-RUN] dashboard.yaml への書き込みをスキップ"
    echo "[DRY-RUN] 追加予定エントリ:"
    echo "[DRY-RUN]   - cmd: $CMD_ID"
    echo "[DRY-RUN]     content: $CONTENT"
    echo "[DRY-RUN]     status: 🔄 進行中"
    echo "[DRY-RUN]     assignee: $ASSIGNEE"
else
    if [[ ! -f "$DASHBOARD_YAML" ]]; then
        echo "[ERROR] dashboard.yaml が存在しません: $DASHBOARD_YAML" >&2
        exit 1
    fi

    "$PYTHON" - <<PYEOF
import yaml, sys, tempfile, os

dashboard_path = '$DASHBOARD_YAML'

with open(dashboard_path, 'r') as f:
    data = yaml.safe_load(f)

if data is None:
    data = {}

# in_progress リストを初期化 (なければ作成)
if 'in_progress' not in data or data['in_progress'] is None:
    data['in_progress'] = []

# 同一エントリの重複チェック (cmd + content + assignee が全一致の場合スキップ)
existing = data['in_progress']
for entry in existing:
    if (entry.get('cmd') == '$CMD_ID'
            and entry.get('content') == '$CONTENT'
            and entry.get('assignee') == '$ASSIGNEE'):
        print('[WARNING] 同一エントリが既に存在します。重複追加をスキップします。', file=sys.stderr)
        sys.exit(0)

new_entry = {
    'cmd': '$CMD_ID',
    'content': '$CONTENT',
    'status': '🔄 進行中',
    'assignee': '$ASSIGNEE',
}
data['in_progress'].append(new_entry)

# アトミック書き込み
tmp_fd, tmp_path = tempfile.mkstemp(
    dir=os.path.dirname(dashboard_path), suffix='.tmp'
)
try:
    with os.fdopen(tmp_fd, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
    os.replace(tmp_path, dashboard_path)
except Exception:
    os.unlink(tmp_path)
    raise

print(f'  → in_progress エントリ追加完了 (合計 {len(data["in_progress"])} 件)')
PYEOF
fi

# ── Step 3: dashboard.md を再生成 ────────────────────────────
echo ""
echo "[Step 3] dashboard.md 再生成"

if [[ ! -f "$GENERATE_SCRIPT" ]]; then
    echo "[ERROR] generate_dashboard_md.py が見つかりません: $GENERATE_SCRIPT" >&2
    exit 1
fi

if $DRY_RUN; then
    echo "[DRY-RUN] python3 $GENERATE_SCRIPT"
else
    if ! "$PYTHON" "$GENERATE_SCRIPT"; then
        echo "[ERROR] generate_dashboard_md.py の実行に失敗しました" >&2
        exit 1
    fi
    echo "  → dashboard.md 再生成完了"
fi

# ── Step 4: inbox_write.sh でエージェントに通知 ─────────────
echo ""
echo "[Step 4] inbox_write.sh → $AGENT"

# メッセージ生成 (--message 省略時は自動生成)
if [[ -z "$INBOX_MSG" ]]; then
    INBOX_MSG="【task_assigned: ${TASK_ID:-$CMD_ID}】${TASK_TITLE:+$TASK_TITLE。}queue/tasks/${AGENT}.yaml 参照。完了後 karo inbox へ task_completed を報告せよ。"
fi

echo "  message: $INBOX_MSG"

if [[ ! -f "$INBOX_SCRIPT" ]]; then
    echo "[ERROR] inbox_write.sh が見つかりません: $INBOX_SCRIPT" >&2
    exit 1
fi

run_cmd bash "$INBOX_SCRIPT" "$AGENT" "$INBOX_MSG" task_assigned karo

echo "  → inbox_write 完了"

# ── Step 5: 完了ログ ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if $DRY_RUN; then
    echo "  [DRY-RUN] dispatch シミュレーション完了"
    echo "  実際の dispatch を行うには --dry-run を除いて再実行してください"
else
    echo "  dispatch 完了 ✅"
    echo "  agent    : $AGENT"
    echo "  task_id  : ${TASK_ID:-N/A}"
    echo "  cmd      : $CMD_ID"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
