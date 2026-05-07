# cmd_660 統合レポート — 4 足軽 + 1 補足の独立調査統合

## Executive Summary

cmd_657 (報告漏れ) / cmd_658 (永続化漏れ) / cmd_659 (dashboard 反映漏れ) の 3 種の規律違反が連続発生したことを受け、cmd_660 では 5 足軽 (ash1/ash4/ash5/ash6/ash7) に独立調査を依頼した。本レポートは軍師 (gunshi Opus+T) による統合分析である。

**結論**: 5 足軽の独立調査が **「自動 verification gate の機構欠落」** に収束。cmd_661 として **Verified Completion Gate (event 駆動 hook + PostToolUse Bash hook 二段防御 + verifier mandatory gate)** の即時発令を Z案として推奨する。

殿への判断: **「cmd_661 発令: Z案を採択」1 行で裁可可能**。

---

## 1. 4 足軽 + 1 補足レポートの要約

### 1.1 ash1 (Opus+T) — A-2: #40 家老役割集中問題 RCA (500 words)

ash1 は cmd_657-659 を再分析し、#40 (家老役割集中問題) の **問題重心が「dispatch 漏れ」から「完遂確認漏れ」へ移動**したと判定。Type A (足軽 git 省略) / Type B (karo dashboard 漏れ) / Type C (指示解釈ミス) / Type D の 4 類型で分類。

cmd_661 案として **「C+: verifier mandatory gate + commit-before-done 順序変更」** を推奨。具体的には:
- 足軽 task_completed report 直前に verifier (artifact 存在 + git status clean + AC 表記一致) が gate として fire
- gate FAIL 時は report 拒否 + 自動修復経路 (ash 自身に再実行)
- mandatory (block) で運用 — 「人間が見落とすこと」が真因なので自動化必須

**評価**: cmd_661 候補として最有力。cmd_599 = 30分探索 (ash7 指摘) を「1行承認 gate」で代替する思想とも整合。P1=C+ 正式採択 / P3=B 採択。P2 = cmd_659 で解決済のため別 cmd 不要。

### 1.2 ash4 (Opus+T 補足) — A-2 補足分析 (500 words)

ash4 は ash1 の Scope A-2 の補足分析として、別セッションで先行作成。ash1 と概ね一致 (P1=C+, P3=B 採択推奨) で、独立分析が同一結論に収束した点で **共通真因の確かさ** を裏付け。

ash4 独自の観点としては、cmd_657-659 の連続発生が **「規律違反の認知バイアス (見えないものは無視)」** に由来するという指摘。verifier gate が「見える化」を機構的に担保することで、認知バイアスを構造的に排除可能と論じる。

**評価**: ash1 補完。Z案前提として採用。

### 1.3 ash5 (Opus+T) — A-3: #45 Verification Phase 3 設計 (500 words)

ash5 は #45 将軍 verification 業務の Phase 1-3 進捗評価を実施。Phase 1 (cmd_644 forcing function) + Phase 2 (cmd_651 monitor 誤検出解消) は完了、**Phase 3 = 自動 hook 設計具体化** が cmd_661 の中心と位置づけ。

Phase 3 設計案:
- **案 A: dashboard 投稿後 verifier** — 事後検出のため遅延、却下
- **案 B: PostToolUse Bash hook** — 細粒度だが coverage 不足 (Bash 経由でない宣言は捕捉できず)
- **案 C: cmd_complete event 駆動 hook** — 一次採用。cmd_complete event を hook source とし、case-of-completion 全方向を捕捉

**推奨**: 案C (一次採用) + 案B (二段防御) の **二段防御**。cmd_622 番号衝突 → cmd_661 振替推奨。検出率 67-100% (test 環境シミュレーション)。

**評価**: cmd_661 実装具体化として最も詳細。Z案の機構実装層を担う。

### 1.4 ash6 (Codex) — A-4: 共通真因パターン分析 (500 words)

ash6 (Codex) は #40 + #45 を Codex 独立視点で再評価。本日の 3 事象 (cmd_657 報告漏れ / cmd_658 永続化漏れ / cmd_659 dashboard 反映漏れ) の **共通真因 = 「人間宣言 done の手動 fan-out」** と特定。

具体的には:
- **Type A (足軽 git 省略)**: cmd_657 で発生 — 足軽が git push 前に done 宣言
- **Type B (karo dashboard 漏れ)**: cmd_659 で発生 — karo が dashboard 反映前に cmd done 宣言
- **Type C (指示解釈ミス)**: cmd_658 で発生 — 永続化先 (suggestions.yaml) を誤解
- **Type D**: 未観測 (将来の type 候補)

ash6 は実装案ではなく **共通真因の正確な記述** を提供。Opus 系 (ash1/ash5) の実装案がこの真因記述を前提として組み立てられている関係。

**評価**: Z案の前提として採用。実装案は Opus 系に委ねる構図。

