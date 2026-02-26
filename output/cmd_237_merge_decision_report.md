# cmd_237 マージ判断レポート
upstream/main 22コミット → original ブランチ

**実行日時**: 2026-02-25
**ベース**: e6e7641 (merge commit)
**コンフリクトファイル数**: 9件

---

## 取り込んだ主要変更（upstream）

| コミット | 内容 | 判断 |
|---------|------|------|
| feat: bloom_model_preference優先ルーティング (#80) | Bloomレベルに基づくモデル動的切替 | ✅ 取込 |
| feat: MEMORY.md自動初期化 + リポジトリローカルメモリ | first_setup.shにMEMORY.md初期化追加 | ✅ 取込 |
| feat: instructions英語化 + north_starフィールド (#79) | 指示ファイルの英語化とnorth_star戦略フィールド追加 | ✅ 取込 |
| feat: model-switchスキル + switch_cli.sh | CLIモデル切替スクリプト | ✅ 取込 |
| feat: Stop Hook auto-notification + バッチ処理プロトコル | Stop Hookによる自動通知、バッチ処理プロトコル追加 | ✅ 取込 |
| fix: macOS互換 shebang統一 (#78) | `#!/usr/bin/env bash` に統一 | ✅ 取込 |
| fix: bash 3.2 compat 3件 | mapfile→while loop、fswatch fallback等 | ✅ 取込 |
| fix: ntfy受信ブロック解除、Stop Hook inbox配信 (#75) | shogunのntfy受信を妨げていた3機構を除去 | ✅ 取込 |
| fix: Codex /clear→/new変換 + テスト11件 | Codex用の/new対応（フォークは/clearのまま） | ✅ 取込（フォーク部分は保持） |
| docs: README Quick Start追加、README_ja同期 | ドキュメント整備 | ✅ 取込 |

---

## コンフリクト解決詳細（9ファイル）

### 1. `.gitignore`
- **HEAD**: `!scripts/update_dashboard_timestamp.sh` + `!scripts/notion_session_log.sh`
- **upstream**: `!scripts/switch_cli.sh`
- **解決**: 両方保持（3行全て追加）
- **根拠**: フォーク独自スクリプトを維持しつつ、upstreamの新機能も取込

### 2. `AGENTS.md` (2箇所)
- **コンフリクト1**: Pattern B (VSCode) セクション vs `/new Recovery`
  - **解決**: HEAD優先（Pattern Bはフォーク独自機能、/clearを維持）
  - **根拠**: 当フォークはClaude Codeが主CLI。/clearコマンドを使用
- **コンフリクト2**: 5層コンテキスト(/clear) vs 4層(/new)
  - **解決**: HEAD優先（global_context.md Layer 1、/clear維持）
  - **根拠**: フォーク独自のglobal_context.md管理システムを保護

### 3. `instructions/ashigaru.md`
- **内容**: Agent Self-Watch Phase Rulesの表現差異
- **解決**: upstream採用（より簡潔で明確な表現）
- **根拠**: 意味に変化なし、upstreamの洗練された表現を採用

### 4. `instructions/gunshi.md`
- **HEAD**: `## Quality Check (Gunshi Delegation)` ヘッダーのみ
- **upstream**: North Star Alignmentセクション新設 + `## Quality Check & Dashboard Aggregation` に改称
- **解決**: upstream採用（North Star機能を取り込み）
- **根拠**: North Starフィールドは戦略的目標追跡の新機能。cmd_190の教訓を基にした重要改善

### 5. `instructions/karo.md` (3箇所)
- **コンフリクト1**: ターゲットパス vs bloom_level_rule
  - **解決**: upstream採用（bloom_level_ruleを取り込み）
  - **根拠**: bloom_level_ruleは既存のbloom_routingシステムの必須コンポーネント
- **コンフリクト2**: 「独り言・進捗報告・思考もすべて戦国風口調で行え」 vs 英語版
  - **解決**: HEAD優先（日本語指示を維持）
  - **根拠**: 当フォークの言語設定がja（日本語）のため、日本語指示が必要
- **コンフリクト3**: 「The 戦国風 tone applies to outward speech」 vs 英語簡略版
  - **解決**: HEAD優先（具体的な説明を維持）
  - **根拠**: フォーク固有の表現を保護

### 6. `instructions/shogun.md` (2箇所)
- **コンフリクト1**: 日本語エージェント名（家老/足軽/軍師）のフロー説明 vs 英語版
  - **解決**: HEAD優先（日本語名を維持）
  - **根拠**: システム全体が戦国テーマ。日本語エージェント名は必須
- **コンフリクト2**: Phase Rulesの表現差異（minor wording）
  - **解決**: upstream採用（より標準化された表現）
  - **根拠**: 意味に変化なし、upstreamの表現が明確

### 7. `scripts/inbox_watcher.sh`
- **HEAD**: shogunペインがアクティブ&クライアント接続時、`tmux display-message`で視覚通知+send-keys
- **upstream**: display-message廃止、send-keysのみ（PR#75）
- **解決**: upstream採用
- **根拠**: PR#75でntfy受信ブロックの原因として特定・除去された機構。テストも対応変更済み

### 8. `scripts/inbox_write.sh`
- **HEAD**: Python書き込み成功後、ntfy自動通知（cmd_complete/cmd_milestone→shogunのみ）
- **upstream**: ntfy通知なし（シンプルなexitのみ）
- **解決**: HEAD優先（ntfy通知機能を保持）
- **根拠**: **フォーク必須機能**。殿がiOSのntfyアプリで完了通知を受け取るために必要。upstreamには不要だが当フォークの核心機能

### 9. `tests/unit/test_send_wakeup.bats` (2箇所)
- **HEAD**: T-SHOGUN-003がdisplay-message + send-keysをテスト
- **upstream**: T-SHOGUN-003がsend-keysのみをテスト（PR#75後）
- **解決**: upstream採用
- **根拠**: inbox_watcher.shの変更（display-message廃止）と整合させるため

---

## 自動マージされた主要ファイル

以下のファイルはgitが自動的にマージ（コンフリクットなし）:

| ファイル | 内容 |
|---------|------|
| `CLAUDE.md` | upstream front-matterが追加。フォーク独自カスタマイズは保持 |
| `agents/default/system.md` | 自動マージ成功 |
| `lib/agent_status.sh` | agent_statusの改善 |
| `scripts/ntfy.sh` | ntfy改善 |
| `scripts/watcher_supervisor.sh` | supervisor改善 |
| `memory/global_context.md` | 学習メモが追加 |
| `skills/shogun-model-switch/SKILL.md` | 新規追加 |
| `skills/shogun-readme-sync/SKILL.md` | 新規追加 |
| `scripts/switch_cli.sh` | 新規追加 |

---

## 動作確認状況

- コンフリクットマーカー残存: 0件 ✅
- git status: 正常 ✅

---

## 注意事項

### CLAUDE.md の状態
git auto-mergeによりupstreamのfront-matter（YAML設定ブロック）が追加されたが、
フォーク独自のカスタマイズ（Pattern A/B、instructions/*.md参照、日本語ペルソナ等）は全て保持済み。

### inbox_write.sh の非同期性
upstreamがlocking機構をリファクタリングしているが、フォークはntfy通知のために
旧locking（`200>"$LOCKFILE"`）を継続使用。将来的に統合を検討。
