# cmd_716i Phase F: 横断回帰レポート

- 作成: 2026-05-15 17:34 JST
- 担当: ashigaru2
- 親 cmd: cmd_716 (judgement gate / alert suppression 整備)

---

## 1. 結論

Phase F は **PASS**。

| AC | チェック内容 | 結果 |
|---|---|---|
| F-1 | Phase A-E unit tests 一括実行 SKIP=0 | ✅ PASS — 123/123 |
| F-2 | cross-phase regression tests 追加・証明 | ✅ PASS — 4件追加 (TestCrossPhaseRegression) |
| F-3 | Phase E 残件分類 | ✅ 記録 (scope外 3件、実装不要 1件) |
| F-4 | GHA 25904789492 が cmd_716 本体 regression でないことを証明 | ✅ PASS — cmd_729系テスト失敗。cmd_716 tests all passed |
| F-5 | shogun_in_progress_monitor --dry-run で never-suppress 境界確認 | ✅ PASS |
| F-6 | cmd_704 git preflight | ✅ 実施済み (editable_files のみ commit) |
| F-7 | P_DIGEST_SENDER_DOWN 緊急調査 | ✅ 完了 (output/cmd_716i_p_digest_sender_down_repair.md) |
| F-8 | 8:00 JST cron idempotent 登録 | ✅ 完了 (`0 23 * * *` UTC) |
| F-9 | dry-run + liveness 更新経路確認 | ✅ 完了 (実送信成功、is_down=False) |

---

## 2. F-1: Phase A-E unit tests 一括実行

```
$ python3 -m pytest tests/unit/ -v
============================= 123 passed in 1.36s ==============================
SKIP=0
```

| テストファイル | 件数 | 結果 |
|---|---|---|
| test_gate_suppression.py (Phase B/C/D + F cross-phase) | 85 + 4 = 89 件 | PASS |
| test_daily_digest.py (Phase E) | 31 件 | PASS |
| test_discord_notify.py | 3 件 | PASS |
| **合計** | **123 件** | **PASS (SKIP=0)** |

---

## 3. F-2: cross-phase regression tests

`TestCrossPhaseRegression` (test_gate_suppression.py 末尾) として 4 件追加:

| テスト名 | 検証内容 |
|---|---|
| `test_phase_b_suppression_unchanged_by_phase_d_e` | Phase D/E データ存在下でも Phase B suppression が正常動作 |
| `test_never_suppress_boundaries_all_phases` | P7/P_GATE_ZOMBIE/P_DIGEST_SENDER_DOWN/JUDGEMENT_LOG_WRITE_FAILURE 全て never-suppress として識別 |
| `test_alert_state_integrity_after_phase_d_e_writes` | Phase D (judgement_log) + Phase E (digest_liveness) 書込みで alert_state 構造が保持される |
| `test_digest_liveness_and_zombie_are_independent` | Phase D zombie 検出と Phase E liveness が独立している (一方変化が他方に影響しない) |

---

## 4. F-3: Phase E 残件分類

| 残件 | 分類 | 理由 |
|---|---|---|
| cron/systemd schedule (§6-1) | **Phase F 実装対象 → 完了** | 8:00 JST cron 登録 + 初回送信実施 |
| action_required 昇格手順 (§6-2) | **scope外** | karo/殿の手動承認が境界。自動昇格は設計上不可 |
| promoted_at 欠落 dashboard 補正 (§6-3) | **scope外** | karo dashboard 生成側の修正が必要 (cmd_716 範囲外) |
| consecutive_failures 段階的 alert (§6-4) | **scope外** | Phase F 候補として残す。P_DIGEST_SENDER_DOWN 単一で十分 |

---

## 5. F-4: GHA 25904789492 regression evidence

**GHA run**: `25904789492` — "Multi-CLI Test Suite" — 2026-05-15 06:53 UTC

**トリガーコミット**: `0a7c12c` — `feat: cmd_716g Phase D — judgement_log + zombie 7日 alert + resolution`

**失敗テスト**:
```
not ok 211 gunshi_report schema has latest and history after migration (macOS only)
not ok 212 gunshi_report_append updates latest ... (macOS only)
not ok 213 action_required_sync reads latest candidates and legacy top-level fallback (Ubuntu + macOS)
```

**判定**: これらは `gunshi_report` スキーマ移行 (cmd_729 系) と `action_required_sync` のテストであり、**cmd_716 とは無関係**。

