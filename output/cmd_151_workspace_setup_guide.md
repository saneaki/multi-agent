# multi-agent-shogun ワークスペース設定ガイド

> 作成日: 2026-02-14
> cmd_151 統合ドキュメント（subtask_151a/151b/151c の調査結果を統合）

---

## 1. 概要

本ドキュメントは multi-agent-shogun システムのワークスペース設定を網羅的に記録したものである。新環境構築時の手順書として、また既存環境の設定確認リファレンスとして利用できる。

**対象読者**: multi-agent-shogun を新規環境にセットアップする開発者

**構成**: 前提条件 → 依存ツール → ディレクトリ構成 → 各種設定 → インフラ → セットアップ手順 の順に記載。時系列に実行可能な構成とした。

---

## 2. 前提条件

### 2.1 OS要件

| 項目 | 要件 |
|------|------|
| OS | Ubuntu/Debian系 Linux（WSL2 または VPS） |
| カーネル | Linux 5.x 以上（WSL2: 5.15+推奨） |
| メモリ | 8GB以上推奨（Claude Code複数起動時） |
| ディスク | 2GB以上の空き容量 |

### 2.2 必要権限

| 権限 | 用途 |
|------|------|
| sudo | apt-get によるパッケージインストール |
| SSH鍵 | GitHub SSH接続（origin リモート） |
| 環境変数設定権限 | MCP認証トークン等の設定 |

---

## 3. 依存ツールのインストール

### 3.1 必須ツール一覧

| ツール | 用途 | インストール方法 |
|--------|------|------------------|
| tmux (3.4+) | マルチエージェントセッション管理 | `sudo apt install -y tmux` |
| inotify-tools | inbox_watcher.sh のファイル監視 | `sudo apt install -y inotify-tools` |
| python3 (3.12+) | YAML解析、スクリプト実行 | `sudo apt install -y python3 python3-pip` |
| PyYAML | Python YAML ライブラリ | `pip3 install pyyaml` |
| flock | ファイルロック（排他制御） | util-linux に同梱（通常プリインストール） |
| curl | HTTP通信（通知等） | `sudo apt install -y curl` |
| Node.js (20+) | Claude Code CLI 実行環境 | nvm 経由推奨 |
| Claude Code CLI | AI エージェント本体 | `npm install -g @anthropic-ai/claude-code` |
| git | バージョン管理 | `sudo apt install -y git` |

### 3.2 オプションツール

| ツール | 用途 | 備考 |
|--------|------|------|
| jq | JSON解析 | 現在は python3 で代替。性能要件次第で導入検討 |
| yq | YAML編集 | 同上。inbox_write.sh は python fallback で動作中 |
| Docker | GitHub MCP サーバー実行 | github MCP 使用時のみ必要 |

### 3.3 一括インストールコマンド

```bash
# 基本ツール
sudo apt update
sudo apt install -y tmux inotify-tools curl python3 python3-pip git
pip3 install pyyaml

# Node.js（nvm経由）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install 20

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
```

---

## 4. ディレクトリ構成と各ディレクトリの役割

### 4.1 全体構成

```
multi-agent/
├── .claude/              # Claude Code プロジェクト設定
├── .github/              # GitHub Actions CI/CD、copilot-instructions.md
├── .trees/               # git worktree 並列実行用（Git管理外）
├── .vscode/              # VSCode設定
├── agents/               # Multi-CLI対応エージェント定義（Kimi K2用）
├── backups/              # バックアップデータ（Git管理外）
├── config/               # 設定ファイル群
├── context/              # プロジェクト別コンテキスト
├── demo_output/          # デモ出力
├── docs/                 # ドキュメント
├── images/               # スクリーンショット、ASCIIアート
├── instructions/         # エージェント指示書
├── lib/                  # 共通ライブラリ
├── logs/                 # 実行ログ（Git管理外）
├── memory/               # Memory MCP用データ
├── output/               # コマンド出力レポート
├── queue/                # タスクキュー・inbox・レポート（Git管理外）
├── saytask/              # SayTask用データ
├── scripts/              # 全スクリプト
├── skills/               # スキル定義
├── status/               # ステータス管理（Git管理外）
├── templates/            # テンプレートファイル
├── tests/                # テストスクリプト（bats）
├── CLAUDE.md             # プロジェクトルート指示書
├── dashboard.md          # 家老生成ダッシュボード（Git管理外）
└── shutsujin_departure.sh # 出陣（起動）スクリプト
```

