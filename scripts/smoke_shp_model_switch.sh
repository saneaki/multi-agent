#!/usr/bin/env bash
# Smoke test for shp model switching without touching live settings.yaml or panes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts" "$TMP_DIR/config" "$TMP_DIR/lib" "$TMP_DIR/logs"
cp "$ROOT_DIR/scripts/shp.sh" "$TMP_DIR/scripts/shp.sh"
cp "$ROOT_DIR/config/settings.yaml" "$TMP_DIR/config/settings.yaml"
cp "$ROOT_DIR/lib/cli_adapter.sh" "$TMP_DIR/lib/cli_adapter.sh"

cat > "$TMP_DIR/scripts/switch_cli.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
echo "$1" >> "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs/fake_switch_calls.log"
echo "OK: fake switch $1"
EOS
chmod +x "$TMP_DIR/scripts/switch_cli.sh"

formations_before="$TMP_DIR/formations.before.json"
formations_after="$TMP_DIR/formations.after.json"

python3 - "$TMP_DIR/config/settings.yaml" "$formations_before" <<'PY'
import json
import sys
import yaml

settings_path, out_path = sys.argv[1:3]
with open(settings_path, encoding="utf-8") as f:
    cfg = yaml.safe_load(f) or {}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(cfg.get("formations", {}), f, sort_keys=True, ensure_ascii=False)
PY

(
    cd "$TMP_DIR"
    bash scripts/shp.sh 1 1 1 1 1 1 1 1 2 3 --yes > logs/shp.out
)

python3 - "$TMP_DIR/config/settings.yaml" "$formations_after" <<'PY'
import json
import sys
import yaml

settings_path, out_path = sys.argv[1:3]
with open(settings_path, encoding="utf-8") as f:
    cfg = yaml.safe_load(f) or {}

agents = cfg.get("cli", {}).get("agents", {})
assert agents["shogun"]["cli_type"] == "claude", agents["shogun"]
assert agents["shogun"]["model"] == "claude-sonnet-4-6", agents["shogun"]
assert agents["ashigaru7"]["cli_type"] == "claude", agents["ashigaru7"]
assert agents["ashigaru7"]["model"] == "claude-opus-4-7", agents["ashigaru7"]
assert agents["gunshi"]["cli_type"] == "codex", agents["gunshi"]
assert agents["gunshi"]["model"] == "gpt-5.5", agents["gunshi"]

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(cfg.get("formations", {}), f, sort_keys=True, ensure_ascii=False)
PY

cmp -s "$formations_before" "$formations_after"
grep -qx "shogun" "$TMP_DIR/logs/fake_switch_calls.log"
grep -qx "ashigaru7" "$TMP_DIR/logs/fake_switch_calls.log"
test "$(wc -l < "$TMP_DIR/logs/fake_switch_calls.log")" -eq 10

echo "PASS: shp shogun selection, ashigaru7 model update, and formations immutability verified"
