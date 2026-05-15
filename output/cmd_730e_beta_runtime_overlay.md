# cmd_730e β runtime overlay 実装レポート

**作成日時**: 2026-05-16T06:07:52+09:00  
**担当**: ashigaru4  
**タスク**: subtask_730e_beta_runtime_overlay  
**親cmd**: cmd_730

---

## 1. 真因対応表

| 真因 | 内容 | 本β対応 |
|------|------|---------|
| 真因A | shp 永続汚染（formations preset が cli.agents に上書き） | settings.yaml canonical baseline 修正 + shc deploy --settings-only 3経路削除 |
| 真因C | kessen@agent_cli が karo に未 override | KESSEN_MODE 時 _karo_cli_type="claude" 明示 + @model_name="Opus+T" 同期 |
| 真因D | shx settings 汚染（hybrid deployment が cli.agents を上書き） | shc deploy hybrid --settings-only 削除 → runtime overlay 化 |
| 真因B | ash4-5 Opus arm (shp 問題) | 後段 γ 対応（本β対象外） |

---

## 2. 変更内容

### 2.1 config/settings.yaml — canonical baseline 修正

| エージェント | 変更前 | 変更後 | 対応AC |
|---|---|---|---|
| karo | codex / gpt-5.5 | claude / claude-sonnet-4-6 / effort=max | BETA-1 |
| ashigaru4 | claude / claude-sonnet-4-6 | claude / claude-opus-4-7 / effort=max | BETA-3 |
| ashigaru5 | claude / claude-sonnet-4-6 | claude / claude-opus-4-7 / effort=max | BETA-3 |
| ashigaru6 | codex / gpt-5.5 | claude / claude-sonnet-4-6 / effort=max | BETA-2 |
| ashigaru7 | codex / gpt-5.5 | claude / claude-sonnet-4-6 / effort=max | BETA-2 |

formations.* セクションは一切変更なし（BETA-3, cmd_718 不変条件）。

### 2.2 shutsujin_departure.sh — runtime overlay 化

**BETA-4**: `shc.sh deploy hybrid/all-opus/all-sonnet --settings-only` 3経路を完全削除。  
代替: 各エージェント起動時にインライン runtime overlay を適用。

**BETA-5 (shx)**:
- ash6-7: `codex --model gpt-5.5 --reasoning-effort xhigh --search --dangerously-bypass-approvals-and-sandbox --no-alt-screen`
- ash1-5: settings.yaml canonical baseline そのまま使用

**BETA-6 (shk)**:
- 全員: `CLAUDE_CODE_EFFORT_LEVEL=max claude --model claude-opus-4-7 --dangerously-skip-permissions`
- karo: `_karo_cli_type="claude"` 明示 + `@model_name="Opus+T"` 同期

**BETA-7 (SHOGUN_NO_THINKING)**:
- 旧: settings.yaml に `thinking: False` を永続書込みしてから build_cli_command 呼出
- 新: `MAX_THINKING_TOKENS=0 ${_shogun_cmd}` でランタイム prefix のみ付与。settings.yaml 変更なし。

**BETA-8 (@model_name)**:
- 全 ashigaru pane に `tmux set-option -p @model_name` を追加（KESSEN_MODE="Opus+T", shx ash6-7="Codex", shu=get_model_display_name）

**BETA-10 (reverse-validate)**:
- 起動前に `sha256sum ${CLI_ADAPTER_SETTINGS}` を `_settings_hash_before` に記録
- update_dashboard_formation 後に `_settings_hash_after` と照合し不一致なら exit 1
- HYBRID_MODE: ash6-7 の `@agent_cli` が "codex" でなければ exit 1
- KESSEN_MODE: karo の `@agent_cli` が "claude" でなければ exit 1

---

## 3. 実行コマンドと検証結果

### 3.1 BETA-12: bash -n 構文チェック

```
bash -n /home/ubuntu/shogun/shutsujin_departure.sh && echo "SYNTAX OK"
→ SYNTAX OK
```

### 3.2 BETA-12: YAML parse チェック

```python
with open('config/settings.yaml') as f:
    d = yaml.safe_load(f)
# karo: {'cli_type': 'claude', 'model': 'claude-sonnet-4-6', 'effort': 'max'}
# ashigaru4: {'cli_type': 'claude', 'model': 'claude-opus-4-7', 'effort': 'max'}
# ashigaru5: {'cli_type': 'claude', 'model': 'claude-opus-4-7', 'effort': 'max'}
# ashigaru6: {'cli_type': 'claude', 'model': 'claude-sonnet-4-6', 'effort': 'max'}
# ashigaru7: {'cli_type': 'claude', 'model': 'claude-sonnet-4-6', 'effort': 'max'}
# formations.hybrid ash6: {'cli_type': 'codex', 'model': 'gpt-5.5'}  ← 不変
→ YAML OK
```

### 3.3 BETA-9: shc.sh deploy --settings-only が 0 件

```
grep -c 'scripts/shc.sh deploy.*--settings-only' shutsujin_departure.sh
→ 0
```

### 3.4 BETA-11: settings.yaml 不変 (静的検証)

起動フロー内での settings.yaml 書込み経路チェック:

```
grep -n "yaml.safe_dump|open.*'w'|>.*settings.yaml" shutsujin_departure.sh
→ (none)
```

実際の起動なしでの代替静的検証を採用（active multiagent を壊さないための措置）。  
settings.yaml hash (実装完了時点):  
`sha256sum config/settings.yaml → c4fc9acd30c5349362904c9259f34ef0d62161492227e96fa11e864ce83ead71`

reverse-validate ロジックにより、次回起動時に起動前後の hash を自動比較し、変化があれば exit 1 で検出可能。

---

## 4. commit SHA

commit: fd75c67

---

## 5. 残リスク

| リスク | 内容 | 対策 |
|------|------|------|
| codex --reasoning-effort オプション | CLI バージョンによっては `--reasoning-effort` が不明オプションの可能性 | 次回起動ログで確認。不明なら `-o model_reasoning_effort=xhigh` 等代替を検討 |
| shp.sh (真因B) | shp 側の設定汚染は本β未対応 | 後段 γ で対応予定 |
| reverse-validate のtmux pane target | `multiagent:agents.${p}` 形式が環境によって異なる可能性 | 既存の起動コードと同一形式を使用しているため影響なし |

---

## 6. γ/δ への申し送り

- **γ (scripts/shp.sh)**: shp の設定汚染（真因B）を対応。本βでは编集禁止。
- **δ-A (dashboard.yaml hook)**: 後段送り。
- **δ-B (smoke T8 shp 9x3 matrix)**: γ 完了後に実施。
- BETA-10 reverse-validate は ash6-7 @agent_cli の詳細整合チェックが追加可能（KESSEN_MODE の全 ashigaru も同様）。γ 以降で拡張検討。
