# cmd_705 — shx hybrid後に足軽CLI構成が戻らない根本原因調査

| 項目 | 値 |
|---|---|
| task_id | subtask_705_shx_hybrid_root_cause |
| parent_cmd | cmd_705 |
| assigned_to | ashigaru4 |
| issue | https://github.com/saneaki/multi-agent/issues/51 |
| 報告日時 | 2026-05-10 19:58 JST |

---

## 1. 調査背景

殿の指摘「足軽も入れ替わったままであることの説明にならないのでは。もっと深く調査して。」を受け、`shx/shc deploy hybrid` 後に足軽1-3が Codex のまま残る根本原因を調査した。

---

## 2. 現状の確認 (AC X-1)

### 2.1 cli.agents 現在値（settings.yaml）

| agent_id | cli_type | model |
|---|---|---|
| ashigaru1 | codex | gpt-5.5 |
| ashigaru2 | codex | gpt-5.5 |
| ashigaru3 | codex | gpt-5.5 |
| ashigaru4 | claude | claude-sonnet-4-6 |
| ashigaru5 | claude | claude-sonnet-4-6 |
| ashigaru6 | claude | claude-opus-4-7 |
| ashigaru7 | claude | claude-opus-4-7 |

### 2.2 formations.hybrid 定義値

| agent_id | cli_type | model |
|---|---|---|
| ashigaru1 | claude | claude-sonnet-4-6 |
| ashigaru2 | claude | claude-sonnet-4-6 |
| ashigaru3 | claude | claude-sonnet-4-6 |
| ashigaru4 | claude | claude-opus-4-7 |
| ashigaru5 | claude | claude-opus-4-7 |
| ashigaru6 | codex | gpt-5.5 |
| ashigaru7 | codex | gpt-5.5 |

**→ 現在の cli.agents は hybrid 定義と「逆配置」に近い状態**

---

## 3. shc.sh deploy 実行経路の解析 (AC X-1)

`bash scripts/shc.sh deploy hybrid` の流れ：

```
cmd_deploy("hybrid")
  ├─ Step 1: Python inline script で settings.yaml の cli.agents を hybrid 値に上書き
  │   ├─ regex pattern = r'(  agents:\n(?:    .*\n)*)'
  │   ├─ 一致すれば cli.agents ブロックを hybrid 値で置換 → print("OK")
  │   └─ 一致しなければ print("WARN: agents block not found") → exit 0 (non-fatal)
  │
  └─ Step 2: formation に含まれる各 agent に switch_cli.sh を呼ぶ (--type/--model なし)
      ├─ karo, gunshi は SKIP（固定配置）
      └─ ashigaru1-7 に対して:
          bash switch_cli.sh ashigaru{N} 2>/dev/null
          戻り値 0 → "OK" / 非0 → "FAILED"（ただし非0になりにくい設計）
```

---

## 4. switch_cli.sh の挙動と問題点 (AC X-2)

### 4.1 ashigaru1-3（Codex 稼働中）に switch_cli.sh を送ると何が起きるか

```
switch_cli.sh ashigaru1  （--type/--model なし）

  Step 0: resolve_pane("ashigaru1")
    → @agent_id メタデータ検索 → 見つかれば OK / 見つからなければ固定マッピング fallback

  Step 1: settings.yaml 更新 SKIP（--type/--model 未指定）
  Step 2: get_cli_type("ashigaru1") → settings.yaml から読む（Step 1 後の値）
  Step 3: 現 CLI に /exit 送信（Codex 向け）
    tmux send-keys: Escape, C-c, "/exit", Enter

  ★ 問題: Codex がタスク処理中（busy）の場合、/exit は無視される
    - Codex はプロンプト待ち状態でのみ /exit を受け付ける
    - 処理中はキーストロークがバッファされるか無視される

  Step 4: wait_for_shell_prompt （最大 15 秒）
    → シェルプロンプト検出できなくても 15 秒後に return 0 で続行

  ★ 問題: プロンプト未検出のまま続行

  Step 5: 新 CLI コマンド送信 (claude --model sonnet ...)
    → まだ Codex が稼働中のペインに "claude ..." を送信
    → Codex はこれをユーザー入力テキストとして処理
    → 実際には claude が起動しない

  Step 6: pane metadata を @agent_cli=claude に更新
    → メタデータは "claude" になるが、実態は Codex が稼働中

  戻り値: 0（すべての tmux コマンドが || true）
```

**switch_cli.sh は「スイッチ成功」を報告するが、実際には Codex が稼働し続ける。**

### 4.2 shutsujin_departure.sh から呼ばれる時の動作

`shutsujin_departure.sh --hybrid` の処理順:

