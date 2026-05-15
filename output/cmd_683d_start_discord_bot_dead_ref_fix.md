# cmd_683d start_discord_bot.sh dead reference 補修レポート

作成: 2026-05-15 22:20 JST / 担当: ashigaru5 / 親 cmd: cmd_683 / task: subtask_683d_start_discord_bot_dead_ref_fix / 重要度: low (L3)

---

## 1. 任務背景

implementation-verifier の L3 軽微指摘:

> `scripts/start_discord_bot.sh:26` の `BOT_SCRIPT` が cmd_683 Phase3 で削除済の `scripts/discord_to_ntfy.py` を参照しており、dead reference after deletion 状態。

旧構造:

```bash
# scripts/start_discord_bot.sh (修正前)
BOT_SCRIPT="$SCRIPT_DIR/scripts/discord_to_ntfy.py"        # ← 削除済ファイル参照
...
tmux new-window -d -t "$TMUX_SESSION" -n "$TMUX_WINDOW" \
    "$VENV_PYTHON $BOT_SCRIPT ${BOT_ARGS[*]:-}; ..."        # ← 起動しても No such file
```

文脈:

- cmd_497 (2026-04-15) で systemd user service `shogun-discord.service` へ移行済。`start_discord_bot.sh` は当時 "緊急時手動デバッグ用" として残置されていた。
- cmd_683 Phase3 (2026-05-15) で `scripts/discord_to_ntfy.py` を削除済。これにより `start_discord_bot.sh` を呼ぶと該当 BOT_SCRIPT が存在せず Python 側で `No such file or directory` を吐いて即時 fail する半壊状態だった。
- 現行 Discord 系統は `shogun-discord.service` → `scripts/discord_gateway.py` 構成。`start_discord_bot.sh` のラッパは旧 ntfy 中継時代の設計で、現行 gateway とは architecture が異なる (gateway は ntfy 経由ではなく external_inbox.yaml へ atomic 書込)。

本タスクは cmd_683 配下の dead-reference-after-deletion 後処理として、`start_discord_bot.sh` を deprecation 早期失敗構造へ置換する軽補修。

## 2. 修正内容

### 2.1. scripts/start_discord_bot.sh 全面置換

旧 86 行を deprecation header 強化 + 早期 abort 構造の 53 行へ縮約:

```bash
#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# DEPRECATED: このスクリプトは cmd_497 (2026-04-15) で systemd user service
# (shogun-discord.service) に移行済。さらに cmd_683 Phase3 (2026-05-15) で
# 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) が削除されたため、ここから起動
# しても動作しない。dead reference 起動を防ぐため deprecation メッセージを
# 出して即時失敗のみ行う。cmd_683d で本体ロジックを除去。
#
# 通常運用は systemd user service:
#   systemctl --user status   shogun-discord    # 状態確認
#   systemctl --user restart  shogun-discord    # 再起動
#   systemctl --user stop     shogun-discord    # 停止
#   journalctl --user -u shogun-discord -f      # ログ追跡
# ...
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

cat >&2 <<'EOF'
[DEPRECATED] scripts/start_discord_bot.sh は使用不可。
  - cmd_497 (2026-04-15): systemd user service (shogun-discord.service) に移行
  - cmd_683 Phase3 (2026-05-15): 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) 削除済
  - cmd_683d (2026-05-15): 本スクリプト本体ロジック撤去 (dead reference 解消)
... (略: systemctl コマンド一覧 + 緊急時手動起動方法 + discord_gateway.py への案内) ...
EOF

exit 2
```

**設計判断**:

| 候補 | 採否 | 理由 |
|------|------|------|
| (a) BOT_SCRIPT を discord_gateway.py へ更新し本体ロジック維持 | 不採用 | gateway は systemd 配下で常駐運用。tmux からの追加起動は duplicate bot instance を生み Discord API token 同時接続違反となる |
| (b) 早期 abort + systemctl 案内 | **採用** | DEPRECATED 方針を厳密化、誤実行 (cmd_683 Phase3 後) を完全に防ぐ |
| (c) 本体維持し BOT_SCRIPT 行のみ修正 | 不採用 | 上記 (a) と同じく duplicate 起動リスク |

