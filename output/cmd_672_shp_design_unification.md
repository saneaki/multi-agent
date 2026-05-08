# cmd_672: shp 9構成員設計統一 — 完了レポート

**作成日時**: 2026-05-08T11:04:21+09:00  
**担当**: ashigaru4  
**ステータス**: 完了

---

## 1. 根因分析: cmd_662/666 設計分裂

### 分裂の経緯

| cmd | 変更内容 | 結果 |
|-----|---------|------|
| cmd_662 | shp.sh 初期実装 | `MEMBER_IDS` = 将軍を含む **10名** |
| cmd_666 | `--kill/--retreat` 撤収モード実装 | `RETREAT_MEMBER_IDS` = 将軍除く **9名** に設定 |

この結果、出陣側 MEMBER_IDS (10名) と撤収側 RETREAT_MEMBER_IDS (9名) が乖離。  
出陣時に将軍 SKIP 表示が出る問題 → 殿御指摘「将軍再起動を求められている時点で shp 改修に問題がある」。

### 根本原因

将軍は Claude Code の性質上、通常の `switch_cli.sh` (tmux send-keys ベース) での切替が困難。  
初期実装時に MEMBER_IDS へ将軍を含めたことで、後続の撤収実装との不整合が生まれた。

---

## 2. 統一方針

**shp の責務を 9構成員 (家老/足軽1-7/軍師) に限定する。**  
将軍のモデル切替は `shogun-model-switch` skill または殿手動という別経路に明文化。

---

## 3. 変更内容

### scripts/shp.sh

| 変更 | 内容 |
|------|------|
| `MEMBER_IDS` | `shogun` を除外 → 9名 (家老/足軽1-7/軍師) に統一 |
| `RETREAT_MEMBER_IDS` | コメント更新 (= MEMBER_IDS と同一である旨) |
| `apply_positional()` | 仕様を {1,2,3,9} 個に再定義。10個は互換警告で将軍指定を無視 |
| `apply_preset()` sonnet-codex-mix | `SELECTIONS[shogun]` 削除 |
| `execute_deploy()` | 将軍 SKIP 処理ブロックを削除 |
| 出陣完了メッセージ | 「将軍は手動再起動」メッセージを削除 |
| `interactive_select_retreat()` | 「将軍は撤収対象外」→「対象: 家老→足軽1-7→軍師 ※将軍は別管理」に変更 |
| ヘッダーコメント/usage/examples | 9名ベースに統一、10名表記を撤去 |

### positional args 新仕様

| 個数 | 意味 |
|------|------|
| 1 | 全9名 = N1 |
| 2 | 家老 = N1, 他8名 = N2 |
| 3 | 家老 = N1, 足軽1-7 = N2, 軍師 = N3 |
| 9 | MEMBER_IDS 順に個別指定 |
| 10 | 互換のみ: 将軍指定 (N1) を WARNING 出力後に無視して残り9名に適用 |

### docs/shogun_shell_commands.md

| 変更 | 内容 |
|------|------|
| shp 対象明記 | 「9構成員 (将軍除く)」に統一 |
| sonnet-codex-mix | 将軍除外を反映 |
| positional args テーブル | 新仕様 ({1,2,3,9,10互換}) に更新 |
| 使い分けガイド | 「将軍だけ別モデル」→「将軍のモデル切替」行を追加 |
| 出陣プロンプト順序 | 家老始まりの9名に更新 |
| 将軍モデル切替説明 | shogun-model-switch skill セクションに追記 (B-2 対応) |

---

## 4. 将軍モデル切替の代替経路

shp は将軍を管理対象外とする。将軍のモデルを変更するには:

1. **`/shogun-model-switch` skill** — Claude Code から自然言語で指定
2. **殿手動** — 将軍ペインで Claude Code を終了し `--model <model>` 付きで再起動

---

## 5. 回帰テスト結果

| テスト | コマンド | 結果 |
|--------|---------|------|
| C-1 | `bash -n scripts/shp.sh` | **PASS** |
| C-2 | `bash scripts/shp.sh --help` | **PASS** (9構成員ベース、10名表記なし) |
| C-3a | `shp 1 --dry-run --yes` | **PASS** (9名全員 Sonnet+T) |
| C-3b | `shp 1 2 --dry-run --yes` | **PASS** (家老Sonnet, 他8名Opus) |
| C-3c | `shp 1 2 1 --dry-run --yes` | **PASS** (家老Sonnet, 足軽1-7 Opus, 軍師Sonnet) |
| C-3d | `shp 1 2 1 1 1 1 1 1 1 --dry-run --yes` (9個) | **PASS** (9名個別指定) |
| C-4 | `shp --kill --dry-run` | **PASS** (9名表示、将軍行なし) |
| C-5a | `shp --preset all-sonnet --dry-run` | **PASS** (9名 Sonnet+T) |
| C-5b | `shp --preset heavy-opus --dry-run` | **PASS** (9名 Opus+T) |
