---
name: shogun-lord-approval-request-pattern
description: >
  [English] Use when Shogun or Karo needs to ask the Lord for approval, decision,
  or judgement before proceeding with high-risk, irreversible, externally visible,
  costly, or policy-changing work. Provides 8 required fields, a Discord detailed
  decision memo template, a dashboard short-form template, and --chunked usage
  for long bodies. Do NOT use for technical decisions inside Karo / Gunshi /
  Ashigaru level (those belong to dual-review or task delegation).
  [日本語] 殿への承認依頼・判断要請を起草する時に使用。背景・選択肢・推奨・期限・参考資料
  を構造化した必須8フィールドと、Discord 詳細版テンプレ・dashboard 短縮版テンプレ・
  scripts/discord_notify.py --chunked usage を収録。
  Do NOT use for 家老内 / 軍師内 / 足軽内の技術判断 (それらは dual-review か通常 dispatch)。
tags: [shogun-system, human-oversight, decision-memo, dashboard, discord, gate-registry]
---

# Shogun Lord Approval Request Pattern

殿への承認依頼・判断要請を「殿が選べる状態」にして提示するための標準書式。
通知は Discord 詳細版 + dashboard 要対応欄短縮版の二系統で発火する。

## When to Use

殿の判断が必要な以下の局面で起動する:

- **不可逆 / 高 blast_radius**: 本番 deploy、外部公開、外部送金、巨大refactor、scope外実装
- **方針変更**: instructions/CLAUDE.md / 規律 / north_star に触れる改訂
- **金銭・契約**: 有料 API 上限引上げ、外部発注、ライセンス変更
- **dual-review 後の残課題**: `shogun-error-fix-dual-review` で軍師裁定でも収束しない衝突案件
- **skill 化 / cmd 起案**: `skill-creation-workflow` 承認、cmd_716 のような新機構導入
- **gate registry 経由判断**: cmd_716 完成後は `gate_type: lord_approval` 入力として使用

## When NOT to Use (Do NOT use for)

以下は本 skill の対象外。dispatch / dual-review / 通常通知で処理する:

- **家老内の技術判断**: subtask 分割、配備先 ashigaru 選定、test 戦略 — 家老が即断
- **軍師内の技術判断**: north_star 3点 check、QC verdict — 軍師が即断
- **足軽内の実装判断**: 関数命名、test framework 選定 — 足軽が即断
- **報告のみ**: 完了報告、進捗報告、観察報告 — 選択肢がないなら承認依頼ではない
- **system alert**: GHA failure、daemon stuck — `gha_failure_alert` 経路で処理

> 殿の判断が "Approve / Reject / Defer" の3択に圧縮できないなら承認依頼ではない。
> 選択肢がないものは「報告」または「作業不足」として差し戻す。

## Why This Skill Exists

旧来の承認依頼は dashboard 要対応欄に1行だけ書かれ、背景・選択肢・trade-off が薄かった。
結果として殿が「どんな cmd で何を調査した上での提案か」を二度三度問い直す事態が頻発し、
9時間 cmd 進行遅延級の事故 (cmd_716 dogfooding) を発生させた。

本 skill は OpenAI agent oversight ガイド / Anthropic Responsible Scaling Policy /
Google Cloud ADR / IETF RFC 7282 / MADR / HBR + McKinsey premortem / PEP 387 の
共通原則を取込み、「殿に考えさせる」のではなく「殿が選べる状態にして提示する」設計を強制する。

## 8 Required Fields (必須フィールド体系)

承認依頼本文は以下の8項目を必ず含める。順序固定。

| # | フィールド | 目的 | 記入要件 |
|---|----------|------|---------|
| 1 | **件名** | decision_id + 判断事項を1文で固定 | `cmd_XXX: <判断事項30字以内>` |
| 2 | **背景・経緯** | 起案 cmd / 関連 cmd / なぜ今殿判断か | 起案 cmd、関連 cmd、9時間遅延等 incident 引用、why_now |
| 3 | **調査・検討プロセス** | dual review / 軍師統合 / 業界調査 | 担当 (ashigaru/gunshi)、参照 output path、source 件数 |
| 4 | **選択肢一覧 + trade-off** | A / B / C 案。利点 / 欠点 / リスク | 最低2案、推奨案は最初。各案の trade-off を1-2行 |
| 5 | **推奨判断と根拠** | 軍師 or 家老の推薦 | 推奨案 (A/B/C)、根拠 1-3 点、却下案の却下理由 |
| 6 | **殿のアクション** | 具体操作。返信書式を固定 | 「Aで」「Bで」「保留」「差戻し: <理由>」など返信 keyword |
| 7 | **期限 / SLA** | 判断期限 + 無応答時の default 動作 | `YYYY-MM-DD HH:MM JST`、`default_if_no_response: 保留\|A進行\|中止` |
| 8 | **参考資料** | output / report / commit / Issue / source URL | output path、git commit hash、GitHub Issue URL、外部 source URL |

