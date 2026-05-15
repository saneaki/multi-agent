#!/usr/bin/env bats

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    if [ -x "$PROJECT_ROOT/.venv/bin/python3" ]; then
        export PYTHON_BIN="$PROJECT_ROOT/.venv/bin/python3"
    else
        export PYTHON_BIN="${PYTHON_BIN:-python3}"
    fi
}

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "resolved dashboard tags are absent from active action_required but may remain archived" {
    local dashboard_yaml="$TEST_TMPDIR/dashboard.yaml"
    local dashboard_md="$TEST_TMPDIR/dashboard.md"
    local removed_tag="[cmd_716-dogfooding-consent]"

    cat > "$dashboard_yaml" <<'YAML'
action_required:
  - issue_id: still_active
    tag: "[cmd_712-phase-a-manual-verify]"
    title: "active item"
action_required_archive:
  - original:
      issue_id: cmd_716_dogfooding_consent
      tag: "[cmd_716-dogfooding-consent]"
      title: "resolved item"
observation_queue_archive:
  - tag: "[cmd_716-dogfooding-consent]"
    title: "historical observation"
YAML

    cat > "$dashboard_md" <<'MD'
# fixture dashboard

<!-- ACTION_REQUIRED:START -->
## 🚨 要対応 - 殿のご判断をお待ちしております

| タグ | 項目 | 詳細 |
|---|---|---|
| ⚠️ HIGH [cmd_712-phase-a-manual-verify] | active item | still active |
<!-- ACTION_REQUIRED:END -->

## archive

| ⚠️ HIGH [cmd_716-dogfooding-consent] | resolved item | archived evidence |

<!-- OBSERVATION_QUEUE:START -->
## ⏳ 時間経過待ち / 観察継続

| タグ | 項目 | 詳細 |
|---|---|---|
| 📌 MEDIUM [cmd_716-dogfooding-observation] | observation | active observation |
<!-- OBSERVATION_QUEUE:END -->
MD

    run "$PYTHON_BIN" - "$dashboard_yaml" "$removed_tag" <<'PY'
import sys
import yaml

dashboard_path, removed_tag = sys.argv[1], sys.argv[2]
with open(dashboard_path, encoding="utf-8") as f:
    dashboard = yaml.safe_load(f)

active_tags = [item.get("tag", "") for item in dashboard.get("action_required", [])]
archive_tags = [
    (item.get("original") or item).get("tag", "")
    for item in dashboard.get("action_required_archive", [])
]
observation_archive_tags = [
    item.get("tag", "") for item in dashboard.get("observation_queue_archive", [])
]

assert removed_tag not in active_tags
assert removed_tag in archive_tags
assert removed_tag in observation_archive_tags
PY
    [ "$status" -eq 0 ]

    run "$PYTHON_BIN" - "$dashboard_md" "$removed_tag" <<'PY'
import re
import sys

md_path, removed_tag = sys.argv[1], sys.argv[2]
text = open(md_path, encoding="utf-8").read()
match = re.search(
    r"<!-- ACTION_REQUIRED:START -->(.*?)<!-- ACTION_REQUIRED:END -->",
    text,
    flags=re.S,
)
assert match, "ACTION_REQUIRED block missing"
active_block = match.group(1)
assert removed_tag not in active_block
assert removed_tag in text
PY
    [ "$status" -eq 0 ]
}
