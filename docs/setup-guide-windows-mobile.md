# multi-agent-shogun セットアップガイド: Windows（WSLなし）& スマホ

> **対象読者**: WSLを導入せずにWindowsで使いたい方、スマートフォンから操作したい方
> **最終更新**: 2026-02-10

---

## 目次

1. [前提知識: システムの動作要件](#1-前提知識-システムの動作要件)
2. [Windows（WSLなし）での導入方法](#2-windowswslなしでの導入方法)
   - [方法A: Claude Code on the Web（推奨）](#方法a-claude-code-on-the-web推奨)
   - [方法B: Windows ネイティブ Claude Code（単体エージェント）](#方法b-windows-ネイティブ-claude-code単体エージェント)
   - [方法C: リモートサーバー経由](#方法c-リモートサーバー経由)
   - [参考: WSL2を使う場合（既存の方法）](#参考-wsl2を使う場合既存の方法)
3. [スマートフォンでの導入方法](#3-スマートフォンでの導入方法)
   - [方法A: Claude Code on the Web（推奨）](#方法a-claude-code-on-the-web推奨-1)
   - [方法B: iOS Claude アプリ](#方法b-ios-claude-アプリ)
   - [方法C: Android での利用](#方法c-android-での利用)
4. [構成別の機能比較表](#4-構成別の機能比較表)
5. [推奨構成パターン](#5-推奨構成パターン)
6. [トラブルシューティング](#6-トラブルシューティング)

---

## 1. 前提知識: システムの動作要件

multi-agent-shogun は以下に依存している:

| 依存ツール | 用途 | Windows ネイティブ対応 |
|-----------|------|----------------------|
| **bash** | 全スクリプトの実行 | x（Git Bash で一部可能） |
| **tmux** | セッション管理・Agent Teams の tmux モード | x（Windows ネイティブ版なし） |
| **Claude Code CLI** | AI エージェント実行基盤 | o（v2.x〜ネイティブ対応） |
| **Node.js** | MCP サーバー（npx 経由） | o |
| **Git** | バージョン管理 | o |

**重要**: マルチエージェント（将軍・家老・目付・足軽の全階層）を動かすには **tmux が必須**。tmux は Linux/macOS 専用であるため、WSLなしの Windows 単体ではフルシステムは動作しない。

以下では、WSLなしでも利用できる代替手段を説明する。

---

## 2. Windows（WSLなし）での導入方法

### 方法A: Claude Code on the Web（推奨）

**Claude Code on the Web** はブラウザ上で Claude Code を動かすクラウドサービス。Windows に何もインストールせず、ブラウザだけで利用できる。

#### 必要なもの
- ブラウザ（Chrome, Edge, Firefox 等）
- Claude Pro または Max サブスクリプション
- GitHub アカウント（リポジトリ連携用）

#### セットアップ手順

**Step 1: Claude Code on the Web にアクセス**
```
https://claude.ai/code
```
Claude アカウントでログインする。

**Step 2: GitHub リポジトリを接続**
1. 「Connect Repository」をクリック
2. GitHub アカウントを認証
3. multi-agent-shogun のリポジトリを選択

**Step 3: タスクを指示**
ブラウザ上の Claude Code にプロンプトを入力してタスクを実行する。

#### 制限事項
- GitHub リポジトリのみ対応（GitLab, Bitbucket は非対応）
- ローカルファイルの直接操作はできない
- マルチエージェント（Agent Teams の tmux モード）は利用不可
- ベータ版のため機能が制限される場合がある

#### メリット
- **インストール不要**: ブラウザだけで動く
- **セッション永続化**: ブラウザを閉じても処理が続行する
- **どこからでもアクセス可能**: PC でもスマホでも同じセッションにアクセスできる

---

### 方法B: Windows ネイティブ Claude Code（単体エージェント）

Claude Code CLI は Windows 10 以降でネイティブ動作する。ただし、tmux が使えないため **単体エージェント**（将軍のみ、マルチエージェント構成なし）として利用する。

#### 必要なもの
- Windows 10 以降
- Git for Windows（Git Bash 含む）
- インターネット接続
- Claude アカウント（Console, Pro, または Max）

#### セットアップ手順

**Step 1: Git for Windows をインストール**

公式サイトからダウンロード:
```
https://gitforwindows.org/
```
インストール時に「Git Bash」が含まれていることを確認する。

**Step 2: Claude Code CLI をインストール**

PowerShell（管理者権限不要）を開き、以下を実行:

```powershell
# 方法1: PowerShell インストーラー（推奨・自動更新あり）
irm https://claude.ai/install.ps1 | iex

# 方法2: WinGet（手動更新が必要）
winget install Anthropic.ClaudeCode
```

**Step 3: インストール確認**

PowerShell または Git Bash で:
```
claude --version
```

バージョン番号が表示されれば成功。

**Step 4: 認証**

```
claude auth login
```

ブラウザが開くので、Claude アカウントでログインする。

**Step 5: Node.js をインストール（MCP サーバー用）**

```
https://nodejs.org/
```
LTS 版（v20 以降推奨）をダウンロード・インストール。

**Step 6: プロジェクトで使用**

Git Bash またはPowerShell で作業ディレクトリに移動し:
```bash
cd /path/to/your/project
claude
```

#### この方法でできること
- Claude Code による単体エージェントとしてのコード生成・編集
- MCP サーバー経由での外部ツール連携（Memory, Notion 等）
- Git 操作、ファイル操作

#### この方法でできないこと
- マルチエージェント構成（将軍→家老→足軽の階層）
- Agent Teams の tmux モード
- `shutsujin_departure.sh`（出陣スクリプト）の実行
- tmux によるセッション管理
- ダッシュボード自動更新

---

### 方法C: リモートサーバー経由

Linux サーバー（VPS やクラウド VM）にフルシステムを構築し、Windows からリモート接続する方法。フル機能が利用可能。

#### 必要なもの
- Linux サーバー（Ubuntu 20.04+ 推奨）
  - AWS EC2, Google Cloud, Azure VM, ConoHa, さくら VPS 等
  - 最低スペック: 2 vCPU / 4GB RAM
- SSH クライアント（Windows 標準の OpenSSH または PuTTY）

#### セットアップ手順

**Step 1: Linux サーバーを準備**

お好みのクラウドサービスで Ubuntu 20.04+ のインスタンスを作成する。

**Step 2: SSH 接続**

PowerShell から:
```powershell
ssh username@your-server-ip
```

**Step 3: multi-agent-shogun をインストール**

サーバー上で:
```bash
# リポジトリをクローン
git clone https://github.com/your-org/multi-agent-shogun.git
cd multi-agent-shogun

# 初回セットアップ（tmux, Node.js, Claude CLI を自動インストール）
chmod +x first_setup.sh
./first_setup.sh

# Claude Code 認証
claude auth login
```

**Step 4: 出陣（マルチエージェント起動）**

```bash
cd /path/to/your/project
/path/to/multi-agent-shogun/shutsujin_departure.sh
```

**Step 5: Windows から tmux セッションにアタッチ**

SSH 接続した状態で:
```bash
# 将軍にアタッチ
tmux attach -t shogun-<project>

# 配下にアタッチ
tmux attach -t multiagent-<project>
```

#### メリット
- **フル機能が利用可能**: マルチエージェント構成が完全に動作
- **Windows に依存しない**: サーバー側で全て完結
- **複数端末からアクセス可能**: 自宅 PC でもスマホでも SSH で接続可能

#### 注意点
- サーバーの月額費用がかかる（無料枠あり: AWS Free Tier, GCP Free Tier 等）
- SSH 接続が切れてもtmux セッションは保持されるため、再接続すれば続行可能

---

### 参考: WSL2を使う場合（既存の方法）

本システムには WSL2 用の自動インストーラーが同梱されている。WSL2 の導入に抵抗がなければ、これが最も簡単な方法。

```
1. install.bat をダブルクリック（または右クリック→管理者として実行）
2. 画面の指示に従う（WSL2 + Ubuntu が自動インストールされる）
3. 再起動後、再度 install.bat を実行
4. Ubuntu 上で出陣スクリプトを実行
```

WSL2 はWindows 10 バージョン 2004 以降に標準搭載されており、追加費用なし。

---

## 3. スマートフォンでの導入方法

### 方法A: Claude Code on the Web（推奨）

PC と同じ方法。スマホのブラウザからアクセスするだけ。

#### 手順
1. スマホのブラウザで `https://claude.ai/code` にアクセス
2. Claude アカウントでログイン
3. GitHub リポジトリを接続してタスクを実行

#### PC との連携
- PC で開始したセッションをスマホから監視・操作できる
- スマホで開始したセッションを PC の Claude Code CLI に引き継ぐことも可能（`/teleport` コマンド）

---

### 方法B: iOS Claude アプリ

iOS 向け Claude アプリに Claude Code 機能が統合されている（2025年10月〜）。

#### 手順
1. App Store から「Claude」アプリをインストール
2. Claude アカウント（Pro または Max）でログイン
3. Claude Code セッションの監視・操作が可能

#### できること
- Web セッションの監視と操作
- タスクの指示と結果確認
- PR の確認・承認

#### 制限
- 複雑なデバッグやマルチファイル編集は PC の方が効率的
- Research Preview（ベータ機能）

---

### 方法C: Android での利用

Android 向け公式 Claude Code アプリは現時点では提供されていない。以下の代替手段がある。

#### 方法C-1: ブラウザ経由（推奨）

方法A と同じ。Chrome 等のブラウザから `https://claude.ai/code` にアクセスする。

#### 方法C-2: Termux + SSH（上級者向け）

Android 上の Termux アプリで SSH 接続し、リモートサーバーの tmux セッションを操作する方法。

1. Google Play Store から「Termux」をインストール
2. Termux でSSH をセットアップ:
   ```bash
   pkg install openssh
   ssh username@your-server-ip
   ```
3. tmux セッションにアタッチ:
   ```bash
   tmux attach -t shogun-<project>
   ```

Bluetooth キーボードの利用を強く推奨する。

#### 方法C-3: サードパーティアプリ

- **Happy Coder**: iOS/Android/Web 対応のオープンソース Claude Code クライアント
  - `npm install -g happy-coder` でサーバーセットアップ後、モバイルからアクセス
  - エンドツーエンド暗号化対応
- **claude-code-app**: Flutter ベースのクロスプラットフォームアプリ
  - SSH 連携、音声入力対応

---

## 4. 構成別の機能比較表

| 機能 | WSL2 | Win ネイティブ | Web (ブラウザ) | iOS アプリ | Android (Termux+SSH) |
|------|:----:|:-------------:|:-------------:|:---------:|:-------------------:|
| Claude Code 単体 | o | o | o | o | o (リモート) |
| Agent Teams (マルチエージェント) | o | x | x | x | o (リモート) |
| 出陣スクリプト | o | x | x | x | o (リモート) |
| tmux セッション管理 | o | x | x | x | o (リモート) |
| ダッシュボード | o | x | x | x | o (リモート) |
| MCP サーバー連携 | o | o | 一部 | x | o (リモート) |
| オフライン作業 | o | o | x | x | x |
| セットアップ難易度 | 低 | 低 | 最低 | 最低 | 高 |
| 月額費用 | 無料 | 無料 | Claude 課金 | Claude 課金 | サーバー費用 |

**凡例**: o = 対応 / x = 非対応

---

## 5. 推奨構成パターン

### パターン1: 手軽に始めたい（初心者向け）

```
メイン作業: Claude Code on the Web (ブラウザ)
モバイル監視: 同じブラウザ or iOS Claude アプリ
```
- インストール不要
- どこからでもアクセス可能
- マルチエージェントは使えないが、単体でも十分強力

### パターン2: Windows でフル機能を使いたい

```
メイン作業: WSL2 + multi-agent-shogun（install.bat で導入）
モバイル監視: Claude Code on the Web
```
- WSL2 は Windows 標準機能（追加費用なし）
- フルのマルチエージェント構成が利用可能
- install.bat で自動インストール

### パターン3: 本格運用（チーム開発・常時稼働）

```
メイン: リモート Linux サーバー + multi-agent-shogun
PC から: SSH + tmux attach
スマホから: SSH (Termux) or Claude Code on the Web
```
- サーバーが常時稼働するためセッションが途切れない
- 複数端末から同じセッションにアクセス可能
- サーバー費用が発生する（月額 $5〜20 程度）

### パターン4: Windows ネイティブ + Web のハイブリッド

```
軽作業: Windows ネイティブ Claude Code（PowerShell / Git Bash）
重い作業: Claude Code on the Web（バックグラウンド実行）
モバイル: ブラウザから Web セッション監視
```
- WSL 不要
- ローカルファイル操作は Windows ネイティブで実行
- 長時間タスクは Web に委任

---

## 6. トラブルシューティング

### Windows ネイティブ版

**Q: `claude` コマンドが認識されない**
```powershell
# パスが通っているか確認
$env:PATH -split ';' | Select-String claude

# 再インストール
irm https://claude.ai/install.ps1 | iex
```

**Q: Git Bash で日本語が文字化けする**
```bash
# Git Bash の設定で文字コードを UTF-8 に変更
# Options → Text → Character set → UTF-8
```

**Q: 認証エラーが出る**
```
claude auth logout
claude auth login
```

### Claude Code on the Web

**Q: リポジトリが表示されない**
- GitHub の認証設定を確認
- private リポジトリの場合、アクセス権限を許可しているか確認

**Q: セッションが切断される**
- セッションはサーバー側で保持されるため、再アクセスすれば続行される
- 安定した通信環境を推奨

### スマホ

**Q: Termux で SSH 接続できない**
```bash
# 鍵ファイルの権限を確認
chmod 600 ~/.ssh/id_rsa

# 接続テスト
ssh -v username@your-server-ip
```

**Q: スマホの画面が小さくて操作しづらい**
- Bluetooth キーボードを接続する
- タブレットの利用を推奨
- 主な操作は PC で行い、スマホは監視・軽微な指示に限定する

---

## まとめ

| あなたの状況 | 推奨方法 |
|-------------|---------|
| WSL を入れたくない・手軽に使いたい | **Claude Code on the Web** |
| Windows でフル機能が必要 | **WSL2 導入**（install.bat） |
| サーバーを持っている・本格運用したい | **リモートサーバー + SSH** |
| スマホから監視したい | **Claude Code on the Web** or **iOS アプリ** |
| Android から操作したい | **ブラウザ** or **Termux + SSH** |

WSLなしの Windows 単体ではマルチエージェント構成（将軍・家老・目付・足軽）は動作しないが、Claude Code on the Web やリモートサーバー経由で代替できる。用途に応じて最適な構成を選択してほしい。