(b) を採用し、緊急時手動デバッグは systemd 停止 → discord_gateway.py 直接起動の手順をメッセージ中で案内。

### 2.2. 削除した本体ロジック

以下を削除 (deprecation 早期 abort により不要):

- `BOT_ENV` / `BOT_SCRIPT` / `TMUX_SESSION` / `TMUX_WINDOW` 変数定義
- `BOT_ENV` 存在チェック + 編集案内
- `DISCORD_BOT_TOKEN` 未設定検査
- `--dry-run` 引数処理
- tmux session/window 存在チェック + 既存 window kill
- `tmux new-window` で BOT_SCRIPT 起動

これらは cmd_683 Phase3 以降全て unreachable / 不適切 (duplicate 起動原因) であり、保持する価値なし。

## 3. 検証結果 (AC マッピング)

### D-1: dead reference 除去

```
$ grep -n 'discord_to_ntfy' scripts/start_discord_bot.sh
5:# 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) が削除されたため、ここから起動
19:# 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) は cmd_683 Phase3 で削除済
27:  - cmd_683 Phase3 (2026-05-15): 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) 削除済
```

残存 3 件は全て **deprecation 経緯を説明するコメント/メッセージ** であり実行系参照ではない。**PASS**

### D-2: bash -n SYNTAX_OK

```
$ bash -n scripts/start_discord_bot.sh && echo SYNTAX_OK
SYNTAX_OK
```

**PASS**

### D-3: dead reference scan (実行系のみ)

```
$ grep -rn "discord_to_ntfy" --include="*.sh" --include="*.py" \
    | grep -v -E "^(docs/|output/|queue/|originaldocs/|.git/)"
scripts/discord_gateway.py:5:旧 scripts/discord_to_ntfy.py の置換。Discord DM を受信し、
scripts/discord_gateway.py:20:  config/discord_bot.env をフォールバックで読込 (旧 discord_to_ntfy.py 互換)。
scripts/start_discord_bot.sh:5:#   旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) が削除されたため、ここから起動
scripts/start_discord_bot.sh:19:# 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) は cmd_683 Phase3 で削除済
scripts/start_discord_bot.sh:27:  - cmd_683 Phase3 (2026-05-15): 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) 削除済
scripts/install-shogun-discord-service.sh:10:pkill -f discord_to_ntfy || true
scripts/install-shogun-discord-service.sh:14:if pgrep -f discord_to_ntfy > /dev/null; then
scripts/install-shogun-discord-service.sh:15:  echo "ERROR: discord_to_ntfy プロセスが残存しています。手動で停止してから再実行してください。"
scripts/install-shogun-discord-service.sh:39:pgrep -f discord_to_ntfy && echo "OK: Bot プロセス確認" || echo "WARN: プロセス未検出"
```

| 件 | 種別 | 判定 |
|----|------|------|
| `discord_gateway.py` L5/L20 | docstring (履歴説明) | 実行系参照ではない: OK |
| `start_discord_bot.sh` L5/L19/L27 | deprecation コメント (本タスクで追加) | 実行系参照ではない: OK |
| `install-shogun-discord-service.sh` L10/L14/L15/L39 | `pkill -f` / `pgrep -f` 経由のプロセス名 pattern (legacy cleanup) | ファイル実行参照ではなく、process name match。cmd_683 Phase3 以降は match しないが、defensive cleanup として残置妥当 |

実行系 (Python ファイル起動・bash 経由実行・import 等) の参照は **ゼロ**。歴史的 docs/output/queue archive (タスク D-3 で対象外と明記) は本 grep 対象から除外済。**PASS**

> 申し送り: `install-shogun-discord-service.sh` の `pkill/pgrep -f discord_to_ntfy` は cmd_683 Phase3 以降 match することはないが、編集対象外 (editable_files 範囲外) のため本 cmd では touch せず。次の install スクリプト改修時に `discord_gateway` パターンへ更新可能。skill_candidates に "dead reference defensive cleanup audit" を追加検討。

### D-4: deprecated として明確に失敗

実機実行確認:

