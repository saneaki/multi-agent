---
name: shogun-preset-immutability-discipline
description: >
  [English] Use when a config file holds an immutable preset reference (e.g. config/settings.yaml
  `formations.*`) alongside a mutable live state (e.g. `cli.agents`), and a one-way apply engine
  (shc.sh deploy / shp / shutsujin_departure.sh) must read the preset and write only the live state.
  Codifies the three-layer discipline (preset = read-only reference / apply engine = one-way reader /
  live state = writable), violation detection via `git diff` of the preset section, karo dispatch
  pre-check, and gunshi QC reject criteria. Generalizes to DI / config / fixture immutability.
  [日本語] config/settings.yaml の `formations.*` (preset=不変リファレンス) と `cli.agents`
  (live state) を片方向適用エンジン (shc.sh deploy / shp / shutsujin_departure.sh) 経由で
  書き分ける三層構造規律を運用する時に使用。違反検出は `git diff` の `formations:` 配下差分。
  家老 dispatch 規律 (editable_files 事前明示) + 軍師 QC 規律 (差分時の殿裁可確認) も含む。
  cmd_705 (設計) → cmd_717 AC-4 (違反) → cmd_718 (revert + 4軸6触点明文化) で確立。
  DI/config/fixture 系の不変原則継承にも横展開可能。
tags: [shogun, preset-immutability, settings-yaml, formations, config-discipline, dispatch-gate]
created: 2026-05-15
source_cmd: cmd_718c (gunshi autonomous extraction) → cmd_726c (skill 化)
related_cmds: [cmd_705, cmd_717, cmd_718, cmd_718a, cmd_718b, cmd_718c]
---

# shogun-preset-immutability-discipline

設定ファイル内に「不変リファレンス (preset)」と「ランタイム live state」が同居する場合、
両者を片方向適用エンジン経由で書き分ける三層構造規律を運用する pattern。
shogun の `config/settings.yaml` (`formations.*` vs `cli.agents`) を典型例とし、
DI / config / fixture 系の他の immutability 継承にも応用可能。

## Use when

- 1 つの設定ファイルに「テンプレート / リファレンス」と「現行状態」が混在する設計
- 適用エンジン (deploy / apply / restore / hydrate) が preset を read して live state に書込む構造
- `git diff config/<file>` で preset 区画が変わる cmd を dispatch する直前
- 軍師 QC で「preset 改変が殿の明示裁可付きか」を判定する必要がある
- DI container の base config / pytest fixture の baseline / k8s base manifest 等、
  「変更してはいけない baseline」と「派生 live state」を分離したい設計の確立

## Do NOT use for

- live state のみ持つ設定ファイル (preset 概念なし)
- preset 自体の追加 (新規 `formations.<new_name>`) — 既存値の書換のみ対象
- shp 内蔵プリセット (heavy-opus 等のコード内 dict) — 別の immutability スキームで管理
- アプリケーションコードの DI 抽象 (本 pattern は config file レベルの規律)

## Three-Layer Structure

```
Layer 1 [preset]       config/settings.yaml `formations.*`     不変リファレンス
                              │
                              │ 片方向 (read-only)
                              ▼
Layer 2 [apply engine] shp / shc.sh deploy / shutsujin_departure.sh
                              │
                              │ 書込み (live state)
                              ▼
Layer 3 [live state]   config/settings.yaml `cli.agents`       ランタイム書換可
```

### 各層の責務

| 層 | 役割 | 書換可否 | 例 |
|---|---|---|---|
| Layer 1 preset | テンプレート提供 | **不変** (殿の明示裁可必須) | `formations.hybrid` / `formations.all-sonnet` / `formations.all-opus` |
| Layer 2 apply engine | preset 読込 + live state 書込 | engine 自体は不変 | `shc.sh deploy <name> --settings-only` / `shp` / `shutsujin_departure.sh` |
| Layer 3 live state | ランタイム現状 | 自由書換可 | `cli.agents.ashigaru1` の `cli_type` / `model` |

## 禁止行為

家老 / 足軽 / 軍師 (および将軍を含む全エージェント) は、以下の行為を **禁止** する:

1. **既存 preset 値の上書き** (例: `formations.hybrid.agents` 配下の改変)
2. **`description` を「同期」「実態と合わせる」名目で書換** (cmd_717 AC-4 違反例)
3. **別 cmd の副作用としての preset 書換** (purpose に明記なき書換)

