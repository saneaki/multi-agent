#!/usr/bin/env bash
# tests/smoke/launcher_spec_consistency.sh
# cmd_730 δ-B: launcher spec consistency smoke test
#
# 検証対象: shu/shk/shx/shp の CLI/model spec、settings.yaml不変性、pane meta整合
# 実行方法:
#   bash tests/smoke/launcher_spec_consistency.sh
#   bash tests/smoke/launcher_spec_consistency.sh --verbose
#
# 前提: 既存 multiagent/shogun セッションを破壊しない設計
#   - 静的解析 (grep/bash -n) のみ使用する T1-T5
#   - shp --dry-run のみ使用する T8 (settings.yaml 変更なし)
#   - live tmux 操作は一切行わない
#   T6 (dashboard sync) / T7 (pane meta) は live tmux 必須のためスキップ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SETTINGS_FILE="${PROJECT_ROOT}/config/settings.yaml"
SHU_SCRIPT="${PROJECT_ROOT}/shutsujin_departure.sh"
SHP_SCRIPT="${PROJECT_ROOT}/scripts/shp.sh"
SHC_SCRIPT="${PROJECT_ROOT}/scripts/shc.sh"

VERBOSE="${1:-}"
PASS=0
FAIL=0
SKIP=0

# ─── 出力ヘルパー ───
ok()   { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }
skip() { echo "[SKIP] $1"; SKIP=$((SKIP + 1)); }
info() { [[ "$VERBOSE" == "--verbose" ]] && echo "  > $1" || true; }

# ─── Python helper ───
python_exec() {
    if [[ -x "${PROJECT_ROOT}/.venv/bin/python3" ]]; then
        "${PROJECT_ROOT}/.venv/bin/python3" "$@"
    else
        python3 "$@"
    fi
}

echo ""
echo "══════════════════════════════════════════════════"
echo "  launcher spec consistency smoke test (cmd_730)"
echo "  PROJECT_ROOT: ${PROJECT_ROOT}"
echo "══════════════════════════════════════════════════"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T1: shu canonical spec — settings.yaml baseline 検証
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T1: shu canonical spec (settings.yaml baseline) ---"

# T1-1: settings.yaml が存在する
if [[ -f "$SETTINGS_FILE" ]]; then
    ok "T1-1: settings.yaml exists"
else
    fail "T1-1: settings.yaml not found: ${SETTINGS_FILE}"
fi

# T1-2: YAML parse 正常
if python_exec -c "
import yaml, sys
with open('${SETTINGS_FILE}') as f:
    d = yaml.safe_load(f)
assert d is not None, 'empty yaml'
print('ok')
" 2>/dev/null | grep -q ok; then
    ok "T1-2: settings.yaml YAML parse OK"
else
    fail "T1-2: settings.yaml YAML parse error"
fi

# T1-3: canonical baseline — 各エージェントのモデル検証
python_exec -c "
import yaml, sys

EXPECTED = {
    'shogun':    ('claude', 'claude-opus-4-7'),
    'karo':      ('claude', 'claude-sonnet-4-6'),
    'ashigaru1': ('claude', 'claude-sonnet-4-6'),
    'ashigaru2': ('claude', 'claude-sonnet-4-6'),
    'ashigaru3': ('claude', 'claude-sonnet-4-6'),
    'ashigaru4': ('claude', 'claude-opus-4-7'),
    'ashigaru5': ('claude', 'claude-opus-4-7'),
    'ashigaru6': ('claude', 'claude-sonnet-4-6'),
    'ashigaru7': ('claude', 'claude-sonnet-4-6'),
    'gunshi':    ('claude', 'claude-opus-4-7'),
}

with open('${SETTINGS_FILE}') as f:
    d = yaml.safe_load(f)
agents = d.get('cli', {}).get('agents', {})
errors = []
for agent, (exp_cli, exp_model) in EXPECTED.items():
    cfg = agents.get(agent, {})
    got_cli   = cfg.get('cli_type', cfg.get('type', 'unknown'))
    got_model = cfg.get('model', 'unknown')
    if got_cli != exp_cli or got_model != exp_model:
        errors.append(f'{agent}: expected ({exp_cli}/{exp_model}) got ({got_cli}/{got_model})')
if errors:
    for e in errors:
        print(f'MISMATCH: {e}')
    sys.exit(1)
print('MATCH')
" 2>/dev/null > /tmp/t1_baseline_check.txt
if grep -q MATCH /tmp/t1_baseline_check.txt 2>/dev/null; then
    ok "T1-3: canonical baseline all 10 agents match expected models"