### 4.2 Git管理方式

**ホワイトリスト型 .gitignore**: デフォルト全除外（`*`）→ OSS公開対象のみ明示的に許可（`!path`）

| カテゴリ | Git管理 | 理由 |
|----------|---------|------|
| instructions/, scripts/, output/ | ✅ | OSS公開対象 |
| queue/, projects/, logs/ | ❌ | 個人データ・シークレット含む可能性 |
| config/ | 一部✅ | settings.yaml（サンプル）は管理、ntfy_auth.env は除外 |
| .trees/ | ❌ | worktree 一時ディレクトリ |
| dashboard.md | ❌ | 家老が動的に生成 |

---

## 5. Claude Code設定（~/.claude/ 配下の構成）

### 5.1 ディレクトリ構成

```
~/.claude/
├── settings.json          # 権限・Hook・プラグイン設定
├── .mcp.json              # MCPサーバー定義
├── CLAUDE.md              # Agent-First ワークフロー定義
├── agents/                # 専門エージェント定義（13件）
├── commands/              # スラッシュコマンド定義（33件）
├── skills/                # 再利用スキル（60件以上）
├── rules/                 # コーディング規約
│   ├── common/            # 言語共通ルール
│   ├── typescript/        # TypeScript固有
│   ├── python/            # Python固有
│   └── golang/            # Go固有
├── projects/              # セッション履歴（JSONL）
└── scripts/
    └── hooks/             # Hookスクリプト（JS）
```

### 5.2 settings.json 主要設定

#### permissions セクション
- **allow**: 自動承認ツール呼び出しパターンのホワイトリスト
  - Git操作（add, push, fetch, pull, checkout等）
  - GitHub CLI（gh workflow run, gh api）
  - Python実行、Memory MCP、Notion MCP の自動許可

#### hooks セクション

| Hook種別 | 内容 |
|----------|------|
| PreToolUse | Dev server のtmux外起動ブロック、長時間コマンド警告、git push レビュー、不要.md作成ブロック、戦略的コンパクション提案 |
| PostToolUse | PR URL表示、Prettier自動実行、TypeScript型チェック、console.log警告 |
| PreCompact | pre-compact.js による事前処理 |
| SessionStart | session-start.js による前回コンテキスト読込 |
| SessionEnd | session-end.js による状態保存、evaluate-session.js によるセッション評価 |
| Stop | console.log 監査 |

#### enabledPlugins
- `everything-claude-code@everything-claude-code`
- `claude-md-management@claude-plugins-official`

### 5.3 エージェント一覧（~/.claude/agents/）

| エージェント | 用途 |
|-------------|------|
| planner | 実装計画の策定 |
| architect | システム設計・技術判断 |
| tdd-guide | テスト駆動開発の遂行 |
| code-reviewer | コード品質・セキュリティレビュー |
| security-reviewer | 脆弱性分析・セキュリティ監査 |
| build-error-resolver | ビルドエラー解決 |
| e2e-runner | Playwright E2Eテスト実行 |
| refactor-cleaner | デッドコード削除 |
| doc-updater | ドキュメント同期 |
| go-reviewer | Goコードレビュー |
| go-build-resolver | Goビルドエラー修正 |
| python-reviewer | Pythonコードレビュー |
| database-reviewer | DBクエリ・スキーマレビュー |

### 5.4 スラッシュコマンド（~/.claude/commands/）

33件のコマンドが定義済み。主要なもの:

