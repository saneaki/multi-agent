# cmd_703 — settings 構成員名称不整合修正

| 項目 | 値 |
|---|---|
| task_id | subtask_703_settings_agent_name_sync |
| parent_cmd | cmd_703 |
| assigned_to | ashigaru7 |
| issue | https://github.com/saneaki/multi-agent/issues/49 |
| 報告日時 | 2026-05-10 17:55 JST |

## 1. 目的

`config/settings.yaml` の `karo.idle_member_names` が古い構成名を含み、同ファイル
`cli.agents` および実 tmux pane 構成 (`@agent_id` メタ) とズレていた。dispatch 時に
agent 識別が誤る潜在リスクがあるため、settings.yaml を最小修正で同期する。

## 2. 差分整理 (S-1)

修正前の三系統を突合した結果が以下の通り。

| agent_id | settings.idle_member_names (旧) | settings.cli.agents | 実 tmux pane | ズレ判定 |
|---|---|---|---|---|
| ashigaru1 | 足軽1号(Sonnet) | codex / gpt-5.5 | node (codex) | YES |
| ashigaru2 | 足軽2号(Sonnet+T) | codex / gpt-5.5 | node (codex) | YES |
| ashigaru3 | 足軽3号(Sonnet) | codex / gpt-5.5 | node (codex) | YES |
| ashigaru4 | 足軽4号(Opus+T) | claude / claude-sonnet-4-6 | claude | YES |
| ashigaru5 | 足軽5号(Opus+T) | claude / claude-sonnet-4-6 | claude | YES |
| ashigaru6 | 足軽6号(Codex) | claude / claude-opus-4-7 | claude | YES |
| ashigaru7 | 足軽7号(Codex) | claude / claude-opus-4-7 | claude | YES |
| gunshi | 軍師(Opus+T) | claude / claude-opus-4-7 | claude | OK |

cli.agents が実運用上の SoT (source of truth)。idle_member_names を cli.agents の
`cli_type` × `model` に合わせる方針で同期する。

## 3. 命名規則

| cli_type | model 接頭 | 表記 |
|---|---|---|
| codex | gpt-5.x | (Codex) |
| claude | claude-sonnet-* | (Sonnet) |
| claude | claude-opus-* | (Opus+T) — 既存 ashigaru6/7・gunshi の表記踏襲 (Extended Thinking 既定 enabled) |

ashigaru4/5 は cli.agents が `claude-sonnet-4-6` のため (Sonnet) 採用。dashboard.yaml
側で `(Opus+T)` と記載されているのは旧 formation `hybrid` 切替時の名残と判断。本タスクの
SoT は cli.agents を採用。

## 4. 実施した修正 (S-2)

### 修正ファイル: `config/settings.yaml`

```diff
   idle_member_names:
-    - 足軽1号(Sonnet)
-    - 足軽2号(Sonnet+T)
-    - 足軽3号(Sonnet)
-    - 足軽4号(Opus+T)
-    - 足軽5号(Opus+T)
-    - 足軽6号(Codex)
-    - 足軽7号(Codex)
+    - 足軽1号(Codex)
+    - 足軽2号(Codex)
+    - 足軽3号(Codex)
+    - 足軽4号(Sonnet)
+    - 足軽5号(Sonnet)
+    - 足軽6号(Opus+T)
+    - 足軽7号(Opus+T)
     - 軍師(Opus+T)
```

最小修正。cli.agents/formations/その他 section は触っていない。dashboard.md および
dashboard.yaml は editable_files 範囲外のため未編集 (S-4 遵守)。

## 5. 検証 (S-3)

### 5.1 YAML syntax validation

```bash
$ python3 -c "import yaml; yaml.safe_load(open('config/settings.yaml'))"
# (no output, exit 0)
```

### 5.2 validate_idle_members.sh

