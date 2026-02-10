# Shogunシステム vs Claude Code Agent Teams 比較レポート

**作成日**: 2026-02-09
**目的**: 現行Shogunシステムと Claude Code Agent Teams 機能の技術比較、自己改善の要否検討

---

## 1. エグゼクティブサマリー

2026年2月6日、AnthropicはOpus 4.6と同時に**Agent Teams**機能を公式リリースした（experimental）。これはShogunシステムが1年以上かけて独自に構築してきた「複数AIエージェントの並列統率」を、Claude Code本体がネイティブ機能として提供し始めたことを意味する。

本レポートでは両システムを技術的に比較し、Shogunシステムの自己改善の要否を検討する。

---

## 2. アーキテクチャ比較

| 観点 | Shogunシステム | Claude Code Agent Teams |
|------|---------------|------------------------|
| **階層構造** | 3層（Shogun→Karo→Ashigaru×8） | 2層（Lead→Teammates×N） |
| **通信基盤** | YAML files + inotifywait + tmux send-keys | 内蔵Mailbox + 共有Task List |
| **タスク管理** | 手動YAML生成（Karoが分解・割当） | 共有タスクリスト（自動claim + file locking） |
| **依存関係** | `blocked_by`フィールド（Karoが手動解除） | 自動依存解決（完了時に自動unblock） |
| **表示方式** | tmux multi-pane（常時可視） | in-process / tmux split-pane（選択可） |
| **対応CLI** | Claude Code, Codex, Copilot, Kimi Code | Claude Codeのみ |
| **モデル選択** | Bloom Taxonomy（L1-L3=Sonnet, L4-L6=Opus） | Lead指定 or 個別指定 |
| **安全装置** | Forbidden Actions F001-F005 + Tier1-3破壊操作禁止 | Leadの権限設定を継承 |
| **スキル学習** | ボトムアップ自動発見（skill_candidate） | なし（CLAUDE.mdで共有のみ） |
| **セッション管理** | /clear Recovery Protocol + エスカレーション | 制限あり（in-processは/resume不可） |
| **コスト** | ゼロ連携コスト（YAMLのみ） | 各teammateが独立セッション |

---

## 3. Shogunシステムの優位点

### 3.1 Multi-CLI対応（最大の差別化要因）

Agent Teamsは**Claude Code専用**。ShogunはClaude Code, OpenAI Codex, GitHub Copilot, Kimi Codeの4 CLIに対応し、CLI固有の指示書を統一ビルドシステムから自動生成する。ベンダーロックインなし。

### 3.2 連携コストゼロ

Agent Teamsの各teammateは独立したClaude Codeセッション（=独立コンテキストウィンドウ）。通信自体にトークンを消費する。Shogunの通信はYAMLファイルの読み書きのみで、APIトークンは実作業にのみ使用。

### 3.3 3層階層の意思決定分離

Agent Teamsは2層（Lead+Teammates）。Shogunは3層で、**意思決定（Karo）と実行（Ashigaru）を明確に分離**。Karoが品質ゲート・依存関係管理・ダッシュボード更新を担う。Agent TeamsのLeadは「自分で実装を始めてしまう」問題があり、delegate modeで抑制する必要がある。

### 3.4 ボトムアップスキル発見

Ashigaruが作業中に再利用可能パターンを自動発見 → Karoがdashboard集約 → Shogunが承認。組織知が有機的に成長する仕組み。Agent Teamsには同等の機能がない。

### 3.5 厳格な安全装置

Forbidden Actions（F001-F005）が各層に明示され、破壊操作はTier1-3で段階管理。Agent Teamsの安全性はLeadの権限設定の継承に依存し、粒度が粗い。

### 3.6 CLI定額制の経済性

8体×Opus級をAPI経由で動かすと~$100+/時間。CLI定額サブスク（~$200/月）なら同じコスト構造で無制限に稼働可能。

---

## 4. Agent Teamsの優位点

### 4.1 ネイティブ統合・ゼロセットアップ

`settings.json`に1行追加するだけで有効化。tmux、inotify-tools、シェルスクリプト群のセットアップが不要。

### 4.2 自動タスクclaim + file locking

Teammateがタスク完了後、次の未割当・unblocked taskを自動claim。ファイルロックでrace conditionを防止。Shogunではkaroが手動でタスク割当・依存解除を行う。

### 4.3 直接的なteammate間通信

Teammateが互いに直接メッセージを送れる（broadcast含む）。Shogunのashigaruは**karo経由でしか**情報を共有できない（階層の制約）。

### 4.4 Hooks統合（TeammateIdle, TaskCompleted）

品質ゲートをHookで宣言的に定義。exit code 2で完了を拒否したり、idle状態のteammateにフィードバックを送れる。Shogunの品質管理はKaroのプロンプト依存。

### 4.5 Plan Approval Mode

Teammateに「計画を立ててからLeadの承認を得る」フローを強制可能。Shogunではkaroが計画を立てるが、ashigaruレベルの計画レビューは仕組みとして存在しない。

### 4.6 セッション内の柔軟な操作

Shift+Up/Down でteammateを選択し直接メッセージ送信。Ctrl+Tでタスクリスト表示。UIレベルでの操作性が高い。

---

## 5. 共通する設計思想

両システムは驚くほど似た設計原則を共有している：

