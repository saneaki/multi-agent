# cmd_634 Scope C — cmd_631/cmd_633 回帰検証レポート

- **task_id**: subtask_634_scope_c_regression_test
- **担当**: ashigaru6
- **作成日時**: 2026-05-03 00:44 JST
- **対象**: 強化版 implementation-verifier による cmd_631 / cmd_633 回帰検証
- **判定**: AC13 PASS — 旧 verifier が見落とした欠陥を新版 verifier が検出

---

## 0. 強化版 verifier 前提確認

| check | result |
|---|---:|
| `grep -c "Layer 5\|TMUX_STATE_MISMATCH\|DASHBOARD_STALE\|STATE_VISIBILITY_GAP" /home/ubuntu/.claude/agents/implementation-verifier.md` | 8 |

確認行:
- `TMUX_STATE_MISMATCH`: L207
- `DASHBOARD_STALE`: L219
- `STATE_VISIBILITY_GAP`: L232
- `Layer 5: Reporting Quality Check`: L246
- output format 追記: L298-L300

前提条件「4件以上 hit」を満たす。

---

## 1. cmd_631 回帰テスト結果

### 1.1 対象概要

| item | result |
|---|---|
| commit | `9f15085 feat(cmd_631): session→Obsidian→Notion統合 ...` |
| archive | `scripts/archived/notion_session_log.sh` 存在 |
| old QC | `output/cmd_631_scope_e1_qc_report.md` は Go 判定 |
| origin差分 | `git log origin/main..HEAD --oneline` は空 |

### 1.2 Layer 別判定

| Layer / pattern | 判定 | 根拠 |
|---|---|---|
| L4 PUSH漏れ | PASS | `git log origin/main..HEAD --oneline` は空。未push差分なし。 |
| L4 STATUS漏れ | PASS | 本回帰対象の完了後未反映そのものは今回検出なし。 |
| L4 STATE_VISIBILITY_GAP | WARN | archive 後も `.claude/settings.json:66` に `bash /home/ubuntu/shogun/scripts/notion_session_log.sh ...` が残存。旧 script は `scripts/archived/` へ移動済みのため、Stop hook が存在しない旧 path を呼ぶ後続経路として残っていた。 |
| L5 報告品質 | WARN | 旧 QC は N4 で「参照確認 (scripts/ + instructions/, archived 除外) = 0件」と報告して Go 判定したが、`.claude/settings.json` を検証対象に含めず hook 残存を見落とした。 |

### 1.3 旧版見落としの実証

旧 QC (`output/cmd_631_scope_e1_qc_report.md`) は以下を根拠に Go とした。

- N4: `crontab -l | grep -c notion_session_log` = 0
- archive 配置 = 存在
- `scripts/ + instructions/` の参照 = 0件
- 結論: N1-N4 全 PASS / Go

しかし新版 verifier の `STATE_VISIBILITY_GAP` 観点で、data/side-effect の後続経路まで grep すると以下を検出する。

```text
/home/ubuntu/shogun/.claude/settings.json:66:
"command": "bash /home/ubuntu/shogun/scripts/notion_session_log.sh >> /tmp/notion_session_log.log 2>&1 || true"
```

これは「archive した script を、別の状態更新経路がまだ参照する」欠陥であり、旧 4-Layer / 旧 QC の確認範囲では PASS だったが、新版では WARN と判定できる。

---

## 2. cmd_633 回帰テスト結果

### 2.1 対象概要

| item | result |
|---|---|
| commit | `7b9db85 feat(cmd_633): KPI overhaul ...` |
| old QC | `output/cmd_633_scope_d_qc_report.md` は Go 判定 |
| hotfix | `93d4e38 feat(cmd_637+638): 4新列+失敗列redefine...` |
| Violation | `memory/Violation.md` No.23 に shelf-ware と State Visibility Gap を記録済み |

### 2.2 Layer 別判定

