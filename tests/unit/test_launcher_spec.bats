#!/usr/bin/env bats
# tests/unit/test_launcher_spec.bats
# cmd_730 δ-B: launcher spec consistency BATS wrapper
#
# CI/手動どちらでも呼べる wrapper。
# 実体は tests/smoke/launcher_spec_consistency.sh
# 各 T グループを独立した @test として実行し、SKIP=0 を保証。

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SMOKE_SCRIPT="${PROJECT_ROOT}/tests/smoke/launcher_spec_consistency.sh"
    export SETTINGS_FILE="${PROJECT_ROOT}/config/settings.yaml"
    if [[ -x "${PROJECT_ROOT}/.venv/bin/python3" ]]; then
        export PYTHON_BIN="${PROJECT_ROOT}/.venv/bin/python3"
    else
        export PYTHON_BIN="python3"
    fi
}

# ─── T1: shu canonical spec ───────────────────────────────────────
@test "T1-syntax: shutsujin_departure.sh bash -n PASS" {
    run bash -n "${PROJECT_ROOT}/shutsujin_departure.sh"
    [ "$status" -eq 0 ]
}

@test "T1-yaml: settings.yaml parses without error" {
    run "$PYTHON_BIN" -c "
import yaml
with open('${SETTINGS_FILE}') as f:
    d = yaml.safe_load(f)
assert d is not None
"
    [ "$status" -eq 0 ]
}

@test "T1-baseline: settings.yaml canonical agent models match expected" {
    run "$PYTHON_BIN" -c "
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
    print('\n'.join(errors))
    sys.exit(1)
"
    [ "$status" -eq 0 ]
}

@test "T1-hybrid: formations.hybrid ash6-7 = codex/gpt-5.5 (immutable)" {
    run "$PYTHON_BIN" -c "
import yaml, sys
with open('${SETTINGS_FILE}') as f:
    d = yaml.safe_load(f)
hybrid = d.get('formations', {}).get('hybrid', {}).get('agents', {})
for agent in ('ashigaru6', 'ashigaru7'):
    cfg = hybrid.get(agent, {})
    assert cfg.get('cli_type') == 'codex', f'{agent} cli_type={cfg.get(\"cli_type\")}'
    assert cfg.get('model') == 'gpt-5.5',  f'{agent} model={cfg.get(\"model\")}'
"
    [ "$status" -eq 0 ]
}

# ─── T2: shk all-opus (KESSEN_MODE) ──────────────────────────────
@test "T2-kessen-flag: --kessen flag defined in shutsujin_departure.sh" {
    grep -qE '\-k\|--kessen' "${PROJECT_ROOT}/shutsujin_departure.sh"
}

@test "T2-kessen-opus-cmd: KESSEN_MODE karo/ashigaru claude-opus-4-7 command present" {
    grep -q "CLAUDE_CODE_EFFORT_LEVEL=max claude --model claude-opus-4-7" \
        "${PROJECT_ROOT}/shutsujin_departure.sh"
}

@test "T2-kessen-karo-cli: KESSEN_MODE _karo_cli_type=claude explicitly set (BETA-6)" {
    grep -q '_karo_cli_type="claude"' "${PROJECT_ROOT}/shutsujin_departure.sh"
}

@test "T2-kessen-hybrid-mutex: KESSEN and HYBRID are mutually exclusive" {
    grep -qE "KESSEN_MODE.*HYBRID_MODE|HYBRID_MODE.*KESSEN_MODE" \
        "${PROJECT_ROOT}/shutsujin_departure.sh"
}

# ─── T3: shx ash6-7 codex/xhigh (HYBRID_MODE) ───────────────────
@test "T3-hybrid-flag: --hybrid flag defined in shutsujin_departure.sh" {
    grep -qE '\-H\|--hybrid' "${PROJECT_ROOT}/shutsujin_departure.sh"
}

@test "T3-hybrid-codex: shx ash6-7 codex/gpt-5.5/xhigh runtime overlay present" {
    grep -q "codex --model gpt-5.5 --reasoning-effort xhigh" \
        "${PROJECT_ROOT}/shutsujin_departure.sh"
}

