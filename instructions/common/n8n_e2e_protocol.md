# n8n E2E Protocol: test_file vs production_file 区別

> このプロトコルは **n8n workflow 修正 cmd** 限定で適用される。
> SO-22 (機能検証) と SO-23 (業務成果) の AND 運用を前提とし、
> test payload と実運用 resource の混同による誤判定 (cmd_553 → cmd_554 連鎖) を再発防止する。

## 1. 背景 (Why this protocol exists)

**cmd_553 → cmd_554 incident (2026-04-21)**:
- cmd_553 で `exec 15605` (trigger E2E 全22ノード成功) をもって「修正完了」と判定。
- しかし殿の業務観察で「今日アップロードされた3文書のうち2文書はまだ動いていない」と判明。
- 真因: cmd_553 が検証したのは **test payload 経由の trigger 発火** であり、
  殿が実際に業務でアップロードした **real Drive resource** とは異なる execution だった。
- 「機能は動く」が「業務が完遂していない」状態を見逃した。

→ semantic gap: **機能検証 (SO-22) vs 業務成果 (SO-23)** = **手段 vs 目的** の混同。

## 2. ファイル semantic の二層定義

n8n cmd 検証に使う「ファイル」は以下の **2 層** に semantic が分離される。
両者を **混同禁止** とする。

### Layer A: test_file (SO-22 機能検証用)

| 項目 | 内容 |
|------|------|
| 命名規則 | ファイル名 prefix = **`test_e2e_`** (例: `test_e2e_20260421_sample.pdf`) |
| 用途 | trigger E2E の機能検証 (全ノードが動作するかの smoke test) |
| 生成主 | ashigaru (検証目的でアップロードするダミー payload) |
| 検証対象 SO | **SO-22** (機能検証 PASS) |
| 合格基準 | trigger 発火 → 全ノード success → output 生成 |
| report 記載欄 | `test_executions:` (exec_id / trigger_type / status) |

### Layer B: production_file (SO-23 業務成果用)

| 項目 | 内容 |
|------|------|
| 識別 | 殿が観察した file_id (Drive 上に実在する業務 resource) |
| 用途 | 実運用で処理されるべき real resource (業務価値の直接対象) |
| 提供主 | 殿 (業務フロー中で自然にアップロードされた file) |
| 検証対象 SO | **SO-23** (業務完遂) |
| 合格基準 | Drive trigger 経由の exec で全ノード success + Drive output 生成確認 |
| report 記載欄 | `resource_completion:` (pending_resource_id / exec_id / all_nodes_success / output_paths / verified_at) |

### 区別の本質

- **test_file**: 「機能が動くかを見るための手段」 → pass すれば SO-22 OK
- **production_file**: 「業務完遂の目的そのもの」 → pass しない限り SO-23 NG

**test_file の成功 ≠ production_file の成功**。
test_file で trigger が発火しても、production_file が trigger されたかは別 exec で確認要。

## 3. n8n cmd 担当 ashigaru の責務

n8n workflow 修正 cmd を担当する ashigaru は、
report YAML に以下 2 つの欄を **明示的に分離** して記載する。

```yaml
# Layer A: SO-22 機能検証 (test_file)
test_executions:
  - exec_id: "15605"
    trigger_type: "test_e2e"      # test payload 経由
    test_file: "test_e2e_20260421_sample.pdf"
    status: "success"
    all_nodes_success: true
    node_count: 22

# Layer B: SO-23 業務成果 (production_file)
resource_completion:
  - pending_resource_id: "1AbCdEfGh..."   # 殿 observed file_id
    file_name: "契約書_ABC商事_20260421.pdf"
    exec_id: "15612"
    trigger_type: "drive_poll"          # 実 Drive trigger 経由
    all_nodes_success: true
    output_paths:
      - "projects/n8n_workflows/output/..."
    verified_at: "2026-04-21T16:30:00+09:00"
```

