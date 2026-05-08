# cmd_675 再評価: 12件 skill候補 既存スキル統合監査

**実施日時**: 2026-05-08T13:48 JST
**実施者**: gunshi (軍師, Opus+T)
**親 cmd**: cmd_675 (殿指示による cmd_675 正式実装停止 → 統合可能性精査)
**前提 commit**: 3aafb82 (新規 2 SKILL.md 採用保留・破棄候補)

---

## 1. 監査背景

将軍指示により cmd_675 の正式実装を停止。ashigaru4 が `skill-creation-workflow §2 (既存スキルとの統合検討)` を十分実施せず新規 SKILL.md 2 件を commit/push したため、cmd_675 全体を再評価する。

**監査対象**: 12件 skill候補
**統合先候補**: `/home/ubuntu/.claude/skills/` (236件) + `/home/ubuntu/shogun/skills/` (25件) = **261 既存スキル**

**分類軸**:
- **a**: 既存スキルに統合可能 (統合先 + 統合後行数見込み記録)
- **b**: 新規作成必要 (独立ドメイン or 統合後 ≥500行)
- **c**: 棄却 (既存スキル完全包含 / 5行以下の自明 / 1回限り対処 / 既存実装済み)

---

## 2. 監査マトリクス (12 候補 × 既存スキル)

### 候補 1: shogun-gas-clasp-rapt-reauth-fallback

| 項目 | 内容 |
|---|---|
| 実体 | `/home/ubuntu/shogun/skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` ✅ 存在 |
| 概要 | clasp push invalid_grant/invalid_rapt 復旧プロトコル (cmd_565) |
| 既存包含 | 自身が既に独立スキル化完了 (battle_tested cmd_486/cmd_564/cmd_565) |
| **判定** | **c (棄却 — 既存実装済み)** |
| 理由 | 新規作成も統合も不要。SKILL.md 既存。残作業は dashboard 🛠️ 承認待ち → ✅実装済み 化 + skill_history.md append のみ (運用フロー、cmd_675 範囲外) |
| 統合後行数 | N/A (既存維持) |

---

### 候補 2: shogun-gas-automated-verification

| 項目 | 内容 |
|---|---|
| 実体 | `/home/ubuntu/shogun/skills/shogun-gas-automated-verification/SKILL.md` ✅ 存在 |
| 概要 | GAS (clasp 3.x) 自動検証基盤スキル (cmd_567 battle_tested 5点) |
| 既存包含 | 自身が既に独立スキル化完了 |
| **判定** | **c (棄却 — 既存実装済み)** |
| 理由 | 候補1と同様、新規作成も統合も不要。dashboard ✅実装済み 化のみ |
| 統合後行数 | N/A (既存維持) |

---

### 候補 3: SC-667 / codex-context-pane-border

| 項目 | 内容 |
|---|---|
| 実体 | `/home/ubuntu/shogun/skills/codex-context-pane-border/SKILL.md` ⚠️ commit 3aafb82 で作成済 (採用保留) |
| 概要 | SQLite 二段階照合方式 (cmd_667/671) — Codex 0.129.0 rollout file 検出 |
| 行数 | 135 行 (新規) |
| 既存統合候補 | (a) `shogun-tmux-busy-aware-send-keys` — tmux pattern 共通だが send-keys 主題で異なる<br>(b) `shogun-systemd-user-cron-healthcheck-pattern` — 常駐 healthcheck で類似だが SQLite 照合は固有 |
| **判定** | **c (棄却 — 1 事例のみで battle_tested 弱)** |
| 理由 | • cmd_667 (failure) → cmd_671 (修復) の 1 instance のみで battle_tested<br>• Codex 0.129.0 specific (将来 0.130.0+ で構造変化リスク)<br>• 既存パターン (tmux + 常駐検出) と独立性が薄い<br>• 1ヶ月運用観察後に再評価推奨。それまで dashboard 🛠️ 承認待ち維持 + skills/codex-context-pane-border/ の保留扱い (削除はしない) |
| 統合後行数 | N/A (棄却保留) |

---

### 候補 4: codex-skill-index

