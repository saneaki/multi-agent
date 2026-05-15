# cmd_728e: discord_notify Long Message Chunking

作成: 2026-05-15 JST  
担当: ashigaru7  
範囲: `scripts/discord_notify.py` / `scripts/notify.sh` の長文分割 opt-in 対応。

## 1. Summary

Discord の 2000 文字制限で殿への承認依頼が truncate される問題に対し、`scripts/discord_notify.py` に `--chunked` を追加した。

既定挙動は従来通りで、`--chunked` 未指定時は1通に整形し 2000 文字で truncate する。既存の cron / inbox / notifier 呼び出しが暗黙に複数DMを送ると運用ノイズが増えるため、後方互換を優先して明示 opt-in とした。

## 2. Implementation

変更点:

- `scripts/discord_notify.py`
  - `--chunked` オプションを追加。
  - `CHUNK_TARGET = 1800` を追加。
  - `format_messages(..., chunked=True)` で本文を複数partへ分割。
  - 各partに `Part N/M` を付与。
  - 各partへ title と type/tag を維持。
  - dry-run は `formatted N part(s)` と part別文字数を表示。
- `scripts/notify.sh`
  - 既存の `body/title/type` 引数互換は維持。
  - `NOTIFY_CHUNKED=1|true|yes` の場合だけ `--chunked` を渡す。
- `tests/unit/test_discord_notify.py`
  - デフォルト長文は1part truncate。
  - chunked長文は複数part、title/tag維持、truncateなし。
  - chunked短文は1part。
- `tests/unit/test_notify_discord.bats`
  - `NOTIFY_CHUNKED=1` が `--chunked` として backend に渡ることを確認。

## 3. Usage

直接実行:

```bash
python3 scripts/discord_notify.py \
  --chunked \
  --body "$LONG_APPROVAL_REQUEST" \
  --title "cmd_728 approval request" \
  --type "decision"
```

既存 wrapper 経由:

```bash
NOTIFY_CHUNKED=1 bash scripts/notify.sh \
  "$LONG_APPROVAL_REQUEST" \
  "cmd_728 approval request" \
  "decision"
```

`shogun-lord-approval-request-pattern` から参照する場合:

```bash
NOTIFY_CHUNKED=1 bash scripts/notify.sh \
  "$(cat output/<cmd>_lord_approval_request.md)" \
  "<decision_id> Lord approval request" \
  "decision"
```

dashboard は短縮版、Discord は詳細 decision memo という cmd_728a の二系統設計に合わせる。Discord 本文が 2000 文字を超える可能性がある場合は `NOTIFY_CHUNKED=1` を明示する。

## 4. Verification

| Check | Result |
|---|---|
| `python3 -m py_compile scripts/discord_notify.py tests/unit/test_discord_notify.py` | PASS |
| `bash -n scripts/notify.sh` | PASS |
| `python3 -m unittest tests.unit.test_discord_notify` | PASS, 3 tests |
| `bats tests/unit/test_notify_discord.bats` | PASS, 5 tests |
| 8KB級 body dry-run | PASS, `formatted 5 part(s)`, 各part 1789 chars |
| short body dry-run | PASS, `formatted 1 part(s)` |
| default long body dry-run | PASS, `formatted 1 part(s)` and `(truncated)` |

Dry-run evidence:

```text
[discord_notify] DRY-RUN — formatted 5 part(s):
--- part 1/5 (1789 chars) ---
**Lord approval**
[vps] Part 1/5
...
--- part 5/5 (1789 chars) ---
...
_(decision)_
```

短文:

```text
[discord_notify] DRY-RUN — formatted 1 part(s):
--- part 1/1 (46 chars) ---
**Short**
[vps] Part 1/1
short body
_(notice)_
```

既定長文:

```text
[discord_notify] DRY-RUN — formatted 1 part(s):
--- part 1/1 (2000 chars) ---
...
…(truncated)
```

## 5. Acceptance Criteria

| ID | Status | Evidence |
|---|---|---|
| E-1 | PASS | `--chunked` 追加。約1800字/chunkで分割。 |
| E-2 | PASS | 各chunkに `Part N/M`、title、type/tag を保持。8KB級 dry-run は5partで truncateなし。 |
| E-3 | PASS | `--chunked` 未指定時は従来通り1part truncate。既存呼び出しの挙動変更なし。 |
| E-4 | PASS | unit test + dry-run で長文複数part、短文1partを確認。 |
| E-5 | PASS | §3 に lord approval request pattern から参照できる usage を記録。 |
| E-6 | PASS | §6 に作業前後 git status、変更ファイル、commit/push判断を記録。 |

## 6. Git Preflight

作業前 `git status --short`:

```text
 M memory/global_context.md
 M memory/skill_history.md
 M queue/external_inbox.yaml
 M queue/reports/ashigaru1_report.yaml
 M queue/reports/ashigaru4_report.yaml
 M queue/reports/ashigaru5_report.yaml
 M queue/reports/gunshi_report.yaml
 M queue/suggestions.yaml
 M queue/tasks/ashigaru4.yaml
 M scripts/shc.sh
 M skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md
```

本タスクの変更:

```text
scripts/discord_notify.py
scripts/notify.sh
tests/unit/test_discord_notify.py
tests/unit/test_notify_discord.bats
output/cmd_728e_discord_notify_long_message_support.md
queue/tasks/ashigaru7.yaml
queue/reports/ashigaru7_report.yaml
queue/inbox/ashigaru7.yaml
```

作業後の注意:

- 既存の unrelated dirty files には触れていない。
- `tests/unit/test_discord_notify.py` と `output/cmd_728e_discord_notify_long_message_support.md` は repo の ignore 規則により通常 `git status` へ出ない。
- commit/push は未実施。cmd_728 の統合作業または Karo の squash/pub 判断に委ねる。commitする場合は `Refs cmd_728` を含める。
