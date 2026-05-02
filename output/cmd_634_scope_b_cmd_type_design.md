# cmd_634 Scope B — cmd種別判定 logic + AC11 auto-done 設計

**task_id**: subtask_634_scope_b_cmd_type_design  
**parent_cmd**: cmd_634  
**担当**: ashigaru7  
**作成日時**: 2026-05-03T00:28:08+09:00

## 1. cmd 種別判定 logic

### 1.1 目的

`implementation-verifier` が完遂報告を検証する際、すべての cmd に同じ Stage 1-4 確認を要求すると document-only cmd で過剰検証になり、逆に cron / hook / git push / script 系 cmd では実稼働確認が不足する。  
そのため、task YAML の `editable_files` と `description` から cmd 種別を自動分類し、必須 Stage と Skip 可 Stage を決める。

### 1.2 分類基準

| 種別 | 判定条件 | 必須確認 | Skip 可 |
|---|---|---|---|
| `cron` | `editable_files` に `crontab` / `cron` / `*.timer` / `*.service`、または `description` に `crontab` / `cron` / `毎時` / `定期実行` | Stage 3: `crontab -l | grep ...` または systemd timer 確認。Stage 4: 実行ログ確認 | なし |
| `hook` | `editable_files` に `settings.json` / `.claude/settings` / `.codex` / `hooks`、または `description` に `hook` / `フック` | Stage 3: `jq '.hooks' settings.json` など hook 登録確認。Stage 4: hook 発火ログまたは dry-run | なし |
| `git_push` | `description` に `commit` / `push` / `git` / `origin/main`、または AC に push 確認がある | Stage 1: `git log origin/main..HEAD` が空、`git status --porcelain` 確認 | Stage 3-4 は内容次第 |
| `script` | `editable_files` に `scripts/`、`.sh`、`.py`、`.js` が含まれる | Stage 2: `ls -la` / 実体確認。Stage 4: `bash -n`、unit/dry-run、実行ログ確認 | Stage 3 は登録不要なら Skip |
| `doc_only` | `editable_files` が `output/*.md` / `instructions/*.md` / `memory/*.md` / `context/*.md` のみ | Stage 1: ファイル存在・行数。Stage 2: AC キーワード確認 | Stage 3-4 は Skip 可 |
| `general` | 上記に該当しない | Stage 1-2 必須。Stage 3-4 は task AC に従う | task AC 次第 |

分類は複数該当を許可する。優先順位は `cron` / `hook` / `git_push` / `script` / `doc_only` / `general` とし、`cron` と `script` のように重なる場合は厳しい側の必須確認を採用する。

### 1.3 pseudo-code

```python
def classify_cmd(task_yaml: dict) -> dict:
    files = [str(f) for f in task_yaml.get("editable_files", []) or []]
    desc = str(task_yaml.get("description", "") or "")
    ac_text = " ".join(str(x) for x in task_yaml.get("acceptance_criteria", []) or [])
    haystack = " ".join(files + [desc, ac_text]).lower()

    tags = []

    if any(token in haystack for token in ["crontab", " cron", "cron ", ".timer", ".service", "毎時", "定期実行"]):
        tags.append("cron")

    if any(token in haystack for token in ["settings.json", ".claude/settings", ".codex", "hooks", "hook", "フック"]):
        tags.append("hook")

    if any(token in haystack for token in ["commit", "push", "origin/main", "git log", "git push"]):
        tags.append("git_push")

    if any(f.startswith("scripts/") or f.endswith((".sh", ".py", ".js", ".ts")) for f in files):
        tags.append("script")

    doc_prefixes = ("output/", "instructions/", "memory/", "context/")
    doc_suffixes = (".md", ".txt", ".yaml")
    if files and all(f.startswith(doc_prefixes) and f.endswith(doc_suffixes) for f in files):
        tags.append("doc_only")

    if not tags:
        tags.append("general")

    required = {"stage1": True, "stage2": True, "stage3": False, "stage4": False}
    skip_allowed = {"stage3": True, "stage4": True}

    if "cron" in tags:
        required.update({"stage3": True, "stage4": True})
        skip_allowed.update({"stage3": False, "stage4": False})
    if "hook" in tags:
        required.update({"stage3": True, "stage4": True})
        skip_allowed.update({"stage3": False, "stage4": False})
    if "git_push" in tags:
        required["stage1_push_check"] = True
    if "script" in tags:
        required["stage4"] = True
        skip_allowed["stage4"] = False
    if tags == ["doc_only"]:
        required.update({"stage3": False, "stage4": False})
        skip_allowed.update({"stage3": True, "stage4": True})

    return {
        "tags": tags,
        "required": required,
        "skip_allowed": skip_allowed,
    }
```

