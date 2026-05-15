# cmd_728a: Lord Approval Request Best Practice Research

作成: 2026-05-15 JST  
担当: ashigaru7  
範囲: 調査のみ。コード、skill、instructions は編集しない。

## 1. Executive Summary

殿への承認依頼は「通知」ではなく「高リスク action に対する structured decision intake」として扱うべきである。OpenAI の agent 実務ガイドは、高リスク・不可逆・高 stakes の action は human oversight を発火させるべきとし、失敗閾値超過時も人間へ制御を戻すべきとしている。shogun の承認依頼も同じ構造で、Karo/Shogun が勝手に判断できないものだけを、短く、比較可能で、選択肢とリスクが明確な形で殿に渡すのがよい。

結論:

- `shogun-decision-notify-pattern` は現 repo に存在しない。新設推奨。
- 既存 `skill-creation-workflow` とは「候補を skill 化する工程」であり、承認依頼文そのものの設計ではないため統合ではなく関連 skill として参照。
- `shogun-error-fix-dual-review` とは「判断前に Opus/Codex/軍師で材料を作る」関係。承認依頼 skill は、その材料を殿向け decision memo に圧縮する後段として定義するのが自然。
- cmd_728 の必須8項目は概ね妥当。ただし industry practice に照らすと `options`、`recommended_option`、`tradeoffs`、`risk_if_no_decision`、`deadline`、`evidence_links`、`reversibility` を明示した方がよい。
- dashboard は要対応の短縮版、Discord は詳細 decision memo として二系統に分けるべき。

## 2. Sources and Findings

| 観点 | 出典 | この task への適用 |
|---|---|---|
| AI human oversight | OpenAI, *A practical guide to building agents*: https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/ | 高リスク action、失敗閾値超過、不可逆 action は human intervention。承認依頼発火条件の根拠。 |
| AI risk governance | OpenAI, *Our updated Preparedness Framework*: https://openai.com/index/updating-our-preparedness-framework/ | Capabilities/Safeguards report、residual risk review、leadership recommendation の分離。承認依頼にも「事実・対策・残リスク・推薦」を分ける。 |
| AI deployment oversight | OpenAI, *Approach to Frontier Risk*: https://openai.com/global-affairs/our-approach-to-frontier-risk/ | deployment threshold 以上は Deployment Safety Board が承認。shogun では threshold を「殿承認 gate」として定義する。 |
| AI governance | Anthropic, *Responsible Scaling Policy v3 announcement*: https://www.anthropic.com/news/responsible-scaling-policy-v3 | voluntary framework と明示。最新版は v3.0 だが詳細本文はページから PDF 参照。AI framework は変化が速いため日付付き出典が必須。 |
| AI governance detail | Anthropic, *Responsible Scaling Policy v1.0 PDF*: https://www-cdn.anthropic.com/1adf000c8f675958c2ee23805d91aaade1cd4613/responsible-scaling-policy.pdf | board/LTBT consultation、documented safety procedures、Responsible Scaling Officer、non-compliance reporting。承認依頼の audit trail / accountable owner の根拠。v1.0 なので最新版差分には注意。 |
| ADR | Google Cloud, *Architecture decision records overview*: https://docs.cloud.google.com/architecture/architecture-decision-records | ADR は options, requirements, decision, rationale, timestamp を記録し、将来の再判断を助ける。承認結果の永続記録設計に適用。 |
| ADR template | MADR: https://adr.github.io/madr/ / ADR templates: https://adr.github.io/adr-templates/ | context/problem, considered options, pros/cons, decision makers, confirmation が重要。短い decision memo の必須欄に採用。 |
| RFC consensus | IETF RFC 7282: https://www.rfc-editor.org/rfc/rfc7282.html | 多数決でなく、少数意見を検討し、反対理由を説明することが consensus。承認依頼では「却下した選択肢と理由」を短く残す。 |
| Pre-mortem | HBR, Gary Klein, *Performing a Project Premortem*: https://hbr.org/2007/09/performing-a-project-premortem | 計画段階で dissent を安全に出す。承認依頼には「失敗したとしたら何が原因か」を1-3件入れる。 |
| Pre-mortem evidence | McKinsey, *Premortems: Being smart at the start*: https://www.mckinsey.com/capabilities/strategy-and-corporate-finance/our-insights/bias-busters-premortems-being-smart-at-the-start | premortem は過信を減らし、未検討リスクを発見する。殿判断前のリスク欄に適用。 |
| Compatibility/process | Python PEP 387: https://peps.python.org/pep-0387/ | backward compatibility では benefit/breakage ratio、deprecation period、steering council consultation が重要。shogun の instructions 変更承認では互換性・移行負担を明示する。 |

