# cmd_659 実装報告書

**cmd**: cmd_659  
**title**: Action Required Pipeline 構造化 (Codex 案 F Phase 1)  
**completed_at**: 2026-05-08T02:50:00+09:00  
**qa_decision**: Pass (gunshi QC Go)

---

## 実装サマリー

5/8 00:00 JST の dashboard_rotate.sh 事故 (md 直編集分全消失) の恒久対応として、
Action Required Pipeline を構造化した。yaml を Single Source of Truth とし、
dashboard.md を完全 render artifact 化する Phase 1 実装を完遂。

---

## Scope 別実施結果

### Scope A: データ契約 (ash1)
- A-1: gunshi_report.yaml の result 配下に action_required_candidates schema 追加
- A-2: instructions/gunshi.md に「QC完了時 action_required_candidates 必須出力」明記
- A-3: normalize() 関数仕様明記 (全角→半角 NFKC / trim / lowercase / 連続空白1個)

### Scope D: 責務一本化 (ash1)
- D-1: instructions/common/dashboard_responsibility_matrix.md 新設 (canonical責務マトリクス)
- D-2: instructions/karo.md / gunshi.md / common/shogun_mandatory.md を canonical 参照に改修
- D-3: dashboard.md 直接編集禁止 (緊急例外時のみ将軍/家老の明示判断) 明文化

### Scope B: Sync Script (ash5)
- B-1: scripts/action_required_sync.sh 新設 — inbox watcher event 駆動、polling 禁止
- B-2: flock /var/lock/shogun_dashboard.lock 取得実装
- B-3: gunshi_report.yaml schema validate (不正 yaml は abort + log)
- B-4: issue_id stable hash dedup upsert (idempotent)
- B-5: status=resolved → dashboard.yaml.action_required_archive 移動
- B-6: P0/HIGH 新規追加時 notify.sh push + P_AR_<severity>_<issue_id> key 分離

### Scope C: Renderer 拡張 (ash5)
- C-1: generate_dashboard_md.py — ACTION_REQUIRED:START/END + ACHIEVEMENTS_TODAY:START/END 境界全置換
- C-2: 境界外セクション (🐸/📊/🔄/🏯/🛠️/📋) は input md からそのままコピー (touch 禁止)
- C-3: severity 並び替え強制 (P0→HIGH→MEDIUM→INFO) + badge prefix (🔥/⚠️/📌/ℹ️)
- C-4: atomic rename (tempfile + fsync + os.rename) + validation 失敗時前回 md 保持
- C-5: dashboard_rotate.sh 改修 — flock 同ロック + generate_dashboard_md.py 呼出

### Scope E: テスト (ash5)
- tests/dashboard_pipeline_test.sh 新設
- **全 36/36 PASS** (unit/golden/integration/concurrency/AUTO_CMD coexistence/rotate regression)
- E-1: normalize() 10 ケース + upsert + golden
- E-2: integration (5min 反映 assert)
- E-3: concurrency (10並列100回 race ゼロ)
- E-4: 文言整合 (canonical参照確認 + schema一致)
- E-5: AUTO_CMD coexistence (P_AR_* vs P9b/P9c 衝突なし)
- E-6: rotate regression (rotate後 action_required/achievements データ保持)

### Scope F: 移行 (ash3)
- F-1: dashboard.yaml.action_required に 10件 upsert (issue_id stable hash)
- F-2: dashboard.yaml.achievements — today 4件 / yesterday 21件 / day_before 5件 投入
- F-3: dashboard.md に ACTION_REQUIRED:START/END + ACHIEVEMENTS_TODAY:START/END 境界マーカー追加
- F-4: generate_dashboard_md.py 初回 render PASS (差分=境界マーカーのみ)

### Scope G: 軍師 QC (gunshi)
- **qa_decision: Pass**
- N1 (rotate regression 防止): aligned
- N2 (5min 反映チェーン): aligned
- N3 (AUTO_CMD coexistence): aligned

---

## 6リスク mitigation 動作確認

| リスク | 対策 | 確認結果 |
|---|---|---|
| R1: 二重 SoT | HTML comment 境界限定 (🚨と✅戦果のみ) | PASS |
| R2: 重複 issue | issue_id stable hash + normalize() | PASS |
| R3: renderer 破損 | 3層防御 (validation + atomic rename + 失敗時保持) | PASS |
| R4: 責務文書ドリフト | canonical体系 + 文言整合 test | PASS |
| R5: 重大 issue 埋もれ | severity 並び替え + badge + 自動 push | PASS |
| R6: rotate race | 同一 flock スコープ統合 | PASS |

---

## 成果物一覧

| ファイル | 種別 | 備考 |
|---|---|---|
| scripts/action_required_sync.sh | 新規 | inbox watcher event 駆動 Sync |
| tests/dashboard_pipeline_test.sh | 新規 | 36件 PASS |
| instructions/common/dashboard_responsibility_matrix.md | 新規 | canonical 責務マトリクス |
| scripts/generate_dashboard_md.py | 改修 | ACTION_REQUIRED/ACHIEVEMENTS 境界置換 |
| scripts/dashboard_rotate.sh | 改修 | flock + renderer 経由化 |
| instructions/gunshi.md | 改修 | step 8.8 追加 |
| instructions/karo.md | 改修 | canonical 参照化 |
| instructions/common/shogun_mandatory.md | 改修 | rule#1 canonical 参照化 |
| dashboard.yaml | 更新 | action_required 10件 / achievements 30件 |
| dashboard.md | 更新 | 境界マーカー追加 / severity badge 適用 |
| output/cmd_659_risk_mitigation_plan.md | 既存 | 6リスク対応方針 (事前策定) |