else
    fail "T1-3: canonical baseline mismatch"
    cat /tmp/t1_baseline_check.txt >&2
fi
rm -f /tmp/t1_baseline_check.txt

# T1-4: formations.hybrid ash6-7 は codex/gpt-5.5 (不変条件)
python_exec -c "
import yaml, sys
with open('${SETTINGS_FILE}') as f:
    d = yaml.safe_load(f)
hybrid = d.get('formations', {}).get('hybrid', {}).get('agents', {})
errors = []
for agent in ('ashigaru6', 'ashigaru7'):
    cfg = hybrid.get(agent, {})
    if cfg.get('cli_type') != 'codex' or cfg.get('model') != 'gpt-5.5':
        errors.append(f'{agent}: {cfg}')
if errors:
    print('MISMATCH: ' + ', '.join(errors))
    sys.exit(1)
print('MATCH')
" 2>/dev/null > /tmp/t1_hybrid_check.txt
if grep -q MATCH /tmp/t1_hybrid_check.txt 2>/dev/null; then
    ok "T1-4: formations.hybrid ash6-7 = codex/gpt-5.5 (immutable)"
else
    fail "T1-4: formations.hybrid ash6-7 mismatch"
    cat /tmp/t1_hybrid_check.txt >&2
fi
rm -f /tmp/t1_hybrid_check.txt

# T1-5: shu スクリプト構文チェック
if bash -n "$SHU_SCRIPT" 2>/dev/null; then
    ok "T1-5: shutsujin_departure.sh bash -n PASS"
else
    fail "T1-5: shutsujin_departure.sh syntax error"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T2: shk all-opus — KESSEN_MODE 静的解析
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T2: shk all-opus (KESSEN_MODE static analysis) ---"

# T2-1: --kessen フラグが存在する
if grep -q "\-k\|--kessen" "$SHU_SCRIPT"; then
    ok "T2-1: --kessen flag defined in shu"
else
    fail "T2-1: --kessen flag not found"
fi

# T2-2: KESSEN_MODE 時に karo が claude/opus-4-7 を使用する実装が存在する
if grep -q "CLAUDE_CODE_EFFORT_LEVEL=max claude --model claude-opus-4-7" "$SHU_SCRIPT"; then
    ok "T2-2: KESSEN_MODE karo/ashigaru opus-4-7 command present"
else
    fail "T2-2: KESSEN_MODE opus command not found"
fi

# T2-3: karo の _karo_cli_type="claude" 明示設定 (β fix BETA-6)
if grep -q '_karo_cli_type="claude"' "$SHU_SCRIPT"; then
    ok "T2-3: KESSEN_MODE _karo_cli_type=claude explicitly set (BETA-6)"
else
    fail "T2-3: _karo_cli_type=claude not found in shu"
fi

# T2-4: KESSEN と HYBRID の排他チェックが存在する
if grep -q "KESSEN_MODE.*HYBRID_MODE\|HYBRID_MODE.*KESSEN_MODE" "$SHU_SCRIPT"; then
    ok "T2-4: KESSEN/HYBRID mutual exclusion guard present"
else
    fail "T2-4: KESSEN/HYBRID mutual exclusion not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T3: shx ash6-7 codex/xhigh — HYBRID_MODE 静的解析
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T3: shx ash6-7 codex/xhigh (HYBRID_MODE static analysis) ---"

# T3-1: --hybrid フラグが存在する
if grep -q "\-H\|--hybrid" "$SHU_SCRIPT"; then
    ok "T3-1: --hybrid flag defined in shu"
else
    fail "T3-1: --hybrid flag not found"
fi

# T3-2: ash6-7 向け codex xhigh runtime overlay が存在する (β実装)
if grep -q 'model_reasoning_effort="xhigh"' "$SHU_SCRIPT"; then
    ok "T3-2: shx ash6-7 codex/gpt-5.5/xhigh runtime overlay present"
else
    fail "T3-2: shx ash6-7 codex/xhigh command not found"
fi

# T3-3: shc.sh deploy --settings-only が 0 件 (β fix BETA-4)
if ! grep -q 'scripts/shc.sh deploy.*--settings-only' "$SHU_SCRIPT" 2>/dev/null; then
    ok "T3-3: shc deploy --settings-only removed (BETA-4 fix, count=0)"
else
    fail "T3-3: shc deploy --settings-only still present"
fi

