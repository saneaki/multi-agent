# cmd_731 β-1 reality_check 3検知追加 + done漏れ修復

**作成**: 2026-05-16T11:16:36+09:00
**担当**: ashigaru4 (subtask_731e_beta1_reality_check_rules)
**親 cmd**: cmd_731 (監視層補強・silent silence 構造除去)

---

## 実装概要

### AC-1: check_dashboard_senka_empty

`scripts/lib/status_check_rules.py` に追加。

- `achievements.today` がリスト/dictのどちらでも空判定可能
- JST 12:00 以降かつ戦果空 → `"PENDING: dashboard 戦果が当日 N時間空"`
- 12:00 前または戦果あり → `"ok"`

### AC-2: check_frog_unset

同モジュールに追加。

- `frog.today` が `null`/未設定 かつ JST 18:00 以降 → `"PENDING: frog 未設定"`
- frog 設定済みまたは 18:00 前 → `"ok"`

### AC-3: check_metrics_stale

同モジュールに追加。

- `metrics[-1].date`（`date_jst` フォールバック）を JST 午前0時と解釈
- 現在 JST 時刻との差が 36h 以上 → `"PENDING: 運用指標 stale (Nh)"`
- 直近または空 → `"ok"`

### AC-4: check_ash_done_pending 修正

`DONE_MAX_AGE_MIN = 6 * 60` 定数を削除。

変更前:
```python
if status == "done":
    if not (30 <= age_min < DONE_MAX_AGE_MIN):
        continue
```

変更後:
```python
if age_min < 30:
    continue
```

`done` / `completed_pending_karo` ともに 30分以上で PENDING。上限なし。

### AC-1〜3 wiring: shogun_reality_check.sh

```bash
RESULT7=$(run_rule_check check_dashboard_senka_empty)
handle_check_result "7" "${RESULT7}" "yes"

RESULT8=$(run_rule_check check_frog_unset)
handle_check_result "8" "${RESULT8}" "no"

RESULT9=$(run_rule_check check_metrics_stale)
handle_check_result "9" "${RESULT9}" "no"
```

「全6項目」を「全9項目」に更新。

---

## テスト結果

```
tests/unit/test_status_check_rules.py  23 passed, 0 skipped
bash -n scripts/shogun_reality_check.sh → SYNTAX_OK
```

---

## 検証

| AC | 結果 |
|----|------|
| B1-1 新3検知追加+CHECKS登録 | PASS |
| B1-2 DONE_MAX_AGE_MIN撤廃 | PASS |
| B1-3 reality_check.sh 9検知 | PASS |
| B1-4 unit tests 23 PASS SKIP=0 | PASS |
| B1-5 bash -n + pytest | PASS |

---

## 変更ファイル

- `scripts/lib/status_check_rules.py` — 3関数新設、AC-4修正、JST helper追加
- `scripts/shogun_reality_check.sh` — RESULT7/8/9追加、9項目メッセージ
- `tests/unit/test_status_check_rules.py` — 新設 (23テスト)