| コマンド | 用途 |
|----------|------|
| /plan | 実装計画の作成 |
| /tdd | TDDワークフロー強制 |
| /code-review | 品質レビュー |
| /verify | 包括検証 |
| /pub | ドキュメント更新→コミット→プッシュ |
| /orchestrate | マルチエージェントオーケストレーション |
| /multi-workflow | マルチモデル協調開発 |

### 5.5 スキル（~/.claude/skills/）

60件以上。カテゴリ別:

| カテゴリ | 件数 | 代表例 |
|----------|------|--------|
| n8n関連 | 10 | n8n-workflow-patterns, n8n-expression-syntax |
| テスト・TDD | 7 | springboot-tdd, python-testing, golang-testing |
| 言語パターン | 7 | springboot-patterns, django-patterns, python-patterns |
| セキュリティ | 5 | security-review, security-scan |
| インフラ・デプロイ | 5 | deployment-patterns, docker-patterns |
| フロントエンド/バックエンド | 4 | frontend-patterns, api-design |
| データベース | 2 | postgres-patterns, clickhouse-io |
| 学習・評価 | 3 | continuous-learning-v2, eval-harness |
| プロジェクト固有 | 8+ | legal-document-namer, tkinter-segment-operation |

### 5.6 ルール（~/.claude/rules/）

| ディレクトリ | 内容 |
|-------------|------|
| common/ | coding-style, security, testing, git-workflow, agents, patterns, performance, hooks |
| typescript/ | coding-style, security, testing, patterns, hooks |
| python/ | coding-style（PEP 8, ruff）, security, testing（pytest）, patterns, hooks |
| golang/ | coding-style（gofmt）, security, testing（table-driven）, patterns, hooks |

---

## 6. MCP サーバー構成

### 6.1 登録済みサーバー一覧

| サーバー名 | コマンド | 用途 | 設定方法 |
|-----------|---------|------|---------|
| notionApi | `notion-mcp-server` | Notion API連携 | 自動（.mcp.json） |
| desktop-commander | `npx @wonderwhy-er/desktop-commander@latest` | デスクトップ操作 | 自動 |
| n8n-mcp | `node ${N8N_MCP_PATH}` | n8nワークフロー操作 | 手動（環境変数設定要） |
| hostinger-mcp | `npx hostinger-api-mcp@latest` | Hostinger API | 手動（トークン要） |
| serena | uvx経由 | Serena MCP | 自動 |
| github | Docker経由 | GitHub操作 | 手動（PAT要、Docker要） |
| codex | `codex mcp-server` | コード検索・分析 | 自動 |
| memory | Claude CLI内蔵 | ナレッジグラフ永続化 | `claude mcp add memory` |

### 6.2 認証情報（環境変数）

| 環境変数 | 用途 | 設定場所 |
|----------|------|---------|
| NOTION_BEARER_TOKEN | Notion API | ~/.bashrc |
| N8N_API_KEY | n8n API | ~/.bashrc |
| N8N_MCP_PATH | n8n MCPサーバーパス | ~/.bashrc |
| HOSTINGER_API_TOKEN | Hostinger API | ~/.bashrc |
| GITHUB_PERSONAL_ACCESS_TOKEN | GitHub API | ~/.bashrc |
| SERENA_UVX_COMMAND | Serena起動コマンド | ~/.bashrc |

**原則**: 全て環境変数で管理。.mcp.json には `${VAR_NAME}` 形式で参照のみ記載。ハードコード禁止。

### 6.3 Memory MCP セットアップ

```bash
claude mcp add memory
```

settings.json の permissions で `mcp__memory__read_graph` が自動許可される。

---

## 7. tmux セッション構成

### 7.1 セッション一覧

| セッション名 | ウィンドウ | ペイン数 | 用途 |
|-------------|----------|---------|------|
| shogun | 1（shogun） | 1 | 将軍専用 |
| multiagent | 1（agents） | 9 | 家老 + 足軽1-8 |

### 7.2 ペインレイアウト（multiagent セッション）