### Field Notes

- **件名 (1)**: 短縮版 dashboard entry の主要部にも流用。20-35字を超えないこと。
- **背景・経緯 (2)**: 起案 cmd は必須。関連 cmd は3件まで。長い経緯は参考資料へ逃がす。
- **調査・検討プロセス (3)**: `shogun-error-fix-dual-review` 由来なら担当 Opus/Codex/軍師を明示。
- **選択肢 (4)**: 1案だけしか書けないなら承認依頼ではない (報告として差戻す)。
- **推奨判断 (5)**: 推奨なしで殿に丸投げするのは禁止。推薦がない場合は dual-review に差戻す。
- **殿のアクション (6)**: 自由記述ではなく `A/B/C/保留/差戻し` の返信 keyword を提示する。
- **期限 (7)**: `default_if_no_response` がない承認依頼は event-driven 運用で詰まる。必須。
- **参考資料 (8)**: 最低1件。output path または cmd report yaml への参照を含める。

## Discord Detailed Template

詳細版は Discord DM で殿へ送る。1通 2000 字制限のため 1200-1600 字を目安に、
詳細比較や長文 evidence は output path に逃がす。長文時は `--chunked` で分割。

```text
【判断依頼】<decision_id>: <判断事項1文>

■ 背景・経緯
- 起案 cmd: cmd_XXX (<purpose 1文>)
- 関連 cmd: cmd_YYY, cmd_ZZZ
- なぜ今殿判断か: <不可逆 / 高影響 / 費用 / 方針変更 / production 変更>

■ 調査・検討プロセス
- dual-review: Opus=<ashigaruN>, Codex=<ashigaruM>, 軍師統合=<verdict>
- 業界 best practice: <source 数>件 (詳細は参考資料)

■ 選択肢
A. <案名> — 利点 / 欠点 / リスク
B. <案名> — 利点 / 欠点 / リスク
C. <案名> — 利点 / 欠点 / リスク

■ 推奨: <A/B/C>
根拠:
- <根拠 1>
- <根拠 2>
却下した案の理由:
- <案>: <却下理由>

■ 殿のアクション
返信形式: 「Aで」「Bで」「保留」「差戻し: <理由>」

■ 期限 / SLA
- 期限: <YYYY-MM-DD HH:MM JST>
- 無応答時: <保留 | A進行 | 中止>

■ 失敗想定 (premortem)
- <premortem 1>
- <premortem 2>

■ 参考資料
- output: output/cmd_XXX_<slug>.md
- report: queue/reports/<agent>_report.yaml
- git: <commit hash>
- Issue: <GitHub URL>
- source: <外部 URL>
```

## Dashboard Short Template

dashboard 要対応欄は一覧性が主目的。詳細は Discord / output に逃がす。
1行 120-180 字を目安に短縮する。`action-N` は cmd 完了時 SO-19 で削除し ✅ 戦果に反映。

```markdown
| ⚠️ HIGH [action-N] [<decision_id>] | <判断事項 20-35字> | 推奨=<A案>; 期限=<MM/DD HH:MM JST>; 無応答時=<保留/A進行/中止>; 詳細=<output path>; 返信=A/B/保留/差戻し |
```

短縮ルール:

- 選択肢の trade-off 詳細は Discord / output へ。dashboard には書かない。
- `default_if_no_response` が「保留」以外の場合は dashboard に必ず明記。
- 殿が dashboard だけ見て即判断できる粒度を維持 (推奨 + 期限 + 返信 keyword)。
- 編集権限: Karo / Gunshi のみ。Ashigaru は output / report に案を書き、家老 dispatch に委ねる。

## --chunked Usage (Discord Long Body)

