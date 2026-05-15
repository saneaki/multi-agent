# cmd_683c inbox_write.sh cmd完了通知gate修復レポート

作成: 2026-05-15 22:04 JST / 担当: ashigaru5 / 親 cmd: cmd_683 / task: subtask_683c_inbox_write_notify_gate_fix

---

## 1. 任務背景

cmd_683b 検収 §5.2 (申し送り) で、`scripts/inbox_write.sh:138-139` の shogun cmd_complete/cmd_milestone 自動通知 gate が、退役済 `ntfy_topic` (settings.yaml) を grep する旧構造のままだと判明した。

```bash
# 旧コード (inbox_write.sh L137-L140)
if [[ "$TARGET" == "shogun" ]] && [[ "$TYPE" == "cmd_complete" || "$TYPE" == "cmd_milestone" ]]; then
    NTFY_TOPIC=$(grep 'ntfy_topic:' "$SCRIPT_DIR/config/settings.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"')
    if [ -n "$NTFY_TOPIC" ]; then
        ...
```

cmd_683b で `ntfy_topic:` を settings.yaml から完全廃止したため、上記 grep は常に空文字を返し、`[ -n "$NTFY_TOPIC" ]` 判定が常時 false となり、`notify.sh` 経由の Discord 通知も停止する状態だった。実 backend (Discord) と無関係な退役 key に依存する silent fail 構造。

本タスクは ntfy 退役方針を維持しつつ、gate を Discord backend 前提の現行設定 (`config/discord.env`) ベースへ置換する。

## 2. 修正内容

### 2.1. scripts/inbox_write.sh (L136-L177)

旧 ntfy_topic 依存 gate を以下のロジックへ置換:

```bash
# cmd_683c: Discord auto-notification gate (cmd_complete/cmd_milestone → shogun only)
if [[ "$TARGET" == "shogun" ]] && [[ "$TYPE" == "cmd_complete" || "$TYPE" == "cmd_milestone" ]]; then
    DISCORD_ENV_FILE="$SCRIPT_DIR/config/discord.env"
    NOTIFY_GATE_OPEN=0
    if [ -f "$DISCORD_ENV_FILE" ]; then
        BACKEND_LINE=$(grep '^NOTIFY_BACKEND=' "$DISCORD_ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
        BACKEND_LINE="${BACKEND_LINE:-discord}"
        if [ "$BACKEND_LINE" != "ntfy" ]; then
            NOTIFY_GATE_OPEN=1
        fi
    fi

    if [ "$NOTIFY_GATE_OPEN" = "1" ]; then
        ... (notify.sh 呼出ロジック、本体は不変) ...
    fi
fi
```

**判定ロジック**:

| 条件 | gate |
|------|------|
| `config/discord.env` 不存在 | CLOSED (Discord 未構成) |
| `config/discord.env` 存在 + `NOTIFY_BACKEND` 未指定/`=discord` | **OPEN** |
| `config/discord.env` 存在 + `NOTIFY_BACKEND=ntfy` (退役) | CLOSED |
| `TARGET != shogun` | CLOSED |
| `TYPE != cmd_complete && != cmd_milestone` | CLOSED |

### 2.2. config/settings.yaml (L76-L83)

退役注記コメントに cmd_683c での gate 置換先を記述:

```yaml
# ntfy 通知は cmd_692 で退役・cmd_683 Phase3 で関連 scripts 削除済
# cmd_683b: 旧トピック設定キー (n_t_p) を完全廃止
# cmd_683c: scripts/inbox_write.sh の cmd_complete/cmd_milestone gate は
#   旧 n_t_p 参照から config/discord.env の存在 + NOTIFY_BACKEND != ntfy へ置換済。
#   gateキーをそのまま記述するとgrepにヒットして silent fail の芽になるため
#   コメント中もkey名は伏字で表記する。
```

`ntfy_topic` / `NTFY_TOPIC` の新規設定キーは復活させていない (N-2 遵守)。歴史的言及はコメント中も伏字 (`n_t_p`) で表記。

### 2.3. tests/unit/test_notify_discord.bats (追加 6 件)

既存 5 件 (notify.sh 単体) に加え、inbox_write.sh gate 統合テストを 6 件追加:

| # | テスト名 | 検証内容 |
|---|---------|----------|
| 6 | gate opens when discord.env exists with default backend | OPEN ケース (cmd_complete) |
| 7 | gate stays closed when discord.env is absent | discord.env 不在 → CLOSED |
| 8 | gate stays closed when NOTIFY_BACKEND=ntfy is set | 退役 backend → CLOSED |
| 9 | gate does not fire for non-shogun target | TARGET=karo → CLOSED |
| 10 | gate does not fire for non cmd_complete/cmd_milestone type | TYPE=report_received → CLOSED |
| 11 | gate opens for cmd_milestone to shogun | OPEN ケース (cmd_milestone) |

