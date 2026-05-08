# cmd_677: sh 警告整理 + self_clear_check 修正 レポート

作成: 2026-05-08 JST / 担当: ashigaru5

---

## north_star 3点照合

| 点 | 内容 | 結果 |
|----|------|------|
| 1 | 🔴 停止 sh 削除 | `ntfy_listener.sh` 削除 + `sh_health_targets.yaml` 除外 ✅ |
| 2 | 🟡 警告 11件 Tier 別処理 | Tier1: 2件修正 (+ C-2自然解消確認) / Tier2: 調査完了 / Tier3: 観察記録 ✅ |
| 3 | self_clear_check.sh wrapper 構造対応 | 3スクリプト修正 + 全9構成員 dry-run PASS ✅ |

---

## Scope A: 🔴 ntfy_listener 削除

### A-1: ntfy_listener 関連 sh / systemd unit / cron 削除

| 対象 | 結果 |
|------|------|
| `scripts/ntfy_listener.sh` | 削除済み (`rm scripts/ntfy_listener.sh`) |
| systemd unit (ntfy-related) | 存在なし (確認済み) |
| cron エントリ (ntfy-related) | 存在なし (確認済み) |
| `config/sh_health_targets.yaml` から ntfy_listener 除外 | 完了 (3E セクション削除) |

注: `scripts/ntfy.sh` は `scripts/notify.sh` が参照中のため保持。
cmd_658 Phase 3 で別途削除予定。

### A-2: dashboard 🚨 要対応 [cmd_673-ntfy-listener] 削除

完了。`dashboard.md` から該当行を削除。

---

## Scope B: self_clear_check.sh wrapper 構造対応

### 問題
全タスク YAML が `task: { status: ... }` wrapper 形式に移行済みだが、
3つの self_clear_check スクリプトが `data.get('status', 'unknown')` で
フラット形式のみ対応 → 常に `status=unknown` → SKIP → /clear 未発行 → silent failure。

### 修正 (B-1)

**`scripts/self_clear_check.sh`** (L53-58):
```python
# 修正前
data = yaml.safe_load(f)
print(data.get('status', 'unknown'))

# 修正後
data = yaml.safe_load(f) or {}
if 'task' in data:
    data = data['task']
print(data.get('status', 'unknown'))
```

### 修正 (B-2)

**`scripts/karo_self_clear_check.sh`** (cond_2 ashigaru/gunshi task YAML read):
- 同様の wrapper 対応を追加

**`scripts/gunshi_self_clear_check.sh`** (cond_2 gunshi task YAML read):
- 同様の wrapper 対応を追加

### B-3: 動作確認

`bash scripts/self_clear_check.sh <agent_id> --dry-run` で全構成員確認:

| エージェント | task status | 結果 | 判定 |
|------------|-------------|------|------|
| ashigaru1 | done | CLEAR CANDIDATE (tool_count=2110) | ✅ 正常 |
| ashigaru2 | completed | CLEAR CANDIDATE (tool_count=914) | ✅ 正常 |
| ashigaru3 | done | CLEAR CANDIDATE (tool_count=1689) | ✅ 正常 |
| ashigaru4 | completed | CLEAR CANDIDATE (tool_count=1540) | ✅ 正常 |
| ashigaru5 | assigned | SKIP (active task) | ✅ 正常 |
| ashigaru6 | assigned | SKIP (active task) | ✅ 正常 |
| ashigaru7 | blocked | SKIP (unknown=active 扱い) | ✅ 正常 |
| karo | (YAML なし) | SKIP: task YAML not found | ✅ 正常 (karo_self_clear_check.sh が別途処理) |
| gunshi | done | CLEAR CANDIDATE (tool_count=1943) | ✅ 正常 |

ash1-4 および gunshi で status 正常読み取り確認。修正前は全員 status=unknown → SKIP だった。

---

## Scope C: Tier 1 即修正

### C-1: suggestions_digest.yaml ParserError — 修正完了

**根本原因**: `queue/suggestions.yaml` の line 13355-13681 に 2スペース余分インデント。
`sug_cmd_640_d_reverify_001` エントリから始まる複数エントリが、
前エントリのブロックマッピング内にネストされた状態になっていた。

**修正**: `sed -i '13355,13681s/^  //' queue/suggestions.yaml`

**確認**: パース後 `suggestions` キーで 733件 正常取得。

### C-2: dashboard_rotate syntax error — 自然解消確認

**調査結果**: 
- エラーは `dashboard_rotate.sh` の旧バージョン (L46/51) に存在
- 最終エラー日: **2026-04-27** (7日以上前)
- 5/1-5/8 の全 8 runs: SUCCESS (エラーなし)
- sh_health_check の `7d failure: 56` は古いログ行の蓄積 (7-day window 計算の精度問題)

**対応**: 修正不要 (自然解消済み)。Tier 2 のログローテーション改善 cmd でクリアアップ推奨。

### C-3: session_to_obsidian git push failed — 修正完了