### 1.4 `implementation-verifier.md` への組込方法

現行 `/home/ubuntu/.claude/agents/implementation-verifier.md` は `## Input Context` が 37行目から始まり、task YAML と report message を入力として扱う。ここに「Cmd Type Classification」小節を追加する。

追加位置:
- `/home/ubuntu/.claude/agents/implementation-verifier.md:37` の `## Input Context` 内
- 既存の入力項目 (`task_id`, `from`, `report_content`, `working_dir`) の直後
- `## 4-Layer Checklist` の前

追加内容の骨子:

```markdown
### Cmd Type Classification

Before running the checklist, read `queue/tasks/{agent}.yaml` and classify the cmd:

- `cron`: require Stage 3 registration check and Stage 4 runtime log check.
- `hook`: require Stage 3 hook configuration check and Stage 4 trigger/dry-run evidence.
- `git_push`: require Stage 1 push check (`git log origin/main..HEAD` must be empty when push is claimed).
- `script`: require Stage 2 file existence and Stage 4 syntax/dry-run/runtime evidence.
- `doc_only`: Stage 1-2 are enough; Stage 3-4 may be skipped with explicit reason.
- `general`: Stage 1-2 required; Stage 3-4 follow task AC.

If multiple types match, apply the strictest required stages. A skipped required stage is FAIL, not PASS.
```

Stage 定義との接続:
- Stage 1: git / existence / push 整合
- Stage 2: file placement and AC content
- Stage 3: registration/configuration (`crontab`, hook settings, systemd, external registry)
- Stage 4: runtime evidence (`bash -n`, dry-run, logs, execution result)

## 2. AC11 詳細設計書 — `task_completed` 受領時の task YAML auto-done

### 2.1 背景とゴール

REGISTRY_UPDATE_LAG は、ashigaru が `task_completed` を inbox に投函した後も `queue/tasks/ashigaru{N}.yaml` の `status: assigned` が残る事象である。cmd_637 follow-up 系で再発したため、家老の inbox watcher が `task_completed` を検出した時点で該当 agent の task YAML を `done` に自動更新する。

ゴール:
- `task_completed` メッセージ受領で、対応する `queue/tasks/{from}.yaml` を `status: done` にする
- `completed_at` を `bash scripts/jst_now.sh --yaml` 相当で追加
- 既に `done` なら no-op
- 失敗しても watcher は継続
- 書込みは tmp file + `os.replace` による原子操作

### 2.2 実装ファイルと追加位置

対象ファイル:
- `/home/ubuntu/shogun/scripts/inbox_watcher.sh`

現行構造:
- `get_unread_info()` は `/home/ubuntu/shogun/scripts/inbox_watcher.sh:492` から開始
- `get_unread_info()` 内で unread normal messages と `has_task_assigned` を集計している
- `send_wakeup()` は `/home/ubuntu/shogun/scripts/inbox_watcher.sh:904` から開始

追加位置:
1. `get_unread_info()` の直後、`send_cli_command()` の前 (`scripts/inbox_watcher.sh:541` 直前) に `auto_mark_task_done_from_completed_messages()` を追加する。
2. `get_unread_info()` の Python 内で `task_completed` の存在を `has_task_completed` として payload に含める、または main loop 側で常に補助関数を呼ぶ。
3. main loop の unread event 処理で、nudge 前に `auto_mark_task_done_from_completed_messages "$AGENT_ID"` を呼ぶ。家老 watcher だけでなく全 watcher に入れても、対象は `type: task_completed` の `from` に紐づく task YAML なので副作用は限定的。ただし AC11 の責務上、まず karo watcher の起動 path で動かすのが最小。

推奨は「常に呼んで関数内で no-op 判定」。理由は `task_completed` が `special_types` ではなく normal message なので、nudge 処理に進む前に registry lag を解消できるため。

### 2.3 追加コード案

`scripts/inbox_watcher.sh:541` 直前に追加する bash wrapper:

```bash
auto_mark_task_done_from_completed_messages() {
    (
        if command -v flock &>/dev/null; then
            flock -x 200
        else
            _ld="${LOCKFILE}.d"
            _i=0
            while ! mkdir "$_ld" 2>/dev/null; do
                sleep 0.1
                _i=$((_i+1))
                [ $_i -ge 300 ] && break
            done
            trap "rmdir '$_ld' 2>/dev/null" EXIT
        fi

        INBOX_PATH="$INBOX" SCRIPT_DIR="$SCRIPT_DIR" "$SCRIPT_DIR/.venv/bin/python3" - << 'PY'
import datetime
import os
import re
import subprocess
import sys
import yaml

inbox_path = os.environ["INBOX_PATH"]
script_dir = os.environ["SCRIPT_DIR"]
tasks_dir = os.path.join(script_dir, "queue", "tasks")

def jst_now():
    try:
        return subprocess.check_output(
            ["bash", os.path.join(script_dir, "scripts", "jst_now.sh"), "--yaml"],
            text=True,
        ).strip()
    except Exception:
        return datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).replace(microsecond=0).isoformat()

def valid_agent(agent):
    return re.fullmatch(r"(ashigaru[1-7]|gunshi|karo)", str(agent or "")) is not None

try:
    with open(inbox_path, "r", encoding="utf-8", errors="replace") as f:
        inbox_data = yaml.safe_load(f) or {}

    changed = []
    for msg in inbox_data.get("messages", []) or []:
        if msg.get("type") != "task_completed":
            continue

        sender = msg.get("from")
        if not valid_agent(sender):
            continue

        task_path = os.path.join(tasks_dir, f"{sender}.yaml")
        if not os.path.exists(task_path):
            changed.append({"agent": sender, "result": "missing_task_yaml"})
            continue

        with open(task_path, "r", encoding="utf-8", errors="replace") as tf:
            task_data = yaml.safe_load(tf) or {}

        task = task_data.get("task", task_data)
        current_status = str(task.get("status") or "").strip()
        if current_status == "done":
            changed.append({"agent": sender, "result": "already_done"})
            continue
        if current_status not in ("assigned", "failed", "blocked"):
            changed.append({"agent": sender, "result": f"skip_status:{current_status}"})
            continue

        task["status"] = "done"
        task["completed_at"] = jst_now()
        task["auto_done_by"] = "inbox_watcher"
        task["auto_done_reason"] = "task_completed inbox message received"

        if "task" in task_data:
            task_data["task"] = task
        else:
            task_data = task

        tmp_path = f"{task_path}.tmp.{os.getpid()}"
        with open(tmp_path, "w", encoding="utf-8") as out:
            yaml.safe_dump(task_data, out, default_flow_style=False, allow_unicode=True, sort_keys=False)
        os.replace(tmp_path, task_path)
        changed.append({"agent": sender, "result": "done"})

    for item in changed:
        print(f"[auto_done] {item['agent']}: {item['result']}", file=sys.stderr)
except Exception as exc:
    print(f"[auto_done][ERROR] {exc}", file=sys.stderr)
    sys.exit(0)
PY
    ) 200>"$LOCKFILE" 2>/dev/null || true
}
```

main loop 側の呼出案:

```bash
# get_unread_info 実行後、send_wakeup / context_reset 判定より前
auto_mark_task_done_from_completed_messages
```

`get_unread_info()` payload に `has_task_completed` を追加する場合の差分:

```python
has_task_completed = any(m.get("type") == "task_completed" for m in normal_msgs)
payload = {
    "count": normal_count,
    "has_task_assigned": has_task_assigned,
    "has_task_completed": has_task_completed,
    "specials": [{"type": m.get("type", ""), "content": m.get("content", "")} for m in specials],
}
```

その場合の bash 側:

```bash
has_task_completed=$(echo "$info" | "$SCRIPT_DIR/.venv/bin/python3" -c 'import json,sys; print(json.load(sys.stdin).get("has_task_completed", False))')
if [ "$has_task_completed" = "True" ] || [ "$has_task_completed" = "true" ]; then
    auto_mark_task_done_from_completed_messages
fi
```

### 2.4 task_id 特定方法

第一候補:
- message に `task_id` field があればそれを利用し、task YAML の `task.task_id` と一致確認する。