```
$ bash scripts/start_discord_bot.sh
[DEPRECATED] scripts/start_discord_bot.sh は使用不可。
  - cmd_497 (2026-04-15): systemd user service (shogun-discord.service) に移行
  - cmd_683 Phase3 (2026-05-15): 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) 削除済
  - cmd_683d (2026-05-15): 本スクリプト本体ロジック撤去 (dead reference 解消)

通常運用コマンド:
  systemctl --user status   shogun-discord
  systemctl --user restart  shogun-discord
  systemctl --user stop     shogun-discord
  journalctl --user -u shogun-discord -f

再インストール:
  bash scripts/install-shogun-discord-service.sh

現行 Bot 本体は scripts/discord_gateway.py (systemd 配下) です。
緊急時手動デバッグは systemd を停止してから直接起動してください:
  systemctl --user stop shogun-discord
  .venv/discord-bot/bin/python3 scripts/discord_gateway.py

EXIT=2
```

- exit code 2 (`set -euo pipefail` + `exit 2`) で明確に失敗 ✓
- 削除済 BOT_SCRIPT への起動試行を完全に遮断 ✓
- systemctl + 緊急時手動起動手順を提示し誤運用を防止 ✓

**PASS**

### D-5: cmd_683 含む commit + push、未関係 dirty 巻き込み禁止

§4.1 で選択 add、本レポート確定後に commit/push。未関係 dirty (`docs/dashboard_schema.json` / `memory/global_context.md` / `queue/alert_state.yaml` / `queue/external_inbox.yaml` / `queue/reports/ashigaru1_report.yaml` / `scripts/shc.sh`) は意図的に除外。

### D-6: output に implementation-verifier 指摘対応 + 動作確認 + skill 候補要否

- implementation-verifier 指摘対応: §1 (背景) + §2 (修正内容) + §3 (検証) で全件追跡可能
- 動作確認: §3 D-2 (bash -n) + D-4 (実機 abort 確認)
- skill 候補要否判断: §5 を参照

**PASS**

## 4. 変更ファイル一覧

### 4.1. 本 cmd の commit 対象 (選択 add)

| ファイル | 種別 | 内容 |
|---------|------|------|
| scripts/start_discord_bot.sh | M | 本体ロジック撤去 + deprecation 早期 abort 構造へ置換 |
| output/cmd_683d_start_discord_bot_dead_ref_fix.md | A (new) | 本レポート |
| queue/reports/ashigaru5_report.yaml | M | task_completed 追記 |
| queue/tasks/ashigaru5.yaml | M | status=done |
| queue/inbox/ashigaru5.yaml | M | msg_20260515_131611_6c22c5ed read:true (既に処理済) |

### 4.2. 本 cmd の commit 対象外 (別件 dirty, 巻き込まない)

| ファイル | 推定 cmd / 所有者 |
|---------|------------------|
| docs/dashboard_schema.json | 別 cmd の dashboard schema 拡張作業中 |
| memory/global_context.md | 別 ashigaru の学習記録更新 |
| queue/alert_state.yaml | shogun_in_progress_monitor.sh 等の自動更新 |
| queue/external_inbox.yaml | discord_gateway / external 連携 |
| queue/reports/ashigaru1_report.yaml | ashigaru1 の進行中 cmd |
| queue/tasks/ashigaru5.yaml の cmd_683d 関連箇所以外 | 本 cmd で必要箇所のみ更新 |
| scripts/shc.sh | 別 cmd / 別 ashigaru の改修中 |

## 5. skill 候補要否判断

候補名 (仮): **`dead-reference-after-deletion`**

**要否: 要登録 (priority=low)**

判断根拠:

1. **再発性**: cmd_683 Phase3 削除作業で 14 ファイルが削除された際、`discord_to_ntfy.py` を参照していた `start_discord_bot.sh` が implementation-verifier 検収まで漏れ、削除済参照を持つ状態が残った。本パターンはファイル削除を伴う cleanup cmd で再発する可能性が高い。
2. **既存知見との関係**: `shogun-silent-failure-audit-pattern` (silent failure 検出) と隣接領域だが、こちらは "削除後に残るリンク切れ" に特化。`refactor-cleaner` agent や `knip/ts-prune/depcheck` の bash 版が存在しないため、shell project 向けに体系化価値あり。
3. **検出パターン例**:
   - 削除予定ファイル一覧を `pre-delete-targets.txt` に保持
   - 削除後に全リポジトリで `grep -rn` 実行 → execution-system 参照と documentation 参照を区別
   - `pgrep/pkill -f` 等の process-name pattern は別カテゴリで判定
   - bash の `source` / `python` / `node` などの explicit executor + path を実行系として抽出