| Layer / pattern | 判定 | 根拠 |
|---|---|---|
| L4 PUSH漏れ | PASS | `git log origin/main..HEAD --oneline` は空。 |
| L4 STATUS漏れ | PASS | 完了後の未push/未反映は今回検出なし。 |
| L4 STATE_VISIBILITY_GAP | FAIL | `git show 7b9db85:scripts/cmd_kpi_observer.sh | grep ...` では `karo_self_clear` のコメント/報告用 count のみで、`gunshi_self_clear` / `karo_self_compact` / `gunshi_self_compact` の data supply が存在しない。dashboard schema/表示列は追加済みだったため shelf-ware。 |
| L5 報告品質 | WARN | `output/cmd_633_scope_d_qc_report.md` は dashboard.yaml field 存在、10列表示、script/cron/.gitignore を確認して Go としたが、列へ実測値が流入するかを検証していない。 |

### 2.3 旧版見落としの実証

旧 QC は以下を PASS として Go 判定した。

- `dashboard.yaml` に `karo_self_clear / gunshi_self_clear / karo_self_compact / gunshi_self_compact` が存在
- `dashboard.md` が 10列ヘッダで表示
- `detect_compact.sh` / `gunshi_self_clear_check.sh` / cron / `.gitignore` は確認済み

しかし cmd_633 当時の `cmd_kpi_observer.sh` は次の状態だった。

```text
13:#   6. karo_self_clear_check 発動 (... 報告用; dashboard 列なし)
147:# ── KPI 6: karo_self_clear_check 発動回数 (today, 報告用)
```

`gunshi_self_clear`, `karo_self_compact`, `gunshi_self_compact` の供給 logic は存在しない。cmd_637 後は以下の供給 logic が追加されている。

```text
178:KARO_SELF_CLEAR=...
181:GUNSHI_SELF_CLEAR=...
224:karo_self_clear, gunshi_self_clear = sys.argv[8], sys.argv[9]
248:'karo_self_clear': ...
249:'gunshi_self_clear': ...
250:'karo_self_compact': ...
251:'gunshi_self_compact': ...
```

`memory/Violation.md` No.23 も「列だけ追加 → 常時 None (実質 0)」「State Visibility Gap」と記録しており、cmd_633 の shelf-ware は事後実証済みである。

---

## 3. 旧版 vs 新版比較

| cmd | 旧版 / 旧QCの結果 | 新版 verifier の検出 | 新規検出 pattern |
|---|---|---|---|
| cmd_631 | Go / N1-N4 PASS | `.claude/settings.json` の旧 hook 残存を WARN | `STATE_VISIBILITY_GAP`, L5 報告品質 |
| cmd_633 | Go / N1-N3 PASS | 4新列の data supply 欠落を FAIL | `STATE_VISIBILITY_GAP`, L5 報告品質 |

旧版は「ファイル追加・列追加・cron登録・syntax・表示」を中心に確認していた。一方、新版は「追加された state/schema が実際の供給経路と接続されているか」「完了報告に inline 実測値と負例探索があるか」を見るため、旧版 PASS の欠陥を WARN/FAIL として検出できた。

---

## 4. AC13 達成判定

| AC | 判定 | 根拠 |
|---|---|---|
| AC1: cmd_631 回帰テストで新版 verifier が WARN/FAIL を検出 | PASS | `STATE_VISIBILITY_GAP` WARN + L5 WARN。 |
| AC2: cmd_633 回帰テストで STATE_VISIBILITY_GAP を検出 | PASS | cmd_633 当時の data supply 欠落、cmd_637 hotfix、Violation No.23 で三点実証。 |
| AC3: report 作成 | PASS | `output/cmd_634_scope_c_regression_report.md` 作成済み。 |
| AC13: 旧版見落とし → 新版検出 | PASS | cmd_631/cmd_633 とも旧 QC Go 後に、新版 pattern で WARN/FAIL を再現。 |

**総合判定: PASS。**

新版 implementation-verifier は、旧版が PASS とした cmd_631 / cmd_633 から `STATE_VISIBILITY_GAP` と L5 報告品質問題を検出した。AC13 の「旧 verifier が見落とし、新 verifier が検出」は満たされた。
