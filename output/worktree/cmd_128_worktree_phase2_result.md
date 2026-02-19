# Git Worktree Phase 2 検証結果レポート

検証日: 2026-02-12
実施者: 足軽5号（ashigaru5）
親コマンド: cmd_128
タスク: subtask_128c

## 1. エグゼクティブサマリー

**総合結果: PASS**

Phase 1で発見された全課題（symlink不在、SCRIPT_DIR解決問題）が改修により解決されたことを実証。
worktree内で足軽がcmd実行→報告の全フローを完走できることを確認した。

| 検証項目 | 結果 | 備考 |
|----------|------|------|
| 検証1: inotifywait + symlink | **PASS** | 双方向でイベント検知成功、`-L`オプション不要 |
| 検証2: 実動テスト全フロー | **PASS** | worktree作成→ファイル操作→inbox_write→マージ→クリーンアップ完走 |
| 検証3: inotify worktreeクリーンアップ | **PASS** | symlink安全解除→worktree除去→ブランチ削除 |

### Phase 1からの改善点

| Phase 1の課題 | Phase 2の改修 | 検証結果 |
|--------------|-------------|---------|
| queue/がworktreeに存在しない | worktree_create.shにsymlink作成追加 | ✅ symlink正常動作 |
| inbox_write.shのパス解決問題 | SHOGUN_ROOT環境変数対応 | ✅ 動作確認済み |
| クリーンアップ時のsymlink残留リスク | cleanup.shにsymlink解除処理追加 | ✅ 安全解除＋整合性確認 |

## 2. 検証1: inotifywait + symlink結果

### 結果: PASS

### テスト構成

- worktree: `.trees/test-inotify`（feat/test-inotifyブランチ）
- symlink: `.trees/test-inotify/queue → /home/saneaki/multi-agent/queue`

### テストA: メインのqueue/を監視、worktree symlink経由で変更

```
$ inotifywait -m -e modify,create,attrib /home/saneaki/multi-agent/queue/inbox/ &
$ touch /home/saneaki/multi-agent/.trees/test-inotify/queue/inbox/test_inotify_check

出力:
/home/saneaki/multi-agent/queue/inbox/ CREATE test_inotify_check
/home/saneaki/multi-agent/queue/inbox/ ATTRIB test_inotify_check
```

**結果: PASS** — メインqueue/を監視中に、worktree側のsymlink経由でファイル作成→検知成功。

### テストB: worktree側のsymlink queue/を監視、メインから変更

```
$ inotifywait -m -e modify,create,attrib /home/saneaki/multi-agent/.trees/test-inotify/queue/inbox/ &
$ touch /home/saneaki/multi-agent/queue/inbox/test_inotify_check2

出力:
/home/saneaki/multi-agent/.trees/test-inotify/queue/inbox/ CREATE test_inotify_check2
/home/saneaki/multi-agent/.trees/test-inotify/queue/inbox/ ATTRIB test_inotify_check2
```

**結果: PASS** — symlink パスで監視しても、実体パスでのファイル変更を検知。

### 重要発見

- **`-L`（dereference）オプションは不要。** Linuxのinotifywaitはデフォルトでsymlink先のディレクトリを監視する。
- Phase 1の調査レポートで「`-L`が必要な可能性」と記載したが、実測で不要と確認。
- これはinbox_watcher.shの改修が不要であることを意味する（現行のinotifywaitコマンドがそのまま動作する）。

## 3. 検証2: 実動テスト結果

### 結果: PASS（全10ステップ完走）

### Step 1: worktree作成

```
$ bash scripts/worktree_create.sh test-phase2 feat/worktree-phase2-test
[WORKTREE] Symlink: queue → /home/saneaki/multi-agent/queue
[WORKTREE] Symlink: logs → /home/saneaki/multi-agent/logs
[WORKTREE] SKIP: Source does not exist: projects
[WORKTREE] Symlink: dashboard.md → /home/saneaki/multi-agent/dashboard.md
[WORKTREE] Success!
```

