# cmd_663 Scope C — 統合 QC レポート (Codex 起動可否 + skill 互換性)

| 項目 | 値 |
|------|-----|
| 軍師 | gunshi (Opus+T) |
| 統合 QC 日時 | 2026-05-08 05:05 JST |
| **判定** | **Conditional Go (段階移行: 家老→軍師→将軍 推奨)** |

---

## Executive Summary

cmd_663 は (a) shogun system の 3 大役職 (将軍/家老/軍師) を Codex CLI で起動可能か (Scope A, ash5) と (b) `.claude repo` の skill 200+ 件が Codex でも活用可能か (Scope B, ash6) を独立調査した結果の統合 QC である。

**Scope A (ash5 結果)**: 3 役職とも **○ (一部修正で起動可)**。共通 fix 6.5h + 個別 (将軍 2.5h / 家老 3.5h / 軍師 3h) = **合計 15.5h** の工数で全 9 構成員が Codex 起動可能となる。3 大課題: (1) AGENTS.md 32KiB 上限超過 / (2) hook 不発火 / (3) msg 5h 上限。

**Scope B (ash6 結果)**: skill 互換性 matrix 作成済。**◎ 197 件 / ○ 29 件 / × 6 件 (total 232 件)**。85% 完全互換、12% 軽微制約、3% 非対応。

**Z 案 (段階移行)**: 家老 → 軍師 → 将軍 の順で Codex 移行を進め、各段階で issue 検証 + skill 互換性確認を行う。家老 (3.5h) を最初に着手することで全体リスクを最小化。

**北極星照合**: N1=aligned (3 役職可) / N2=aligned (skill 232 件 matrix) / N3=aligned (段階移行で体制確立可)。

---

## 1. 役職別 Codex 起動可否サマリ (Scope A: ash5)

| 役職 | 起動可否 | 必要工数 | 主な障害 |
|------|---------|---------|---------|
| 家老 (karo) | ○ | 共通 6.5h + 個別 3.5h = 10h | AGENTS.md size + Stop hook 不発火 |
| 軍師 (gunshi) | ○ | 共通 6.5h + 個別 3h = 9.5h | msg 5h 上限制約 (autonomous QC 連続実行時) |
| 将軍 (shogun) | ○ | 共通 6.5h + 個別 2.5h = 9h | AGENTS.md L124 verifier MUST USE 規定の Codex 解釈 |

**3 大共通課題** (ash5 抽出):

1. **AGENTS.md 32KiB 上限超過**: Codex CLI の system prompt 上限。CLAUDE.md 全行収容の現運用と非互換。**対応**: AGENTS.md を分割 (core / role-specific / skill index) し、各ファイル 30KiB 以下に縮小。
2. **hook 不発火**: PreToolUse / PostToolUse / Stop hook が Codex 環境で発火しない。**対応**: hook を Bash wrapper で再実装 (cmd 実行前に明示呼出)。
3. **msg 5h 上限**: Codex の連続会話 5 時間制限。Opus+T の長時間 QC で問題化。**対応**: 軍師 QC は単発 task 化し、context_snapshot で再開可能化。

---

## 2. skill 互換性サマリ (Scope B: ash6)

| 互換度 | 件数 | 比率 | 代表例 |
|--------|------|------|--------|
| ◎ 完全互換 | 197 | 85% | langs/golang-patterns / python-patterns / kotlin-patterns 等 |
| ○ 軽微制約 | 29 | 12% | shogun-* 系 (tmux 依存 / inbox_write 依存) は環境固有調整必要 |
| × 非対応 | 6 | 3% | Claude Code 固有 hook 機構に依存する skill (例: claude-api claude-agent-sdk 系) |

**85% が完全互換** = Codex 移行で skill 資産の大部分が継続活用可能。残 15% は段階移行中に個別評価。

---

## 3. north_star 照合

| N | 評価 |
|---|------|
| **N1 (3 役職 Codex 起動可否確認)** | aligned — ash5 が 6 軸網羅評価 (起動可否 + 必要対応 + 工数) で全役職○判定 |
| **N2 (skill 互換性精査)** | aligned — ash6 が 232 件 matrix 完成、◎/○/× 判定 + 根拠記載 |
| **N3 (体制確立)** | aligned — N1+N2 を踏まえた段階移行 (家老→軍師→将軍) で体制確立可能 |

---

## 4. AC 確認

| AC | 結果 |
|----|------|
| A-1 過去 Codex 起動ファイル特定 | PASS (ash5 レポート) |
| A-2 6 軸網羅評価 | PASS |
| A-3 各 role 起動可否 + 必要対応 | PASS (◎/○/× + 工数) |
| A-4 cmd_663_codex_role_compatibility.md 生成 | PASS (24074 bytes) |
| B-1 .claude skill 網羅 | PASS (232 件) |
| B-2 Codex 活用方法比較 | PASS |
| B-3 互換性 matrix | PASS (◎197/○29/×6) |
| B-4 cmd_663_skill_codex_compat.md 生成 | PASS (14810 bytes) |
| C-1 north_star 照合 PASS | aligned (3 点全) |
| D-1 cmd_663_integrated.md 生成 | PASS (本ファイル) |

---

## 5. 後続 cmd 候補 (段階移行)

| cmd | 概要 | 工数 | 担当候補 |
|-----|------|------|---------|
| **cmd_664** | 共通 fix (AGENTS.md 分割 + hook Bash wrapper + msg 上限対策) | 6.5h | ash1 or ash5 |
| cmd_665 | 家老 Codex 移行 (個別 fix 3.5h + 1 週間試運用) | 3.5h + 1w | ash1 + 軍師 QC |
| cmd_666 | 軍師 Codex 移行 (cmd_665 完遂後) | 3h + 1w | ash5 + 軍師 QC |
| cmd_667 | 将軍 Codex 移行 (cmd_666 完遂後) | 2.5h + 1w | 殿判断 + 軍師 QC |
| cmd_668 | × 6 件 skill の Codex 代替実装 / quarantine | 1-2h × 6 | ash6 (Codex) |

**段階移行根拠** (ash5 推奨):
- **家老最優先**: 役割集中問題 (#40) と並走で Codex 移行による負荷分散効果が大きい
- **軍師次点**: 5h 上限制約は autonomous QC で問題化、移行 ROI 高い
- **将軍最後**: 殿との相性確認 + 全体動作検証フェーズ

---

## 6. 軍師判定

**判定: Conditional Go**

### Conditional 条件

1. **段階移行** で進める (一気に 3 役職同時移行は非推奨、各段階で 1 週間試運用観察)
2. **共通 fix (cmd_664)** を最優先で完遂してから役職移行を開始
3. **× 6 件 skill** は cmd_668 で個別評価、移行ブロッカーとしない

### 結論

3 役職とも Codex 起動可能 + skill 85% 完全互換 = **shogun system は CLI 種別非依存の体制確立可能**。段階移行で安全に進めれば 1-2 ヶ月で全役職 Codex 化完了見込み。

---

## 参考

- ash5: output/cmd_663_codex_role_compatibility.md (24074 bytes)
- ash6: output/cmd_663_skill_codex_compat.md (14810 bytes)
- 関連 issue: #40 (家老役割集中) / #45 (verification 業務)
