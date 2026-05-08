# cmd_669: Claude/Codex 指示書統一 — 実装報告

**日時**: 2026-05-08T12:05:49+09:00  
**担当**: ashigaru4  
**タスク**: subtask_669_instructions_unification

---

## 実装内容

### 問題の背景

cmd_667/668 インシデントにて、Codex 家老が `instructions/generated/codex-karo.md`（61KB）を
AGENTS.md の 32KiB 上限により読み込めず、QC pipeline が切断された。  
殿御裁可（2026-05-08 09:48 JST）：「指示書は Claude と Codex で統一する」

### 実施した変更

#### 1. AGENTS.md の instructions パス統一 (A-1)

**変更前（AGENTS.md line 80）**:
```
shogun→`instructions/generated/codex-shogun.md`, karo→`instructions/generated/codex-karo.md`, ...
```

**変更後**:
```
shogun→`instructions/shogun.md`, karo→`instructions/karo.md`, ...
```

Codex エージェントも Claude と同じ `instructions/{role}.md` を参照するように統一。

#### 2. instructions/generated/codex-*.md の symlink 化 (A-2)

実体ファイルを削除し、`instructions/{role}.md` への symlink に変換：

```
instructions/generated/codex-shogun.md  ->  ../shogun.md
instructions/generated/codex-karo.md   ->  ../karo.md
instructions/generated/codex-gunshi.md ->  ../gunshi.md
instructions/generated/codex-ashigaru.md -> ../ashigaru.md
```

旧来の参照が残っていても symlink 経由で正本を読む。実体重複なし。

#### 3. scripts/build_instructions.sh の改修 (B-1)

3点の変更：

1. **シンボリックリンク保護**: `build_instruction_file()` 冒頭で symlink チェックを追加。
   symlink ターゲットへの上書きを防止（`codex-*.md` が symlink の場合はスキップ）。

2. **generate_agents_md() の instructions パス置換を廃止**:
   旧: `instructions/{role}.md` → `instructions/generated/codex-{role}.md` の sed 置換を削除  
   新: AGENTS.md に instructions パス置換なし（Claude と同一パスを保持）

3. **`--check` モード追加**: `bash scripts/build_instructions.sh --check` で
   AGENTS.md と CLAUDE.md の差分が CLI 名のみであることを検証可能。
   `build_all()` 関数に分離してフラグ処理を先行評価。

---

## 廃止ファイル

| ファイル | 対応 |
|---------|------|
| `instructions/generated/codex-shogun.md` | symlink 化（実体廃止） |
| `instructions/generated/codex-karo.md` | symlink 化（実体廃止） |
| `instructions/generated/codex-gunshi.md` | symlink 化（実体廃止） |
| `instructions/generated/codex-ashigaru.md` | symlink 化（実体廃止） |

---

## 検証結果

| 検証項目 | 結果 | 詳細 |
|---------|------|------|
| A-1: instructions パス統一 | ✅ PASS | Claude/Codex 両者とも `instructions/{role}.md` を参照 |
| A-2: codex-*.md 実体廃止 | ✅ PASS | symlink 化完了。実体重複なし |
| A-3: AGENTS.md ≈ CLAUDE.md | ✅ PASS | `--check` で「CLI 名のみ差分」確認済み（24 raw lines、全 CLI 名差）|
| B-1: build_instructions.sh 役割変更 | ✅ PASS | `--check` モード追加、symlink 保護実装 |
| B-2: project_doc_max_bytes 確認 | ✅ PASS | `~/.codex/config.toml`: `project_doc_max_bytes = 131072`（128KB） |
| C-1: Codex が instructions/{role}.md を完全 load 可能 | ✅ PASS | 全 4 役職とも < 131072B: shogun=24KB, karo=54KB, gunshi=42KB, ashigaru=25KB |
| C-2: Claude が instructions/{role}.md を完全 load 可能 | ✅ PASS | Claude は従前通り同パスを使用（変更なし） |
| C-3: AGENTS.md 32KiB 上限解消 | ✅ PASS | AGENTS.md=19KB < limit=128KB。上限は `project_doc_max_bytes = 131072` で解消済み |
| E-1: 実装記録 | ✅ PASS | 本ファイル（output/cmd_669_instructions_unification.md） |

---

## 残課題

なし。全 AC 達成。

### 補足: Codex セッション反映

本 cmd で行った AGENTS.md / instructions 変更は、次回 Codex セッション開始時に自動反映される。
既存の active Codex セッションへの反映は `/new` コマンドで再起動が必要。