| 原則 | Shogun | Agent Teams |
|------|--------|-------------|
| **Mailbox通信** | YAML inbox | 内蔵Mailbox |
| **タスクリスト共有** | queue/tasks/ YAML | ~/.claude/tasks/{team}/ |
| **ファイル衝突回避** | ashigaruごとに専用ファイル | teammateごとにファイル所有権 |
| **tmux活用** | 必須基盤 | split-pane mode |
| **CLAUDE.md共有** | 全エージェントが読み込み | 全teammateが読み込み |
| **コンテキスト分離** | 各ashigaruが独立セッション | 各teammateが独立コンテキスト |

Agent Teamsの公式ドキュメントが述べる「タスクのサイズ設計」「ファイル所有権の分離」「仕様の明確化が実行品質を決める」は、Shogunが実戦で培ってきた原則そのもの。

---

## 6. 自己改善の検討

### 6.1 改善賛成派の意見（移行・統合すべき）

**「公式機能には勝てない」論:**

- Agent TeamsはClaude Code本体に統合されており、今後のアップデートで自動的に改善される
- ShogunのYAML+シェルスクリプト基盤は保守コストが高く、壊れやすい（inotifywait、tmux send-keysのタイミング問題等）
- Claude Code 2.x以降でAgent Teamsが安定すれば、Shogunの独自基盤は技術的負債になる
- 「自動タスクclaim」「file locking」「Plan Approval」は、Shogunが手動で行っていることの自動化

**具体的な改善案:**

1. Agent Teamsをashigaru層に採用し、karo→ashigaru間の通信をネイティブMailboxに移行
2. 独自のinbox_write.sh / inbox_watcher.sh をTeammateIdle / TaskCompleted Hooksに置換
3. 3層構造を維持しつつ、ashigaru間のタスク管理をAgent Teamsに委譲

### 6.2 改善反対派の意見（現状維持すべき）

**「差別化要因を捨てるな」論:**

- Multi-CLI対応はShogun最大の独自価値。Agent TeamsはClaude Code専用
- CLI定額制のコスト最適化戦略はAgent Teamsでは再現不能
- ボトムアップスキル発見は独自の知的資産成長エンジン
- Agent Teamsはまだ**experimental**。既知の制限が多い（セッション復旧不可、nested team不可、1セッション1チーム制限）
- 3層階層の意思決定分離は、Agent Teamsの2層モデルより組織的に成熟
- YAMLベースの完全透明性は、デバッグ・監査・版管理で不可欠
- Shogunの安全装置（Forbidden Actions, Tier制破壊操作管理）はAgent Teamsより厳格

**リスク:**

- Agent Teamsに依存すると、Anthropicの方針変更に脆弱になる
- experimentalフェーズで全面移行すると、破壊的変更の影響を受ける
- 既存の実戦ノウハウ（エスカレーション、/clear Recovery等）が失われる

---

## 7. 推奨戦略：ハイブリッドアプローチ

完全移行でも完全現状維持でもなく、**段階的に公式機能を取り込みつつ独自の強みを保持**する戦略を推奨する。

### Phase 1: 観察・評価（現在〜1ヶ月）

- Agent Teamsをexperimentalのまま**別ブランチで検証**
- 既存Shogunワークフローとの互換性をテスト
- 特にタスクclaim精度、通信の信頼性、コスト影響を計測

### Phase 2: 部分統合（1〜3ヶ月）

- **採用候補**: 自動タスクclaim、file locking、TeammateIdle/TaskCompleted Hooks
- **維持するもの**: 3層階層、Multi-CLI対応、ボトムアップスキル発見、Forbidden Actions
- **具体的**: KaroがAgent TeamsのLead機能を内部的に使い、ashigaru管理を効率化

### Phase 3: アーキテクチャ進化（3ヶ月〜）

- Agent Teamsが安定版になった時点で、通信基盤の移行を本格検討
- ただし**Multi-CLI対応とスキル発見は絶対に維持**（これがShogunの存在意義）
- Agent Teamsの「subagent」と「teammate」の使い分けをShogunの階層に写像

---

## 8. 結論

Shogunシステムは、Agent Teamsが「これから実現しようとしていること」を**すでに実戦投入している**。ただし、公式機能の成熟に伴い、**低レベル基盤（通信・タスク管理）は公式に任せ、高レベル設計（階層構造・安全装置・スキル学習・Multi-CLI）に注力する**のが最適解。

> 「車輪の再発明」を避けつつ「独自のエンジン」は守る。

---

## 参考資料

- [Orchestrate teams of Claude Code sessions - 公式ドキュメント](https://code.claude.com/docs/en/agent-teams)
- [Create custom subagents - 公式ドキュメント](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Swarms - Addy Osmani](https://addyosmani.com/blog/claude-code-agent-teams/)
- [Building a C compiler with a team of parallel Claudes - Anthropic Engineering](https://www.anthropic.com/engineering/building-c-compiler)
- [Anthropic releases Opus 4.6 with new 'agent teams' - TechCrunch](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/)
- [Claude Code's Hidden Multi-Agent System](https://paddo.dev/blog/claude-code-hidden-swarm/)
- [Claude Code multiple agent systems: Complete 2026 guide](https://www.eesel.ai/blog/claude-code-multiple-agent-systems-complete-2026-guide)
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Claude Opus 4.6 Agent Teams Tutorial - NxCode](https://www.nxcode.io/resources/news/claude-agent-teams-parallel-ai-development-guide-2026)
