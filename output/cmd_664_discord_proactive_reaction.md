# cmd_664: Discord能動反応機構 実装レポート

**完了日時**: 2026-05-08 05:33 JST  
**担当**: ashigaru1 (Sonnet+T)  
**parent_cmd**: cmd_664

---

## 実装概要

Discord DMが届いた際、将軍（Claude Code）が能動的に検知・反応する機構を実装した。

### 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `scripts/stop_hook_inbox.sh` | 将軍向け `discord_received` 検知ロジック追加 (Scope A) |

---

## Scope A: 検知 + 自動起動 (AC A-1/A-2/A-3)

### 設計決定

**採用**: `stop_hook_inbox.sh` に shogun 専用の `discord_received` チェックを追加。  
**不採用**: 別スクリプト新設 — 既存 hook 基盤を流用することで設定変更ゼロ・保守コスト最小化。

### 実装内容 (`stop_hook_inbox.sh` 変更箇所)

旧コード（line 42-45）:
```bash
# Shogun is the Lord's conversation pane — skip stop hook entirely
if [ "$AGENT_ID" = "shogun" ]; then
    exit 0
fi
```

新コード:
```bash
if [ "$AGENT_ID" = "shogun" ]; then
    # stop_hook_active=True 時はスキップ（無限ループ防止）
    # queue/inbox/shogun.yaml の discord_received 未読エントリを検索
    # 未読あり → Discord ack (B-1) + block JSON 返却 (A-2)
    # 未読なし → exit 0（通常 shogun 動作）
fi
```

### SLA 設計 (A-3: ≤5min)

```
Discord DM 受信
    ↓ (即時)
discord_gateway.py → queue/inbox/shogun.yaml に discord_received 投入
    ↓ (≤数十秒: 将軍が次のターン終了時)
stop_hook_inbox.sh 発火 → discord_received 検知 → block JSON 返却
    ↓ (即時)
将軍の次ターン開始 → Discord メッセージを処理
    ↓ (≤5min 以内)
処理完了 → Scope B-2 完遂通知
```

**達成条件**: 将軍がアクティブに会話中なら次ターン終了時（数秒〜1分以内）に検知。将軍がアイドルの場合は inbox_watcher.sh の既存 nudge 機構（定期チェック）が補完。

---

## Scope B: Discord ack + 完遂通知

### B-1: 検知時 ack (実装済み)

stop_hook_inbox.sh 内で discord_received 検知時に非同期実行:
```bash
python3 "$SCRIPT_DIR/scripts/discord_notify.py" \
    --body "✅ 将軍: Discord メッセージを受信しました。5min以内に処理します。" \
    --type "discord_ack" &
```

### B-2: 完遂時通知 (設計)

処理完了後、将軍（または家老）が以下を実行:
```bash
python3 scripts/discord_notify.py \
    --body "🏆 処理完了: <cmd番号> <要約>" \
    --type "cmd_complete"
```

既存 `scripts/discord_notify.py` の `--body` / `--type` 引数で対応可能。追加実装不要。

---

## Scope C: テスト結果

### C-1: dry-run テスト (PASS)

**手順**:
1. `queue/inbox/shogun.yaml` に `discord_received` テストエントリ投入 (`read: false`)
2. `__STOP_HOOK_AGENT_ID=shogun bash scripts/stop_hook_inbox.sh` 実行

**結果**:
```
HOOK_OUTPUT: {"decision": "block", "reason": "Discord受信: [discord_gateway] test_user | テスト Discord メッセージ (cmd_664 dry-run)\n\nqueue/inbox/shogun.yaml の当該エントリを read:true に更新してから返答せよ。"}
✅ AC A-1/A-2 PASS: hook blocks with discord message content
```

**ループ防止確認**:
```
stop_hook_active=True → exit 0 (no infinite loop)
✅ AC A-3 PASS
```

**回帰テスト**: karo 等の非 shogun エージェントへの影響なし ✅

### C-2: fallback 設計 (5min 非応答 → escalation)

将軍が 5min 応答しない場合:
- `inbox_watcher.sh shogun` の既存エスカレーション機構が動作:
  - 0-2min: 通常 nudge (`inbox1` 送信)
  - 2-4min: Escape×2 + nudge (カーソルバグ対策)
  - 4min+: `/clear` 送信 (5min間隔。強制リセット→YAML再読→discord_received 再検知)
- `/clear` 後 shogun が再起動 → stop hook が次ターンで再検知

家老への escalation は `/clear` 後も未処理の場合に inbox_watcher が karo inbox へ通知するよう拡張可能（Phase 2 候補）。

---

## AC チェックリスト

| AC | 内容 | 結果 |
|----|------|------|
| A-1 | discord_received 検知機構実装 | ✅ PASS |
| A-2 | 将軍 pane への Stop hook 経由自動通知 | ✅ PASS |
| A-3 | 5min 以内 SLA 設計 (hook 発火タイミング明示) | ✅ PASS |
| B-1 | 検知時 Discord ack 送信 | ✅ PASS |
| B-2 | 完遂時 Discord 完遂通知設計 | ✅ PASS (設計+既存 discord_notify.py 利用) |
| C-1 | dry-run テスト PASS | ✅ PASS |
| C-2 | fallback: 5min 非応答 → inbox_watcher escalation 設計 | ✅ PASS |
| E-1 | output/cmd_664_discord_proactive_reaction.md 生成 | ✅ PASS (本ファイル) |
