---
name: shogun-dashboard-sync-silent-failure-pattern
description: dashboard.yaml → dashboard.md 同期の silent failure パターンと防止策。dispatch 漏れ・field 名不一致・rotation バグ・schema validation 不在の 4 incident と 5 pattern を体系化。「dashboard が更新されない」「in_progress が空欄」「dispatch したのに表示されない」で起動。
tags: [shogun, dashboard, reliability, incident-pattern]
created: 2026-05-01
source_cmd: cmd_621 Scope B
related_cmds: [cmd_607, cmd_615, cmd_619, cmd_620, cmd_621]
---

# shogun-dashboard-sync-silent-failure-pattern

## 概要

shogun システムにおいて dashboard.yaml (SoT) → dashboard.md (生成物) の同期チェーンで発生する silent failure の体系化スキル。
2026-04 〜 2026-05 の 4 incident (cmd_607 / cmd_615 / cmd_619 / agent-vs-assignee 不一致) を分析し、
5 つの pattern (P1-P5) と 3 層の防止策 (cmd_620 Scope A/C/D で実装済) を整理した。

主旨: dashboard 更新は SoT (yaml) と表示 (md) の二重源を持ち、validation・dispatch・rotation の各経路で silent failure を引き起こす。
発見が後発 (gunshi QC / 殿目視) になりがちで、修正までの間「戦況外部不透明」状態が継続する。
本スキルは症状から原因を絞り込み、既存の防止策へ誘導する。

## よく発生する Silent Failure パターン

### Pattern P1: dashboard.md/yaml 更新の手動依存

**症状**: dispatch したのに dashboard.md `🔄進行中` セクションに新規 cmd エントリが現れない。
**真因**: `instructions/karo.md` の dispatch protocol Step 3 (in_progress 追加) が手動 markdown 編集として記述されており、
家老が skip しても script 側で検出できない。dispatch 時に `update_dashboard.sh` を auto-call する step が無い。
**典型 incident**: cmd_619 dispatch 漏れ (2026-05-01) — 殿が dashboard 目視で気付き直接修正。
**防止策**: cmd_620 Scope D の `karo_dispatch.sh` で dispatch 自動化 (Step D1-D6 を物理的に必須化)。

### Pattern P2: validation が non-blocking で silent failure

**症状**: 必須 field が欠落しているのに dashboard.md は生成され、空欄 / 空文字フォールバック値が表示される。
**真因**: `generate_dashboard_md.py` の `validate_in_progress` が WARN レベル (stderr 出力) のみで non-blocking。
exit code 0 で呼出元 (update_dashboard.sh) は成功と解釈。silent fallback (空文字埋め込み) が運用層で観測不能。
**典型 incident**: agent-vs-assignee field 名不一致 (2026-05-01) — `agent: 足軽X号` と書かれた entry が
`assignee` として空文字解釈 → silent empty。
**防止策**: cmd_620 Scope A の `--strict` フラグで FAIL 化 (exit 2/3)。CI / pre-commit では強制、運用 hook では警告止まり。

### Pattern P3: SoT 不在 / 二重源

**症状**: dashboard.yaml と queue/tasks/ashigaru*.yaml の status が乖離。dispatch 時に同期 trigger が発火しない。
**真因**: SoT が dashboard.yaml であるべきだが、同期 trigger が dispatch 経路に組み込まれていない (二重源化)。
field 名規約 (assignee vs agent) も明文化されておらず、外部編集で誤名が混入する。
**典型 incident**: cmd_619 dispatch 漏れ + agent-vs-assignee 混入。
**防止策**: cmd_620 Scope C の `test_dashboard_roundtrip.py` で `dashboard.yaml ⇄ queue/tasks` 整合 check (AC-3) を実装。

### Pattern P4: 発見が後発 (post-hoc detection)

**症状**: dashboard 凍結 / 乖離が gunshi QC や殿目視まで気付かれず、6h+ silent 継続。
**真因**: 発見経路が人手 (gunshi review / 殿の dashboard 目視) に依存。機械的 freshness check が無い。
**典型 incident**: cmd_607 dashboard 乖離 (2026-04-29) — gunshi QC まで 6h+ silent。
**防止策 (中期)**: dashboard freshness monitor (last_updated 経過時間 > 30min → ntfy 通知) — 別 cmd で実装推奨。
**防止策 (即効)**: cmd_620 Scope C の `pre-commit-dashboard` hook で commit 時に round-trip 検証。

### Pattern P5: reality check 規律違反 (dashboard 表示 = 実態と扱う)

**症状**: dashboard.md の表示を「実態」と信じて運用判断する → 実態は task YAML / report YAML に記録された別状態。
**真因**: dashboard.md は secondary source (家老の主観サマリ) であり cross-source 照合 (L019) が必須だが、
dispatch / 完了 経路には組み込まれていなかった。
**典型 incident**: cmd_607 (家老が "実装中" を dashboard に書き続け、実態は ash3/ash7 dry-run skip)。
**防止策**: memory/global_context.md §reality check 規律 (2026-04-26 確立) の徹底 + Scope C round-trip による機械的照合。