4-8KB 規模の承認依頼は Discord 2000 字制限で truncate される。
`scripts/discord_notify.py --chunked` で Part N/M 付き複数 part に分割送信する。

### 直接実行

```bash
python3 /home/ubuntu/shogun/scripts/discord_notify.py \
  --chunked \
  --body "$(cat output/cmd_XXX_lord_approval_request.md)" \
  --title "<decision_id> 殿承認依頼" \
  --type "decision"
```

### notify.sh wrapper 経由 (推奨)

```bash
NOTIFY_CHUNKED=1 bash /home/ubuntu/shogun/scripts/notify.sh \
  "$(cat output/cmd_XXX_lord_approval_request.md)" \
  "<decision_id> 殿承認依頼" \
  "decision"
```

### --chunked を使う判定基準

- 本文 1600 字超 → `--chunked` 必須
- 本文 1200-1600 字 → 通常送信 (truncate 余地あり)
- 本文 1200 字未満 → 通常送信
- 迷ったら `--dry-run` で part 数を事前確認:

```bash
python3 /home/ubuntu/shogun/scripts/discord_notify.py \
  --dry-run --chunked \
  --body "<body>" --title "<title>" --type "decision"
```

### Behavior Note

- 既定挙動 (`--chunked` 未指定) は従来通り1通整形 + 2000字 truncate (後方互換)。
- chunked 時は CHUNK_TARGET=1800、各 part に title / tag / `Part N/M` を維持。
- 詳細仕様: `output/cmd_728e_discord_notify_long_message_support.md`

## Relation to cmd_716 Gate Registry

cmd_716 は dashboard 上で gate / action_required を扱う設計 (Phase A-F 進行中)。
本 skill は gate registry の「人間判断 gate」を統一する入力形式として使う。

### Mapping

| 本 skill フィールド | cmd_716 gate registry entry |
|------------------|---------------------------|
| 件名 (1) | `gate_id` + `expected_action` |
| 背景・経緯 (2) | `cmd_id`, `registered_at` |
| 選択肢 (4) | `options[]` (machine-readable) |
| 推奨判断 (5) | `recommended_option` |
| 殿のアクション (6) | `reply_keywords` |
| 期限 / SLA (7) | `expires_at`, `default_if_no_response` |
| 参考資料 (8) | `evidence_paths[]` |

### Coexistence

- 既存 `action_required` の `issue_id` entry と新 `gate_id` entry を共存させる方針と矛盾しない。
- dashboard には人間が読む短縮版だけを置き、gate registry には machine-readable fields を置く。
- `default_if_no_response` は gate registry 側に必ず持たせる (dashboard に書き忘れても machine 処理が詰まらない)。
- cmd_716 Phase D 完成後、本 skill のテンプレで gate を登録するフローに統合する。

## Relation to shogun-error-fix-dual-review

`shogun-error-fix-dual-review` は「修正前に Opus + Codex 並列 review、軍師統合、家老 dispatch」の workflow。
本 skill とは「材料 → 承認依頼」の前後関係:

- dual-review の output (CRITICAL/HIGH findings、衝突裁定) は本 skill の **背景・経緯 (2)** と **選択肢 (4)** の材料。
- 軍師集約で **unresolved / conflict が残った場合**、殿承認依頼の **件名 (1)** へ昇格する。
- 承認依頼は「レビュー結果全文」ではなく「殿が選ぶべき差分」だけを提示する。
- dual-review Variant 1 (smoke + QC) で軍師 verdict=conditional になった場合も同様に昇格対象。

## Relation to skill-creation-workflow

`skill-creation-workflow` は skill 候補を SKILL.md に変換し、`queue/skill_candidates.yaml` /
`memory/skill_history.md` / `dashboard.md` を同期する workflow。本 skill とは並列関係:

- **skill 化承認の dashboard 表現には本 skill のテンプレを使う** (起案 cmd / 推奨 / 期限 / 返信 keyword)。
- ただし `skill-creation-workflow` 本体へは統合しない。skill 化以外の本番 deploy / GitHub Issue close /
  manual gate / external cost approval にも使うため独立性が高い (skill-creation-workflow §1 の独立性評価合格)。
- 本 skill 自身も `skill-creation-workflow` §1-§6 に従って作成された (cmd_728b による起草)。

## Anti-Patterns