## 許可される操作

以下は禁止対象外:

1. **新規 preset の追加** (`formations.<new_name>` を新設、既存値は不変)
2. **殿の明示裁可付き書換** (cmd の `purpose` / `acceptance_criteria` に preset 改訂を明記し殿承認)
3. **live state (`cli.agents`) の書換** (shp / shc.sh deploy / switch_cli.sh が日常的に書換える)

## 違反検出パターン

### 1. `git diff` による差分検出

```bash
# preset 差分検出 (軍師 QC で使用)
git diff config/settings.yaml | grep -E '^[+-][[:space:]]*(formations|hybrid|all-sonnet|all-opus|description|agents):'
```

差分があれば cmd の `purpose` / `acceptance_criteria` で preset 書換が明示されているかを確認。
明示なし → FAIL 判定。

### 2. CI / pre-commit / git hook での自動検出 (推奨 follow-up)

cmd_718c F1: 現状は軍師 QC の手動 `git diff` 確認に依存。CI / pre-commit / git hook で
自動検出する仕組みを追加するのが推奨。`scripts/validate_preset_immutability.sh` (新規) で
HEAD と origin/main の `formations:` 差分を `git show :config/settings.yaml` と比較し、
purpose / commit msg に「preset」「formations」キーワードがなければ exit 1。

## 家老 (dispatch) 規律

cmd を ashigaru に dispatch する前のチェック手順:

1. `editable_files` に `config/settings.yaml` が含まれるか確認
2. 含まれる場合: cmd の `purpose` / `command` / `acceptance_criteria` に **preset 書換が明示されているか** 確認
3. 明示あり: 殿の `purpose` / `command` 内に「preset 改訂」「`formations.<name>` 同期」等の明確な記述があるか
4. 明示なし: ashigaru の task YAML `description` に **「`formations.*` は触らない」を明記**

task YAML 例 (preset を触らせない明示):

```yaml
description: |
  config/settings.yaml の cli.agents 配下のみ編集してよい。
  formations.* (不変リファレンス) は preset_immutability.md に基づき変更禁止。
```

## 軍師 (QC) 規律

cmd QC 時の手順:

1. `git diff config/settings.yaml` を実行し `formations:` 配下差分を抽出
2. 差分あり → cmd の `purpose` / `acceptance_criteria` に preset 書換明示があるか確認
3. 明示なし → **FAIL 判定**。verdict=no_go で karo に返却
4. 明示あり → 殿の裁可確認 (purpose 内の明示文 + Issue / dashboard での裁可記録)
5. SO-17 outcome evidence ブロックで preset → live state 片方向適用の証跡を必須化
   (隔離 tmux session E2E が望ましい — `shogun-silent-failure-audit-pattern` Stage 3 と連携)

## Battle-Tested Examples

| cmd | 状況 | 結果 |
|---|---|---|
| cmd_705 | 三層構造設計 (preset / engine / live state の役割分離設計) | shc.sh hybrid 構造解析で三層の片方向適用構造を最初に明示 |
| cmd_717 AC-4 | **違反**: `formations.hybrid` を実運用構成 (Codex×3 + Sonnet×2 + Opus×2) に「同期」 | 殿の明示裁可なき書換 → preset immutability 違反として cmd_718 で revert |
| cmd_718a (subtask_718a) | `formations.hybrid` を b8ac913^ 値 (Sonnet×3 + Opus×2 + Codex×2) に revert + 隔離 `test_718_isolation` で E2E | preset (Layer 1) → cli.agents (Layer 3) の片方向適用を実機実証 |
| cmd_718b (subtask_718b) | **4軸6触点** の構造的明文化 | `docs/formation_immutability.md` (119行) + `instructions/common/preset_immutability.md` (101行) + `scripts/shp.sh` 6箇所 + `docs/shogun_shell_commands.md` note + `instructions/karo.md §Preset Immutability Discipline` + `output/cmd_717a §0a` corrective note |
| cmd_718c | gunshi 統合 QC verdict=go + skill 化候補 autonomous extraction | 本 SKILL.md の出典。三層構造 + 4軸6触点 + 違反検出 + dispatch/QC 規律を pattern 化 |

### 4軸6触点 (cmd_718b で確立)

