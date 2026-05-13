# Preset Immutability — 陣形プリセット書換禁止規律

> **規律 (cmd_718 制定)**: `config/settings.yaml` の `formations.*` プリセットは
> 不変リファレンスである。書換は **殿の明示裁可** を要する。

---

## 規律本文

### 禁止行為

家老 / 足軽 / 軍師 (および将軍を含む全エージェント) は、以下の行為を **禁止** する:

1. **`formations.<name>` の既存値の上書き** (例: `formations.hybrid` の `agents` 配下を改変)
2. **`formations.<name>` の `description` を「同期」「実態と合わせる」名目で書換**
3. **`formations.<name>` を別 cmd の副作用として書換**

### 許可される操作

以下は禁止対象外:

1. **新規 formation の追加** (`formations.<new_name>` を新設して既存を増やす)
2. **殿の明示裁可付き書換** (cmd の `purpose` / `acceptance_criteria` に「formations.* 改訂」が明記され、殿が承認した場合)
3. **`cli.agents` 配下の書換** (これは ランタイム live state であり、shp / shc.sh deploy / switch_cli.sh が日常的に書き換える対象)

---

## 三層構造

```
formations.*   = 不変リファレンス  (config/settings.yaml)
   │
   │ 片方向 (read-only)
   ▼
shp / shc.sh deploy / shutsujin_departure.sh
   │
   │ 書込み (live state)
   ▼
cli.agents     = ランタイム live state  (config/settings.yaml)
```

詳細図は [`docs/formation_immutability.md`](../../docs/formation_immutability.md) を参照。

---

## 違反例 (再発防止参照)

### cmd_717 AC-4 (cmd_718 で revert 済み)

- **事象**: `formations.hybrid` を実運用構成 (Codex×3 + Sonnet×2 + Opus×2) に「同期」した。
- **問題**: 殿の明示裁可なき書換。formations.* は不変リファレンスのため違反。
- **revert**: cmd_718 AC-1 で b8ac913^ 当時の値 (Sonnet×3 + Opus×2 + Codex×2) に戻す。
- **再発防止**:
  1. `scripts/shp.sh` 冒頭コメントに preset immutability を明記 (cmd_718 AC-4)
  2. `docs/formation_immutability.md` 新設 (cmd_718 AC-5)
  3. 本ファイル新設 (cmd_718 AC-6)
  4. `instructions/karo.md` に参照追加 (cmd_718 AC-6)

---

## 家老 / 軍師の dispatch 規律

### 家老の事前チェック

cmd を ashigaru に dispatch する前に、task YAML の `editable_files` に `config/settings.yaml` が含まれる場合は以下を確認:

1. cmd の `purpose` / `command` / `acceptance_criteria` に **formations.* 書換が明示されているか**
2. 明示されている場合: 殿の `purpose` または `command` 内に「formations.* 改訂」「formations.<name> 同期」等の明確な記述があるかを確認
3. 明示されていない場合: ashigaru には「formations.* は触らない」と明記して dispatch

task YAML 例 (formations を触らせない明示):

```yaml
description: |
  config/settings.yaml の cli.agents 配下のみ編集してよい。
  formations.* (不変リファレンス) は preset_immutability.md に基づき変更禁止。
```

### 軍師の QC 規律

cmd QC 時に `git diff config/settings.yaml` を確認し、`formations:` セクションに差分がある場合:

1. cmd の `purpose` / `acceptance_criteria` に formations 書換が明示されているか確認
2. 明示なし → **preset immutability 違反として FAIL 判定**
3. 明示あり → 殿の裁可確認 (purpose 内の明示文 + Issue / dashboard での裁可記録)

---

## 関連

- `docs/formation_immutability.md` — 三層構造の図解
- `instructions/karo.md` — 家老 dispatch 規律 (cmd_717 AC-4 違反例参照)
- `instructions/gunshi.md` — 軍師 QC 規律 (SO-17 outcome check と併用)
- `scripts/shp.sh` — preset immutability を冒頭コメントに明記
- `scripts/shc.sh` — preset を読み出して cli.agents に適用 (read-only に preset 側)
- `output/cmd_717a_shx_parent_silent_failure_fix.md §0` — corrective note

---

**履歴**:
- 2026-05-13 cmd_718 で新設 (cmd_717 AC-4 違反を受けた規律確立)