| 項目 | 内容 |
|---|---|
| 実体 | `/home/ubuntu/shogun/skills/codex-skill-index/SKILL.md` ⚠️ commit 3aafb82 で作成済 (採用保留) |
| 概要 | Codex 向け 232 skill 索引 + trigger phrase 互換性分類 (cmd_663) |
| 行数 | 143 行 (新規) |
| 既存統合候補 | (a) `skill-stocktake` — skill 監査スキル、本候補は「索引」目的で類似ドメイン<br>(b) `skill-creator` — 作成スキル、検索用途と異なる<br>(c) `skill-creation-workflow` — 候補処理プロセス、本候補と用途分離 |
| **判定** | **a (統合可能 → `skill-stocktake` に Codex 互換性索引セクション追加)** |
| 理由 | • skill-stocktake は既に skill 群の品質監査を実施<br>• 本候補の「索引 + Codex 互換性分類」は skill-stocktake の派生機能として自然<br>• 232 skill matrix (◎197/○29/×6) を skill-stocktake の audit 結果として引き継ぎ可能 |
| 統合後行数 | skill-stocktake (推定 ~150行) + codex-skill-index 抜粋 100行 = **約 250 行** (≤500 行で統合妥当) |

---

### 候補 5: shogun-autonomous-compaction-management

| 項目 | 内容 |
|---|---|
| 実体 | なし (dashboard 候補のみ) |
| 概要 | 自律 compaction 管理 cron + self-notify + 動的 context (cmd_586/592) |
| 既存統合候補 | (a) `strategic-compact` — manual /compact 提案 (補完関係)<br>(b) `continuous-learning-v2` — instinct/skill 進化 (異なる)<br>(c) `shogun-compaction-log-analysis` — post-mortem 分析 (補完関係)<br>(d) `shogun-precompact-snapshot-e2e-pattern` — snapshot 連携 (補完関係) |
| **判定** | **a (統合可能 → `strategic-compact` に「自律実装」セクション追加)** |
| 理由 | • strategic-compact は manual /compact ベース<br>• 本候補の cron + self-notify は strategic-compact の自動化版として自然<br>• shogun-compaction-log-analysis (post-mortem) と関連参照で完結 |
| 統合後行数 | strategic-compact (~80行) + 自律実装 100行 = **約 180 行** |

---

### 候補 6: shogun-deploy-verify-cycle

| 項目 | 内容 |
|---|---|
| 実体 | なし (dashboard 候補のみ) |
| 概要 | shelf-ware 防止 deploy & verify cycle (Stage 1-4, cmd_593/596) |
| 既存統合候補 | (a) `verification-loop` — 包括的検証 (汎用)<br>(b) `shogun-systemd-user-cron-healthcheck-pattern` — 登録確認 (Stage 3 相当)<br>(c) `shift-left-validation-pattern` — 検証早期化 (Stage 1 相当) |
| **判定** | **a (統合可能 → `verification-loop` に「Stage 1-4 deploy & verify cycle」セクション追加)** |
| 理由 | • verification-loop は汎用検証スキルで Stage 別 cycle 概念が欠落<br>• 本候補の Stage 1-4 (commit/配置/登録/実行ログ) は verification-loop の構造化拡張として自然<br>• shelf-ware 文脈は shogun特有だが「deploy & verify cycle」自体は汎用 |
| 統合後行数 | verification-loop (~120行) + Stage 1-4 cycle 80行 = **約 200 行** |

---

### 候補 7: shogun-report-history-mechanism

| 項目 | 内容 |
|---|---|
| 実体 | なし (dashboard 候補のみ) |
| 概要 | report yaml history[] append-only Hybrid pattern (cmd_595) |
| 既存統合候補 | (a) `skill-creation-workflow` — skill 候補処理 (関連)<br>(b) `shogun-bloom-config` — shogun config パターン<br>(c) `notion-session-log-section-pattern` — log section append-only |
| **判定** | **a (統合可能 → `skill-creation-workflow` または新設 shogun-runtime-data-patterns に統合)** |
| 理由 | • report yaml history[] append-only は shogun runtime data pattern の 1 つ<br>• 単独スキル化するには小さい (推定 30-50 行)<br>• skill-creation-workflow に「report YAML history append-only pattern」付録として統合可能 |
| 統合後行数 | skill-creation-workflow (~120行) + history 機構 50行 = **約 170 行** |

---

### 候補 8: shogun-rule-inventory-pattern

