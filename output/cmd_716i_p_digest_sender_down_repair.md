# cmd_716i P_DIGEST_SENDER_DOWN 緊急修復レポート

- 作成: 2026-05-15 17:34 JST
- 担当: ashigaru2
- 親 cmd: cmd_716 Phase F (subtask_716i_phase_f_regression)

---

## 1. 根本原因 (Root Cause)

| 項目 | 内容 |
|---|---|
| 検出アラート | `P_DIGEST_SENDER_DOWN` (system_failure — never suppress) |
| 根本原因 | `scripts/lib/daily_digest.py` が Phase E で実装されたが、8:00 JST cron 登録が Phase F 残作業として未実施 |
| 状態 | `queue/alert_state.yaml` に `digest_liveness` セクションが存在せず、`check_digest_liveness()` が `last_success_at=None` を検出して `is_down=True` を返していた |
| suggestions_digest との混同 | なし。`suggestions_digest.sh` (09:05 JST cron) は候補サジェスト配信で別系統。`daily_digest.py` は行動中 cmd digest で完全に独立 |

### 詳細

Phase E (`cmd_716h`, ashigaru5 担当) で `daily_digest.py` が新設された際、Phase E のスコープとして "cron/systemd schedule は Phase F 候補" と明記 (`cmd_716h_phase_e_followup_pr.md §6-1`) され、8:00 JST 自動実行は未登録だった。

`shogun_in_progress_monitor.sh` の `check_pattern_digest_liveness()` は毎時起動時に `check_digest_liveness(ROOT)` を呼び出す。`alert_state.yaml.digest_liveness` セクションが存在しないため `last_success_at=None` と判定され、26h grace を超えたとして `P_DIGEST_SENDER_DOWN` アラートを発火し続けていた。

---

## 2. 修復手順 (Repair)

### 2-1. cron 登録 (F-8)

```bash
# 既存 crontab バックアップ
crontab -l > /tmp/crontab_backup_daily_digest_20260515.txt

# idempotent 追記 (daily_digest.py が未登録のことを確認してから実施)
(crontab -l; \
 echo "# cmd_716 Phase F: daily digest 8:00 JST (= UTC 23:00)"; \
 echo "0 23 * * * python3 /home/ubuntu/shogun/scripts/lib/daily_digest.py >> /home/ubuntu/shogun/logs/daily_digest.log 2>&1" \
) | crontab -
```

**登録結果**: `0 23 * * *` (UTC) = 8:00 JST 毎日

```
# 確認 (crontab -l 末尾)
# cmd_716 Phase F: daily digest 8:00 JST (= UTC 23:00)
0 23 * * * python3 /home/ubuntu/shogun/scripts/lib/daily_digest.py >> /home/ubuntu/shogun/logs/daily_digest.log 2>&1
```

### 2-2. 初回送信 (F-9)

dry-run で digest 生成を確認後、実送信を実施して liveness を初期化:

```bash
# dry-run
python3 scripts/lib/daily_digest.py --dry-run
# [daily_digest] DRY-RUN — count=1 oldest_stall_days=0
# [daily_digest] cmd_ids=['cmd_716']
# --- body ---
# 行動中 1 件 (cmd_716) | 最古滞留 0 日 | 詳細 dashboard 参照

# 実送信 (Discord DM)
python3 scripts/lib/daily_digest.py
# [daily_digest] sent: 行動中 1 件 (cmd_716) | 最古滞留 0 日 | 詳細 dashboard 参照
```

実送信成功。`alert_state.yaml.digest_liveness` が更新された:

```yaml
digest_liveness:
  last_attempt_at: '2026-05-15T17:30:21+09:00'
  last_success_at: '2026-05-15T17:30:21+09:00'
  consecutive_failures: 0
```

---

## 3. 検証 (Verification)

### 3-1. liveness ステータス確認

```python
from daily_digest import check_digest_liveness
status = check_digest_liveness('/home/ubuntu/shogun')
# {'is_down': False, 'hours_since_last': 0.002, 'last_success_at': '2026-05-15T17:30:21+09:00', 'consecutive_failures': 0}
```

`is_down=False` → P_DIGEST_SENDER_DOWN アラートは次回 shogun_in_progress_monitor 起動時に消える。

### 3-2. shogun_in_progress_monitor --dry-run 確認

```
[DRY-RUN] DETECT [P7-GHA-upsert-0件]: ...
[DRY-RUN] DETECT [P9_*]: × 3 件
[DRY-RUN] DETECT [P9b_*]: × 3 件 (SLA 72h超過)
2026-05-15 17:30 JST [in_progress_monitor] DRY-RUN: 7件検出
```

P_DIGEST_SENDER_DOWN は検出リストから**消えた** (修復前 8件 → 修復後 7件)。

### 3-3. 実送信リスク評価

| 項目 | 評価 |
|---|---|
| 重複通知リスク | 低。今回 1 回のみ手動送信 (通常は 8:00 JST 自動)。直近 24h で自動送信は未実施のため重複なし |
| 送信内容 | `行動中 1 件 (cmd_716) \| 最古滞留 0 日 \| 詳細 dashboard 参照` |
| 受信者 | 殿 (Discord DM) |

---

## 4. 残課題

| 項目 | ステータス |
|---|---|
| cron 登録 | ✅ 完了 (`0 23 * * *` UTC = 8:00 JST) |
| liveness 初期化 | ✅ 完了 (実送信で `last_success_at` 更新) |
| P_DIGEST_SENDER_DOWN 消去 | ✅ 次回 monitor 実行で自動消去 |
| suggestions_digest との混同 | ✅ なし (別系統を確認済み) |
| promoted_at 欠落による最古滞留 0 日 | 既知課題 (Phase F §6-3 参照)。dashboard.yaml 側修正が必要 (cmd_716 範囲外) |
