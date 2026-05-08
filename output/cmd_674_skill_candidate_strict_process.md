# cmd_674 skill_candidate Strict Process — 規律改訂・監査結果・反映実績・残課題

**実施日**: 2026-05-08 13:10 JST
**実施者**: 足軽7号 (Opus+T)
**親 cmd**: cmd_674 (skill_candidate 反映プロセス strict 化)
**前提**: A案即時対応 (SC-667 + codex-skill-index 反映) は cmd_674 Scope A で軍師完遂済み。本 report は cmd_674 本体 (規律改訂 + 遡及スキャン + 反映)。

## 1. 北極星 (north_star) との整合

> 軍師の skill_candidate 反映プロセスを strict 化し、ash report の skill_candidate 発見が必ず dashboard 🛠️ 欄に反映される体制を確立する。SC-667 / codex-skill-index 等の silent failure (発見されたが dashboard 未反映) を恒久解消

本 cmd は (1) 規律改訂による予防、(2) 遡及スキャンによる過去 silent failure 検出、(3) un-reflected 候補の dashboard 反映、の 3 段で north_star を達成する。

## 2. 規律改訂 (instructions/gunshi.md)

### 2.1 Step 7.5 全面改訂 — skill_candidate scan and reflection (MANDATORY)

**Before**: "If ashigaru report contains skill_candidate → append to dashboard..." (条件付き、走査自体が任意)

**After**: 全 QC で必須走査 + 反映を実施。要点:

- ash report (top-level + history[]) の `skill_candidate.found: true` を必ず抽出
- 各候補について以下の cross-reference を実施:
  - `~/.claude/skills/{name}/` または `skills/{name}/` 存在 → skill 化済
  - `memory/skill_history.md` に同名 → 反映済
  - `dashboard.yaml.skill_candidates` に同名 → 反映済
  - 上記いずれにも該当しなければ **un-reflected** → dashboard 🛠️ + dashboard.yaml.skill_candidates へ必ず追記
- 追記 format を dashboard.md / dashboard.yaml で各々規定
- F006b 反映権限を再確認

### 2.2 Step 8.5 enforcement check 強化

- check #3 を strict 化: un-reflected entry が dashboard.md + dashboard.yaml の両方へ追記されたことを Read で実機確認
- check #6 を新設: candidate ゼロでも「走査済 + 該当なし」を report に明記要求
- silent failure (検出 + 反映スキップ) → QC FAIL に格上げ

### 2.3 編集差分 (要約)

instructions/gunshi.md:
- L314-318 → L314-329 改訂 (Step 7.5)
- L351-356 → L351-358 拡張 (Step 8.5 enforcement check)

## 3. 遡及スキャン結果 (B-1 / B-2)

詳細: [output/cmd_674_skill_candidate_audit.md](./cmd_674_skill_candidate_audit.md)

- ユニーク skill 名: 15
- 内訳: skill 化済 5 / 反映済 (cmd_674 A案分含) 4 / un-reflected 8 / silent inconsistency 1 / 整合性矛盾 2

## 4. 反映実績 (B-4)

dashboard.md 🛠️スキル候補 + dashboard.yaml.skill_candidates へ以下 8 件を追記:

| # | Skill | 出典 |
|---|---|---|
| 1 | shogun-autonomous-compaction-management | gunshi cmd_586/592 |
| 2 | shogun-deploy-verify-cycle | gunshi cmd_593/596 |
| 3 | shogun-report-history-mechanism | gunshi cmd_595 |
| 4 | shogun-rule-inventory-pattern | ash3 cmd_566 |
| 5 | shogun-qc-auto-check-naming-mode-pattern | ash cmd_552 |
| 6 | pre-gate-vs-true-gate-separation-pattern | gunshi cmd_596 |
| 7 | shogun-suggestions-lifecycle-management | cmd_596 |
| 8 | shogun-gemini-thinking-token-guard ⚠️登録漏れ | gunshi (要分類) |

dashboard 🛠️ 欄合計: 4 (既存) + 8 (本 cmd) = **12 件**

## 5. AC 自己照合

| AC | 内容 | 状況 |
|---|---|---|
| A-1 | instructions/gunshi.md QC 規律に skill_candidate 走査 + dashboard 反映必須化 | ✅ Step 7.5 改訂で明記 |
| A-2 | 軍師 QC checklist に skill_candidate 反映確認追加 | ✅ Step 8.5 check #3 strict 化 + check #6 新設 |
| B-1 | queue/reports/ashigaru* + gunshi_report.yaml 遡及スキャン | ✅ grep + git log 2 ヶ月遡及で実施 |
| B-2 | output/cmd_674_skill_candidate_audit.md に未反映候補一覧 | ✅ 本 cmd 配下 audit.md 作成 |
| B-3 | memory/skill_history.md と dashboard 🛠️ 欄突合分類 | ✅ audit.md (a)/(b)/(b')/(c)/(d) 4 分類 |
| B-4 | 未反映候補を dashboard.md / dashboard.yaml に追記 | ✅ 8 件追記完了 |
| D-1 | output/cmd_674_skill_candidate_strict_process.md 作成 | ✅ 本ファイル |

## 6. 残課題 (殿/家老判断要)

1. **shogun-gas-clasp-rapt-reauth-fallback / shogun-gas-automated-verification 状態整理**: SKILL.md 実体は skills/ にあるが dashboard では「承認待ち」のまま。殿承認 → ✅実装済み 化 → skill_history.md append + dashboard 🛠️ 削除、の運用フロー確立要。
2. **shogun-gemini-thinking-token-guard の分類**: skills/ に存在 + skill_history.md 未登録 + git 履歴で一度 found: false 打ち消しあり。✅実装済み として遡及登録するか、運用観察継続するか、殿/karo の最終判断要。
3. **cmd_500 以前の遡及スキャン**: 本監査は 2 ヶ月遡及。それ以前に silent failed した candidate は未検出の可能性あり。3 ヶ月以上遡及は次回 cmd で実施推奨。
4. **suggestions.yaml への skill_candidate 言及 cron triage**: 既存 suggestions_digest.sh 実行時に skill_candidate 行も dashboard 反映状況をチェックする拡張要 (cmd_596 既設機構の延長)。

## 7. RACE-001 整合確認

- 編集権限: instructions/gunshi.md / dashboard.md / dashboard.yaml / dashboard.yaml.skill_candidates
- 並走 cmd_673 は統合レポートのみ (dashboard 編集禁止指定済み) のため衝突なし
- ash6 / ash3 等は別ファイルを編集中で衝突なし

## 8. context_policy

`clear_between` (本 cmd は cmd_674 本体で多段ではない)。次 cmd へ context 持ち越し不要。

---

**完了報告先**: karo (inbox_write task_completed)