4. **本 cmd で十分か**: 単発の補修 cmd レベルで skill 化までは過剰の可能性もあるが、cmd_683 のように Phase3 削除 14 件レベルの cleanup で 1 件漏れた事実は再発防止価値あり。

**推奨**: 軍師レビューで skill 化是非を最終判断。即時不要なら `queue/skill_candidates.yaml` への提案 entry 追加に留める。

## 6. 副作用 / リスク評価

| 項目 | 修正前 | 修正後 |
|------|--------|--------|
| `bash scripts/start_discord_bot.sh` 実行結果 | Python `No such file` で半壊 fail | 明示的 deprecation message + exit 2 |
| `--dry-run` 引数サポート | あり (ただし BOT_SCRIPT 存在しないため半壊) | 削除 (deprecation により無意味) |
| tmux window `shogun-discord` 作成 | あり (半壊状態) | なし |
| 現行 systemd service `shogun-discord` 動作 | 影響なし | 影響なし |
| `scripts/discord_gateway.py` の動作 | 影響なし | 影響なし |
| install スクリプト (`install-shogun-discord-service.sh`) | 影響なし | 影響なし (本 cmd では touch せず) |

**ロールバックリスク**: 低。緊急時に旧本体ロジックが必要になった場合、git history (cmd_683d 前 commit) から復元可能。ただし旧本体は cmd_683 Phase3 削除後の dead reference を含むため復元しても動作しない点に注意。

## 7. SO-18 GitHub Issue 要否

**Issue 不要 (cmd_683 配下で完結)**

判断根拠:

1. **cmd_683 配下後処理**: cmd_683b → cmd_683c → cmd_683d と申し送り構造で連続補修中の cmd であり、Phase3 削除作業 (cmd_683 親) に対する後始末として完結。新規 design 変更ではない。
2. **影響範囲限定**: 修正対象は `scripts/start_discord_bot.sh` 単一ファイルのみ。検証も bash -n と実機 abort 確認で完結。
3. **bug fix の性質**: 純粋な dead reference 除去であり、新機能追加・design 変更は伴わない。SO-18 が要求する "bug fix Issue tracking" の対象は通常本番 production 影響のあるバグだが、本件は deprecated script の半壊で production 影響は皆無。

## 8. AC 達成状況サマリ

| AC | 内容 | 結果 |
|----|------|------|
| D-1 | scripts/discord_to_ntfy.py 参照除去 | PASS (執行系参照ゼロ、コメント言及のみ残存) |
| D-2 | bash -n SYNTAX_OK | PASS |
| D-3 | dead reference scan (執行系のみ) | PASS (process-name pattern と歴史的コメントのみ残存) |
| D-4 | deprecated として明確に失敗 / systemctl 案内 | PASS (exit 2 + 詳細メッセージ) |
| D-5 | cmd_683 含む commit + push、未関係 dirty 巻き込まない | 本レポート確定後に実施 |
| D-6 | output 記録 (指摘対応 / 動作確認 / skill 候補要否) | PASS (本レポート) |

## 9. 結論

cmd_683 Phase3 申し送り (dead reference after deletion) を cmd_683d として補修完了。`scripts/start_discord_bot.sh` の半壊状態 (削除済 BOT_SCRIPT 参照) を解消し、deprecation 早期 abort 構造へ移行。実機実行で exit 2 + 明示メッセージを確認。execution-system 参照は完全除去、残存はコメント/docstring/process-name pattern のみ。SO-18 Issue 不要 (cmd_683 配下完結)。

申し送り:

1. `install-shogun-discord-service.sh` の `pkill/pgrep -f discord_to_ntfy` は process-name pattern として残置 (legacy cleanup 用)。defensive cleanup の妥当性は将来の install スクリプト改修時に再評価可。
2. skill 候補 `dead-reference-after-deletion` を `queue/skill_candidates.yaml` への提案として軍師レビューに付託。