### Step 2: symlink確認

| 対象 | 存在 | リンク先 |
|------|------|----------|
| queue | ✅ symlink | `/home/saneaki/multi-agent/queue` |
| logs | ✅ symlink | `/home/saneaki/multi-agent/logs` |
| dashboard.md | ✅ symlink | `/home/saneaki/multi-agent/dashboard.md` |
| projects | ❌ (SKIP) | メインに存在しないため正常スキップ |

### Step 3: ファイル作成・コミット

```
$ cd .trees/test-phase2
$ echo "# Phase 2 worktree test ..." > output/cmd_128_worktree_test.md
$ git add output/cmd_128_worktree_test.md
$ git commit -m "test: worktree Phase 2 verification"
[feat/worktree-phase2-test b3d7abe] test: worktree Phase 2 verification
```

### Step 4: inbox_write パス解決テスト

| テスト | SHOGUN_ROOT | 書き込み先 | 結果 |
|--------|------------|-----------|------|
| テストA | 未設定 | メインqueue（symlink経由） | **PASS** |
| テストB | `/home/saneaki/multi-agent` | メインqueue（直接） | **PASS** |

**重要発見: SHOGUN_ROOT未設定でもメインqueueに到達した。**

理由: inbox_write.shのフォールバック（BASH_SOURCE[0]ベース）でSCRIPT_DIRがworktreeルートに解決されるが、worktreeの`queue/`がsymlinkなので、結果的にメインのqueueに書き込まれる。

**結論: symlinkがあればSHOGUN_ROOTは必須ではない。ただし二重安全策として価値あり。**

| シナリオ | symlink | SHOGUN_ROOT | 結果 |
|---------|---------|-------------|------|
| Phase 1（改修前） | なし | なし | ❌ 孤立queue作成 |
| Phase 2 symlink only | あり | なし | ✅ symlink経由で到達 |
| Phase 2 SHOGUN_ROOT only | なし | あり | ✅ 直接到達 |
| Phase 2 両方 | あり | あり | ✅ 二重安全（SHOGUN_ROOT優先） |

### Step 5: メイン側inbox到着確認

```
$ grep "Phase2テスト" queue/inbox/karo.yaml
- content: 'Phase2テストA: SHOGUN_ROOT未設定 — 対応不要'
- content: 'Phase2テストB: SHOGUN_ROOT設定済み — 対応不要'
```

両テストメッセージがメインkaro inboxに正常到達。

### Step 6: マージ

```
$ git merge feat/worktree-phase2-test
Updating b0e6f23..b3d7abe
Fast-forward
 output/cmd_128_worktree_test.md | 1 +
```

Fast-forwardマージ成功。

### Step 7-8: マージ確認・テストファイル削除

```
$ cat output/cmd_128_worktree_test.md
# Phase 2 worktree test Thu Feb 12 22:39:30 JST 2026

$ git rm output/cmd_128_worktree_test.md
$ git commit -m "chore: remove worktree Phase 2 test file"
[original 4496c70] chore: remove worktree Phase 2 test file
```

### Step 9: worktreeクリーンアップ

```
$ bash scripts/worktree_cleanup.sh test-phase2
[WORKTREE] Removing symlinks in worktree...
[WORKTREE] Unlinked symlink: dashboard.md (was → /home/saneaki/multi-agent/dashboard.md)
[WORKTREE] Unlinked symlink: queue (was → /home/saneaki/multi-agent/queue)
[WORKTREE] Unlinked symlink: logs (was → /home/saneaki/multi-agent/logs)
[WORKTREE] Verifying link target integrity...
[WORKTREE] ✓ Intact: queue (in main worktree)
[WORKTREE] ✓ Intact: logs (in main worktree)
[WORKTREE] ✓ Intact: dashboard.md (in main worktree)
[WORKTREE] Cleanup complete!
```