| 項目 | 内容 |
|---|---|
| 実体 | なし (dashboard 候補のみ) |
| 概要 | shogun ルール ID 棚卸 grep 戦略 + qc_checklist 読取 (ash3 cmd_566) |
| 既存統合候補 | (a) `skill-stocktake` — 監査ドメイン (関連)<br>(b) `s-check` — チェック系統 (関連) |
| **判定** | **c (棄却 — 5行以下の自明手順)** |
| 理由 | • 「rule ID 一覧 grep + qc_checklist.yaml 読取」は 5 行以下のスクリプトで充足<br>• `grep -E '^[A-Z][0-9]+' instructions/*.md` 程度の手順<br>• スキル化価値が低い (1 sh script で十分) |
| 統合後行数 | N/A |

---

### 候補 9: shogun-qc-auto-check-naming-mode-pattern

| 項目 | 内容 |
|---|---|
| 実体 | なし (dashboard 候補のみ) |
| 概要 | qc_auto_check.sh standalone サブコマンド追加 pattern (cmd_552) |
| 既存統合候補 | (a) `s-check` — 既存 qc 自動チェック<br>(b) `shogun-readme-sync` — ファイル同期パターン |
| **判定** | **c (棄却 — 1 sh script の機能拡張で汎用化価値低)** |
| 理由 | • qc_auto_check.sh への「naming サブコマンド追加」は 1 script の機能拡張<br>• 他 sh script への横展開価値が薄い (各 script で独立判断)<br>• スキル化不要、existing script のリファクタリング範疇 |
| 統合後行数 | N/A |

---

### 候補 10: pre-gate-vs-true-gate-separation-pattern

| 項目 | 内容 |
|---|---|
| 実体 | なし (dashboard 候補のみ) |
| 概要 | 自動 pre-gate + manual true gate 二段構成 (cmd_596) |
| 既存統合候補 | (a) `quality-gate` — 品質ゲート (汎用)<br>(b) `shift-left-validation-pattern` — 検証早期化<br>(c) `verification-loop` — 検証ループ |
| **判定** | **a (統合可能 → `shift-left-validation-pattern` に「2段構造 (pre-gate + true gate)」追加)** |
| 理由 | • shift-left-validation-pattern は検証早期化の汎用スキル<br>• 本候補の「自動 pre-gate (early) + manual true gate (late)」は shift-left の二段構成として自然<br>• quality-gate との重複も少なく、shift-left の補強が最適 |
| 統合後行数 | shift-left-validation-pattern (~100行) + 2段構造 60行 = **約 160 行** |

---

### 候補 11: shogun-suggestions-lifecycle-management

| 項目 | 内容 |
|---|---|
| 実体 | なし (dashboard 候補のみ) |
| 概要 | suggestions.yaml append-only + cron triage + status migration (cmd_596) |
| 既存統合候補 | (a) `notion-session-log-section-pattern` — append-only パターン (一部関連)<br>(b) `shogun-bloom-config` — shogun内部 config |
| **判定** | **b (新規必要 — shogun内部 tooling 固有 + 独立ドメイン)** |
| 理由 | • shogun 固有の suggestions.yaml lifecycle は他プロジェクト類似なし<br>• cron triage + status migration は独立ドメイン (pending → deferred → resolved の状態機械)<br>• 既存スキルへの統合先が見つからない<br>• ただし battle_tested は cmd_596 の 1 instance のみ → 1ヶ月運用観察後に正式 SKILL.md 化推奨 (棚上げ) |
| 統合後行数 | 新規スキル想定 約 150-200 行 (shogun内部 tooling) |

---

### 候補 12: shogun-gemini-thinking-token-guard

| 項目 | 内容 |
|---|---|
| 実体 | `/home/ubuntu/shogun/skills/shogun-gemini-thinking-token-guard/SKILL.md` ✅ 存在 |
| 概要 | Gemini API thinking token が maxOutputTokens 予算を消費する問題 |
| 既存包含 | 自身が既に独立スキル化完了 (silent inconsistency: skill_history.md 未登録) |
| **判定** | **c (棄却 — 既存実装済み)** |
| 理由 | 候補1/2と同様、新規作成も統合も不要。skill_history.md append + dashboard 🛠️ → ✅実装済み 化のみ (運用フロー、cmd_675 範囲外) |
| 統合後行数 | N/A (既存維持) |

---

## 3. 判定サマリ