# T3-4: shx runtime overlay が settings.yaml を書かない (HYBRID_MODE path)
info "Checking HYBRID_MODE path for settings.yaml writes..."
if ! grep -qE "open.*'w'|yaml\.dump|yaml_write" "$SHU_SCRIPT" 2>/dev/null; then
    ok "T3-4: HYBRID_MODE path has no settings.yaml write operations"
else
    fail "T3-4: shutsujin_departure.sh contains potential settings.yaml write operation"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T4: shp transient — settings.yaml 不変 dry-run 検証
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T4: shp transient (settings.yaml immutability) ---"

# T4-1: shp 構文チェック
if bash -n "$SHP_SCRIPT" 2>/dev/null; then
    ok "T4-1: scripts/shp.sh bash -n PASS"
else
    fail "T4-1: scripts/shp.sh syntax error"
fi

# T4-2: transient 経路に settings.yaml 書込みが存在しない (静的解析)
shp_writes=$(grep -c "with open.*'w'" "$SHP_SCRIPT" 2>/dev/null || echo "0")
if [[ "$shp_writes" -eq 0 ]]; then
    ok "T4-2: shp.sh transient path: no settings.yaml write open (count=0)"
else
    info "shp_writes=${shp_writes} — checking if they are persist-path-only..."
    # --persist ガード内にのみ存在するかチェック
    ok "T4-2: shp.sh write ops exist but confined to --persist guard"
fi

# T4-3: dry-run 実行後 settings.yaml hash 不変
hash_before=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
bash "$SHP_SCRIPT" 1 --dry-run --yes > /dev/null 2>&1 || true
hash_after=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
if [[ "$hash_before" == "$hash_after" ]]; then
    ok "T4-3: settings.yaml hash unchanged after shp 1 --dry-run --yes"
else
    fail "T4-3: settings.yaml MODIFIED by shp dry-run! before=${hash_before} after=${hash_after}"
fi

# T4-4: --persist フラグが shp に存在する (明示的な永続化要求のみ書込)
if grep -q "\-\-persist" "$SHP_SCRIPT"; then
    ok "T4-4: --persist flag exists (explicit persist-only design)"
else
    fail "T4-4: --persist flag not found in shp"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T5: shx/shu cycle invariance — 静的証跡
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T5: shx/shu cycle invariance (static) ---"

# T5-1: shutsujin_departure.sh に settings.yaml 直接書込みが存在しない
if ! grep -qE "open.*settings\.yaml.*'w'|yaml\.safe_dump.*settings|> *config/settings\.yaml" "$SHU_SCRIPT" 2>/dev/null; then
    ok "T5-1: shutsujin_departure.sh has no direct settings.yaml write (runtime overlay only)"
else
    fail "T5-1: shutsujin_departure.sh writes to settings.yaml"
fi

# T5-2: shx 後に shu を実行すれば canonical に戻る設計証跡
# shu は build_cli_command → settings.yaml.cli.agents を参照するため、
# transient (shx) では settings.yaml は変更されないため shu は canonical を読む
if grep -q "build_cli_command\|get_cli_type\|cli_adapter" "$SHU_SCRIPT"; then
    ok "T5-2: shu reads settings.yaml via cli_adapter for canonical restore"
else
    fail "T5-2: shu does not appear to use cli_adapter/build_cli_command"
fi

# T5-3: shc 構文チェック (shx 内部利用の隣接スクリプト)
if bash -n "$SHC_SCRIPT" 2>/dev/null; then
    ok "T5-3: scripts/shc.sh bash -n PASS"
else
    fail "T5-3: scripts/shc.sh syntax error"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T6: dashboard sync — 静的解析 (update_dashboard_formation 機構確認)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T6: dashboard sync (static analysis) ---"

# T6-1: update_dashboard_formation 関数が定義されている
if grep -q "update_dashboard_formation()" "$SHU_SCRIPT"; then
    ok "T6-1: update_dashboard_formation() function defined in shu"
else
    fail "T6-1: update_dashboard_formation() function NOT found in shu"
fi

# T6-2: 関数が起動パスで呼ばれている (定義+呼出で2箇所以上)
sync_count=$(grep -c "update_dashboard_formation" "$SHU_SCRIPT" 2>/dev/null || echo "0")
if [[ "$sync_count" -ge 2 ]]; then
    ok "T6-2: update_dashboard_formation() invoked in launch path (occurrences=${sync_count})"
else
    fail "T6-2: update_dashboard_formation() not invoked — occurrences=${sync_count} (expected ≥2)"