- ❌ **選択肢なしの承認依頼**: 1案だけ → 報告として差戻す
- ❌ **推奨判断なしの丸投げ**: 「殿のお考えをお聞かせください」 → dual-review に差戻す
- ❌ **期限・default なし**: event-driven で詰まる → 必須化
- ❌ **dashboard に詳細詰め込み**: 一覧性破壊 → Discord / output へ逃がす
- ❌ **Ashigaru が直接 dashboard 編集**: 権限違反 → output / report に案を書く
- ❌ **Discord truncate 放置**: `--chunked` を使わず 2000 字超本文 → 殿が判断できない
- ❌ **terminal-only / inbox-only 経路**: cmd_728 運用変更で禁止 → Discord + dashboard 二系統必須
- ❌ **system alert との混在**: GHA / daemon alert は本 skill 対象外 (`gha_failure_alert` 経路)

## Battle-Tested Examples

| cmd | 状況 | 結果 |
|-----|------|------|
| cmd_716 | 殿判断 gate × Alert dedup 設計。dual-review + 軍師統合後に殿承認 | conditional_go → lord approval ✅ (Discord akisame4842 経由)。本 skill の dogfooding 起点 |
| cmd_728 | 本 skill 自身の起案 (α 業界調査 / β 起草 / γ instructions改訂 / δ 軍師 QC) | α/728e=done, β=本 task で起草 |

### cmd_716 の学び

1. **dashboard 1行説明では足りない**: 殿が「どんな cmd で何を調査したのか」を再質問
2. **dual-review + 軍師統合まで終わっているのに**: 殿には「同意/拒否」だけに見えた
3. **9時間 cmd 進行遅延**: 構造化された承認依頼書式の不在が直接原因
4. **対策**: 必須8フィールド + Discord 詳細 + dashboard 短縮の二系統発火 (本 skill)

## Output / Sync Proposal (この skill の発行に伴う後段同期)

本 cmd_728b では `queue/skill_candidates.yaml` / `memory/skill_history.md` / `dashboard.md` は編集禁止 (B-5)。
後段同期 (cmd_728c instructions 改訂 / cmd_728d 軍師 QC 後) で以下を反映する案:

- `queue/skill_candidates.yaml`: SC entry `shogun-lord-approval-request-pattern` 追加 (status: created, source_cmd: cmd_728b)
- `memory/skill_history.md`: `| **shogun-lord-approval-request-pattern** ✅ | cmd_728b: 殿承認依頼の必須8フィールド + Discord/dashboard 二系統テンプレ + --chunked usage を体系化。新規 ~280L |`
- `dashboard.md`: cmd_728 戦果欄に「cmd_728b 完了: skill 起草」追記。要対応欄から該当 action_required 削除 (SO-19)

詳細案は `output/cmd_728b_lord_approval_skill_draft.md` §5 参照。

## Related Skills

- `shogun-error-fix-dual-review` — 判断材料 (dual-review findings) を供給する前段 workflow
- `shogun-error-fix-dual-review` Variant 1 (L017 smoke QC) — verdict=conditional 時に承認依頼へ昇格
- `skill-creation-workflow` — skill 化判断の承認依頼に本 skill を使う関係
- `shogun-decision-notify-pattern` — **通知 infrastructure (ntfy 4要素: push + atomic append + cooldown + fail-safe)。本 skill とは補完関係**: 本 skill は「殿向け content の structured format」、`shogun-decision-notify-pattern` は「通知配信機構の堅牢性」。Discord 経路化後は本 skill のテンプレを `shogun-decision-notify-pattern` の Element 1 (push) body に詰める形で連携

## Source

- cmd_728 (起案 2026-05-15): 殿御下命「承認依頼の説明が薄い。skill 化して Discord 統合せよ」
- cmd_728a (業界調査 2026-05-15, ashigaru7): OpenAI agent oversight / Anthropic RSP / Google Cloud ADR /
  IETF RFC 7282 / MADR / HBR + McKinsey premortem / PEP 387 など 11 source
- cmd_728e (long message 対応 2026-05-15, ashigaru7): `scripts/discord_notify.py --chunked` 実装 + tests
- cmd_716 (起案 2026-05-12): 殿判断 gate × Alert dedup。dashboard 1行説明の不足を露呈した事故事例
- cmd_728b (本 skill 起草 2026-05-15, ashigaru5): 必須8フィールド + Discord/dashboard 二系統テンプレ + --chunked usage 統合