### Step 10: 事後確認

| 確認項目 | 結果 |
|---------|------|
| `.trees/test-phase2/` ディレクトリ | ✅ 削除済み |
| `feat/worktree-phase2-test` ブランチ | ✅ 削除済み |
| メインqueue/ | ✅ 健在（inbox/*.yaml正常） |
| メインlogs/ | ✅ 健在（health_check.log等正常） |
| git worktree list | ✅ メインのみ |
| git status | ✅ PoC前と同一状態 |

## 4. worktree_create.sh symlink動作確認

### 改修内容

```bash
SYMLINK_TARGETS=("queue" "logs" "projects" "dashboard.md")

for target in "${SYMLINK_TARGETS[@]}"; do
    # 存在チェック → スキップ判定 → symlink作成
done
```

### 動作確認結果

| 動作 | 結果 |
|------|------|
| 存在するディレクトリのsymlink作成 | ✅ queue, logs |
| 存在するファイルのsymlink作成 | ✅ dashboard.md |
| 存在しないターゲットのスキップ | ✅ projects（SKIP表示） |
| 既存worktreeの重複チェック | ✅ （Phase 1から引き継ぎ） |
| 既存ブランチの重複チェック | ✅ （Phase 1から引き継ぎ） |

## 5. worktree_cleanup.sh symlink安全処理確認

### 改修内容

```bash
# find で symlink を検出 → unlink で安全解除 → リンク先整合性確認
SYMLINKS=$(find "$WORKTREE_PATH" -maxdepth 1 -type l)
for symlink in $SYMLINKS; do
    unlink "$symlink"
done
# 整合性確認
for target in "queue" "logs" "projects" "dashboard.md"; do
    [ -e "$SCRIPT_DIR/$target" ] && echo "✓ Intact"
done
```

### 動作確認結果

| 動作 | 結果 |
|------|------|
| symlink検出（find -type l） | ✅ 3件検出 |
| 安全解除（unlink） | ✅ リンク先は破壊されない |
| リンク先整合性確認 | ✅ queue, logs, dashboard.md健在 |
| 存在しないターゲットの報告 | ✅ projects "Not found (may not exist)" |
| worktree除去（git worktree remove） | ✅ 正常 |
| ブランチ安全削除（git branch -d） | ✅ マージ済みのため安全削除 |
| メタデータ整理（git worktree prune） | ✅ 正常 |

## 6. SHOGUN_ROOT + inbox_write パス解決確認

### 改修内容

```bash
# 旧: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 新: SHOGUN_ROOT環境変数を優先、未設定時はフォールバック
SCRIPT_DIR="${SHOGUN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
```

### パス解決マトリクス

| 実行場所 | SHOGUN_ROOT | scripts/の所在 | SCRIPT_DIR解決先 | queue/パス | 結果 |
|---------|-------------|---------------|-----------------|-----------|------|
| メインworktree | 未設定 | メイン | メインルート | メインqueue/ | ✅ |
| メインworktree | 設定済み | メイン | SHOGUN_ROOT | メインqueue/ | ✅ |
| worktree | 未設定 | worktreeコピー | worktreeルート | symlink→メインqueue/ | ✅ |
| worktree | 設定済み | worktreeコピー | SHOGUN_ROOT | メインqueue/ | ✅ |
| worktree | 未設定 | 絶対パス指定 | メインルート | メインqueue/ | ✅ |

**後方互換性: 完全維持。** 既存のメインworktree運用に影響なし。

## 7. 残存する制約事項

### 制約1: .gitignoreホワイトリストとgit add（重要度: 低）

worktree内で任意ファイルをgit addする際、.gitignoreホワイトリストに含まれていないとエラーとなる。Phase 1から変更なし。

**対策**: 成果物は`output/`配下の`.md`ファイルとして配置するルールで対応可能。

### 制約2: projects/ディレクトリの不在（重要度: 低）

メインworktreeに`projects/`が存在しない場合、symlinkが作成されない。worktree内でprojects/を参照するタスクがある場合は事前にメインで作成が必要。

**対策**: 必要に応じてメインworktreeでmkdir projects/を実行。

### 制約3: worktree間のマージコンフリクト（重要度: 中、未検証）

複数の足軽が同一ファイルを異なるworktreeで編集した場合のコンフリクト解決は未検証。Phase 3で実際のcmd運用時に検証が必要。

**対策**: 家老が一元的にマージを管理（タスク分離でコンフリクト自体を予防するのが最善策）。

### 制約4: SHOGUN_ROOT環境変数の設定方法（重要度: 低）

SHOGUN_ROOT未設定でもsymlink経由で動作するが、shutsujin_departure.shでのexport追加が望ましい。

**対策**: Phase 4でshutsuji_departure.shに `export SHOGUN_ROOT=$(pwd)` を追加。

## 8. Phase 3（全足軽worktree化）への提言

### 必須対応

1. **shutsujin_departure.shの改修**
   - 足軽起動前にworktree_create.shを呼び出す
   - エージェント起動時にworktreeディレクトリにcdする設定
   - `export SHOGUN_ROOT` をtmux環境に設定

2. **ブランチ命名規則の策定**
   - 例: `agent/ashigaru{N}/cmd_{CMD_ID}` または `feat/cmd_{CMD_ID}-ashigaru{N}`
   - 一意性と追跡性を確保

3. **マージタイミングの規定**
   - タスク完了時: 足軽がコミット → 家老がマージ
   - cmd完了時: 全足軽のブランチをマージ → worktreeクリーンアップ

### 推奨対応

4. **worktreeライフサイクルの自動化**
   - cmd開始時: 自動worktree作成
   - cmd完了時: 自動マージ＋クリーンアップ
   - 異常時: 家老が手動介入

5. **監視機構の拡張**
   - watcher_supervisor.shのmanifestにworktreeパスを追加
   - worktree数・ディスク使用量の監視

### 検証項目

- [ ] 足軽2名以上の同時worktree運用
- [ ] 実cmdの全フロー（タスク割当→作業→報告→マージ）
- [ ] 長時間運用でのGC・lock問題
- [ ] worktree間のコンフリクト発生時のハンドリング
- [ ] shutsujin_departure.shとの統合テスト

## 9. 家老のworktreeマージワークフロー設計案

### 基本フロー

```
[足軽タスク完了]
  ↓
足軽: output/ にファイル作成 → git add → git commit → 報告YAML
  ↓
家老: 報告受領 → 品質チェック
  ↓
家老: cd /home/saneaki/multi-agent（メインworktree）
  ↓
家老: git merge <足軽ブランチ> → コンフリクト解決（必要時）
  ↓
家老: bash scripts/worktree_cleanup.sh <agent_id>
  ↓
家老: dashboard.md更新（マージ結果記録）
```

### コンフリクト発生時

```
家老: git merge <足軽ブランチ>
  ↓ (CONFLICT)
家老: コンフリクトファイルを確認
  ↓
家老: 手動解決 or 足軽に再作業指示
  ↓
家老: git add <解決済みファイル> → git commit
```

### cmd完了時の一括処理

```
家老: 全足軽の報告完了を確認
  ↓
家老: 各足軽ブランチを順次マージ
  ↓
家老: 全worktreeクリーンアップ
  ↓
家老: git worktree list で残存確認
  ↓
家老: cmd完了報告（将軍へ）
```

### 注意事項

- 家老自身はメインworktreeで作業する（worktree不要）
- マージ順序: コンフリクトの少ないブランチから（独立タスクを先にマージ）
- マージ前に必ずgit statusで現在の状態を確認
- 破壊的操作禁止（D003, D004）: force mergeやreset --hardは使わない