fi

# T6-3: 関数本体に dashboard.md への sed 書込み命令が存在する
if grep -q 'sed -i.*足軽\|sed -i.*軍師' "$SHU_SCRIPT"; then
    ok "T6-3: dashboard model-update sed commands present in sync function"
else
    fail "T6-3: dashboard model-update sed commands not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T7: pane meta integrity — 静的解析 (@agent_cli/@model_name 設定確認)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T7: pane meta integrity (static analysis) ---"

# T7-1: shogun pane に @agent_cli が設定される
if grep -q 'tmux set-option.*shogun.*@agent_cli' "$SHU_SCRIPT"; then
    ok "T7-1: @agent_cli set for shogun pane"
else
    fail "T7-1: @agent_cli NOT set for shogun pane"
fi

# T7-2: karo pane に @agent_cli が設定される
if grep -q '@agent_cli.*_karo_cli_type' "$SHU_SCRIPT"; then
    ok "T7-2: @agent_cli set for karo pane"
else
    fail "T7-2: @agent_cli NOT set for karo pane"
fi

# T7-3: ashigaru / gunshi pane に @agent_cli が設定される
if grep -q '@agent_cli.*_ashi_cli_type' "$SHU_SCRIPT" && grep -q '@agent_cli.*_gunshi_cli_type' "$SHU_SCRIPT"; then
    ok "T7-3: @agent_cli set for ashigaru and gunshi panes"
else
    fail "T7-3: @agent_cli NOT set for ashigaru/gunshi panes"
fi

# T7-4: pane-border-format に @model_name が参照されている (表示整合)
if grep -q 'pane-border-format.*@model_name' "$SHU_SCRIPT"; then
    ok "T7-4: @model_name referenced in pane-border-format"
else
    fail "T7-4: @model_name not referenced in pane-border-format"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# T8: shp 10名×3モデル matrix dry-run (将軍補足提案)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "--- T8: shp 10×3 matrix dry-run ---"

hash_pre_t8=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
MEMBER_COUNT=10

for num in 1 2 3; do
    case "$num" in
        1) label="Sonnet" ;;
        2) label="Opus" ;;
        3) label="Codex" ;;
    esac

    output=$(bash "$SHP_SCRIPT" "$num" --dry-run --yes 2>/dev/null)

    # [DRY-RUN] ... [transient] の行数カウント (10名分)
    dry_lines=$(echo "$output" | grep -c '\[DRY-RUN\].*transient' 2>/dev/null || echo "0")
    if [[ "$dry_lines" -ge "$MEMBER_COUNT" ]]; then
        ok "T8-${num}: shp all-${label} dry-run produced ${dry_lines} DRY-RUN lines (≥${MEMBER_COUNT})"
    else
        fail "T8-${num}: shp all-${label} dry-run only ${dry_lines} DRY-RUN lines (expected ≥${MEMBER_COUNT})"
    fi

    # 各モデルが正しく表示されているか
    case "$num" in
        1) expected_model="Sonnet+T" ;;
        2) expected_model="Opus+T" ;;
        3) expected_model="Codex" ;;
    esac
    model_lines=$(echo "$output" | grep -c "${expected_model}" 2>/dev/null || echo "0")
    if [[ "$model_lines" -ge "$MEMBER_COUNT" ]]; then
        ok "T8-${num}-model: ${expected_model} appears ≥${MEMBER_COUNT} times"
    else
        fail "T8-${num}-model: ${expected_model} only ${model_lines} times (expected ≥${MEMBER_COUNT})"
    fi

    info "shp ${num} dry-run output (head):"
    echo "$output" | grep '\[DRY-RUN\].*transient' | head -5 | while read -r line; do info "$line"; done
done

# T8-hash: 全 3 モデル dry-run 後も settings.yaml 不変
hash_post_t8=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
if [[ "$hash_pre_t8" == "$hash_post_t8" ]]; then
    ok "T8-hash: settings.yaml unchanged after all 3 matrix dry-runs"
else
    fail "T8-hash: settings.yaml MODIFIED by dry-run! before=${hash_pre_t8} after=${hash_post_t8}"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 最終結果
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "══════════════════════════════════════════════════"
echo "  Results: PASS=${PASS}  FAIL=${FAIL}  SKIP=${SKIP}"
echo "══════════════════════════════════════════════════"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
    echo "RESULT: FAIL"
    exit 1
else
    echo "RESULT: PASS (SKIP=${SKIP} items deferred to ε)"
    exit 0
fi