テスト構造:
- `_gate_setup()` ヘルパで `$TEST_TMPDIR/scripts/inbox_write.sh` を本物コピー、`.venv` を symlink、`notify.sh` を invocation log stub に差替え
- discord.env を各テストケースで動的生成 (or 生成せず) し、stub log の有無で gate 動作を確認
- 実 Discord webhook は呼ばない (mock/stub 隔離検証、AC N-3 整合)

## 3. 検証結果 (AC マッピング)

### N-1: ntfy_topic 依存除去 + Discord/notify.sh 用 gate 置換

```
$ grep -n 'ntfy_topic\|NTFY_TOPIC' scripts/inbox_write.sh
137:            # cmd_683c: 旧 ntfy_topic 依存 gate を Discord backend prerequisite gate へ置換。
```

実行系参照 0 件 (コメント中の歴史記述のみ)、gate は `config/discord.env` + `NOTIFY_BACKEND != ntfy` へ完全置換。**PASS**

### N-2: ntfy_topic / NTFY_TOPIC を新規設定として復活させない

```
$ grep -c 'ntfy_topic:' config/settings.yaml
0
```

settings.yaml には設定キーとして復活させず、cmd_683b の伏字 (`n_t_p`) 表記を維持。**PASS**

### N-3: 隔離検証で notify.sh 呼出経路到達可能性