## 診断チェックリスト

症状から原因を絞り込むフロー:

1. **「dispatch したのに dashboard に出ない」** → P1 / P3
   - `cat queue/tasks/{agent}.yaml` で status: assigned + cmd_ref を確認
   - `grep -A3 "{cmd_id}" dashboard.yaml` で in_progress 反映を確認
   - 反映なし → `bash scripts/karo_dispatch.sh ...` を再実行 (cmd_620 Scope D)

2. **「dashboard.md の担当列が空欄」** → P2 / P3
   - `grep -B1 -A3 "agent:" dashboard.yaml` で禁止 field `agent:` の混入を確認
   - 検出 → `agent:` を `assignee:` にリネーム + Scope A の `--strict` で再検証

3. **「dashboard.md が古い (last_updated が 30min 以上前)」** → P4
   - `python3 scripts/generate_dashboard_md.py` を手動実行し例外を確認
   - 例外あり → P2 (schema 不一致) を疑い incident 履歴を参照

4. **「dashboard.md の今日の成果が空 / 昨日と重複」** → rotation バグ
   - `bash scripts/dashboard_rotate.sh` の実行履歴を確認 (cmd_604 で idempotent 化済)
   - cron 未稼働なら `crontab -l` で確認

5. **「実態と dashboard が乖離している」** → P5
   - `cat queue/reports/{agent}_report.yaml` で実態 status を取得
   - dashboard.md の表記と diff → 差分があれば update_dashboard.sh を再実行

## 防止策 (cmd_620 で実装済)

| Scope | 実装ファイル | 防止対象 pattern |
|-------|------------|--------------|
| **A** (ash6) | `scripts/generate_dashboard_md.py` schema validation 強化 (`--strict` 化 / exit 2/3) | P2, P3 (field 名規約遵守) |
| **C** (ash4) | `scripts/test_dashboard_roundtrip.py` (5 checks) + `scripts/git-hooks/pre-commit-dashboard` | P3 (二重源整合), P4 (機械的検出) |
| **D** (ash1) | `scripts/karo_dispatch.sh` (Step D1-D6 自動化) | P1 (手動 step 廃止), P3 (dispatch 時 SoT 同期) |

## 関連 cmd

| cmd_id | 内容 | 本スキルとの関連 |
|--------|------|----------------|
| cmd_607 | dashboard 乖離発覚 (gunshi QC) | P1, P4, P5 の出発点 |
| cmd_615 | today.items iterate バグ | P2 の典型 (legacy list / dict 混在で AttributeError) |
| cmd_619 | dispatch 漏れ → 殿介入 | P1, P3 の典型 |
| cmd_620 | 構造的改善 4 Scope (A/B/C/D) | 全 pattern の防止策実装 |
| cmd_621 | skill 結晶化 + .gitignore whitelist 整備 | 本スキル新設 (Scope B) |

## インシデント事例

### Incident 1: cmd_607 dashboard 乖離 (2026-04-29)

家老が dashboard に "実装中" と書き続け、実態は ash3/ash7 が dry-run skip のまま完了報告していた。
gunshi QC で 6h+ 後に発覚。dashboard 更新と実態の **乖離検出機構欠如** が真因。

### Incident 2: cmd_615 today.items iterate バグ (2026-04-30)

`generate_dashboard_md.py` が dashboard.yaml の `achievements.today` を list 直書きで受けると `dict.items()` 例外で md 生成全停止。
`_section_items()` ヘルパで両形式を吸収して修正 (commit a0283d9)。
yaml schema 未定義が真因。

### Incident 3: cmd_619 dispatch 漏れ (2026-05-01)

cmd_619 dispatch 後も dashboard.yaml `in_progress` に cmd_619 行が無く、殿が dashboard 目視で気付き直接修正。
家老 dispatch protocol Step 3 (手動 markdown 編集) を skip 可能だったことが真因。

### Incident 4: agent vs assignee field 名不一致 (2026-05-01)

dashboard.yaml `in_progress` の各 entry が `agent: 足軽X号` で書かれていたため、
`r.get("assignee", "")` が空文字に解釈され担当列が silent empty。
field 名規約不在 + validation が non-blocking が真因。

## 横展開対象

本 silent failure パターンは以下にも適用可能:

- queue/reports/*.yaml ⇄ 完了報告整合 (Pattern P3 同型)
- inbox 既読/未読 状態 ⇄ 実処理状況 (Pattern P5 同型)
- task YAML status ⇄ pane 稼働状態 (Pattern P4: shogun-agent-status と連携)

## 参考資料

- `output/cmd_620_scope_b_incident_analysis.md` (229行) — 4 incident 詳細 + Pattern 抽出 + 構造的改善案
- `memory/global_context.md` — reality check 規律 (2026-04-26 確立)
- `instructions/karo.md` — dispatch protocol (cmd_620 Scope D 後は karo_dispatch.sh 必須)
- `skills/shogun-agent-status/SKILL.md` — pane 状態 + task YAML 整合確認スキル (Pattern P4 横展開)