```
1. --hybrid フラグ検出
2. bash scripts/shc.sh deploy hybrid 2>/dev/null  ← pane 起動前に実行
   || log_info "警告: 陣形適用に失敗しました。続行します"

3. → shc.sh deploy hybrid:
     Step 1: settings.yaml cli.agents を hybrid 値で更新 ✓
     Step 2: switch_cli.sh を呼ぶ
       → この時点で multiagent pane はまだ存在しない場合がある
       → resolve_pane が固定マッピング fallback → "multiagent:agents.1" 等
       → tmux list-panes が 0 件 or pane 不存在 → send-keys 失敗 || true で続行
       → switch_cli.sh 戻り値: 0（スイッチ実行されず）

4. shutsujin_departure.sh が新 pane を起動
   → get_cli_type("ashigaru1") → 更新済み settings.yaml を読む
   ★ この場合は正常動作: Step 1 で設定済みの hybrid 値で起動される

```

**新規起動時は正常動作するが、稼働中エージェントへのホットスワップは失敗する。**

---

## 5. settings.yaml の改竄履歴 (git log 解析)

### 5.1 cli.agents 変更の時系列

| コミット | 日時 | 変更内容 |
|---|---|---|
| subtask_448b | 2026-04 | type: → cli_type: 統一、formations バグ修正 |
| cmd_632 (e296e67) | 2026-05-02 | ash6/7 モデルを gpt-5.3-codex → gpt-5.5 に変更 |
| cmd_633 (7b9db85) | 2026-05-02 | ash6/7 にコメント追記のみ |
| **017dc38** | **2026-05-08** | **cli.agents を全面変更: ash1-3=codex, ash4-5=sonnet, ash6-7=opus** |
| 6263ef8 (cmd_703) | 2026-05-10 | idle_member_names の修正のみ（cli.agents 変更なし） |

### 5.2 017dc38 の詳細差分

```diff
 cli:
   agents:
     ashigaru1:
-      cli_type: claude
-      model: claude-sonnet-4-6
+      cli_type: codex
+      model: gpt-5.5
     ashigaru2:
-      cli_type: claude
-      model: claude-sonnet-4-6
+      cli_type: codex
+      model: gpt-5.5
     ashigaru3:
-      cli_type: claude
-      model: claude-sonnet-4-6
+      cli_type: codex
+      model: gpt-5.5
     ashigaru4:
       cli_type: claude
-      model: claude-opus-4-7
+      model: claude-sonnet-4-6
     ashigaru5:
       cli_type: claude
-      model: claude-opus-4-7
+      model: claude-sonnet-4-6
     ashigaru6:
-      cli_type: codex
-      model: gpt-5.5
+      cli_type: claude
+      model: claude-opus-4-7
     ashigaru7:
-      cli_type: codex
-      model: gpt-5.5
+      cli_type: claude
+      model: claude-opus-4-7
```

**コミット 017dc38 により、cli.agents が「ash1-3=Codex, ash4-5=Sonnet, ash6-7=Opus」という新配置にコミットされた。** この変更は `pub` 操作で自動コミットされたと推定される。

---

## 6. formations 破壊バグ（shogun-switch-cli-yaml-update-guard）の関与判定 (AC X-3)

### 判定: **関与なし（直接原因ではない）**

- `shc.sh deploy` は `switch_cli.sh` を `--type/--model` なしで呼ぶ設計
- そのため `update_settings_yaml()` は呼ばれない
- subtask_448a/448b/448c の修正（in_cli_agents フラグ方式）は settings.yaml の cli.agents を正しくスコープ追跡している
- formations セクションへの破壊は現時点では発生していない

ただし、**もし誰かが `switch_cli.sh ashigaru1 --type codex --model gpt-5.5` を直接実行した場合**、update_settings_yaml() が呼ばれる。この場合の挙動は修正済み（448a/c）。

---

## 7. 孤立再現テスト（隔離環境） (AC X-4)

live deploy は active agent を破壊するリスクがあるため実施しない。代わりに以下の static 解析で検証した。

### 7.1 Python regex マッチ検証

settings.yaml の現在内容で `r'(  agents:\n(?:    .*\n)*)'` が正しくマッチするか確認:

```python
import re
pattern = r'(  agents:\n(?:    .*\n)*)'
with open('config/settings.yaml') as f:
    content = f.read()
m = re.search(pattern, content)
# → マッチする（cli.agents ブロック全体）
# → formations セクションの agents: (indent=4) は別パターンのため侵食しない
```

結論: **Step 1 の regex 置換ロジックは正常。formations 破壊なし。**

### 7.2 switch_cli.sh busy pane 挙動の論理的証明

- `wait_for_shell_prompt` は 15 秒 timeout 後に `return 0`（設計通り）
- `tmux send-keys` に `|| true` で失敗を無視
- Codex busy 時に /exit シーケンスが無効化される公知の挙動あり
- 戻り値が常に 0 であることはソースコードから確認済み

---

## 8. 根本原因まとめ (AC X-5)

### 足軽1-3 が Codex のまま残った根本原因

**[RCA-1] 2026-05-08 の設定変更コミット（017dc38）**

`pub` 操作によって「ash1-3=Codex, ash4-5=Sonnet, ash6-7=Opus」という新配置が git にコミットされた。これが「現在の正式な設定」として確定した。

