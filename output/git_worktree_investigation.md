# Git Worktree × Shogun マルチエージェントシステム 検討レポート

調査日: 2026-02-12
依頼: 殿（shogunシステムでgit worktreeを活用できるか検討）

## 結論

**活用可能。ただし現時点では即時導入の必要性は低く、段階的導入を推奨。**

## Git Worktree とは

1つの `.git` ディレクトリを共有しつつ、複数の作業ディレクトリ（各々が異なるブランチ）を同時展開できる Git の機能。

```bash
# 基本操作
git worktree add /tmp/worktrees/ashigaru1 feature-branch-1
git worktree list
git worktree remove /tmp/worktrees/ashigaru1
```

**制約**: 同一ブランチを複数の worktree で同時にチェックアウトできない。

## 現行システムの構成

```
multi-agent/                ← 全エージェントが同一ディレクトリで作業
├── queue/                  ← 通信基盤（inbox, tasks, reports）
├── scripts/                ← 共有スクリプト
├── instructions/           ← エージェント設定
├── output/                 ← 成果物
└── ...

エージェント構成:
  将軍(1) + 家老(1) + 足軽(8) = 10エージェント
  全員が同一ディレクトリ内で動作
```

## 現行システムの課題

| 課題 | 深刻度 | 発生頻度 |
|------|--------|----------|
| 足軽間のファイル同時編集による競合 | 中 | 低（タスク分離で回避中） |
| git status が全員の変更で汚染される | 低 | 常時 |
| 並列ビルド/テストが干渉する可能性 | 中 | 外部プロジェクト作業時 |
| 足軽のミスが他エージェントの作業に影響 | 高 | 稀 |

## 推奨アーキテクチャ（ハイブリッド型）

```
multi-agent/                        ← メイン worktree（将軍 + 家老）
├── .git/                           ← 共有 git ディレクトリ
├── queue/                          ← 全エージェント共有
│   ├── inbox/                      ← メッセージキュー
│   ├── tasks/                      ← タスク割り当て
│   └── reports/                    ← 報告
├── scripts/                        ← 共有スクリプト
├── instructions/                   ← エージェント設定
└── ...

/tmp/worktrees/ashigaru1/           ← 足軽1号専用 worktree
├── queue/ → symlink to main        ← 通信基盤は共有
├── scripts/ → symlink to main      ← スクリプトは共有
├── output/                         ← 独立した成果物ディレクトリ
└── （作業対象ファイル群）            ← 独立したブランチ

/tmp/worktrees/ashigaru2/           ← 足軽2号専用 worktree
└── （同上の構成）
```

### 設計原則

1. **将軍・家老はメイン worktree に留まる**: 指揮・通信・ダッシュボード管理のため
2. **各足軽に独立 worktree を付与**: ブランチ分離で衝突回避
3. **queue/ は symlink で全員共有**: 通信基盤の統一（inbox_write.sh がそのまま動作）
4. **scripts/ も symlink で共有**: スクリプトの二重管理を回避
5. **output/ は独立**: 成果物は各足軽が独自に書き出し、家老がメインに集約

### ディスク使用量

- フルクローン: ~1GB（仮定）
- Worktree: ~150MB/個（.git 共有のため約85%削減）
- 足軽8名分: ~1.2GB追加

## 導入フェーズ

| Phase | 内容 | 期間目安 | リスク |
|-------|------|----------|--------|
| Phase 1 | PoC — 足軽1名だけ worktree 化して動作検証 | 1 cmd | 低 |
| Phase 2 | 半数の足軽を worktree 化、運用課題の洗い出し | 1-2 cmd | 中 |
| Phase 3 | 全足軽を worktree 化 | 1 cmd | 中 |
| Phase 4 | shutsujin_departure.sh に worktree ライフサイクル管理を統合 | 1 cmd | 低 |

### Phase 1 の具体的検証項目

1. `git worktree add` で足軽用 worktree を作成
2. queue/ と scripts/ の symlink が正常に機能するか
3. inotifywait が symlink 先のファイル変更を検知するか
4. inbox_watcher.sh が worktree 内から正常動作するか
5. 足軽が worktree 内で Claude Code セッションを起動できるか
6. 作業完了後のブランチマージフローが機能するか

## 懸念事項と対策

| 懸念 | 対策 |
|------|------|
| inotifywait と symlink の互換性 | Phase 1 で検証。`-L` (dereference) オプションで対応可能な場合あり |
| shutsujin_departure.sh の改修規模 | worktree 作成・削除をスクリプト化し、既存フローに最小限の変更で統合 |
| ブランチマージの複雑さ | 足軽は feature branch で作業 → 家老がメインにマージ（既存の報告フローに統合） |
| CLAUDE.md の参照パス | worktree 内にも CLAUDE.md が存在するため問題なし |
| watcher_supervisor.sh との整合性 | manifest に worktree パスを追加（Phase 4 で対応） |

## 業界動向

- **Claude Code**: `--worktree` フラグをネイティブサポート（並列タスク実行用）
- **Nx.dev**: monorepo でのマルチエージェント開発に worktree を推奨
- **incident.io**: 複数 AI エージェントの並列開発で worktree を採用

## 総合評価

| 観点 | 評価 |
|------|------|
| 技術的実現可能性 | ◎ 高い（Git 標準機能、追加ツール不要） |
| 現時点の必要性 | △ 低い（現行のタスク分離で衝突は稀） |
| 将来的な価値 | ○ 高い（足軽増員、外部プロジェクト並列作業時に威力） |
| 導入コスト | ○ 低〜中（shutsujin_departure.sh の改修が主） |
| 推奨時期 | ファイル衝突が顕在化した時、または足軽を10名以上に増やす時 |

## 結論（再掲）

現時点では「研究成果として蓄えておき、実際にファイル衝突が頻発する状況が生じた際に導入する」が最も合理的。今すぐ必要な改修ではないが、将来の拡張時には有力な選択肢となる。