| 軸 | 触点 | 用途 |
|---|---|---|
| 1. shp.sh 明記 | `scripts/shp.sh` L6-9, L26, L31-33, L111-113, L139-146 | shp 自身が `formations.*` を書換えないことを 6 箇所で繰返し明記 |
| 2. 三層構造図解 | `docs/formation_immutability.md` (新規 119行) | ASCII 図 + 違反例 + 検出方法 |
| 3. 規律本文 | `instructions/common/preset_immutability.md` (新規 101行) | 禁止 / 許可 / dispatch / QC 規律 |
| 4. 派生 docs note | `docs/shogun_shell_commands.md` L3-9 | 全シェルコマンドが preset を書換えない旨を明示 |
| 4b. 家老 dispatch | `instructions/karo.md` §Preset Immutability Discipline (L351-363) | dispatch 前のチェック手順、違反例参照 |
| 4c. corrective note | `output/cmd_717a §0a` (L10-58) | 違反構造解析、revert+再発防止、保持される cmd_717 成果、学び |

## Diagnostic Checklist

新しい cmd の dispatch / QC 直前に以下を確認:

1. cmd の `editable_files` に `config/settings.yaml` が含まれるか?
2. 含む場合: `purpose` / `acceptance_criteria` に preset 書換明示があるか?
3. 明示なし: ashigaru の `description` に「`formations.*` は触らない」明記があるか?
4. cmd 完了時: `git diff config/settings.yaml` で preset 差分なしを確認したか?
5. 差分あり: 殿の裁可記録 (Issue / dashboard / purpose 内明示文) が揃っているか?
6. SO-17 outcome evidence: 片方向適用 (preset → live state) の隔離 E2E 証跡があるか?

## 横展開対象

本 pattern は `formations.*` 特有ではなく、以下のような **「baseline / derived」分離設計** に応用可:

- DI container の base config / 環境別 override
- pytest fixture の baseline yaml / 各 test case の派生
- k8s base manifest (`kustomize` の `base/`) / overlay
- Terraform module variable defaults / 環境別 tfvars
- Ansible group_vars baseline / host_vars derived
- shogun の `formations.*` (本 pattern の出典) / `cli.agents`

横展開時は以下を読み替える:

| shogun 用語 | 一般化 |
|---|---|
| `formations.*` | baseline / preset / template / base manifest |
| `cli.agents` | derived / overlay / live state / runtime config |
| `shc.sh deploy` | apply engine / kustomize build / ansible-playbook / terraform apply |
| 殿の明示裁可 | RFC 承認 / code review approval / change advisory board |

## Related Skills

- `shogun-silent-failure-audit-pattern` — cmd_717/718 の corrective で同時に確立した相補規律 (silent failure halt 化 + preset immutability)
- `shogun-switch-cli-yaml-update-guard` — settings.yaml の `cli.agents` 書換系バグ (live state 側の bug — Layer 3 限定)
- `shift-left-validation-pattern` — preset 差分の pre-gate (自動 git diff) と true-gate (軍師 QC) の二段構成
- `verification-loop` — Stage 1-4 の deploy & verify cycle に preset 不変確認を組込む
- `shogun-tmux-busy-aware-send-keys` — live state (cli.agents) 切替時の tmux 連携 (Layer 2 apply engine の実装側)

## Anti-patterns

- ❌ preset を「実態と合わせる」名目で書換 (cmd_717 AC-4 の典型違反)
- ❌ purpose に明示せず別 cmd の副作用で preset 書換 (殿の裁可なし)
- ❌ ashigaru に `editable_files: [config/settings.yaml]` を渡すだけで「preset は触るな」を明記しない
- ❌ 軍師 QC で `git diff config/settings.yaml` を確認せず verdict=go 出す
- ❌ active 環境で preset 書換テスト (live state を破壊するリスク — 隔離 tmux session 必須)

## Source

- cmd_705: 三層構造の設計 (shc.sh hybrid 構造解析)
- cmd_717 AC-4: 違反事例 (preset を実態に同期した cmd_717 fix の corrective 必要性発生)
- cmd_718a: `formations.hybrid` revert + 隔離 tmux E2E
- cmd_718b: 4軸6触点で構造的明文化 (docs/instructions/scripts)
- cmd_718c: 軍師統合 QC verdict=go + autonomous extraction → 本 skill 候補
- cmd_726c: skill 化 (本 SKILL.md 作成 — γ subtask ashigaru4)
