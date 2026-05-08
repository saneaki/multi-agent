# cmd_674 Skill Candidate Audit — 遡及スキャン結果

**監査日**: 2026-05-08 13:10 JST
**実施者**: 足軽7号 (Opus+T)
**対象**: cmd_500 以降 〜 cmd_674 (git log 1ヶ月相当)
**対象 file**: queue/reports/ashigaru{1..8}_report.yaml + queue/reports/gunshi_report.yaml

## サマリ

- 遡及スキャン総 hit (skill_candidate.found: true): **20+ 箇所** (history append-only により多重)
- ユニーク skill 名: **15 候補**
- skill 化済 (skills/ + skill_history.md 両方): **5 件**
- skill_history.md 反映済 (skill_history.md 登録のみ): **2 件**
- dashboard 反映済 (cmd_674 A案 即時対応分): **2 件 (SC-667 / codex-skill-index)**
- **un-reflected (cmd_674 本タスクで追記対象): 8 件**
- 整合性矛盾 (skill_history 未登録 + 承認待ち in dashboard): **2 件**
- silent inconsistency (skill 実体あり + skill_history 未登録 + dashboard 未反映): **1 件**

## 分類表

### (a) skill 化済 — skills/ ディレクトリに SKILL.md 存在 + skill_history.md 登録済

| Skill | 出典 cmd | 配置 |
|---|---|---|
| semantic-gap-diagnosis | cmd_559 | ~/.claude/skills/semantic-gap-diagnosis/SKILL.md |
| shogun-tmux-busy-aware-send-keys | cmd_582 | skills/shogun-tmux-busy-aware-send-keys/SKILL.md |
| shogun-bash-daemon-restart-subcommand-pattern | cmd_546 | skills/.../SKILL.md |
| shogun-gas-backfill-pattern | cmd_585/590 | skills/.../SKILL.md |
| shogun-dashboard-sync-silent-failure-pattern | cmd_621 | skills/.../SKILL.md |

### (b) dashboard 反映済 — dashboard.md 🛠️ + dashboard.yaml.skill_candidates にエントリあり

| Skill | 出典 | 状況 |
|---|---|---|
| SC-667 (tmux-pane-border-codex-context) | ash3 cmd_667 / cmd_671 | cmd_674 A案 即時対応で gunshi 反映 |
| codex-skill-index | ash6 cmd_663 | cmd_674 A案 即時対応で gunshi 反映 |

### (b') 整合性矛盾 — skills/ に実体あり + dashboard には「承認待ち」のまま (要状態整理)

| Skill | skills/ 実体 | dashboard 状態 | 推奨 action |
|---|---|---|---|
| shogun-gas-clasp-rapt-reauth-fallback | ✅ | 承認待ち | 殿承認後 ✅実装済み 化 → skill_history.md append + dashboard 🛠️ から削除 |
| shogun-gas-automated-verification | ✅ | 承認待ち | 同上 |

### (c) un-reflected — 検出されたが dashboard 未反映 (cmd_674 本タスクで追記)

| Skill | 出典 cmd | 概要 | 反映先 |
|---|---|---|---|
| shogun-autonomous-compaction-management | gunshi cmd_586/592 | 自律 compaction 管理 cron + self-notify + 動的 context | dashboard.md + dashboard.yaml |
| shogun-deploy-verify-cycle | gunshi cmd_593/596 | shelf-ware 防止 deploy & verify cycle (Stage 1-4) | dashboard.md + dashboard.yaml |
| shogun-report-history-mechanism | gunshi cmd_595 | report yaml history[] append-only Hybrid pattern | dashboard.md + dashboard.yaml |
| shogun-rule-inventory-pattern | ash3 cmd_566 | shogun ルール ID 棚卸 grep 戦略 + qc_checklist 読取 | dashboard.md + dashboard.yaml |
| shogun-qc-auto-check-naming-mode-pattern | ash cmd_552 | qc_auto_check.sh standalone サブコマンド追加 pattern | dashboard.md + dashboard.yaml |
| pre-gate-vs-true-gate-separation-pattern | gunshi cmd_596 | 自動 pre-gate + manual true gate 二段構成 | dashboard.md + dashboard.yaml |
| shogun-suggestions-lifecycle-management | cmd_596 | suggestions.yaml append-only + cron triage + status migration | dashboard.md + dashboard.yaml |

### (d) silent inconsistency — skill 実体あり + skill_history.md 未登録 + dashboard 未反映 (要分類)

| Skill | 状態 | 推奨 action |
|---|---|---|
| shogun-gemini-thinking-token-guard | skills/ に存在 (実体あり)、skill_history.md 未登録、dashboard 未反映、git 履歴では一度 found: false で打ち消されている | 殿/karo 判断: ✅実装済み として skill_history.md 追記 か、🛠️ 承認待ち として残す か |

## 監査手法

1. `grep -rnE "found:[[:space:]]*true" queue/reports/` で現行 YAML 内の skill_candidate を抽出
2. `git log --since="2 months ago" --all -p -- queue/reports/` で過去 commit から overwrite 喪失分を抽出
3. `ls skills/` + `ls ~/.claude/skills/` で実体存在確認
4. `grep -E "skill name" memory/skill_history.md` で skill_history.md 整合確認
5. `grep -E "skill name" dashboard.md / dashboard.yaml` で dashboard 反映確認

## 検出根因 (silent failure 分析)

軍師 QC 規律 (instructions/gunshi.md Step 7.5) に skill_candidate handling の文言は存在したが:

1. 「If ashigaru report contains skill_candidate」と条件付きで記述されており、**走査自体が必須化されていなかった**
2. ash report の skill_candidate field を gunshi 自身がセットして「reason のみ書いて dashboard 追記をスキップ」する pattern が cmd_586〜cmd_596 期に頻発
3. 8.5 enforcement check #3 は存在したが「if skill_candidate in ashigaru report」condition があり、gunshi 自身が candidate を出した場合の transcription を強制していなかった
4. 結果: cmd_586/592/593/595/596/566/552 の 7 cmd 連続で silent failure

cmd_674 改訂 (本タスク) で:
- Step 7.5 を「MANDATORY scan and reflection」に変更
- ash report scan を必須化
- `un-reflected` 判定 algorithm を明記
- 8.5 enforcement check #3 を strict 化 (silent failure → QC FAIL)
- candidate ゼロでも「走査済 + 該当なし」を report に明記要求

## 残課題

1. shogun-gas-clasp-rapt-reauth-fallback / shogun-gas-automated-verification の状態整理 (殿承認待ち)
2. shogun-gemini-thinking-token-guard の分類 (✅実装済み or 承認待ち)
3. cmd_500 以前の更に古い skill_candidate scan (本監査では git log 2ヶ月遡及まで)
4. queue/suggestions.yaml にも skill_candidate 言及があるため将来 cron triage で再走査推奨
