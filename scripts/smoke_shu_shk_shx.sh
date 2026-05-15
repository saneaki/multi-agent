#!/usr/bin/env bash
# Non-destructive startup smoke for shu/shk/shx aliases.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/shutsujin_departure.sh"
SMOKE_ID="shu-shk-shx-smoke-$$"
TMUX_CMD="tmux -L ${SMOKE_ID} -f /dev/null"
TMP_DIR="$(mktemp -d)"

cleanup() {
    if ${TMUX_CMD} kill-server >/dev/null 2>&1; then
        :
    fi
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

run_case() {
    local name="$1"
    shift
    local log_path="${TMP_DIR}/${name}.log"

    if SHOGUN_TMUX="${TMUX_CMD}" bash "${SCRIPT}" "$@" >"${log_path}" 2>&1; then
        printf 'PASS %s\n' "${name}"
    else
        printf 'FAIL %s\n' "${name}"
        sed -n '1,160p' "${log_path}"
        return 1
    fi
}

if ! command -v tmux >/dev/null 2>&1; then
    echo "FAIL preflight: tmux not found"
    exit 1
fi

if ! bash -n "${SCRIPT}"; then
    echo "FAIL preflight: shutsujin_departure.sh syntax"
    exit 1
fi

run_case help --help
run_case shu_setup --setup-only
run_case shk_setup --kessen --setup-only
run_case shx_setup --hybrid --setup-only

echo "PASS smoke_shu_shk_shx"
