# cmd_620 Scope D — karo_dispatch.sh 実装仕様書

**cmd_ref**: cmd_620  
**担当**: 足軽1号(Sonnet+T)  
**完了日**: 2026-05-01  

---

## 概要

`scripts/karo_dispatch.sh` は、karo が ashigaru/gunshi にタスクを dispatch する際の一括ヘルパースクリプト。
以下の3ステップを1コマンドで自動化し、dispatch 時の in_progress 更新漏れを構造的に不能化する。

**問題**: 2026-05-01 karo が cmd_619 dispatch 時に dashboard.yaml の in_progress 更新を漏らし、将軍が直接修正する事態が発生。  
**解決**: task YAML 更新 → dashboard in_progress 追加 → inbox_write の3ステップを1スクリプトに集約。

---

## ファイル情報

| 項目 | 値 |
|------|-----|
| ファイルパス | `scripts/karo_dispatch.sh` |
| 実行権限 | `755` (chmod +x 済み) |
| 依存スクリプト | `scripts/inbox_write.sh`, `scripts/generate_dashboard_md.py` |
| Python 実行 | `.venv/bin/python3`（フォールバック: `python3`） |

---

## 使用例

### 基本使用

```bash
bash scripts/karo_dispatch.sh \
  --agent ashigaru3 \
  --task-yaml queue/tasks/ashigaru3.yaml \
  --cmd cmd_620 \
  --content "[Scope C] round-trip test 実装" \
  --assignee "足軽3号(Sonnet+T)"
```

### dry-run モード

```bash
bash scripts/karo_dispatch.sh \
  --agent ashigaru3 \
  --task-yaml queue/tasks/ashigaru3.yaml \
  --cmd cmd_620 \
  --content "[Scope C] round-trip test 実装" \
  --assignee "足軽3号(Sonnet+T)" \
  --dry-run
```

### カスタムメッセージ付き

```bash
bash scripts/karo_dispatch.sh \
  --agent gunshi \
  --task-yaml queue/tasks/gunshi.yaml \
  --cmd cmd_620 \
  --content "[Scope E] QC review" \
  --assignee "軍師(Opus+T)" \
  --message "【task_assigned: subtask_620_scope_e】QC を開始せよ。queue/tasks/gunshi.yaml 参照。"
```

---

## 引数仕様

| 引数 | 必須 | 説明 |
|------|------|------|
| `--agent` | ✅ | 対象 agent (ashigaru1-8, gunshi) |
| `--task-yaml` | ✅ | task YAML のパス (既に書込み済み前提) |
| `--cmd` | ✅ | cmd 番号 (例: cmd_620) |
| `--content` | ✅ | in_progress に表示する作業内容の説明文 |
| `--assignee` | ✅ | 担当者表示ラベル (例: 足軽3号(Sonnet+T)) |
| `--message` | ❌ | inbox に送る本文 (省略時は task YAML の title から自動生成) |
| `--dry-run` | ❌ | 実際には何もせず、実行予定の処理を表示 |

---

## 処理ステップ詳細

### Step 1: task YAML 存在確認 + status 確認

- `--task-yaml` のファイル存在確認
- `status` フィールドを読み取り、`assigned` でない場合は WARNING を出力（処理は継続）
- `task_id` と `title` を取得（inbox メッセージ自動生成に使用）
- task YAML が存在しない場合は `exit 1`

### Step 2: dashboard.yaml に in_progress エントリを追加

dashboard.yaml の `in_progress` リストに以下の構造を追加:

```yaml
- cmd: <--cmd の値>
  content: <--content の値>
  status: 🔄 進行中
  assignee: <--assignee の値>
```

実装:
- Python `yaml.safe_load` で読み込み → append → `yaml.dump` で書き戻し
- アトミック書き込み（tmp ファイル + `os.replace`）で部分書き込みを防止
- 同一エントリ（cmd + content + assignee 全一致）の重複追加をスキップ

### Step 3: dashboard.md 再生成

`python3 scripts/generate_dashboard_md.py` を実行して dashboard.yaml から dashboard.md を再生成。
失敗した場合は `exit 1`（dashboard 不整合を防止）。

### Step 4: inbox_write.sh でエージェントに通知

`bash scripts/inbox_write.sh <agent> "<message>" task_assigned karo` を実行。

メッセージ自動生成ロジック（`--message` 省略時）:
```
【task_assigned: <task_id>】<task_title>。queue/tasks/<agent>.yaml 参照。完了後 karo inbox へ task_completed を報告せよ。
```

### Step 5: 完了ログ出力

dispatch 完了を stdout に出力。dry-run 時は各ステップで `[DRY-RUN]` プレフィックスを付与。

---

## エラー処理

| 条件 | 動作 |
|------|------|
| `--task-yaml` が存在しない | `exit 1` |
| task YAML の status が assigned でない | WARNING を出力して続行 |
| `generate_dashboard_md.py` が失敗 | `exit 1` |
| `dashboard.yaml` が存在しない | `exit 1` |
| 同一エントリが既に存在 | WARNING を出力してスキップ（`exit 0`） |

---

## 動作確認結果

dry-run モードで ashigaru3 へのサンプル dispatch を確認:

```
[Step 1] task YAML 確認: OK (status: done → WARNING + 続行)
[Step 2] dashboard.yaml への書き込み: DRY-RUN スキップ (エントリ表示)
[Step 3] generate_dashboard_md.py: DRY-RUN スキップ
[Step 4] inbox_write.sh: DRY-RUN スキップ (メッセージ表示)
→ 全4ステップの処理内容を正常確認
```

---

## 受入基準 (AC) チェック

| AC | 確認 |
|----|------|
| AC1: scripts/karo_dispatch.sh 作成 + --dry-run 実行成功 | ✅ |
| AC2: dashboard.yaml in_progress 追加ロジック実装確認 | ✅ |
| AC3: generate_dashboard_md.py 呼び出し実装 | ✅ |
| AC4: output/cmd_620_scope_d_dispatch_helper.md 作成 (80行以上) | ✅ (本ファイル) |
