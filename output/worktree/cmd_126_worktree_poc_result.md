# Git Worktree PoC検証結果レポート

検証日: 2026-02-12
実施者: 足軽5号（ashigaru5）
親コマンド: cmd_126
タスク: subtask_126b

## エグゼクティブサマリー

**総合結果: PASS（条件付き）**

git worktreeの基本機能は正常に動作するが、通信基盤（inbox_write.sh）のパス解決に重大な注意点がある。
worktree内エージェントは**絶対パス**でスクリプトを呼び出す必要がある。

| 検証項目 | 結果 | 備考 |
|----------|------|------|
| 検証1: Claude Code起動可否 | **PASS** | claude --version 正常動作、CLAUDE.md読取OK |
| 検証2: inbox_write.sh互換性 | **条件付PASS** | 絶対パスならOK、ローカルscripts/はNG |
| 検証3: ファイル操作→マージ | **PASS** | Fast-forwardマージ成功 |
| 検証4: クリーンアップ | **PASS** | ディレクトリ・ブランチ完全削除、汚染なし |

## 検証1: worktree内でClaude Codeセッション起動可否

### 結果: PASS

### 実行ログ

```
$ bash scripts/worktree_create.sh test-poc feat/poc-worktree-test
[WORKTREE] Creating worktree for agent: test-poc
[WORKTREE] Branch: feat/poc-worktree-test
[WORKTREE] Path: /home/saneaki/multi-agent/.trees/test-poc
HEAD is now at 6d35baa feat: watcher_supervisor自動復旧機能 + cmd_122研究レポート追加
[WORKTREE] Success!
```

### 構造確認

