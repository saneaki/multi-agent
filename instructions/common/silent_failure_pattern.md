# Silent Failure Pattern Catalog

このファイルは shogun multi-agent 運用で実発生した **silent failure** (unit AC 全 PASS にもかかわらず north_star outcome 未達) 事案を 1 incident 1 entry で集約する。各 entry は (1) 症状 (2) 誤認チェーン (3) 根因 (4) 構造的防止策 (規律 / 規約 / skill) を含む。

新規 incident 検出時は append-only で追記する (過去 entry を変更しない)。

## Cross-References

- **規律**: `instructions/gunshi.md §L022` (軍師 QC reality verify), `instructions/shogun.md F007` (将軍 unverified_report), `instructions/common/north_star_outcome_check.md` (north_star outcome 評価)
- **Skill**: `skills/shogun-silent-failure-audit-pattern/SKILL.md` (shell script silent failure audit), `skills/shogun-dashboard-sync-silent-failure-pattern/SKILL.md` (dashboard sync silent failure), `skills/shogun-shc-switch-silent-failure/SKILL.md` (shc/switch_cli silent failure)
- **Audit script**: `scripts/audit_silent_failure.sh` (suppression pattern 自動検出)

---

## Incident #001: cmd_712 clasp push "Skipping push." 誤読 (2026-05-11 〜 2026-05-15)

### 症状

ash3 が clasp push を実行し `Skipping push.` 出力を取得。`clasp status` で `Tracked files: <list>` を確認し「local 完遂」として完了報告。**remote (GAS) には 0 byte も反映されていない状態で 4 日間 SLA 超過**。殿の手作業 (`clasp pull` で remote ≠ local 検出) で初発覚。

### 誤認チェーン (4 段)

| 段 | 役職 | 誤認内容 | 正しい解釈 |
|---|------|---------|-----------|
| 1 | ash3 | `clasp push → Skipping push.` を成功と誤解釈 | `Skipping push.` = local と remote が一致 or push 抑制。**新規 push 成功証跡ではない** |
| 2 | gunshi | `clasp status → Tracked files` 一覧を remote 反映証跡と誤解釈し QC PASS | `Tracked files` は **local の追跡対象一覧**。remote 反映の証跡ではない |
| 3 | karo | gunshi QC PASS を信用し中継 | gunshi 側で reality verify が無い場合は karo も QC 結果を疑うべきだった |
| 4 | shogun | karo 中継を信用し殿に「完了」と報告 | F007 (unverified_report) 違反 |

### 根因 (3 層)

- **L1 [ash 報告 evidence]**: clasp CLI の出力文言 (`Skipping push.` / `Tracked files`) の **意味を誤解釈** したまま evidence として採用
- **L2 [gunshi QC 規律]**: local 完遂証跡のみで PASS する慣行。**remote 実態確認手順を AC として必須要求する規律が不在**
- **L3 [task YAML 設計]**: deploy/push 系 cmd の AC に reality_verify_step (clasp pull / API GET / 殿目視) が含まれていなかった

### 構造的防止策

| 策 | 場所 | 内容 |
|----|------|------|
| **L022 Reality Verification Rule** | `instructions/gunshi.md` | 軍師 QC で local 完遂証跡のみによる PASS を禁止。Forbidden Evidence Patterns (Skipping push. / Tracked files / Everything up-to-date 等) を明示。reality verify 手段 (clasp pull / git ls-remote / API GET) を category 別に規定 |
| **F007 (shogun, unverified_report)** | `instructions/shogun.md` | 将軍が殿に「完了」と報告する前に reality verify 必須化。L022 PASS 証跡を以て満たされる |
| **silent_failure_pattern (clasp push 系)** | `skills/shogun-silent-failure-audit-pattern/SKILL.md §Stage 4 / Use when` | clasp / git / n8n / cron 系 silent failure pattern として包括化。golden verify 手順 (clasp pull) を明記 |
| **reality_verify_step template** | `instructions/common/cmd_template_reality_verify.md` (新規) | deploy/push 系 cmd template に reality_verify_step を default 内蔵 |

### 検出キーワード (将来の自動検出用)

ash 報告 / QC report に以下の文言が**単独 evidence** として出現した場合は L022 違反疑い:

- `clasp push.*Skipping push`
- `clasp status.*Tracked files`
- `git push.*Everything up-to-date`
- `cron.*登録.*完了` (実発火 log 確認なし)
- `dashboard.*更新.*完了` (受信側確認なし)

### Reference cmds

- cmd_712 Phase A (ash3 初動): 誤判定発生
- cmd_712 Phase B (殿手作業): reality 検出 + 是正
- cmd_732 (本規律制定): L022 + silent_failure_pattern.md 整備

---

## 追記時の Format

新規 incident 追記時は以下の section 構造を踏襲すること:

```markdown
## Incident #NNN: <短い表題> (発生日範囲)

### 症状

(unit AC 全 PASS / 但し north_star outcome 未達の具体的症状)

### 誤認チェーン

(役職別の誤認内容と正しい解釈の対比 table)

### 根因 (層別)

(L1/L2/L3 等の層別分解)

### 構造的防止策

(規律 / 規約 / skill 別 table)

### 検出キーワード

(将来自動検出用の文言 list)

### Reference cmds

(関連 cmd_id list)
```

NNN は前 incident の次番号 (003 / 004 / ...) を採用。