```
┌──────────────┬────────────┬───────────┐
│   karo       │ ashigaru3  │ ashigaru6 │
│  (107x16)    │  (86x16)   │  (85x16)  │
├──────────────┼────────────┼───────────┤
│  ashigaru1   │ ashigaru4  │ ashigaru7 │
│  (107x10)    │  (86x10)   │  (85x10)  │
├──────────────┼────────────┼───────────┤
│  ashigaru2   │ ashigaru5  │ ashigaru8 │
│  (107x10)    │  (86x10)   │  (85x10)  │
└──────────────┴────────────┴───────────┘
```

3列×3行のグリッドレイアウト。左列上段が家老、それ以外が足軽1-8。

### 7.3 tmux カスタム変数

各ペインに `set-option -p` で設定:

| 変数名 | 用途 | 例 |
|--------|------|-----|
| @agent_id | エージェント識別子 | ashigaru3, karo, shogun |
| @current_task | 現在のタスクID | subtask_151a |
| @model_name | 使用モデル | Sonnet, Opus, Haiku |
| @bloom_level | Bloomレベル | L1, L2, L3 |

### 7.4 tmux.conf

```bash
# ~/.tmux.conf（first_setup.sh が自動追加）
set -g mouse on
```

ペイン境界表示:
```
pane-border-format "#{?pane_active,#[reverse],}#{pane_index}#[default] \"#{pane_title}\""
```

---

## 8. シェル設定（エイリアス・環境変数）

### 8.1 エイリアス（~/.bashrc に追記）

```bash
alias css='tmux attach-session -t shogun'     # 将軍ペインにアタッチ
alias csm='tmux attach-session -t multiagent' # マルチエージェントにアタッチ
alias shu='./shutsujin_departure.sh'           # 出陣スクリプト実行
```

設定方法: `bash scripts/install_aliases.sh`（冪等、重複追加なし）

### 8.2 PATH設定

```bash
export PATH="$HOME/.local/bin:$PATH"  # Claude CLI 等
```

### 8.3 環境変数

| 変数 | 値 | 用途 |
|------|-----|------|
| SHOGUN_ROOT | /home/saneaki/multi-agent | リポジトリルート |
| CLAUDECODE | 1 | Claude Code実行中フラグ（自動設定） |
| TMUX_PANE | %N | 現在のペインID（自動設定） |

### 8.4 ペイン別プロンプト

shutsujin_departure.sh が各ペイン起動時に設定:

```bash
# bash用
PS1="(\[\033[1;32m\]家老\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ "

# zsh用
PS1="(%F{green}%B家老%b%f) %F{green}%B%~%b%f%# "
```

---

## 9. スクリプト群の概要と役割

### 9.1 全スクリプト一覧（行数順）

| スクリプト | 行数 | 目的 | 設定方法 |
|-----------|------|------|---------|
| ntfy.sh | 37 | ntfy経由スマホ通知 | 自動 |
| install_aliases.sh | 66 | bashrc alias設定 | 手動実行 |
| cleanup_extra_agents.sh | 67 | 余剰エージェントクリーンアップ | 手動 |
| shogun_report_hook.sh | 74 | 将軍自動報告hook（DEPRECATED） | 自動 |
| restart_agent.sh | 91 | エージェント再起動 | 手動 |
| worktree_create.sh | 106 | git worktree作成 | 自動（家老が呼び出し） |
| optimize_for_terminus.sh | 111 | Terminus最適化 | 手動 |
| cleanup_orphaned_claude.sh | 112 | 孤立プロセス削除 | 手動 |
| watcher_supervisor.sh | 114 | inbox_watcher監視・再起動 | 自動（出陣時） |
| worktree_cleanup.sh | 117 | git worktree削除 | 自動 |
| health_check.sh | 144 | システムヘルスチェック | 手動 |
| inbox_write.sh | 149 | エージェント間通信 | 自動 |
| test_supervisor.sh | 161 | supervisor テスト | テスト時 |
| ntfy_listener.sh | 171 | ntfy受信リスナー | 手動 |
| build_instructions.sh | 236 | Multi-CLI指示書ビルド | 手動 |
| inbox_watcher.sh | 897 | メールボックス監視 | 自動（出陣時） |