限界:

- Anthropic RSP は 2026-02-24 に v3.0 公開。検索で取得できた詳細 PDF は v1.0 であり、手続き設計の参考には有効だが最新版の正確な条文としては扱わない。
- Google/Amazon 社内 design doc / decision memo の一次資料は公開範囲が限定的。今回の強い根拠は Google Cloud ADR、IETF RFC、MADR、OpenAI/Anthropic 公開文書、HBR/McKinsey premortem に置く。

## 3. Best Practice Synthesis

殿への承認依頼に必要な構造:

| Field | 目的 | 根拠 |
|---|---|---|
| `decision_id` | 後追い可能な一意 ID | ADR/RFC の audit trail |
| `decision_needed` | 何を決めるかを1文で固定 | structured decision intake |
| `why_now` | なぜ今人間判断が必要か | human oversight trigger |
| `recommended_option` | 家老/将軍の推薦を明示 | OpenAI residual risk + leadership recommendation 型 |
| `options` | A/B/C と tradeoff | ADR/MADR/RFC |
| `evidence` | 出典/検証結果/関連 report | RFC の reasoned explanation |
| `risks` | 実行リスク・不実行リスク・premortem | HBR/McKinsey premortem |
| `reversibility` | reversible / hard-to-revert / irreversible | OpenAI high-risk action threshold |
| `blast_radius` | 影響範囲 | human oversight trigger |
| `deadline` | いつまでに判断が必要か | decision intake 実務 |
| `default_if_no_response` | 無応答時の扱い | event-driven 運用で stall を防ぐ |
| `owner` | 次に誰が何をするか | accountable owner |
| `record_path` | dashboard / output / gate registry / ADR の保存先 | ADR の永続化 |

重要なのは「殿に考えさせる」のではなく「殿が選べる状態にする」こと。特に選択肢がない承認依頼は、原則として承認依頼ではなく報告または作業不足である。

## 4. cmd_728 Required 8 Fields Evaluation

現 AGENTS.md の cmd 必須8項目:

1. `id`
2. `timestamp`
3. `purpose`
4. `acceptance_criteria`
5. `command`
6. `project`
7. `priority`
8. `status`

評価:

| Field | 評価 | コメント |
|---|---|---|
| `id` | KEEP | audit trail の基礎。decision_id と連携可。 |
| `timestamp` | KEEP | JST 明記必須。承認期限・判断時刻と連携。 |
| `purpose` | KEEP | 「done の姿」。ただし承認依頼では `decision_needed` の方が直接的。 |
| `acceptance_criteria` | KEEP | 完了検証に必須。承認依頼では「判断後に何をもって実行完了とするか」。 |
| `command` | KEEP | Karo への実行指示。殿向け文面では冗長になりやすいので Discord 詳細の下部へ。 |
| `project` | KEEP | dashboard grouping / context loading に必要。 |
| `priority` | KEEP | dashboard の表示順と通知重要度に必要。 |
| `status` | KEEP | queue 運用の基礎。 |

不足:

- `north_star`: instructions/shogun.md では既に必須。cmd_format summary と不一致がある。承認依頼には必須化すべき。
- `decomposition_hint`: instructions/shogun.md では既に必須。承認依頼には「並列可否・gunshi 要否・RACE-001 risk」を短く含めるべき。
- `decision_options`: A/B/C、推薦、却下理由。
- `risk_profile`: reversibility / blast_radius / failure modes / no-decision risk。
- `evidence_links`: report, source URL, test logs。
- `deadline` and `default_if_no_response`: event-driven で詰まらないため。
- `approval_scope`: 殿が承認する範囲。例: 方針のみ / 実装開始 / push / production deploy。

