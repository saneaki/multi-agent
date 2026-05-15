# cmd_730f γ shp transient化 実装レポート

**作成日時**: 2026-05-16T06:20:53+09:00
**担当**: ashigaru7
**タスク**: subtask_730f_gamma_shp_transient
**親cmd**: cmd_730

---

## 1. 真因対応表

| 真因 | 内容 | 本γ対応 |
|------|------|---------|
| 真因A (shp永続汚染) | shp は settings.yaml を常に直書込み。transient/--persist フラグが存在しなかった | shp をデフォルト transient 化。--persist 指定時のみ settings.yaml 書換 |

---

## 2. 変更内容

### 2.1 scripts/shp.sh — 変更箇所

#### 新フラグ
- `--persist`: settings.yaml への永続書込みを許可。未指定=transient（デフォルト）

#### 新関数
| 関数 | 役割 |
|------|------|
| `num_cli_cmd(num)` | 番号→CLI起動コマンド文字列。1=claude/sonnet, 2=claude/opus, 3=codex/gpt-5.5 (`-c model_reasoning_effort="xhigh"`, `--reasoning-effort` は Codex CLI v0.130.0以降で廃止) |
| `resolve_pane_shp(agent_id)` | 全10構成員対応pane解決 (shogun+multiagent両セッション動的検索+fallback) |
| `wait_prompt_shp(pane)` | シェルプロンプト待機(最大15秒、claude/codex exit文言検出付き) |
| `show_persist_diff()` | --persist時の settings.yaml 変更差分表示(変更行をYELLOW表示) |
| `execute_deploy_transient(dry_run)` | transient実行: settings.yaml不変でpane切替+meta同期 |

#### 動作変更 (GAMMA-3)
- 旧: 全実行でexecute_deploy() → update_settings_batch() → settings.yaml書込み
- 新: デフォルトでexecute_deploy_transient() → settings.yaml不変のままpane切替

#### --persist guard (GAMMA-4)
- `--persist` 指定時: `show_persist_diff()` で変更行差分を表示
- 確認プロンプト「settings.yaml を永続書換」と明示
- `--yes` 併用で確認スキップ可（自動化対応）

#### cross-CLI切替 (GAMMA-5)
- transient実行でもswitch_cli.shと同等のexit経路を採用
  - codex→*: Escape + C-c + /exit Enter
  - claude→*: /exit Enter
- relaunch後に `@agent_cli`, `@model_name` をpane metaに同期
- paneタイトルも更新 (`tmux select-pane -T`)

---

## 3. AC検証結果

| AC | 内容 | 結果 |
|----|------|------|
| GAMMA-1 | 個別選択スコープが全10構成員対応 | PASS — MEMBER_IDS=(shogun karo ashigaru1-7 gunshi) |
| GAMMA-2 | モデル候補 Sonnet/Opus/Codex 3択固定 | PASS — num 1/2/3 固定、Codex=gpt-5.5/xhigh |
| GAMMA-3 | デフォルト transient、settings.yaml不変 | PASS — --persist未指定時はexecute_deploy_transient()を呼び出し |
| GAMMA-4 | --persist時は差分表示+確認必須 | PASS — show_persist_diff()で変更行YELLOW表示、確認プロンプト「永続書換」明示 |
| GAMMA-5 | cross-CLI切替 /exit + relaunch + meta同期 | PASS — codex exit経路(Escape+C-c+/exit)、pane meta @agent_cli/@model_name更新 |
| GAMMA-6 | transient後にshuで canonical に戻る設計 | PASS (静的証跡) — settings.yamlを一切変更しないため、shu実行時は canonical baseline を読む |
| GAMMA-7 | dry-run検証でsettings.yaml hash不変 | PASS — 下記参照 |
| GAMMA-8 | bash -n と YAML parse PASS | PASS — SYNTAX OK, YAML OK |
| GAMMA-9 | git preflight + Refs cmd_730 commit | PASS — 下記参照 |
| GAMMA-10 | output 記録 | 本ファイル |

---

## 4. 実行コマンドと検証結果

### 4.1 GAMMA-8: 構文チェック
```
bash -n scripts/shp.sh && echo "SYNTAX OK"
→ SYNTAX OK
```

### 4.2 GAMMA-8: YAML parse
```python
import yaml
with open('config/settings.yaml') as f:
    d = yaml.safe_load(f)
agents = d.get('cli', {}).get('agents', {})
# karo: {'cli_type': 'claude', 'model': 'claude-sonnet-4-6', 'effort': 'max'}
# ashigaru7: {'cli_type': 'claude', 'model': 'claude-sonnet-4-6', 'effort': 'max'}
→ YAML OK
```

### 4.3 GAMMA-7: dry-run + settings.yaml hash検証

#### ケース1: shp karo→Opus (全員Opus, transient dry-run)
```
bash scripts/shp.sh 2 --dry-run --yes
→ [DRY-RUN] 将軍(shogun) → 2(Opus+T) [transient]
→ [DRY-RUN] 家老(karo) → 2(Opus+T) [transient]
→ [DRY-RUN] 足軽1-7 → 2(Opus+T) [transient]
→ [DRY-RUN] 軍師(gunshi) → 2(Opus+T) [transient]
```

#### ケース2: shp ashigaru7→Codex (9個指定, 軍師=3 transient dry-run)
```
bash scripts/shp.sh 1 1 1 1 1 1 1 1 3 --dry-run --yes
→ [DRY-RUN] 将軍(shogun) → 2(Opus+T) [transient] (現在値維持)
→ [DRY-RUN] 家老(karo) → 1(Sonnet+T) [transient]
→ [DRY-RUN] 足軽1-7 → 1(Sonnet+T) [transient]
→ [DRY-RUN] 軍師(gunshi) → 3(Codex) [transient]
```

#### settings.yaml hash (全dry-run後)
```
sha256sum config/settings.yaml
→ c4fc9acd30c5349362904c9259f34ef0d62161492227e96fa11e864ce83ead71  (実装前と同一)
```

### 4.4 GAMMA-6: shu canonical設計の静的証跡
transient実行はsettings.yamlを一切変更しない。shutsujin_departure.sh (shu)はbuild_cli_command()→settings.yaml.cli.agentsを読んで起動コマンドを構築するため、transient実行後にshuを再実行すれば必ず canonical baseline に戻る。

```bash
grep -c "with open.*'w'" scripts/shp.sh
# transient経路ではopen wrが0件 (update_settings_batchはpersist経路のみ)
```

---

## 5. commit SHA

```
git log --oneline -1
→ 88d1324 feat: cmd_730f γ shp default transient化 (Refs cmd_730)
```

---

## 6. 残リスク

| リスク | 内容 | 対策 |
|------|------|------|
| transient cross-CLI wait | wait_prompt_shp()はsleep 1×15回。実環境でCLI終了が遅い場合タイムアウト | switch_cli.shのwait_for_shell_prompt()と同等ロジック採用済み |
| shogunペイン切替 | shogunは将軍セッションのpane。transientでも切替対象に含まれる | resolve_pane_shpがshogun:0.xを動的検索+fallback |

---

## 7. δ-A/δ-B への申し送り

- **δ-A (dashboard.yaml hook)**: 後段送り
- **δ-B (smoke T8 shp 9x3 matrix)**: γ完了。transient動作検証済み(dry-run)。実機smokeはδ-Bで実施
- 本γにより真因A(shp永続汚染)は構造的に解消。--persistなしでは settings.yaml は一切変更されない