| ファイル/ディレクトリ | 存在 | 理由 |
|---------------------|------|------|
| CLAUDE.md | ✅ | git tracked（.gitignoreで明示的に許可） |
| scripts/ | ✅ | git tracked（.gitignoreで許可） |
| instructions/ | ✅ | git tracked（.gitignoreで許可） |
| output/ | ✅ | git tracked（.gitignoreで許可） |
| config/ | ✅ | git tracked（.gitignoreで許可） |
| **queue/** | **❌** | .gitignore非許可（ホワイトリスト方式で除外） |
| **logs/** | **❌** | .gitignore非許可（ホワイトリスト方式で除外） |

### claude CLI動作

```
$ cd .trees/test-poc && claude --version
2.1.39 (Claude Code)
```

### 発見事項

- CLAUDE.mdはgit trackedなのでworktreeにも正しくコピーされる
- `queue/`と`logs/`はホワイトリスト方式の.gitignore（デフォルト全除外 `*`、明示許可のみ追加）で管理外のため、worktreeには存在しない
- worktree内でClaude Codeの起動は可能だが、通信基盤のqueueがないため単独では通信不能

## 検証2: 通信基盤（inbox_write.sh）互換性

### 結果: 条件付きPASS

### テストケース

| テスト | コマンド | 書込先 | 結果 |
|--------|---------|--------|------|
| ローカルscripts/ | `cd .trees/test-poc && bash scripts/inbox_write.sh karo ...` | `.trees/test-poc/queue/inbox/karo.yaml` | **NG**（worktree内に孤立queue作成） |
| 絶対パス | `cd .trees/test-poc && bash /home/saneaki/multi-agent/scripts/inbox_write.sh karo ...` | `queue/inbox/karo.yaml`（メイン） | **OK** |

### 根本原因

`inbox_write.sh`のSCRIPT_DIR解決ロジック:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX="$SCRIPT_DIR/queue/inbox/${TARGET}.yaml"
```

- `BASH_SOURCE[0]`はスクリプトファイル自体の位置を基準にする
- worktree内の`scripts/inbox_write.sh`を実行すると、SCRIPT_DIRがworktreeルートに解決される
- 結果: worktree内に独立した`queue/`ディレクトリが作成され、メインqueueとは切り離される

### 対策案

| 方法 | 内容 | メリット | デメリット |
|------|------|----------|-----------|
| **A: 絶対パス強制** | エージェントは常に絶対パスでinbox_write.shを呼ぶ | 即時対応可、改修不要 | 設定ミスのリスク |
| **B: symlink** | worktree作成時にqueue/→メインqueue/のsymlinkを張る | エージェント側の変更不要 | worktree_create.sh改修必要 |
| **C: 環境変数** | `SHOGUN_ROOT`環境変数でメインworktreeを指定 | 柔軟性高い | 全スクリプト改修必要 |
| **D: .git参照** | inbox_write.sh内でgit worktree listからメインworktreeパスを取得 | 自動解決 | git依存、パフォーマンス |

**推奨: B（symlink）**— worktree_create.sh にqueue/とlogs/のsymlink作成を追加するのが最もシンプル。

## 検証3: ファイル操作→マージ

### 結果: PASS

### 実行ログ

```
# worktree内でファイル作成・コミット
$ cd .trees/test-poc
$ echo "worktree PoC test Thu Feb 12 22:10:20 JST 2026" > output/worktree_test_file.md
$ git add output/worktree_test_file.md
$ git commit -m "test: worktree PoC verification"
[feat/poc-worktree-test 1c146a9] test: worktree PoC verification
 1 file changed, 1 insertion(+)

# メインworktreeでマージ
$ cd /home/saneaki/multi-agent
$ git merge feat/poc-worktree-test
Updating 6d35baa..1c146a9
Fast-forward
 output/worktree_test_file.md | 1 +
 1 file changed, 1 insertion(+)

# クリーンアップ
$ git rm output/worktree_test_file.md
$ git commit -m "chore: remove worktree PoC test file"
[original b0e6f23] chore: remove worktree PoC test file
```

### 発見事項

- ホワイトリスト方式の.gitignoreにより、`output/*.md`など明示的に許可されたパスのみgit addが成功する
- 任意ファイル名（例: `worktree_test_file.txt`）はgit add時にIgnoredエラーが発生
- Fast-forwardマージが正常に動作（worktreeはメインと同じコミットから分岐しているため）
- マージ後、メインworktreeでファイルが正しく参照可能

## 検証4: クリーンアップ後の汚染確認

### 結果: PASS

### 実行ログ

```
$ bash scripts/worktree_cleanup.sh test-poc
[WORKTREE] Cleaning up worktree for agent: test-poc
[WORKTREE] Checking for uncommitted changes...
[WORKTREE] Branch: feat/poc-worktree-test
[WORKTREE] Running: git worktree remove .trees/test-poc
[WORKTREE] Attempting to delete branch: feat/poc-worktree-test
Deleted branch feat/poc-worktree-test (was 1c146a9).
[WORKTREE] Branch feat/poc-worktree-test deleted (was merged)
[WORKTREE] Running: git worktree prune
[WORKTREE] Cleanup complete!
```

### 確認項目

| 確認項目 | 結果 |
|----------|------|
| `.trees/test-poc/` ディレクトリ | ✅ 削除済み |
| `feat/poc-worktree-test` ブランチ | ✅ 削除済み（マージ済みのため`-d`で安全に削除） |
| `git worktree list` | ✅ メインworktreeのみ |
| `git status` | ✅ PoC前と同一状態 |

### 発見事項

- cleanup.shはuncommitted changes検出→abort機能が正しく動作する設計
- マージ済みブランチは`git branch -d`（安全削除）で問題なく削除
- worktree内で作成されたgit管理外ファイル（queue/等）もworktreeディレクトリごと削除される
- git worktree pruneにより残存メタデータもクリーンアップ

## 発見された制約事項

### 1. .gitignore対象ファイルのworktree不在（重要度: 高）

ホワイトリスト方式の.gitignoreにより、以下の運用上重要なディレクトリがworktreeに存在しない:

- `queue/`（通信基盤）
- `logs/`（ログ）
- `projects/`（プロジェクト設定）
- `dashboard.md`（ダッシュボード）

**対策**: worktree作成スクリプトにsymlink自動作成処理を追加。

### 2. inbox_write.sh のSCRIPT_DIR解決（重要度: 高）

worktree内のscripts/コピーを使用すると、メッセージがworktree内の孤立queueに書き込まれ、通信が断絶する。

**対策**: symlink（推奨）または絶対パス強制。

### 3. ホワイトリスト.gitignoreとgit add（重要度: 中）

任意のファイルをworktree内でgit addする際、.gitignoreのホワイトリストに含まれていない場合はエラーとなる。`output/`配下の`.md`ファイルのみ安全にadd可能。

**対策**: 成果物は必ず`output/`配下に配置する運用ルールを徹底。

## 通信基盤との互換性まとめ

| コンポーネント | 互換性 | 条件 |
|---------------|--------|------|
| inbox_write.sh | ✅ | 絶対パスまたはメインworktreeのscripts/を使用 |
| inbox_watcher.sh | ⚠️ 未検証 | queue/がメインにある限り問題なしと推定 |
| inotifywait | ⚠️ 未検証 | symlink使用時は`-L`オプションが必要な可能性 |
| watcher_supervisor.sh | ⚠️ 未検証 | manifest.yamlの拡張が必要（Phase 4想定） |
| tmux send-keys | ✅ | worktreeとは独立（pane IDベース） |

## 次フェーズ（Phase 2: 実cmdでの運用）への提言

### 必須対応（Phase 2前提条件）

1. **worktree_create.sh改修**: queue/, logs/ へのsymlink自動作成を追加
   ```bash
   # 追加すべき処理
   ln -s "$SCRIPT_DIR/queue" "$WORKTREE_PATH/queue"
   ln -s "$SCRIPT_DIR/logs" "$WORKTREE_PATH/logs"
   ```

2. **inotifywait + symlink検証**: symlinkされたqueue/内のファイル変更をinotifywaitが検知できるか確認

3. **エージェント起動手順の確認**: worktree内でのtmux pane設定、agent_id設定のフロー整備

### 推奨対応

4. **SHOGUN_ROOT環境変数の導入**: 全スクリプトでメインworktreeの絶対パスを参照可能にする
5. **worktree_create.shにsymlink対象の設定ファイル化**: 将来的にsymlink対象を柔軟に追加できるようにする
6. **cleanup.shにsymlink解除処理を追加**: symlinkを残さない安全なクリーンアップ

### Phase 2検証項目案

- [ ] 実際の足軽1名をworktreeで起動し、cmd実行→報告の全フローを完走
- [ ] inotifywait + symlink queue/の動作検証
- [ ] worktree間のgitコンフリクト発生時のハンドリング確認
- [ ] 長時間運用時の安定性（worktreeのGCやlock問題）