削除候補:

- 8項目から削除すべきものはない。ただし殿向け dashboard 短縮版には `command` 全文を載せない。詳細 Discord/output へ逃がす。

表現変更案:

- `purpose` → cmd YAML は現状維持。殿向けテンプレでは `判断事項` として再表現。
- `acceptance_criteria` → 殿向けテンプレでは `承認後の完了条件`。
- `priority` → `緊急度 + 放置時影響` に展開。

## 5. Two-Channel Information Architecture

### 5.1 Discord 詳細通知テンプレ

Discord は 2000 文字制限がある。`scripts/discord_notify.py` は 2000 文字超過時に切り詰めるため、1通目は 1200-1600 字程度に抑え、詳細は output path に逃がすのが安全。

```text
【判断依頼】<decision_id>: <判断事項1文>

推奨: <A/B/C> - <理由1文>
期限: <YYYY-MM-DD HH:MM JST> / 無応答時: <保留|Aで進行|中止>

選択肢:
A. <案名> - 利点 / 欠点 / リスク
B. <案名> - 利点 / 欠点 / リスク
C. <案名> - 利点 / 欠点 / リスク

なぜ殿判断か:
- <不可逆/高影響/費用/外部公開/production変更/方針変更>

証拠:
- <report/output/test URL 1>
- <source URL 2>

失敗想定:
- <premortem 1>
- <premortem 2>

承認後の次手:
- <Karo/ashigaru/gunshi が実行すること>

詳細: <output path or dashboard tag>
返信形式: 「Aで」「Bで」「保留」「差戻し: <理由>」
```

### 5.2 dashboard 要対応短縮版テンプレ

dashboard は一覧性が主目的。詳細比較を詰め込まない。

```markdown
| ⚠️ HIGH [action-N] [<decision_id>] | <判断事項 20-35字> | 推奨=<A案>; 期限=<MM/DD HH:MM JST>; 理由=<殿判断が必要な理由>; 詳細=<output path>; 返信=A/B/保留/差戻し |
```

短縮ルール:

- 1行 120-180 字程度。
- 選択肢の詳細は Discord/output へ。
- `action-N` は cmd 完了時 SO-19 で削除し、✅ 戦果に反映。
- `default_if_no_response` が「保留」以外の場合は dashboard に必ず明記。

## 6. Existing Skill Candidate Search

実行:

```bash
rg -n "shogun-decision-notify-pattern|decision-notify|承認依頼|判断要請|approval|decision memo|gate registry|cmd_716" .
```

結果:

- `shogun-decision-notify-pattern` は存在確認できず。
- `approval` は CLI approval / skill approval / dashboard approval など別文脈が中心。
- 近接既存 skill:
  - `skills/skill-creation-workflow/SKILL.md`: skill 候補の承認後処理。承認依頼文の設計ではない。
  - `skills/shogun-error-fix-dual-review/SKILL.md`: dual-review で判断材料を作る。殿向け判断依頼のフォーマットではない。

判断: 新設推奨。名称は `shogun-decision-notify-pattern` でよい。既存 skill への統合では、通知二系統・human oversight trigger・dashboard/Discord 分離の知識が埋もれる。

## 7. Relation to cmd_716 Gate Registry

cmd_716 は dashboard 上で gate/action_required を扱う設計進行中。今回の承認依頼 skill は gate registry の「人間判断 gate」を統一する入力形式として使う。

推奨関係:

- `gate_id`: `decision_id` と同一または参照。
- `gate_type`: `lord_approval`
- `status`: `pending | approved | rejected | deferred | expired`
- `dashboard_action_id`: `action-N`
- `discord_message_ref`: 可能なら通知ログや message id。
- `evidence_paths`: output/report/source URLs。
- `decision_record_path`: 後で ADR/MADR 風に残す path。

cmd_716 schema coexistence への注意:

- 既存 `action_required` の `issue_id` entry と新 `gate_id` entry を共存させる方針と矛盾しない。
- dashboard には人間が読む短縮版だけを置き、gate registry には machine-readable fields を置く。
- `default_if_no_response` は gate registry 側に必ず持たせる。dashboard に書き忘れても machine 処理が詰まらないようにする。