bats stub 検証 (#6, #11) で `notify.sh` が `body / title / type` 引数付きで呼出されることを確認。本番 discord.env (NOTIFY_BACKEND=discord) でも gate=OPEN を simulation 確認:

```
$ DISCORD_ENV_FILE=/home/ubuntu/shogun/config/discord.env
$ BACKEND_LINE=$(grep '^NOTIFY_BACKEND=' "$DISCORD_ENV_FILE" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
$ echo "BACKEND_LINE='$BACKEND_LINE' OPEN=$([ "$BACKEND_LINE" != "ntfy" ] && echo 1 || echo 0)"
BACKEND_LINE='discord' OPEN=1
```

実 webhook 送信は危険なため stub 経路で AC 満たす (タスク本文許可)。**PASS**

### N-4: tests/unit/test_notify_discord.bats SKIP=0 PASS

```
$ bats tests/unit/test_notify_discord.bats
1..11
ok 1 notify.sh dispatches body title and type to Discord backend
ok 2 notify.sh passes --chunked when NOTIFY_CHUNKED is enabled
ok 3 notify.sh rejects missing body
ok 4 notify.sh rejects retired ntfy backend
ok 5 notify.sh rejects unknown backend
ok 6 inbox_write gate: opens when discord.env exists with default backend (cmd_683c)
ok 7 inbox_write gate: stays closed when discord.env is absent (cmd_683c)
ok 8 inbox_write gate: stays closed when NOTIFY_BACKEND=ntfy is set (cmd_683c)
ok 9 inbox_write gate: does not fire for non-shogun target (cmd_683c)
ok 10 inbox_write gate: does not fire for non cmd_complete/cmd_milestone type (cmd_683c)
ok 11 inbox_write gate: opens for cmd_milestone to shogun (cmd_683c)
```

11/11 PASS、SKIP=0、FAIL=0。**PASS**

### N-5: git preflight + cmd_683 含む commit + push

§4 にて選択 add 実施、commit/push は本レポート確定後に実行。未関係 dirty (`docs/dashboard_schema.json` / `memory/global_context.md` / `queue/alert_state.yaml` / `queue/external_inbox.yaml` / `queue/reports/ashigaru1_report.yaml` / `scripts/shc.sh`) は意図的に除外。

### N-6: 副作用 / 設定キー / SO-18 Issue 要否判断

**副作用**:

| 項目 | 修正前 | 修正後 |
|------|--------|--------|
| shogun cmd_complete/cmd_milestone Discord 通知 | 常時停止 (gate 常 false) | 再開 (config/discord.env 存在 + backend=discord 時) |
| ntfy 経路 (退役済) | 不可 | 不可 (NOTIFY_BACKEND=ntfy で gate CLOSED) |
| notify.sh 単体 | 影響なし | 影響なし |
| 他 TARGET (karo 等) / 他 TYPE (report_received 等) | 影響なし | 影響なし |

**設定キー**:

| キー | 種別 | 役割 |
|------|------|------|
| `config/discord.env` 存在 | ファイル | gate 第一条件 (Discord backend prerequisite) |
| `NOTIFY_BACKEND` (discord.env 内) | 既存 env 変数 | `!= ntfy` で gate 通過。未指定時は `discord` 既定 |
| `settings.yaml ntfy_topic` | **削除済 (cmd_683b)** | 復活させない (N-2) |

**SO-18 Issue 要否判定: Issue 不要 (cmd_683 配下で完了)**

判断根拠:
1. **同一 cmd 内補修**: cmd_683b 検収 §5.2 申し送りで明示的に「次 cmd で別 gate キー化」が示されており、家老が cmd_683c として配備した。cmd_683 整理パッケージの一部であり、新規 Issue 化不要。
2. **影響範囲限定**: 修正対象は inbox_write.sh の単一 gate ブロック (約 30 行) + 退役注記コメント + 単体テスト追加のみ。複数モジュールに跨る design 変更ではない。
3. **後続作業なし**: 申し送り §5.2 で示唆された restoration 目的を達成済。dead reference 除去 (申し送り §5.1) も同時完了 (NTFY_TOPIC 参照は新コメントのみに後退)。

## 4. 変更ファイル一覧

### 4.1. 本 cmd の commit 対象 (選択 add)

| ファイル | 種別 | 内容 |
|---------|------|------|
| scripts/inbox_write.sh | M | gate を Discord backend prerequisite 構造へ置換 |
| config/settings.yaml | M | 退役注記コメントに cmd_683c gate 置換先を追記 |
| tests/unit/test_notify_discord.bats | M | gate 統合テスト 6 件追加 (合計 11 件) |
| output/cmd_683c_inbox_write_notify_gate_fix.md | A (new) | 本レポート |
| queue/reports/ashigaru5_report.yaml | M | task_completed 追記 |
| queue/tasks/ashigaru5.yaml | M | status=done |
| queue/inbox/ashigaru5.yaml | M | msg_20260515_125900_27c3de46 read:true |

### 4.2. 本 cmd の commit 対象外 (別件 dirty, 巻き込まない)

| ファイル | 推定 cmd / 所有者 |
|---------|------------------|
| docs/dashboard_schema.json | 別 cmd の dashboard schema 拡張作業中 |
| memory/global_context.md | 別 ashigaru の学習記録更新 |
| queue/alert_state.yaml | shogun_in_progress_monitor.sh 等の自動更新 |
| queue/external_inbox.yaml | 自動 nudge / external 連携 |
| queue/reports/ashigaru1_report.yaml | ashigaru1 の進行中 cmd |
| scripts/shc.sh | 別 cmd / 別 ashigaru の改修中 |

## 5. 申し送り事項

1. **歴史的コメント残置**: scripts/inbox_write.sh L137 のコメントに `ntfy_topic` 文字列が含まれるが、これは置換経緯の記録であり実行系参照ではない。cmd_683b の伏字方針 (`n_t_p`) を厳密適用する場合、本コメント文字列の修正も将来検討可。**現状は維持** (歴史的経緯記述として有用)。
2. **gate 拡張余地**: 現 gate は `config/discord.env` 存在 + backend ≠ ntfy のみ。将来 webhook URL の placeholder (`your_user_id_here` 等) 判定を追加する場合は、`DISCORD_LORD_USER_ID` の値検査を gate に組込み可。重要度低・現状不要。
3. **回帰防止**: bats テストは inbox_write.sh をフルコピーして検証する構造のため、inbox_write.sh の任意修正が gate を破壊した場合 #6-#11 で検出可能。CI 回帰扉として有効。

## 6. AC 達成状況サマリ

| AC | 内容 | 結果 |
|----|------|------|
| N-1 | ntfy_topic 依存除去 + Discord/notify.sh gate 置換 | PASS |
| N-2 | ntfy_topic / NTFY_TOPIC を新規設定として復活させない | PASS |
| N-3 | dry-run / 隔離検証で notify.sh 呼出経路到達確認 | PASS (stub 検証 + 本番 simulation) |
| N-4 | test_notify_discord.bats SKIP=0 PASS | PASS (11/11 PASS) |
| N-5 | cmd_704 git preflight + cmd_683 含む commit + push | 本レポート確定後に実施 |
| N-6 | output に副作用・設定キー・SO-18 Issue 要否判断記録 | PASS (本 §3 N-6) |

## 7. 結論

cmd_683b 申し送り §5.2 の「次 cmd で別 gate キー化」を cmd_683c として実装完了。退役済 `ntfy_topic` 参照を完全除去し、Discord backend prerequisite (`config/discord.env` 存在 + `NOTIFY_BACKEND != ntfy`) を gate とする恒久構造へ移行。bats 11/11 PASS、SKIP=0、本番 discord.env で gate=OPEN simulation 確認済。SO-18 GitHub Issue 不要 (cmd_683 配下で完結)。家老検収後 cmd_683 完了処理へ移行可能。
