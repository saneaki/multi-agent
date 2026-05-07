# cmd_660 軍師統合戦略 (Z案)

| 項目 | 値 |
|------|-----|
| 軍師 | gunshi (Opus+T) |
| 統合 QC 日時 | 2026-05-08 04:00 JST |
| **Z 案** | **cmd_661 = Verified Completion Gate (event 駆動 hook + PostToolUse Bash hook 二段防御)** |

---

## Executive Summary (300 words 以内)

cmd_657-659 で連続発生した 3 種の規律違反 (cmd_657 報告漏れ / cmd_658 永続化漏れ / cmd_659 dashboard 反映漏れ) を 4 足軽 + 1 補足の独立調査で再分析した結果、**共通真因は「人間宣言 done の手動 fan-out」**。足軽が `task_completed` を報告する直前の **verification gate が機構として欠落** していた。

ash1 (Opus+T) は cmd_661 として「**C+: verifier mandatory gate + commit-before-done 順序変更**」、ash5 (Opus+T) は「**案 C cmd_complete event 駆動 hook (一次) + 案 B PostToolUse Bash hook (二段)**」、ash7 (Codex) は「**P1-C を Verified Completion へ格上げ + cmd_599 修正 = 30分探索ではなく 1行承認 gate**」を推奨。**3/5 が「自動 verification gate」を共通結論**。

ash6 (Codex) の Type A/B/C/D 分類は Z案の前提となる真因記述として採用。ash4 (Opus+T) の補足分析は ash1 と概ね一致 (P1=C+, P3=B 採択)。

**Z案**: cmd_661 として **「足軽 task_completed report 直前に verifier (artifact 存在 + git status clean + AC 表記一致) が mandatory gate として fire する二段防御 hook」を実装**。Phase 3-A (基幹実装) を cmd_661、Phase 3-B (試運用観察) を cmd_662 に配分。P2 は cmd_659 で解決済のため別 cmd 不要。

殿への判断: **「cmd_661 発令: Z案を採択」1 行で裁可可能**。

---

## 5レポート比較表

| 観点 | ash1 (Opus+T) | ash4 (Opus+T 補足) | ash5 (Opus+T) | ash6 (Codex) | ash7 (Codex) |
|------|---------------|-------------------|---------------|--------------|--------------|
| **担当 Scope** | A-2 #40 RCA | A-2 補足 | A-3 #45 Phase3 設計 | A-4 共通真因 | A-5 [提案-4] 再評価 |
| **真因認識** | dispatch 漏れ → 完遂確認漏れに重心移動 | (ash1 と概ね一致) | cmd_complete event hook 不在 | 人間宣言 done の手動 fan-out (Type A/B/C/D) | P1-C 不在 = 30分探索が必要 |
| **cmd_661 案** | **C+: verifier mandatory gate + commit-before-done** | P1=C+ / P3=B 採択 | **案 C event 駆動 hook (一次) + 案 B PostToolUse hook (二段)** | (Z案前提を提供) | **P1-C → Verified Completion 格上げ + cmd_599 修正** |
| **検出率** | — | — | 67-100% | — | — |
| **P2 評価** | cmd_659 で解決済 | — | (Phase3 範囲外) | — | cmd_659 で部分実現 |
| **採用優先度** | 高 (実装直結) | 中 (ash1 補完) | **最高 (実装具体化)** | 高 (前提整理) | 高 (思想統合) |

### 共通点 (consensus, 3/5 以上同意)

| # | 内容 | 同意者 |
|---|------|--------|
| 1 | **自動 verification gate が必要** (足軽宣言 done だけでは不十分) | ash1 / ash5 / ash7 (3/5) |
| 2 | **真因は人間宣言の手動 fan-out** | ash6 (前提) / ash1 / ash7 (3/5) |
| 3 | **P2 は cmd_659 で解決済 = cmd_661 範囲外** | ash1 / ash7 (2/5、ash5 は Phase3 範囲外で言及せず) |

### 相違点 (disagreement)