**禁則**:
- `test_executions` に production_file の file_id を混ぜて記載しない。
- `resource_completion` に test_e2e_ prefix のファイルを記載しない。
- `exec_id` だけを提示して Layer を曖昧にしない (必ず `trigger_type` と `test_file`/`file_name` で明示)。

## 4. 軍師 QC cross-check 手順

n8n cmd QC 時、軍師は以下の cross-check を実施する。

1. **task YAML** の `pending_resources` field を読取る (COND-B)。
2. **ash report** の `resource_completion` mapping table を読取る (COND-C)。
3. `pending_resources[*].file_id` ⟷ `resource_completion[*].pending_resource_id` で 1:1 照合。
4. 不足 **1件でも** あれば **FAIL** (SO-23 不成立)。

**WARN レベル自動検査**: `scripts/qc_auto_check.sh` が n8n cmd を検出した場合、
task YAML に `pending_resources` があれば ash report 側の `resource_completion` 存否を
自動警告する (最終判定は軍師の manual QC)。

## 5. scope

- **適用範囲**: n8n workflow 修正 cmd (cmd YAML に `project: n8n_workflows` または command に `n8n` を含む)。
- **非適用**: 非 n8n cmd (shogun system 改訂、skill 整備、dashboard 整理 等)。

## 5.5. resource_exempt whitelist exemption 仕様

`resource_completion` field-level check を免除するための仕組み。

### 適用条件

| 条件 | 結果 |
|------|------|
| task YAML に `resource_exempt: true` が明示 かつ project が **n8n_workflows でない** | field-level check をスキップ (pass 扱い) |
| task YAML に `resource_exempt: true` が明示 かつ project が **n8n_workflows** | **FAIL** (exempt 無効 — n8n-fix cmd は禁止) |
| `resource_exempt` 未記載 または `resource_exempt: false` | 通常の field-level check を実施 (デフォルト) |

### 適用例

```yaml
# shogun system cmd (非 n8n) — 免除可
resource_exempt: true   # field-level check スキップ

# n8n workflow 修正 cmd — 免除禁止
project: n8n_workflows
resource_exempt: true   # → qc_auto_check.sh が FAIL を返す
```

### 自動検査 (qc_auto_check.sh)

`scripts/qc_auto_check.sh` が SO-23 判定時に以下を順番に確認する:

1. `project: n8n_workflows` かつ `resource_exempt: true` → **FAIL** (exempt 無効)
2. `resource_completion: []` (空配列) かつ `pending_resources` 宣言あり → **WARN FAIL**
3. 各要素の 5 field (`pending_resource_id`, `exec_id`, `all_nodes_success`, `output_paths`, `verified_at`) 欠落 → **WARN**
4. 全条件クリア → **PASS** (軍師 manual cross-check は引き続き必要)

## 6. 関連 SO / COND

| 項目 | 参照 |
|------|------|
| SO-22 | 機能検証 PASS (representative executions 全件成功) |
| SO-23 | 業務完遂 (pending 実 resource 全件 trigger exec success + Drive output) |
| COND-A | SO-23 の strict 定義 (config/qc_checklist.yaml) |
| COND-B | task YAML `pending_resources` field schema (instructions/karo.md) |
| COND-C | ash report `resource_completion` mapping table (instructions/ashigaru.md) |
| COND-D | gunshi QC cross-check 手順 (instructions/gunshi.md) |
| COND-E | **本プロトコル** (test_file vs production_file 区別明文化) |

## 7. 履歴

- **2026-04-22**: cmd_556 COND-E にて新規作成 (ashigaru5)。
  cmd_553 → cmd_554 連鎖 (trigger E2E OK / 業務 NG) を再発防止する五重防御の1枚。
- **2026-04-22**: cmd_557 Scope1 にて §5.5 whitelist exemption 仕様追記 (ashigaru1)。
  qc_auto_check.sh field-level check 追加 (AC1: 空配列NG / AC2: 5field完全性 / AC3: n8n-fix exempt禁止) に対応。