### 9.2 依存関係

```
shutsujin_departure.sh
  ├── inbox_watcher.sh × 10（各エージェント）
  │   └── shogun_report_hook.sh
  └── watcher_supervisor.sh
      └── inbox_watcher.sh（監視対象）

inbox_write.sh
  └── lib/ntfy_auth.sh（ntfy通知）

ntfy.sh
  └── lib/ntfy_auth.sh（認証）

build_instructions.sh
  ├── instructions/roles/*.md
  └── instructions/cli_specific/*.md
```

---

## 10. インフラ常駐プロセス

### 10.1 inbox_watcher.sh（メールボックス監視）

**動作原理**: `inotifywait` でinbox YAML変更をイベント駆動監視

**起動コマンド**:
```bash
bash scripts/inbox_watcher.sh <agent_id> <pane_target> [cli_type]
# 例: bash scripts/inbox_watcher.sh karo multiagent:0.0 claude
```

**エスカレーション機能**:

| 経過時間 | アクション | トリガー |
|---------|----------|---------|
| 0-2分 | 通常nudge（`inboxN` + Enter） | 通常配信 |
| 2-4分 | Escape×2 + nudge | カーソル位置バグ対策 |
| 4分+ | `/clear` 送信（5分に1回） | 強制リセット |

**特殊コマンド**:
- `clear_command` → `/clear` 送信
- `model_switch` → `/model <model_name>` 送信
- `cmd_complete` / `cmd_milestone` → `shogun_report_hook.sh` 呼び出し

**CLI別分岐**:
- claude: コマンドそのまま
- codex: `/clear` → `/new`、`/model` スキップ
- copilot: `/clear` → Ctrl-C + 再起動、`/model` スキップ

### 10.2 watcher_supervisor.sh（監視プロセス監視）

**動作原理**: 30秒間隔で inbox_watcher.sh の生存確認（`kill -0 <pid>`）

**起動コマンド**:
```bash
nohup bash scripts/watcher_supervisor.sh >> logs/watcher_supervisor.log 2>&1 &
```

**レジストリ**: `/tmp/watcher_registry.txt` に登録。`logs/watcher_manifest.txt` からエージェント定義読み込み。

### 10.3 ntfy通知

- **ntfy.sh**: ntfy.sh 経由でスマホにプッシュ通知
- **ntfy_listener.sh**: ntfy subscribe でサーバーからメッセージ受信
- **認証**: `lib/ntfy_auth.sh` で Bearer token / Basic auth 対応
- **設定**: `config/settings.yaml` → `ntfy_topic`

### 10.4 起動順序

```
1. shutsujin_departure.sh  → tmuxセッション構築
2. inbox_watcher.sh × 10   → 各エージェント監視
3. watcher_supervisor.sh    → inbox_watcher監視
```

---

## 11. config/ 設定ファイル群

### 11.1 settings.yaml

| 項目 | デフォルト値 | 説明 |
|------|-------------|------|
| language | ja | 言語設定（ja/en/多言語） |
| ashigaru_count | 3 | 足軽の数（1-8） |
| shell | bash | シェル設定（bash/zsh） |
| skill.save_path | ~/.claude/skills/ | グローバルスキル保存先 |
| skill.local_path | (プロジェクト)/skills/ | ローカルスキル保存先 |
| logging.level | debug | ログレベル |
| logging.path | (プロジェクト)/logs/ | ログ出力先 |
| ntfy_topic | hananoen | ntfy通知トピック名 |

### 11.2 projects.yaml

複数プロジェクト管理用。現在はサンプル設定のみ（将来利用予定）。

### 11.3 ntfy_auth.env（手動作成）

テンプレート: `config/ntfy_auth.env.sample`