修正前:
```
[validate_idle_members] WARN: 足軽2号(Sonnet+T) が idle_members に不在
[validate_idle_members] WARN: 足軽6号(Codex) が idle_members に不在
[validate_idle_members] WARN: 2体不在 (mode=check, dry_run=false)
[exit: 0]
```

修正後:
```
[validate_idle_members] WARN: 足軽1号(Codex) が idle_members に不在
[validate_idle_members] WARN: 足軽2号(Codex) が idle_members に不在
[validate_idle_members] WARN: 足軽3号(Codex) が idle_members に不在
[validate_idle_members] WARN: 足軽4号(Sonnet) が idle_members に不在
[validate_idle_members] WARN: 足軽5号(Sonnet) が idle_members に不在
[validate_idle_members] WARN: 足軽6号(Opus+T) が idle_members に不在
[validate_idle_members] WARN: 足軽7号(Opus+T) が idle_members に不在
[validate_idle_members] WARN: 7体不在 (mode=check, dry_run=false)
[exit: 0]
```

判定: validator は新名称を `EXPECTED_MEMBERS` として正しく取得 (exit 0)。WARN は
dashboard.yaml の `idle_members[].name` が旧名称のまま追従していないため。これは
S-4 の通り karo (dashboard 一次責務者) が反映する。

## 6. 残リスク・引き継ぎ事項

| 項目 | 内容 | 引継先 |
|---|---|---|
| dashboard.yaml 反映 | `idle_members[].name` 8 件を新名称に更新 (足軽1-3 を Codex、足軽4-5 を Sonnet、足軽6-7 を Opus+T へ) | karo |
| dashboard.md 反映 | 「家臣団 / 進行中 / 完了」セクションの 足軽N号 表記更新 | karo |
| Issue #49 close | settings.yaml 同期は完遂。dashboard 反映後に close 可。それまで OPEN 維持推奨 | karo |
| ashigaru4/5 表記 | cli.agents=`claude-sonnet-4-6` のため (Sonnet) 採用。+T 化希望なら settings.yaml.cli.agents の model を `claude-opus-4-7` に切替 + idle_member_names を (Opus+T) へ | 将軍/家老の判断 |
| formations.hybrid との差 | `formations.hybrid` は ashigaru1-5 claude/ashigaru6-7 codex 構成。現行 cli.agents は ashigaru1-3 codex のため逆配置。formation 切替時に再同期が必要 | 切替実施時に再走 |

## 7. Issue #49 close 条件

以下が全て満たされた時点で close 可能:

1. settings.yaml.idle_member_names が cli.agents と整合 (本 PR で完了)
2. dashboard.yaml.idle_members[].name が settings.yaml.idle_member_names と一致 (karo 対応待ち)
3. dashboard.md の 足軽N号 表記が新名称で表示 (karo 対応待ち)
4. validate_idle_members.sh --mode strict が exit 0 (= dashboard 反映後)

## 8. acceptance_criteria 結果

| ID | check | result | evidence |
|---|---|---|---|
| S-1 | idle_member_names と cli.agents の差分を表で整理 | PASS | §2 差分表 |
| S-2 | 最小修正で名称同期 | PASS | §4 diff (1セクション 7行差し替え) |
| S-3 | validate_idle_members.sh で確認 | PASS | §5.2 exit 0、新名称が expected に反映 |
| S-4 | dashboard.md は直接編集しない | PASS | dashboard.md/yaml ともに無変更 |
| S-5 | output に Issue#49・変更・検証・残リスク記録 | PASS | 本 md (§1〜§7) |

## 9. files_modified

- `config/settings.yaml` (idle_member_names 7 行差し替え)
- `output/cmd_703_settings_agent_name_sync.md` (本ファイル新規)
- `queue/reports/ashigaru7_report.yaml` (cmd_703 entry 追記)
- `queue/inbox/ashigaru7.yaml` (read:false 3 件 → read:true)
- `queue/tasks/ashigaru7.yaml` (status 更新)