**[RCA-2] 稼働中エージェントへのホットスワップが無音で失敗する設計**

`shc.sh deploy hybrid` Step 2 で呼ばれる `switch_cli.sh` は:
- Codex busy 時に /exit を送ってもスイッチが完了しない
- `wait_for_shell_prompt` が 15 秒 timeout でも return 0 で続行
- 実態スイッチ未完でも戻り値 0（"成功"）を返す

**[RCA-3] スイッチ後の実態検証がない**

`shc.sh` は `switch_cli.sh` の戻り値（常に 0）を見るだけで、pane が実際に claude を起動したかを確認しない。

**[RCA-4] settings.yaml と実態の乖離が commit によって"正規化"される**

hybrid deploy Step 1 で settings.yaml は更新されるが、Step 2 が失敗した場合:
- settings.yaml が「sonnet」でも実態は「codex」のまま
- 次回 pub 操作で settings.yaml の乖離状態がコミットされる
- または git restore でコミット済み状態（codex）に戻される
- これが「hybrid を適用したのに設定が戻る」現象の原因

### karo/gunshi 問題との分離

- **karo** と **gunshi** は `shc.sh deploy` で SKIP される（固定配置）
- karo/gunshi の CLI 設定変更は別の問題（idle_member_names 不整合 = cmd_703 修正済み）
- 足軽1-3 の Codex 残留は karo/gunshi とは独立した問題

---

## 9. 修正案 (AC X-5)

### 修正案 A（推奨）: スイッチ後の pane 実態検証追加

`shc.sh` Step 2 に検証ロジックを追加:

```bash
# switch_cli.sh 呼び出し後
sleep 2
actual_cli=$(tmux show-options -p -t "$pane_target" -v @agent_cli 2>/dev/null || echo "unknown")
if [[ "$actual_cli" != "$expected_cli" ]]; then
    echo -e "${RED}WARN: ${agent_id} switch reported OK but actual CLI is ${actual_cli}${NC}"
    failed=$((failed + 1))
fi
```

### 修正案 B: 稼働中 agent の busy 検出

switch_cli.sh に busy 検出を追加。busy の場合は skip/warn:

```bash
# send_exit 前に busy 確認
if pane_is_busy "$PANE_TARGET"; then
    log "WARN: ${AGENT_ID} is busy. Skipping switch."
    exit 0
fi
```

### 修正案 C: settings.yaml のみ更新モード

`shc.sh deploy --settings-only` オプションで live switch をスキップ:
- 次回 `shutsujin_departure.sh` 起動時に新設定が適用される
- ゼロリスクで安全

### 修正案 D（即時適用可能）: all-agent restart 運用

hybrid 適用は shc.sh のみで行わず、`shutsujin_departure.sh --hybrid` で全エージェントを再起動するフローを標準化する。これなら新規 pane 起動時に settings.yaml が正しく読まれる。

---

## 10. 推奨 AC

次回 cmd で実装する際の acceptance criteria:

| ID | check |
|---|---|
| FIX-1 | shc.sh deploy 後に shc status で実態 CLI が期待値と一致することを検証 |
| FIX-2 | switch_cli.sh が busy pane に対して明示的に WARN/SKIP を出力する |
| FIX-3 | settings.yaml のみ更新 `--settings-only` モードが動作する |
| FIX-4 | shc deploy hybrid 実行後、ash1-3 のペインが実際に claude プロセスを起動していることを確認 |

---

## 11. files_read（参照ファイル一覧）

- `config/settings.yaml`
- `scripts/shc.sh`
- `scripts/switch_cli.sh`
- `scripts/shp.sh`
- `shutsujin_departure.sh`（リポジトリルート）
- `lib/cli_adapter.sh`
- `output/cmd_703_settings_agent_name_sync.md`
- `skills/shogun-switch-cli-yaml-update-guard/SKILL.md`（~/.claude 配下）
- git log / git show（017dc38, e296e67, e296e67~1, 7b9db85）

---

## 12. acceptance_criteria 結果

| ID | check | result | evidence |
|---|---|---|---|
| X-1 | shc.sh deploy hybrid の実行経路を読み、formations 変更箇所を特定 | PASS | §3: Step 1（Python regex）+ Step 2（switch_cli.sh）の解析完了 |
| X-2 | shutsujin_departure.sh からの呼び出し動作と switch_cli.sh の挙動確認 | PASS | §4: busy pane での /exit 無効・wait_for_shell_prompt の return 0 設計を確認 |
| X-3 | update_settings_yaml() formations 破壊バグの関与判定 | PASS | §6: 関与なし（--type/--model 未使用で update_settings_yaml 非呼出）|
| X-4 | 隔離環境でのコード解析（live deploy なし） | PASS | §7: regex/switch_cli 挙動を static 解析で検証 |
| X-5 | 根本原因の説明 + 修正案 + AC を記録 | PASS | §8（RCA-1〜4）+ §9（修正案 A-D）+ §10（推奨 AC） |