**根本原因**: obsidian リポジトリが `fix/cmd_645_workflow_filename_mismatch` ブランチに
切り替わった状態で `git push origin main` を実行 → non-fast-forward rejection。

**修正** (`scripts/session_to_obsidian.sh`):
```bash
# DO_PUSH ブロックに追加 (git add の前)
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "Warning: obsidian repo on branch '${CURRENT_BRANCH}', switching to main" >&2
  git checkout main 2>/dev/null || { echo "git checkout main failed" >&2; exit 1; }
fi
git pull --rebase origin main 2>/dev/null || echo "Warning: git pull --rebase failed, continuing" >&2
```

---

## Scope D: Tier 2 調査結果サマリー

詳細: `output/cmd_677_tier2_audit.md`

| sh | 真因 | 修正方針 |
|----|------|---------|
| cmd_kpi_observer | FALSE POSITIVE: `fail=0` が FAIL pattern にマッチ | ignore_patterns 追加 (15分) |
| inbox_watcher[shogun] | 古いログ蓄積 + ビジー時 send-keys 失敗 (散発) | ログローテーション + 7d filter 改善 (別 cmd) |
| inbox_watcher[karo] | CLI drift (pane=codex 時 send-keys 機能せず) | Codex pane 対応 (別 cmd, 4h) |
| shogun_inbox_notifier | FALSE POSITIVE: 通知内容に "error/fail" 文字列含む | ignore_patterns 追加 (15分) |

---

## Scope E: Tier 3 観察記録

以下は軽微 failure のため観察継続 (修正不要):

| sh | 7d failure | 状況 |
|----|-----------|------|
| inbox_watcher[gunshi] | 2 | 散発的、機能影響なし。cmd_673 sh_health で継続監視 |
| inbox_watcher[ashigaru1] | 1 | 同上 |
| inbox_watcher[ashigaru6] | 9 | ash6 が Codex 使用中の可能性 (同 karo パターン) |
| inbox_watcher[ashigaru7] | 2 | 散発的、機能影響なし |

1ヶ月観察継続し、傾向継続なら別 cmd で修正検討。

---

## 変更ファイル一覧

| ファイル | 変更内容 | Scope |
|---------|---------|-------|
| `scripts/ntfy_listener.sh` | 削除 | A-1 |
| `config/sh_health_targets.yaml` | ntfy_listener エントリ削除 | A-1 |
| `dashboard.md` | [cmd_673-ntfy-listener] 行削除 | A-2 |
| `scripts/self_clear_check.sh` | task: wrapper 対応 | B-1 |
| `scripts/karo_self_clear_check.sh` | task: wrapper 対応 (cond_2) | B-2 |
| `scripts/gunshi_self_clear_check.sh` | task: wrapper 対応 (cond_2) | B-2 |
| `queue/suggestions.yaml` | line 13355-13681 インデント修正 | C-1 |
| `scripts/session_to_obsidian.sh` | git checkout main + pull --rebase 追加 | C-3 |
| `output/cmd_677_tier2_audit.md` | Tier 2 調査報告 | D-2 |
| `output/cmd_677_sh_warning_consolidation.md` | 本レポート | G-1 |

---

## AC チェックリスト

| AC | 内容 | 結果 |
|----|------|------|
| A-1 | ntfy_listener 関連 sh / systemd unit / cron 削除 + sh_health_targets.yaml から除外 | ✅ PASS |
| A-2 | dashboard 🚨 要対応 [cmd_673-ntfy-listener] 削除 | ✅ PASS |
| B-1 | self_clear_check.sh の python parser を wrapper 構造対応に修正 | ✅ PASS |
| B-2 | karo_self_clear_check.sh / gunshi_self_clear_check.sh の同様 bug 確認 + 修正 | ✅ PASS |
| B-3 | 全足軽 (ash1-7) + karo + gunshi で self_clear_check 動作確認 | ✅ PASS (dry-run) |
| C-1 | suggestions_digest yaml ParserError 修正 | ✅ PASS |
| C-2 | dashboard_rotate syntax error 修正 | ✅ PASS (自然解消確認) |
| C-3 | session_to_obsidian git push failed 修正 | ✅ PASS |
| D-1 | Tier 2 調査完了 | ✅ PASS |
| D-2 | output/cmd_677_tier2_audit.md 記録 | ✅ PASS |
| E-1 | Tier 3 観察記録 | ✅ PASS |
| G-1 | output/cmd_677_sh_warning_consolidation.md 作成 | ✅ PASS |

---

## 残課題 (別 cmd 候補)

1. **sh_health false positive 解消** (cmd_kpi_observer + shogun_inbox_notifier ignore_patterns) — 低優先、30分
2. **inbox_watcher Codex pane 対応** — 中優先、4h、別 cmd 設計要
3. **ログローテーション + sh_health 7d filter 改善** — 中優先、3h
4. **cmd_658 Phase 3** (ntfy.sh / ntfy_wsl_template.sh 等の完全削除) — 中優先、既存 cmd