- cmd_716 の変更対象 (`gate_suppression.py`, `shogun_in_progress_monitor.sh`, `tests/unit/test_gate_suppression.py`) に関するテストは全て PASS。
- 失敗は cmd_729d (`gunshi_report` multi-history 移行) が同時進行中であったことによる既知失敗。
- cmd_716 の never-suppress 方針に対する regression ではない。

---

## 6. F-5: never-suppress 境界確認 (shogun_in_progress_monitor --dry-run)

```bash
$ bash scripts/shogun_in_progress_monitor.sh --dry-run
[DRY-RUN] DETECT [P7-GHA-upsert-0件]: ...
[DRY-RUN] DETECT [P9_d905ca4e]: 【要対応 滞留3日9時間】 ...
[DRY-RUN] DETECT [P9b_d905ca4e]: 🚨 SLA 72h超過 ...
[DRY-RUN] DETECT [P9_da822868]: 【要対応 滞留3日9時間】 ...
[DRY-RUN] DETECT [P9b_da822868]: 🚨 SLA 72h超過 ...
[DRY-RUN] DETECT [P9_328f4479]: 【要対応 滞留3日16時間】 ...
[DRY-RUN] DETECT [P9b_328f4479]: 🚨 SLA 72h超過 ...
2026-05-15 17:30 JST [in_progress_monitor] DRY-RUN: 7件検出
```

- **P_GATE_ZOMBIE_***: 発火条件不成立 (全 gate < 7日) ✓
- **P_DIGEST_SENDER_DOWN**: 発火なし (liveness 修復後) ✓
- **P7 (GHA upsert 0件)**: 発火継続 (never suppress, 正常) ✓
- **P9 / P9b**: 殿判断 gate 滞留アラート (suppressible, Phase B 管理) ✓

---

## 7. F-7/F-8/F-9: P_DIGEST_SENDER_DOWN 緊急対応

詳細: `output/cmd_716i_p_digest_sender_down_repair.md`

| 項目 | 内容 |
|---|---|
| 根本原因 | Phase E で daily_digest.py 実装済みだが cron 未登録 → last_success_at 未記録 → is_down=True |
| suggestions_digest との混同 | なし (suggestions_digest.sh は 09:05 JST、別系統) |
| 修復 | `0 23 * * *` UTC (= 8:00 JST) cron 登録 + 初回実送信 |
| liveness 状態 | `is_down=False`, `last_success_at='2026-05-15T17:30:21+09:00'`, `consecutive_failures=0` |
| 実送信内容 | `行動中 1 件 (cmd_716) \| 最古滞留 0 日 \| 詳細 dashboard 参照` |
| 重複通知リスク | なし (直近 24h で自動送信未実施、今回 1 回のみ) |

---

## 8. F-6: cmd_704 git preflight

- 作業前 dirty: `docs/dashboard_schema.json`, `memory/global_context.md`, `queue/external_inbox.yaml`, `queue/reports/ashigaru1_report.yaml`, `scripts/shc.sh` (他者分、commit 対象外)
- 本 cmd 変更対象 (editable_files):
  - `tests/unit/test_gate_suppression.py` — cross-phase tests 追加
  - `queue/alert_state.yaml` — digest_liveness 初期化 (runtime data)
  - `output/cmd_716i_phase_f_regression.md` — 本レポート
  - `output/cmd_716i_p_digest_sender_down_repair.md` — 修復レポート
  - `queue/reports/ashigaru2_report.yaml` — 完遂報告
  - `queue/tasks/ashigaru2.yaml` — status=done
  - `queue/inbox/ashigaru2.yaml` — read=true
- 他者の dirty ファイルは `git add` しない

---

## 9. cmd_716 Phase 全体サマリー

| Phase | 担当 | 内容 | 結果 |
|---|---|---|---|
| A | ashigaru3/5 | Schema coexist / gate_suppression 基盤 | PASS |
| B | ashigaru2 | Alert classification + suppression 規律 | PASS |
| C | ashigaru2/5 | P6 event ledger + dashboard detection | PASS |
| D | ashigaru2 | judgement_log + zombie 7日 alert + resolution | PASS |
| E | ashigaru5 | gate auto-register + daily_digest + liveness | PASS |
| **F** | **ashigaru2** | **横断回帰 + P_DIGEST_SENDER_DOWN 修復** | **PASS** |