| 項目 | 説明 |
|------|------|
| NTFY_TOKEN | Bearer トークン（推奨、`tk_` + 29文字） |
| NTFY_USER | Basic認証ユーザー名（代替） |
| NTFY_PASS | Basic認証パスワード（代替） |

優先順位: Token > Basic > None

セットアップ:
```bash
cp config/ntfy_auth.env.sample config/ntfy_auth.env
# ntfy_auth.env を編集して認証情報を記入
```

---

## 12. Git設定・ブランチ戦略

### 12.1 リモートリポジトリ

```bash
origin    git@github.com:saneaki/multi-agent.git        # 自分のfork（SSH）
upstream  https://github.com/yohey-w/multi-agent-shogun.git  # 本家（HTTPS）
```

### 12.2 ブランチ運用

| ブランチ | 用途 |
|----------|------|
| main | 安定版（upstreamと同期） |
| original | 日常作業用（fork独自拡張） |
| backup-claude-modifications | Claude修正のバックアップ |
| wt/{task_id} | worktree用（並列実行時の一時ブランチ） |
| claude/*, feature/* | フィーチャーブランチ |

### 12.3 .gitignore（ホワイトリスト方式）

```gitignore
# Step 1: 全て除外
*
# Step 2: ディレクトリ探索を許可
!*/
# Step 3: 公開対象のみ許可
!.gitignore
!CLAUDE.md
!README.md
!instructions/
!scripts/
!output/
# ... 以下許可対象を列挙

# worktreeは除外
.trees/
```

### 12.4 worktree運用

```bash
# 作成（並列実行時）
bash scripts/worktree_create.sh ashigaru1 feature-cmd-126
# → .trees/ashigaru1 に新規ブランチ作成、queue/等をsymlink

# 削除（完了後）
bash scripts/worktree_cleanup.sh ashigaru1
# → worktree・ブランチ削除、symlink除去
```

---

## 13. first_setup.sh による自動セットアップ

### 13.1 実行コマンド

```bash
bash first_setup.sh
```

### 13.2 STEP別処理内容

| STEP | 内容 | 自動/手動 |
|------|------|----------|
| 1 | システム環境チェック（OS情報、WSL検出） | 自動 |
| 2 | tmux インストール | 自動（apt-get） |
| 3 | tmux マウススクロール設定（~/.tmux.conf） | 自動 |
| 4 | Node.js チェック・インストール（nvm経由 v20） | 自動 |
| 4.5 | Python3 / PyYAML / inotify-tools インストール | 自動（apt-get） |
| 5 | Claude Code CLI チェック・インストール | 自動（npm版非推奨警告あり） |
| 6 | ディレクトリ構造作成（queue/tasks, queue/reports等） | 自動 |
| 7 | 設定ファイル初期化（settings.yaml, projects.yaml等） | 自動 |
| 8 | キューファイル初期化（足軽1-8のタスク・レポートYAML） | 自動 |
| 9 | 実行権限設定（setup.sh, shutsujin_departure.sh等） | 自動 |
| 10 | bashrc alias設定（css, csm, shu） | 自動 |
| 10.5 | WSL メモリ最適化（.wslconfig に autoMemoryReclaim=gradual） | 自動（WSL時のみ） |
| 11 | Memory MCP セットアップ（claude mcp add memory） | 自動 |

---

## 14. VPS環境への適用（差異・注意点）

### 14.1 実行ユーザーの違い

| 環境 | 実行ユーザー | HOME | ~/.claude/ の解決先 |
|------|------------|------|-------------------|
| ローカル（WSL2） | saneaki | /home/saneaki | /home/saneaki/.claude |
| VPS（Claude Code） | root | /root | /root/.claude |
| VPS（リポジトリ） | ubuntu | /home/ubuntu | /home/ubuntu/.claude |

### 14.2 symlink構成（setup-vps.sh）

```bash
sudo bash /home/ubuntu/.claude/scripts/setup-vps.sh
```

/root/.claude/ から /home/ubuntu/.claude/ へ symlink を作成:

| symlink元（/root/.claude/） | symlink先（/home/ubuntu/.claude/） |
|---------------------------|--------------------------------|
| commands/ | commands/ |
| agents/ | agents/ |
| scripts/ | scripts/ |
| rules/ | rules/ |
| hooks/ | hooks/ |
| contexts/ | contexts/ |
| skills/* | skills/*（learned/ は除外） |

### 14.3 .mcp.json のパス変換

| 環境 | N8N_MCP_PATH |
|------|-------------|
| ローカル（WSL） | /mnt/c/Users/.../n8n-mcp/build/index.js |
| VPS | /home/ubuntu/.n8n-mcp/n8n/build/index.js |

setup-vps.sh が環境変数を検出し、VPS用 .mcp.json を自動生成。

### 14.4 VPS固有の依存ツール

| ツール | 用途 |
|--------|------|
| systemd | tmux/inbox_watcher/supervisor の自動起動 |
| ufw/iptables | 外部通知用ポート開放 |

### 14.5 rootユーザーでのPATH差異

```
# ローカル（一般ユーザー）
/home/saneaki/.local/bin:/usr/local/bin:/usr/bin:/bin