現行 `inbox_write.sh` の標準メッセージは content/from/type が主で、構造化 `task_id` が無い可能性がある。したがって初期実装は以下にする。

1. `message.from` から agent を特定する。
2. `queue/tasks/{from}.yaml` を読む。
3. 現在の `task.task_id` を対象 task とみなす。
4. content 内に `subtask_...` が含まれる場合は、task YAML の `task_id` と一致するか警告ログを出す。不一致なら skip が安全。

content 解析を入れるなら:

```python
m = re.search(r"(subtask_[A-Za-z0-9_\\-]+)", str(msg.get("content") or ""))
content_task_id = m.group(1) if m else None
yaml_task_id = task.get("task_id")
if content_task_id and yaml_task_id and content_task_id != yaml_task_id:
    changed.append({"agent": sender, "result": f"skip_task_id_mismatch:{content_task_id}!={yaml_task_id}"})
    continue
```

### 2.5 原子操作と冪等性

原子操作:
- task YAML をメモリ上で更新
- 同一ディレクトリに `queue/tasks/ashigaruN.yaml.tmp.$PID` として書く
- `os.replace(tmp_path, task_path)` で atomic rename
- watcher 側は `flock` を使い、同一 inbox 処理内の競合を避ける

冪等性:
- `status == "done"` なら何も更新せず `already_done` を stderr log に出す
- 同じ `task_completed` が複数回残っていても 2回目以降は no-op
- `completed_at` は初回 done 化時だけ設定する

失敗時:
- `except Exception` で stderr に `[auto_done][ERROR] ...` を出す
- `sys.exit(0)` とし、watcher 本体は abort しない
- bash wrapper も `|| true` を付ける

### 2.6 `bash + yq/sed` ではなく Python を推奨する理由

Python + PyYAML 推奨:
- 既存 `inbox_watcher.sh` は `get_unread_info()` などで既に `$SCRIPT_DIR/.venv/bin/python3` と `yaml.safe_load` を使っている
- YAML の入れ子 (`task.status`) と top-level 形式の両方に対応しやすい
- `sed` は `notes: |` など multiline YAML を壊すリスクがある
- `yq` は環境依存が増える

### 2.7 運用中 watcher への影響

想定影響:
- 1 unread cycle ごとに inbox YAML と task YAML を読むため、I/O は軽微
- `task_completed` が無い場合は no-op
- `task_completed` がある場合だけ task YAML を更新

注意点:
- `LOCKFILE` は inbox lock なので task YAML lock ではない。複数 watcher が同じ task YAML を同時更新する可能性を完全排除するなら、`queue/tasks/{agent}.yaml.lock` を別途使うのがより堅牢。
- 初期実装は karo watcher のみで起動するほうが RACE-001 リスクが低い。
- ashigaru 自身も完了時に自 task YAML を更新するため、auto-done は「漏れの補完」として扱う。ashigaru が先に done にした場合は no-op。

## 3. 懸念点・リスク

1. **RACE-001**: ashigaru と watcher が同じ `queue/tasks/ashigaruN.yaml` を同時更新する可能性がある。対策は task YAML 専用 lock (`queue/tasks/ashigaruN.yaml.lock`) の導入、または karo watcher のみが auto-done を担う運用に限定すること。
2. **task_id 不一致**: content に古い task_id が残り、from の現在 task YAML とずれる可能性がある。content task_id が抽出できる場合は YAML task_id と一致しない限り skip する。
3. **特殊 agent**: `gunshi` / `karo` も `task_completed` を送る可能性がある。AC11 は ashigaru task YAML が主対象なので、初期 allowlist は `ashigaru[1-7]` に限定してもよい。
4. **ログ可視性**: watcher stderr に出るだけでは後追いしづらい。安定後は `logs/inbox_watcher_auto_done.log` への追記も検討する。
5. **watcher abort 防止**: `set -euo pipefail` 環境下でも補助関数が `|| true` で戻る設計にする。Python 側も例外を握りつぶして stderr に出す。

## 4. 受入条件対応

- AC1: cron / hook / git_push / script / doc_only / general の分類基準と pseudo-code を明記。
- AC2: AC11 の実装ファイル、追加位置、コード案、原子操作、冪等性、失敗時継続を明記。
- AC3: 本ファイル `output/cmd_634_scope_b_cmd_type_design.md` を作成。行数は `wc -l` で確認する。