@test "T3-beta4: shc deploy --settings-only removed from shutsujin_departure.sh (BETA-4)" {
    run grep -c 'scripts/shc.sh deploy.*--settings-only' \
        "${PROJECT_ROOT}/shutsujin_departure.sh"
    # grep -c は 0件でも "0" を出力し exit 1 するので status は気にしない
    [ "${output}" = "0" ]
}

@test "T3-no-yaml-write: shutsujin_departure.sh has no direct settings.yaml write" {
    run grep -cE "open.*settings\.yaml.*'w'|yaml\.safe_dump.*settings|> *config/settings\.yaml" \
        "${PROJECT_ROOT}/shutsujin_departure.sh"
    [ "${output}" = "0" ]
}

# ─── T4: shp transient (settings.yaml immutability) ──────────────
@test "T4-syntax: scripts/shp.sh bash -n PASS" {
    run bash -n "${PROJECT_ROOT}/scripts/shp.sh"
    [ "$status" -eq 0 ]
}

@test "T4-persist-flag: --persist flag exists in shp.sh (explicit persist-only design)" {
    grep -q "\-\-persist" "${PROJECT_ROOT}/scripts/shp.sh"
}

@test "T4-dry-run-immutable: settings.yaml hash unchanged after shp 1 --dry-run --yes" {
    local hash_before hash_after
    hash_before=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
    run bash "${PROJECT_ROOT}/scripts/shp.sh" 1 --dry-run --yes
    hash_after=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
    [ "$hash_before" = "$hash_after" ]
}

# ─── T5: shx/shu cycle invariance ────────────────────────────────
@test "T5-no-shu-settings-write: shutsujin_departure.sh has no settings.yaml write path" {
    run grep -cE "open.*settings\.yaml.*'w'|yaml\.safe_dump.*settings|> *config/settings\.yaml" \
        "${PROJECT_ROOT}/shutsujin_departure.sh"
    [ "${output}" = "0" ]
}

@test "T5-shc-syntax: scripts/shc.sh bash -n PASS" {
    run bash -n "${PROJECT_ROOT}/scripts/shc.sh"
    [ "$status" -eq 0 ]
}

# ─── T8: shp 10×3 matrix dry-run ─────────────────────────────────
@test "T8-sonnet-matrix: shp all-Sonnet dry-run produces 10 DRY-RUN lines" {
    run bash "${PROJECT_ROOT}/scripts/shp.sh" 1 --dry-run --yes
    local count
    count=$(echo "$output" | grep -c '\[DRY-RUN\].*transient')
    [ "$count" -ge 10 ]
}

@test "T8-opus-matrix: shp all-Opus dry-run produces 10 DRY-RUN lines" {
    run bash "${PROJECT_ROOT}/scripts/shp.sh" 2 --dry-run --yes
    local count
    count=$(echo "$output" | grep -c '\[DRY-RUN\].*transient')
    [ "$count" -ge 10 ]
}

@test "T8-codex-matrix: shp all-Codex dry-run produces 10 DRY-RUN lines" {
    run bash "${PROJECT_ROOT}/scripts/shp.sh" 3 --dry-run --yes
    local count
    count=$(echo "$output" | grep -c '\[DRY-RUN\].*transient')
    [ "$count" -ge 10 ]
}

@test "T8-matrix-hash: settings.yaml unchanged after all 3 matrix dry-runs" {
    local hash_before hash_after
    hash_before=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
    bash "${PROJECT_ROOT}/scripts/shp.sh" 1 --dry-run --yes > /dev/null 2>&1
    bash "${PROJECT_ROOT}/scripts/shp.sh" 2 --dry-run --yes > /dev/null 2>&1
    bash "${PROJECT_ROOT}/scripts/shp.sh" 3 --dry-run --yes > /dev/null 2>&1
    hash_after=$(sha256sum "${SETTINGS_FILE}" | awk '{print $1}')
    [ "$hash_before" = "$hash_after" ]
}

# ─── smoke スクリプト全体実行 ─────────────────────────────────────
@test "smoke-script-syntax: tests/smoke/launcher_spec_consistency.sh bash -n PASS" {
    run bash -n "${SMOKE_SCRIPT}"
    [ "$status" -eq 0 ]
}

@test "smoke-full-run: tests/smoke/launcher_spec_consistency.sh PASS" {
    run bash "${SMOKE_SCRIPT}"
    [ "$status" -eq 0 ]
}