| # | 論点 | A 派 | B 派 |
|---|------|------|------|
| 1 | hook 実装層 | ash5: cmd_complete event 駆動 hook (一次) | ash1/ash7: artifact 存在確認 + git clean (gate) |
| 2 | gate 強度 | ash1: mandatory (block) | ash7: 1行承認 (人間 in the loop) |

→ **収束**: ash5 の event 駆動 hook (機械側 gate) と ash7 の 1行承認 (人間側 gate) は **二段防御として両立可能**。ash1 の mandatory は ash5 の hook 内で実装、ash7 の人間承認は hook 通過後の最終 gate として配置。

### 補完点 (unique_insight)

- **ash5**: 案 B (PostToolUse Bash hook) を二段防御として配置 — event 駆動 hook 漏れの fail-safe として価値高
- **ash6**: Type A/B/C/D 分類 (足軽 git 省略 / karo dashboard 漏れ / 指示解釈ミス / D) は Z 案の真因前提として採用
- **ash7**: cmd_599 修正の方向 = 30分探索ではなく 1行承認は、ash1 の C+ と統合可能

---

## Z案 (統合方針)

### cmd_661 = Verified Completion Gate

```
[足軽 task_completed 宣言]
    ↓ (event)
[案C: cmd_complete event 駆動 hook 発火]
    ↓
[案B: PostToolUse Bash hook 二段防御]
    ↓
[Verifier mandatory gate (ash1 C+):
  - artifact 存在確認 (output/*.md, scripts/*.sh 等)
  - git status clean (uncommitted 変更なし)
  - AC 表記一致 (task YAML AC vs report AC)
]
    ↓ (gate PASS)
[ash7 1行承認 gate (人間 in the loop, optional)]
    ↓ (承認)
[karo inbox に task_completed 配送]
```

### 実装範囲

- **cmd_661 (Phase 3-A)**: 機械側 gate (event 駆動 hook + PostToolUse hook + verifier) の基幹実装
- **cmd_662 (Phase 3-B)**: 試運用観察 + 不具合修正 + ash7 1行承認 gate の追加検討

### 配置先 script

- 推定: `scripts/cmd_complete_notifier.sh` (既存 hook の拡張) + `scripts/verifier.sh` (新設) + Claude Code `~/.claude/hooks/post_tool_use_*.sh`

---

## north_star 3点照合

| N | 評価 |
|---|------|
| **N1 (#40 + #45 + [提案-4] 全件カバー)** | aligned — #40 (家老役割集中) は P2 cmd_659 解決済 / #45 (Phase3 設計) は ash5 案で明示 / [提案-4] (cmd_597) は ash7 で再評価済 |
| **N2 (cmd_658/659 再発防止直結)** | aligned — cmd_658 永続化漏れ + cmd_659 dashboard 反映漏れ は verifier の 3 チェック (artifact + git + AC) で構造的に検出可能 |
| **N3 (殿の判断 1 行明確性)** | aligned — 「cmd_661 発令: Z案を採択」1 行で裁可可能 |

---

## 後続 cmd リスト

| cmd | 概要 | 発令タイミング |
|-----|------|---------------|
| **cmd_661** | Verified Completion Gate 基幹実装 (case C event hook + 案B PostToolUse hook + verifier mandatory gate) | 殿裁可後即時 |
| cmd_662 | cmd_661 試運用 1週間観察 + 不具合修正 + ash7 1行承認 gate 追加検討 | cmd_661 完遂後 |

cmd_622 番号衝突 (ash5 指摘) → cmd_661 振替で解消。

---

## 殿への判断委ね事項

なし (Z案で統合済)。ただし cmd_662 の ash7 1行承認 gate (人間 in the loop) を「自動化を優先 / 1行承認を残す」のいずれにするかは cmd_662 着手時に再判断。

---

## 軍師結論

5 足軽の独立調査が **「自動 verification gate」** に収束。Z案として cmd_661 = 二段防御 hook + verifier mandatory gate の即時発令が合理的。**Conditional 条件なし、Go (Z案 採択推奨)**。