| 分類 | 件数 | 候補 |
|------|------|------|
| **a (統合可能)** | 5件 | codex-skill-index / shogun-autonomous-compaction-management / shogun-deploy-verify-cycle / shogun-report-history-mechanism / pre-gate-vs-true-gate-separation-pattern |
| **b (新規必要)** | 1件 | shogun-suggestions-lifecycle-management (1ヶ月観察後 正式化推奨) |
| **c (棄却)** | 6件 | shogun-gas-clasp-rapt-reauth-fallback (既存実装済) / shogun-gas-automated-verification (既存実装済) / SC-667/codex-context-pane-border (1事例のみ→保留再評価) / shogun-rule-inventory-pattern (5行以下自明) / shogun-qc-auto-check-naming-mode-pattern (1 script拡張) / shogun-gemini-thinking-token-guard (既存実装済) |

---

## 4. commit 3aafb82 採用保留 2 SKILL の処遇

| skill | 判定 | 推奨処遇 |
|---|---|---|
| codex-skill-index (143行) | a (skill-stocktake 統合) | (1) skills/codex-skill-index/SKILL.md を保留維持 (削除しない)<br>(2) cmd_675b で skill-stocktake への統合 cmd を発令<br>(3) 統合完了後 skills/codex-skill-index/ ディレクトリを削除 |
| codex-context-pane-border (135行) | c (1事例のみ保留) | (1) skills/codex-context-pane-border/SKILL.md を保留維持 (削除しない)<br>(2) 1ヶ月運用観察 (2026-06-08 まで)<br>(3) 観察後に再評価 — battle_tested 強化されれば正式採用、変わらなければ削除 |

**両者とも本 cmd_675 では正式採用しない**。commit 3aafb82 はそのまま git に残し、後続 cmd_675b で各々の処遇を実装する。

---

## 5. 殿への提示事項 (cmd_675b 起案資料)

| ID | 内容 | 推奨 |
|---|---|---|
| L-1 | 既存実装済み 3件 (gas-clasp / gas-automated / gemini-thinking-token-guard) を skill_history.md append + dashboard ✅実装済み 化 | 即実施 |
| L-2 | 統合可能 5件 (a) を順次 cmd_675b-1〜5 として既存スキル統合 cmd 発令 | 段階実施 |
| L-3 | shogun-suggestions-lifecycle-management (b) を 1ヶ月運用観察後 (2026-06-08) に正式 SKILL.md 化判断 | 棚上げ |
| L-4 | codex-context-pane-border (c) を 1ヶ月観察後 (2026-06-08) に削除 or 正式採用判断 | 棚上げ |
| L-5 | rule-inventory + qc-auto-check-naming (c) を dashboard 🛠️ から削除 (棄却理由を memory/skill_history.md に記録) | 即実施 |

---

## 6. AC 自己照合

| AC | 内容 | 結果 |
|---|---|---|
| R-1 | 12件全候補を漏れなく監査 | ✅ §2 で全 12 件分類 |
| R-2 | /home/ubuntu/.claude/skills/ + /home/ubuntu/shogun/skills/ 既存スキル確認 | ✅ 261 既存スキル中、対象候補に対し関連 20+ スキルを統合先候補として参照 |
| R-3 | 各候補を a/b/c 分類 + 根拠 + 統合後行数見込み記録 | ✅ §2 で各候補ごと判定 + 行数見込み記録、§3 サマリ |
| R-4 | commit 3aafb82 の2新規SKILL.md評価 + 正式採用しない | ✅ §4 で 2 件保留・破棄評価、両者とも cmd_675 では正式採用しない明記 |
| R-5 | output/cmd_675_skill_integration_audit.md + gunshi_report.yaml 記録 | ✅ 本ファイル + gunshi_report.yaml subtask_675_skill_integration_audit エントリ追記 |

---

## 7. 結論

**12 候補の最終判定: a=5 / b=1 / c=6**

**正式採用すべき新規 SKILL.md は 0 件** (b=1 は 1ヶ月観察後判断、c=6 は棄却)。
**統合可能 5 件 (a) は cmd_675b-1〜5 として段階実施推奨**。
**既存実装済み 3 件 (gas-clasp / gas-automated / gemini-thinking-token-guard)** は dashboard ✅実装済み 化のみ。

commit 3aafb82 の 2 SKILL.md は保留扱いとし、cmd_675 での正式採用は行わない。

殿御裁可後、cmd_675b として段階実施を起案する。

---

(cmd_675 audit report end)
