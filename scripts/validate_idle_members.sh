#!/usr/bin/env bash
# validate_idle_members.sh -- dashboard.yaml idle_members 含有チェック
# Usage: bash scripts/validate_idle_members.sh [--mode check|strict] [--dry-run]
# Exit codes: 0=PASS/WARN(check), 1=CRITICAL(strict), 2=ERROR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETTINGS_FILE="${PROJECT_ROOT}/config/settings.yaml"
DASHBOARD_FILE="${PROJECT_ROOT}/dashboard.yaml"

MODE="check"
DRY_RUN=false

usage() {
  echo "Usage: bash scripts/validate_idle_members.sh [--mode check|strict] [--dry-run]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ $# -lt 2 ]]; then
        echo "[validate_idle_members] ERROR: --mode requires check|strict" >&2
        usage
        exit 2
      fi
      MODE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[validate_idle_members] ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$MODE" != "check" && "$MODE" != "strict" ]]; then
  echo "[validate_idle_members] ERROR: invalid --mode '$MODE' (expected check|strict)" >&2
  exit 2
fi

if [[ ! -f "$DASHBOARD_FILE" ]]; then
  echo "[validate_idle_members] ERROR: not found: $DASHBOARD_FILE" >&2
  exit 2
fi

# settings.yaml から expected members を抽出 (karo.idle_member_names)。
# settings.yaml が唯一の SoT (source of truth)。不在 or 未定義時は ERROR + exit 1。
read_expected_members() {
  local parsed=""
  if [[ -f "$SETTINGS_FILE" ]]; then
    parsed="$(awk '
      /^karo:/ { in_karo=1; next }
      in_karo && /^[^[:space:]]/ { in_karo=0 }
      in_karo && /^  idle_member_names:/ { in_idle=1; next }
      in_idle && /^  [^[:space:]-]/ { in_idle=0 }
      in_idle && /^    - / {
        sub(/^    - /, "", $0)
        print $0
      }
    ' "$SETTINGS_FILE")"
  fi

  if [[ -n "$parsed" ]]; then
    printf '%s\n' "$parsed"
    return 0
  fi

  echo "[validate_idle_members] ERROR: config/settings.yaml の karo.idle_member_names が未定義" >&2
  echo "[validate_idle_members] ERROR: settings.yaml を確認し idle_member_names を設定せよ" >&2
  return 1
}

read_dashboard_members() {
  awk '
    /^idle_members:/ { in_idle=1; next }
    in_idle && /^[A-Za-z_][A-Za-z0-9_]*:/ { in_idle=0 }
    in_idle && /^  name:/ {
      sub(/^  name:[[:space:]]*/, "", $0)
      gsub(/^"|"$/, "", $0)
      print $0
    }
  ' "$DASHBOARD_FILE"
}

EXPECTED_MEMBERS_RAW=""
if ! EXPECTED_MEMBERS_RAW="$(read_expected_members)"; then
  exit 1
fi
mapfile -t EXPECTED_MEMBERS <<< "$EXPECTED_MEMBERS_RAW"
mapfile -t DASHBOARD_MEMBERS < <(read_dashboard_members)

if [[ ${#EXPECTED_MEMBERS[@]} -eq 0 ]]; then
  echo "[validate_idle_members] ERROR: expected member list is empty" >&2
  exit 2
fi

missing=()
for expected in "${EXPECTED_MEMBERS[@]}"; do
  found=false
  for actual in "${DASHBOARD_MEMBERS[@]}"; do
    if [[ "$actual" == "$expected" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == false ]]; then
    missing+=("$expected")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "[validate_idle_members] OK: 全${#EXPECTED_MEMBERS[@]}体確認済み"
  exit 0
fi

if [[ "$MODE" == "strict" ]]; then
  printf '[validate_idle_members] CRITICAL: %d体不在 -- %s\n' "${#missing[@]}" "$(IFS=', '; echo "${missing[*]}")" >&2
  exit 1
fi

for member in "${missing[@]}"; do
  echo "[validate_idle_members] WARN: ${member} が idle_members に不在" >&2
done

echo "[validate_idle_members] WARN: ${#missing[@]}体不在 (mode=check, dry_run=${DRY_RUN})" >&2
exit 0