# VPS（root）
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Claude CLI インストール先（`~/.local/bin`）が `/root/.local/bin` になる点に注意。

---

## 15. 手動設定が必要な項目チェックリスト

### セットアップ後の手動設定

- [ ] **SSH鍵の設定**: GitHub SSH接続用の鍵生成・登録
- [ ] **環境変数の設定**: MCP認証トークン群を ~/.bashrc に追加
  - [ ] NOTION_BEARER_TOKEN
  - [ ] N8N_API_KEY
  - [ ] N8N_MCP_PATH
  - [ ] HOSTINGER_API_TOKEN
  - [ ] GITHUB_PERSONAL_ACCESS_TOKEN
  - [ ] SERENA_UVX_COMMAND
- [ ] **ntfy認証設定**: `config/ntfy_auth.env.sample` → `config/ntfy_auth.env` にコピー・編集
- [ ] **Git リモート設定**: origin/upstream の URL 設定
- [ ] **Claude Code 認証**: `claude login` でAnthropicアカウント認証

### VPS環境のみ追加で必要な手動設定

- [ ] **settings.json マージ**: リポジトリ版の hooks セクションを `/root/.claude/settings.json` にマージ
- [ ] **systemd サービス設定**: tmux/inbox_watcher/supervisor の自動起動設定
- [ ] **ファイアウォール設定**: ntfy通知用ポート開放
- [ ] **.mcp.json 確認**: setup-vps.sh 自動生成のパスが正しいか確認

### 定期メンテナンス

- [ ] **upstreamからのマージ**: `git fetch upstream && git merge upstream/main`
- [ ] **孤立プロセス確認**: `bash scripts/cleanup_orphaned_claude.sh`
- [ ] **ヘルスチェック**: `bash scripts/health_check.sh`
- [ ] **ログローテーション**: `logs/` 配下の肥大化チェック

---

## 付録: 起動手順クイックスタート

### 新規環境での初回セットアップ

```bash
# 1. リポジトリクローン
git clone git@github.com:saneaki/multi-agent.git
cd multi-agent

# 2. 自動セットアップ
bash first_setup.sh

# 3. エイリアス設定
bash scripts/install_aliases.sh
source ~/.bashrc

# 4. 環境変数設定（~/.bashrc に追記）
export NOTION_BEARER_TOKEN="your_token"
export N8N_API_KEY="your_key"
# ... 他の環境変数も同様

# 5. 出陣（システム起動）
./shutsujin_departure.sh

# 6. セッションにアタッチ
csm  # マルチエージェント
css  # 将軍
```

### 日常の起動・停止

```bash
# 起動（前回状態維持）
shu

# 起動（クリーンスタート）
shu -c

# セッションアタッチ
csm  # マルチエージェント
css  # 将軍

# デタッチ
Ctrl+b, d
```