## 8. Relation to shogun-error-fix-dual-review

`shogun-error-fix-dual-review` は「修正前に Opus + Codex で independent review、軍師が統合、家老が修正配備」という調査・検証 workflow。

今回の skill との接続:

- dual-review の output は `evidence` と `options` の材料。
- 軍師集約で unresolved / conflict が残った場合、殿承認依頼の `decision_needed` へ昇格。
- 承認依頼は「レビュー結果全文」ではなく「殿が選ぶべき差分」だけを提示する。

実装指針:

- β は `shogun-decision-notify-pattern` 内に「source material from dual-review」節を置く。
- γ は dual-review 由来の実例 cmd_486/cmd_725 等を1件だけ入れ、長文化しない。

## 9. Relation to skill-creation-workflow

`skill-creation-workflow` は skill 候補を評価し、既存統合判断、SKILL.md 作成、履歴更新、commit/push までを扱う。今回の task はその前段、「殿に skill 化承認を求める説明品質」を標準化する。

実装指針:

- `shogun-decision-notify-pattern` は Related Skills に `skill-creation-workflow` を載せる。
- skill 候補承認の dashboard 表現は今回テンプレを使う。
- ただし `skill-creation-workflow` 本体へ統合しない。skill 化以外の production deploy / GitHub Issue close / manual gate / external cost approval にも使うため独立性が高い。

## 10. β/γ Implementation Guidance

### β: SKILL.md 起草

推奨 path:

```text
skills/shogun-decision-notify-pattern/SKILL.md
```

推奨 front matter:

```yaml
---
name: shogun-decision-notify-pattern
description: >
  Use when Shogun/Karo must ask the Lord for approval or a decision before
  proceeding with high-risk, irreversible, externally visible, costly, or
  policy-changing work. Provides a two-channel Discord + dashboard decision
  memo pattern with options, evidence, risk, reversibility, and default action.
tags: [shogun-system, human-oversight, decision-memo, dashboard, discord]
---
```

必須セクション:

1. When to Use / Do Not Use
2. Human Oversight Trigger
3. Decision Intake Fields
4. Discord Detailed Template
5. Dashboard Short Template
6. Gate Registry Mapping
7. Evidence and Premortem Rules
8. Examples
9. Related Skills
10. Sources

### γ: instructions 改訂

候補変更:

- `instructions/shogun.md` の Command Writing または Skill Candidates 節に「Lord approval request must use decision-notify pattern」を追加。
- `instructions/karo.md` の dashboard/action_required 更新規律に dashboard 短縮版テンプレを追加。
- `instructions/common/shogun_mandatory.md` の Action Required / Verification Before Report 周辺に「詳細は Discord/output、dashboard は短縮」と紐づけ。
- cmd_716 gate registry が入る場合は `gate_type: lord_approval` を schema に追加。

注意:

- dashboard は Ashigaru 編集禁止なので、skill には「Ashigaru は output/report に案を書く。dashboard 反映は Karo/Gunshi」と明記。
- Discord 2000字制限により、詳細本文は truncate される可能性がある。長文比較は output path へ逃がす。
- `date` 直接禁止。すべて `scripts/jst_now.sh`。

## 11. Acceptance Criteria Self Check

| AC | Status | Evidence |
|---|---|---|
| A-1 | PASS | human-in-the-loop / structured decision intake / RFC / ADR / premortem / decision memo 観点を §2-5 に整理。 |
| A-2 | PASS | OpenAI/Anthropic/Google Cloud/MADR/IETF/HBR/McKinsey/PEP を優先。Anthropic v1.0 PDF の限界も明記。 |
| A-3 | PASS | cmd 必須8項目を §4 で過不足評価。追加/削除/表現変更案あり。 |
| A-4 | PASS | Discord 詳細通知 + dashboard 短縮版の二系統テンプレを §5 に提示。 |
| A-5 | PASS | `rg` 探索結果により existing_skill_relation=new と判断。 |
| A-6 | PASS | cmd_716 / dual-review / skill-creation-workflow との関係と β/γ実装指針を §7-10 に整理。 |
| A-7 | PASS | 本 task で編集したのは output/report/task/inbox のみ。コード/skill/instructions は不触。 |