### 1.5 ash7 (Codex) — A-5: [提案-4] 再評価 (500 words)

ash7 (Codex) は [提案-4] (cmd_597 P1-P3) の再評価を実施:
- **P1-C** は「Verified Completion」へ格上げ推奨 — verifier gate を P1 の一部として明示化
- **P2-D** は cmd_659 で一部実現済 (dashboard 編集権限分離 + 自動 fan-out)
- **P3-B** は「Durable Reliability First」へ具体化 — verifier の persistence を強化

ash7 独自の批判: **cmd_599 (もし発令するなら) 修正案 = 30分探索ではなく 1行承認**。これは ash1 の C+ mandatory gate と統合可能で、「機械 gate (verifier) → 人間 1行承認」の二段配置が合理的。

**評価**: 思想統合として高評価。ash1 + ash5 の機械実装を補完する人間 in the loop の位置づけを提供。

---

## 2. 軍師統合分析

### 2.1 共通点 (consensus)

| # | 内容 | 同意者 |
|---|------|--------|
| 1 | **自動 verification gate が必要** | ash1 / ash5 / ash7 (3/5) |
| 2 | **真因は人間宣言 done の手動 fan-out** | ash6 (前提) + ash1 / ash7 (3/5) |
| 3 | **P2 は cmd_659 で解決済** | ash1 / ash7 (2/5) |

### 2.2 相違点 (disagreement)

| # | 論点 | A 派 | B 派 | 収束方針 |
|---|------|------|------|---------|
| 1 | hook 実装層 | ash5: cmd_complete event 駆動 | ash1/ash7: artifact + git + AC gate | **両方採用 (case A + case B 二段)** |
| 2 | gate 強度 | ash1: mandatory (block) | ash7: 1行承認 (人間) | **二段配置 (mandatory → 人間)** |

### 2.3 補完点 (unique insights)

- ash5: 案 B (PostToolUse Bash hook) は event 漏れの fail-safe として採用
- ash6: Type 分類は Z 案の真因前提として採用
- ash7: cmd_599 修正方向は ash1 C+ と統合

### 2.4 Z 案統合フロー

```
[足軽 task_completed 宣言]
    ↓ (event)
[Phase 3-A 一次: cmd_complete event 駆動 hook] ← ash5 案 C
    ↓
[Phase 3-A 二段: PostToolUse Bash hook] ← ash5 案 B (fail-safe)
    ↓
[Verifier mandatory gate] ← ash1 C+
  - artifact 存在 / git status clean / AC 表記一致
    ↓ (PASS)
[Phase 3-B 検討: 1行承認 gate (人間)] ← ash7 (cmd_662 で要否判断)
    ↓
[karo inbox に task_completed 配送]
```

### 2.5 north_star 3点照合

- **N1 (#40 + #45 + [提案-4] 全件カバー)**: aligned — 5 足軽が全件再分析
- **N2 (cmd_658/659 再発防止直結)**: aligned — verifier 3 チェックで Type A/B/C 全捕捉
- **N3 (殿判断 1 行明確性)**: aligned — 「cmd_661 発令: Z案採択」1 行裁可可能

---

## 3. 殿向けアクションアイテム

### 即時アクション (殿裁可待ち)

1. **cmd_661 発令**: Verified Completion Gate 基幹実装 (Phase 3-A 一次 + 二段)
   - 担当候補: ash5 (Phase 3 設計者) + ash1 (C+ 詳細設計者) の協業
   - 工数見積: 4-8 hours

### 後続アクション (cmd_661 完遂後)

2. **cmd_662 発令**: cmd_661 試運用 1 週間観察 + ash7 1 行承認 gate の要否判断
   - 担当候補: ash6 (Codex 独立観察) + 軍師 QC

### 番号管理

- cmd_622 番号衝突 (ash5 指摘) → cmd_661 振替で解消
- cmd_599 (探索 cmd 案) は cmd_661 で代替されるため発令不要

---

## 4. 軍師結論

5 足軽の独立調査が「自動 verification gate」に収束した事実は、Z 案の妥当性を強く裏付ける。**cmd_661 を即時発令することで、cmd_657-659 の連続発生を構造的に終結可能**。

殿の判断: **「cmd_661 発令: Z案を採択」1 行で裁可。** Conditional 条件なし、Go。

---

## 参考

- ash1: output/cmd_660_ash1_role_split_review.md (19655 bytes)
- ash4: output/cmd_660_ash4_role_split_review.md (17697 bytes)
- ash5: output/cmd_660_ash5_verification_phase3.md (23046 bytes)
- ash6: output/cmd_660_ash6_codex_pattern_analysis.md (21078 bytes)
- ash7: output/cmd_660_ash7_codex_proposal_4_review.md (15890 bytes)
- 関連 cmd: cmd_597 ([提案-4] 起源) / cmd_644 (Phase 1) / cmd_651 (Phase 2) / cmd_657-659 (連続違反) / cmd_661 (Phase 3-A 推奨)
