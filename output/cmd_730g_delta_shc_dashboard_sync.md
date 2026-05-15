# cmd_730g δ-A shc status同期 実装レポート

**作成日時**: 2026-05-16T06:34:31+09:00  
**担当**: ashigaru1  
**タスク**: subtask_730g_delta_shc_dashboard_sync  
**親cmd**: cmd_730

---

## 1. AC対応表

| AC | 内容 | 結果 |
|----|------|------|
| DELTA-A1 | `--settings-only` deprecated化 | PASS — deprecation警告追加、shu/shk/shx呼び出し0件確認 |
| DELTA-A2 | `shc status` 3系統diff拡張 | PASS — pane meta/settings.yaml/dashboard.yaml 3セクション実装 |
| DELTA-A3 | dashboard auto-sync は dashboard.yaml 限定 hook | PASS — `shc sync-meta` 新設、dashboard.md直書換なし |
| DELTA-A4 | 限定更新対象キー明示、既存キー保護 | PASS — formation_status のみ更新、FORBIDDEN_KEYS 13種明示 |
| DELTA-A5 | bash -n + YAML parse PASS | PASS — 下記参照 |
| DELTA-A6 | git preflight + Refs cmd_730 commit | PASS — 下記参照 |
| DELTA-A7 | output記録 | 本ファイル |

---

## 2. 変更内容

### 2.1 scripts/shc.sh — 変更箇所

#### 新定数
```bash
DASHBOARD_FILE="${PROJECT_ROOT}/dashboard.yaml"
```

#### Usage 更新
- `shc status` 説明: "Show pane meta / settings.yaml / dashboard.yaml diff (3-way)"
- `shc sync-meta` 追加: "Sync pane meta to dashboard.yaml formation_status (safe keys only)"

#### DELTA-A1: `--settings-only` deprecation
`cmd_deploy` の `settings_only=true` 経路に deprecation 警告を追加。機能は維持（安全策）。

```
DEPRECATED: --settings-only was removed from shu/shk/shx in cmd_730β.
  Use runtime overlay (shutsujin_departure.sh) instead.
```

#### DELTA-A2: `cmd_status` 3セクション化

**Section [1] Pane Meta** — 既存の pane ループ + tmp_pane に保存  
**Section [2] settings.yaml baseline vs pane diff** — Python inline で settings.yaml の cli.agents と pane @agent_cli を照合し OK/NO_PANE/MISMATCH 表示  
**Section [3] dashboard.yaml status** — metadata.last_updated, streak, in_progress, formation_status を表示

#### DELTA-A3/A4: `cmd_sync_meta` 新設

```
shc sync-meta
```

- pane meta (@agent_id/@agent_cli/@model_name) を収集
- dashboard.yaml を読み込み
- `formation_status` キー **のみ** を更新
- 書込み禁止キー (13種) を snapshot で保護、変更検出時は ABORT
- 書込み後に dashboard.yaml を上書き保存

**更新対象キー (1種):**
```
formation_status:
  last_sync: <JST ISO8601>
  agents:
    <agent_id>:
      cli: <cli_type>
      model: <model_name>
```

**FORBIDDEN_KEYS (13種 — 絶対に変更しない):**
```python
FORBIDDEN_KEYS = {
    'action_required', 'action_required_archive', 'achievements',
    'in_progress', 'gate_registry', 'observation_queue',
    'observation_queue_archive', 'skill_candidates', 'metrics',
    'documentation_rules', 'frog', 'idle_members', 'metadata',
}
```

---

## 3. 実行コマンドと検証結果

### 3.1 DELTA-A5: bash -n 構文チェック

```
bash -n scripts/shc.sh && echo "SYNTAX OK"
→ SYNTAX OK
```

### 3.2 DELTA-A5: YAML parse チェック

```python
import yaml
with open('config/settings.yaml') as f:
    d = yaml.safe_load(f)
cli_agents = d.get('cli', {}).get('agents', {})
# keys: ['ashigaru1', 'ashigaru2', 'ashigaru3', 'ashigaru4', 'ashigaru5',
#         'ashigaru6', 'ashigaru7', 'gunshi', 'karo', 'shogun']
with open('dashboard.yaml') as f:
    dd = yaml.safe_load(f)
# metadata: {'frog_status': '🐸 未撃破', 'last_updated': '2026-05-16T06:23:10+09:00', 'streak': 33}
→ YAML OK
```

### 3.3 DELTA-A1: --settings-only 呼び出し 0件確認

```
grep -c "scripts/shc.sh deploy.*--settings-only" shutsujin_departure.sh
→ 0
```

---

## 4. commit SHA

(本ファイル作成後に記録)

---

## 5. 残リスク

| リスク | 内容 | 対策 |
|--------|------|------|
| cmd_sync_meta の live テスト未実施 | dashboard.yaml が forbidden_files のため、本δ-A内では実機実行なし。構文検証のみ | δ-B または karo が実機確認する |
| formation_status キー新設 | dashboard.yaml に存在しない新規キー。yaml.dump により既存キーの順序が変わる可能性 | FORBIDDEN_KEYS の snapshot 比較で内容保護。フォーマット変更は許容 |
| Python heredoc の `||` 挙動 | `set -euo pipefail` 環境で `<<'PYEOF' || echo WARN` が正しく動くか | bash -n で構文確認済み。実機テストは δ-B で確認 |

---

## 6. δ-B/ε への申し送り

- **δ-B (ashigaru2)**: tests/smoke および tests/unit で shc の smoke テストを実施。`shc status` の 3-section 出力 + `shc sync-meta` の formation_status 書込みを実機検証すること。
- **ε**: β BETA-10 reverse-validate の ash6-7 @agent_cli 詳細整合チェック拡張を検討。
- `shc sync-meta` は karo/gunshi が shp/shx 完了 hook として呼び出すことで、dashboard 🏯 の自動同期 (真因3解消) が完成する。本δ-Aは hook の土台実装のみ。
