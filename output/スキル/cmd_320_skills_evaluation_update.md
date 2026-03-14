# ECC スキル・コマンド・エージェント 有用度評価レポート（最新版）

**更新日**: 2026-03-14
**前回レポート**: cmd_148（2026-02-14, 105件）
**作成者**: ashigaru3（subtask_320a）

---

## 差分サマリー（cmd_148 → cmd_320）

| 項目 | cmd_148 | cmd_320 | 差分 |
|------|---------|---------|------|
| 評価対象数 | 105件 | 184件 | +79件（Skills 57件・Commands 17件・Agents 5件） |
| Skills（ECC） | 52件 | 109件 | +57件 |
| Project Skills | 6件 | 6件 | ±0件 |
| Commands | 34件 | 51件 | +17件 |
| Agents | 13件 | 18件 | +5件 |
| S評価数 | 11件 | 11件 | ±0件 |
| A評価数 | 18件 | 20件 | +2件 |
| B評価数 | 22件 | 43件 | +21件 |
| C評価数 | 25件 | 45件 | +20件 |
| D評価数 | 29件 | 65件 | +36件 |

**評価方針**: 前回105件の評価を基本据え置き。新規79件は実使用実績・技術スタック適合性で評価。
Kotlin/Swift/Perl/PHP系は殿の技術スタック外のためD評価。マルチエージェント・自律ループ・AI関連は積極評価。

---

## 評価基準の凡例

| ランク | 定義 | 基準 |
|--------|------|------|
| **S** | 不可欠 | 日常的に使用、業務に不可欠。削除すると即座に支障が出る |
| **A** | 高頻度使用 | 週に複数回使用、または特定プロジェクトの中核 |
| **B** | 時々使用 | 月に数回使用、または将来確実に必要になる |
| **C** | まれに使用 | 使用実績が少ない、または限定的なシーンでのみ有用 |
| **D** | 削除候補 | 未使用かつ殿の技術スタックに合わない。コンテキスト削減対象 |

---

## 殿の技術スタック（評価基準）

**使用中**: Python, n8n, Notion API, Astro+Tailwind, マルチエージェント（shogun システム）, Google Workspace
**業務**: 法律事務所向けシステム、自動化、ドキュメント管理

**未使用技術（→ D評価基準）**: Java/Spring Boot, Django, Go, C++, Kotlin, Swift, Perl, PHP, Android, iOS, Rust

---

## ランク別サマリー

| ランク | Skills(ECC) | Project | Commands | Agents | 合計 |
|--------|-------------|---------|----------|--------|------|
| **S** | 0 | 4 | 3 | 4 | **11** |
| **A** | 13 | 2 | 4 | 1 | **20** |
| **B** | 24 | 0 | 16 | 3 | **43** |
| **C** | 26 | 0 | 15 | 4 | **45** |
| **D** | 46 | 0 | 13 | 6 | **65** |
| **合計** | **109** | **6** | **51** | **18** | **184** |

---

## ランク別一覧表

### S ランク（不可欠）— 11件

| 名前 | カテゴリ | 行数 | 根拠 | 変更 |
|------|----------|------|------|------|
| astro-law-firm-starter | Project | 968 | 殿のAstro+TailwindプロジェクトのHP開発中核 | cmd_148据置 |
| legal-office-research | Project | 671 | cmd_137で大幅拡張。法律事務所業務の中核リサーチスキル | cmd_148据置 |
| n8n-automation-patterns | Project | 707 | n8n自動化設計指針。実運用ワークフロー基盤 | cmd_148据置 |
| n8n-drive-notion-sync | Project | 515 | Google Drive→Notion自動連携。書面管理の核 | cmd_148据置 |
| code-review | Command | 40 | 直近使用実績あり。セキュリティチェック必須 | cmd_148据置 |
| plan | Command | 113 | 全開発・調査の起点。最頻使用コマンド | cmd_148据置 |
| pub | Command | 85 | ドキュメント更新→コミット→プッシュの一括実行 | cmd_148据置 |
| code-reviewer | Agent | 224 | コードレビュー必須。直近使用実績あり | cmd_148据置 |
| planner | Agent | 212 | /plan経由で頻繁使用。実装計画策定必須 | cmd_148据置 |
| python-reviewer | Agent | 98 | Python開発中心。直近使用実績あり | cmd_148据置 |
| security-reviewer | Agent | 108 | 法律事務所業務でセキュリティ最重要 | cmd_148据置 |

### A ランク（高頻度使用）— 20件

| 名前 | カテゴリ | 行数 | 根拠 | 変更 |
|------|----------|------|------|------|
| autonomous-loops | Skill | 612 | 自律ループパターン・マルチエージェントDAG設計の核 | **新規追加** |
| search-first | Skill | 161 | コーディング前リサーチワークフロー。殿の開発プロセス全体に適用可 | **新規追加** |
| continuous-learning-v2 | Skill | 292 | マルチエージェントでパターン学習活用 | cmd_148据置 |
| legal-document-namer | Skill | 353 | hananoenリネーマー設計基盤。法律文書管理 | cmd_148据置 |
| n8n-code-javascript | Skill | 699 | n8n Codeノード頻繁使用。$json構文必須 | cmd_148据置 |
| n8n-expression-syntax | Skill | 516 | n8n式構文必須。webhook body構造等の頻出エラー解決 | cmd_148据置 |
| n8n-node-configuration | Skill | 785 | n8nノード設定は頻出タスク | cmd_148据置 |
| n8n-workflow-patterns | Skill | 411 | n8nワークフロー設計基盤。日常的に使用 | cmd_148据置 |
| python-patterns | Skill | 749 | hananoenプロジェクトで頻繁参照 | cmd_148据置 |
| python-testing | Skill | 815 | hananoenテスト整備に必須 | cmd_148据置 |
| tdd-workflow | Skill | 409 | TDD推進の中核。Python/TS両方に適用 | cmd_148据置 |
| tkinter-help-system | Skill | 490 | hananoenプロジェクトで直接使用 | cmd_148据置 |
| verification-loop | Skill | 125 | PR前品質ゲート。汎用性高い | cmd_148据置 |
| google-chat-bulk-sender | Project | 695 | マルチエージェント通知機能。実績あり | cmd_148据置 |
| skill-creator | Project | 133 | スキル自動生成メタスキル | cmd_148据置 |
| build-fix | Command | 62 | Python開発でのビルドエラー修正に有効 | cmd_148据置 |
| python-review | Command | 297 | Python開発中心。直近使用実績あり | cmd_148据置 |
| skill-create | Command | 174 | Git履歴からパターン抽出。直近使用実績 | cmd_148据置 |
| tdd | Command | 326 | TDD品質確保に必須 | cmd_148据置 |
| tdd-guide | Agent | 80 | TDD専門家。品質確保必須 | cmd_148据置 |

### B ランク（時々使用）— 43件

| 名前 | カテゴリ | 行数 | 根拠 | 変更 |
|------|----------|------|------|------|
| agent-harness-construction | Skill | 73 | AIエージェントのaction space・tool定義設計。マルチエージェント開発に有用 | **新規追加** |
| agentic-engineering | Skill | 63 | eval-first実行・コスト意識モデルルーティング。エージェント開発基盤 | **新規追加** |
| blueprint | Skill | 105 | 一行目標から多セッション・マルチエージェント構築計画生成 | **新規追加** |
| claude-api | Skill | 337 | Anthropic Claude API/SDKパターン（Python/TS）。AIアプリ開発に直接有用 | **新規追加** |
| content-hash-cache-pattern | Skill | 161 | SHA-256コンテンツハッシュキャッシュ。Python処理の高速化に応用可 | **新規追加** |
| continuous-agent-loop | Skill | 45 | 品質ゲート付き自律エージェントループパターン。shogunシステム改善に有用 | **新規追加** |
| cost-aware-llm-pipeline | Skill | 183 | LLM APIコスト最適化・モデルルーティング。API費用削減に有用 | **新規追加** |
| deep-research | Skill | 155 | firecrawl/exa MCPを使った深いリサーチ。法律調査・競合分析に応用可 | **新規追加** |
| prompt-optimizer | Skill | 397 | プロンプト最適化・ECC活用最大化。日常的な指示改善に使える | **新規追加** |
| regex-vs-llm-structured-text | Skill | 220 | 正規表現 vs LLMの構造テキスト解析判断フレームワーク。n8n開発に有用 | **新規追加** |
| skill-stocktake | Skill | 193 | スキル・コマンド品質監査。ECC資産管理に有用 | **新規追加** |
| claude-md-improver | Skill | 179 | CLAUDE.md監査。日常的ではないが重要 | cmd_148据置 |
| coding-standards | Skill | 529 | Astro+Tailwindで関連。時々使用 | cmd_148据置 |
| e2e-testing | Skill | 325 | 将来のHP開発でE2E必要 | cmd_148据置 |
| iterative-retrieval | Skill | 210 | マルチエージェントコンテキスト管理 | cmd_148据置 |
| n8n-api-deploy | Skill | 213 | API経由デプロイ。将来有用 | cmd_148据置 |
| n8n-google-sheets-rate-limit | Skill | 173 | Sheets連携時のレート制限対策 | cmd_148据置 |
| n8n-pipeline-cut-guard | Skill | 163 | 0件出力時のパイプライン停止防止 | cmd_148据置 |
| n8n-validation-expert | Skill | 689 | n8n検証エラー対応。頻度中程度 | cmd_148据置 |
| pull-merge-pub | Skill | 188 | Git操作は家老が担当。殿は直接使用少 | cmd_148据置 |
| pytest-migration | Skill | 808 | 将来のunittest→pytest移行時に必須 | cmd_148据置 |
| security-review | Skill | 494 | セキュリティチェック。部分的にPython適用可 | cmd_148据置 |
| security-scan | Skill | 164 | 設定セキュリティ衛生管理 | cmd_148据置 |
| strategic-compact | Skill | 102 | 長時間セッションで有用だが頻度低 | cmd_148据置 |
| aside | Command | 164 | 作業中断なしのサイドクエスチョン回答。汎用的で有用 | **新規追加** |
| learn-eval | Command | 116 | セッションからパターン抽出・自己評価。継続改善に有用 | **新規追加** |
| loop-start | Command | 32 | 管理された自律ループパターン起動。将来のCI/自動化に有用 | **新規追加** |
| loop-status | Command | 24 | ループ状態・進捗確認。loop-startと対になる | **新規追加** |
| model-route | Command | 26 | タスク複雑度によるモデルルーティング推薦。コスト最適化に有用 | **新規追加** |
| prompt-optimize | Command | 38 | プロンプト最適化コマンド。複雑な指示作成前に使える | **新規追加** |
| quality-gate | Command | 29 | 品質パイプラインをオンデマンド実行。PR前チェックに有用 | **新規追加** |
| resume-session | Command | 155 | セッション状態復元。長時間作業の引き継ぎに必須 | **新規追加** |
| save-session | Command | 275 | セッション状態保存。コンテキスト限界前の保存に必須 | **新規追加** |
| e2e | Command | 363 | Astro HP開発で将来有用 | cmd_148据置 |
| learn | Command | 70 | ナレッジ蓄積に有用。意識的に使えば効果的 | cmd_148据置 |
| orchestrate | Command | 172 | 複雑タスクで有用。将来活用可能 | cmd_148据置 |
| pull-build | Command | 40 | PyInstallerプロジェクトで有用 | cmd_148据置 |
| revise-claude-md | Command | 54 | ドキュメント保守に有用 | cmd_148据置 |
| test-coverage | Command | 69 | 品質保証に有用。定期実行推奨 | cmd_148据置 |
| verify | Command | 59 | PR前品質確認。定期実行推奨 | cmd_148据置 |
| chief-of-staff | Agent | 151 | 多チャネル通信管理（メール/Slack/LINE等）。コミュニケーション自動化に有用 | **新規追加** |
| architect | Agent | 211 | アーキテクチャ判断時に有用 | cmd_148据置 |
| e2e-runner | Agent | 107 | Astro HP開発で将来有用 | cmd_148据置 |

### C ランク（まれに使用）— 45件

| 名前 | カテゴリ | 行数 | 根拠 | 変更 |
|------|----------|------|------|------|
| ai-first-engineering | Skill | 51 | AI主導チームエンジニアリングモデル。参考になるが実践未定 | **新規追加** |
| article-writing | Skill | 85 | 長文コンテンツ作成。法律事務所ブログ等で可能性あり | **新規追加** |
| content-engine | Skill | 88 | X/LinkedIn等コンテンツシステム。SNS運用開始時に有用 | **新規追加** |
| dmux-workflows | Skill | 191 | dmux（tmux+AI agent）多エージェントオーケストレーション。shogunと重複 | **新規追加** |
| enterprise-agent-ops | Skill | 50 | 長時間エージェント監視・セキュリティ境界。大規模化時に有用 | **新規追加** |
| exa-search | Skill | 175 | Exa MCPによるウェブ・コード・企業リサーチ。exa MCP未設定が課題 | **新規追加** |
| frontend-slides | Skill | 184 | HTMLスライド・プレゼン作成。法律事務所プレゼンで使える可能性 | **新規追加** |
| market-research | Skill | 75 | 市場調査・競合分析。法律事務所の競合調査で活用可能性 | **新規追加** |
| nanoclaw-repl | Skill | 33 | NanoClaw v2 REPL操作・拡張。ECC内部ツール、使用実績なし | **新規追加** |
| plankton-code-quality | Skill | 239 | Planktonによるwrite-time品質強制。Python開発に応用可だが未使用 | **新規追加** |
| ralphinho-rfc-pipeline | Skill | 67 | RFC駆動マルチエージェントDAG実行。shogunシステム改善時に参考 | **新規追加** |
| video-editing | Skill | 310 | AI動画編集（FFmpeg/Remotion等）。コンテンツ制作で将来有用 | **新規追加** |
| videodb | Skill | 376 | 動画/音声のインジェスト・分析・編集。高機能だが現状未使用 | **新規追加** |
| visa-doc-translate | Skill | 117 | ビザ申請書類の翻訳PDF作成。法律事務所でビザ案件があれば有用 | **新規追加** |
| api-design | Skill | 522 | 将来HP向けAPI開発で必要になる可能性 | cmd_148据置 |
| backend-patterns | Skill | 597 | フロントエンド中心で限定的 | cmd_148据置 |
| configure-ecc | Skill | 298 | 初回セットアップ専用 | cmd_148据置 |
| continuous-learning | Skill | 118 | v2が上位互換。冗長 | cmd_148据置 |
| deployment-patterns | Skill | 426 | 将来HP公開時に有用だが未使用 | cmd_148据置 |
| docker-patterns | Skill | 363 | 将来デプロイで関連する可能性 | cmd_148据置 |
| eval-harness | Skill | 235 | eval-driven開発を未実践 | cmd_148据置 |
| frontend-patterns | Skill | 641 | Reactベースで現在未使用 | cmd_148据置 |
| n8n-code-python | Skill | 748 | Python得意でもn8nではJS推奨 | cmd_148据置 |
| n8n-mcp-tools-expert | Skill | 642 | MCP経由構築は未実践 | cmd_148据置 |
| postgres-patterns | Skill | 146 | PostgreSQL未使用 | cmd_148据置 |
| project-guidelines-example | Skill | 348 | テンプレート例示のみ | cmd_148据置 |
| claw | Command | 51 | NanoClaw v2 REPL起動。使用実績なし | **新規追加** |
| harness-audit | Command | 58 | エージェントハーネス設定監査。マルチエージェント管理で有用だが頻度低 | **新規追加** |
| projects | Command | 39 | continuous-learning-v2プロジェクト一覧。continuous-learning未活用のため限定的 | **新規追加** |
| promote | Command | 41 | インスティンクトをグローバルへ昇格。continuous-learning未活用のため限定的 | **新規追加** |
| checkpoint | Command | 74 | 使用実績なし。git操作で代替可 | cmd_148据置 |
| eval | Command | 120 | 通常TDDで十分 | cmd_148据置 |
| multi-backend | Command | 158 | Codex/Gemini連携未使用 | cmd_148据置 |
| multi-execute | Command | 310 | 複雑設定が必要。現状不要 | cmd_148据置 |
| multi-frontend | Command | 158 | マルチモデル連携不要 | cmd_148据置 |
| multi-plan | Command | 261 | 通常/planで十分 | cmd_148据置 |
| multi-workflow | Command | 183 | codeagent-wrapperインフラ必要 | cmd_148据置 |
| refactor-clean | Command | 80 | プロジェクト成熟時に有用 | cmd_148据置 |
| sessions | Command | 305 | 通常不要 | cmd_148据置 |
| update-codemaps | Command | 72 | プロジェクト規模小で不要 | cmd_148据置 |
| update-docs | Command | 84 | 現状不要 | cmd_148据置 |
| harness-optimizer | Agent | 35 | エージェントハーネス設定分析・改善。マルチエージェント管理で有用だが頻度低 | **新規追加** |
| loop-operator | Agent | 36 | 自律エージェントループ監視・介入。loop-startと組み合わせて有用 | **新規追加** |
| doc-updater | Agent | 153 | 大規模プロジェクトで有用 | cmd_148据置 |
| refactor-cleaner | Agent | 85 | プロジェクト成熟時に有用 | cmd_148据置 |

### D ランク（削除候補）— 65件

| 名前 | カテゴリ | 行数 | 削除理由 | 変更 |
|------|----------|------|----------|------|
| android-clean-architecture | Skill | 339 | Android/Kotlin未使用 | **新規追加** |
| carrier-relationship-management | Skill | 212 | 運送キャリア管理。業務外 | **新規追加** |
| compose-multiplatform-patterns | Skill | 299 | Kotlin Compose Multiplatform未使用 | **新規追加** |
| cpp-coding-standards | Skill | 723 | C++未使用 | **新規追加** |
| crosspost | Skill | 192 | SNS運用なし | **新規追加** |
| customs-trade-compliance | Skill | 263 | 通関・貿易コンプライアンス。法律事務所業務外 | **新規追加** |
| energy-procurement | Skill | 228 | 電力・ガス調達。業務外 | **新規追加** |
| fal-ai-media | Skill | 284 | fal.ai メディア生成。未使用 | **新規追加** |
| foundation-models-on-device | Skill | 243 | Apple FoundationModels（iOS/macOS）未使用 | **新規追加** |
| inventory-demand-planning | Skill | 247 | 在庫・需要計画。業務外 | **新規追加** |
| investor-materials | Skill | 96 | ピッチデッキ・投資家資料。業務外 | **新規追加** |
| investor-outreach | Skill | 76 | 投資家向けコールドメール。業務外 | **新規追加** |
| kotlin-coroutines-flows | Skill | 284 | Kotlin未使用 | **新規追加** |
| kotlin-exposed-patterns | Skill | 719 | Kotlin Exposed ORM未使用 | **新規追加** |
| kotlin-ktor-patterns | Skill | 689 | Kotlin Ktor未使用 | **新規追加** |
| kotlin-patterns | Skill | 711 | Kotlin未使用 | **新規追加** |
| kotlin-testing | Skill | 824 | Kotlinテスト未使用 | **新規追加** |
| liquid-glass-design | Skill | 279 | iOS 26 Liquid Glass UI未使用 | **新規追加** |
| logistics-exception-management | Skill | 222 | 物流例外管理。業務外 | **新規追加** |
| perl-patterns | Skill | 504 | Perl未使用 | **新規追加** |
| perl-security | Skill | 503 | Perl未使用 | **新規追加** |
| perl-testing | Skill | 475 | Perl未使用 | **新規追加** |
| production-scheduling | Skill | 238 | 生産スケジューリング。業務外 | **新規追加** |
| quality-nonconformance | Skill | 260 | 品質管理・不適合管理（製造業）。業務外 | **新規追加** |
| returns-reverse-logistics | Skill | 240 | 返品・逆物流。業務外 | **新規追加** |
| swift-actor-persistence | Skill | 143 | Swift未使用 | **新規追加** |
| swift-concurrency-6-2 | Skill | 216 | Swift 6.2未使用 | **新規追加** |
| swift-protocol-di-testing | Skill | 190 | Swift未使用 | **新規追加** |
| swiftui-patterns | Skill | 259 | SwiftUI未使用 | **新規追加** |
| x-api | Skill | 209 | X/Twitter API。SNS活動なし | **新規追加** |
| clickhouse-io | Skill | 438 | ClickHouse分析DB。全く無関係 | cmd_148据置 |
| cpp-testing | Skill | 322 | C++未使用 | cmd_148据置 |
| database-migrations | Skill | 334 | DB中心開発なし | cmd_148据置 |
| django-patterns | Skill | 733 | Django未使用 | cmd_148据置 |
| django-security | Skill | 592 | Django未使用 | cmd_148据置 |
| django-tdd | Skill | 728 | Django未使用 | cmd_148据置 |
| django-verification | Skill | 468 | Django未使用 | cmd_148据置 |
| golang-patterns | Skill | 673 | Go未使用 | cmd_148据置 |
| golang-testing | Skill | 719 | Go未使用 | cmd_148据置 |
| java-coding-standards | Skill | 146 | Java未使用 | cmd_148据置 |
| jpa-patterns | Skill | 150 | Java/JPA未使用 | cmd_148据置 |
| nutrient-document-processing | Skill | 165 | APIキー未取得。PyPDF2で代替 | cmd_148据置 |
| springboot-patterns | Skill | 313 | Spring Boot未使用 | cmd_148据置 |
| springboot-security | Skill | 271 | Spring Boot未使用 | cmd_148据置 |
| springboot-tdd | Skill | 157 | Spring Boot未使用 | cmd_148据置 |
| springboot-verification | Skill | 230 | Spring Boot未使用 | cmd_148据置 |
| gradle-build | Command | 70 | Android/KMPのGradleビルドエラー修正。殿未使用 | **新規追加** |
| kotlin-build | Command | 174 | Kotlinビルドエラー修正。殿未使用 | **新規追加** |
| kotlin-review | Command | 140 | Kotlinコードレビュー。殿未使用 | **新規追加** |
| kotlin-test | Command | 312 | KotlinのTDDワークフロー。殿未使用 | **新規追加** |
| evolve | Command | 193 | continuous-learning未活用 | cmd_148据置 |
| go-build | Command | 183 | Go未使用 | cmd_148据置 |
| go-review | Command | 148 | Go未使用 | cmd_148据置 |
| go-test | Command | 268 | Go未使用 | cmd_148据置 |
| instinct-export | Command | 91 | continuous-learning未活用 | cmd_148据置 |
| instinct-import | Command | 142 | continuous-learning未活用 | cmd_148据置 |
| instinct-status | Command | 86 | continuous-learning未活用 | cmd_148据置 |
| pm2 | Command | 272 | Node.js向け。環境不一致 | cmd_148据置 |
| setup-pm | Command | 80 | Python中心でNode.js PM不要 | cmd_148据置 |
| kotlin-build-resolver | Agent | 118 | Kotlinビルドエラー修正エージェント。殿未使用 | **新規追加** |
| kotlin-reviewer | Agent | 159 | Kotlinコードレビュー専門。殿未使用 | **新規追加** |
| build-error-resolver | Agent | 114 | TypeScriptプロジェクト未使用 | cmd_148据置 |
| database-reviewer | Agent | 91 | DB使用なし | cmd_148据置 |
| go-build-resolver | Agent | 94 | Go未使用 | cmd_148据置 |
| go-reviewer | Agent | 76 | Go未使用 | cmd_148据置 |

---

## 新規追加分の個別評価（79件）

### 新規スキル（57件）

| 名前 | ランク | 行数 | 根拠 |
|------|--------|------|------|
| agent-harness-construction | B | 73 | AIエージェントaction space・tool設計。shogunシステム改善に有用 |
| agentic-engineering | B | 63 | eval-first実行・コスト意識モデルルーティング。エージェント開発基盤として有用 |
| ai-first-engineering | C | 51 | AI主導チームエンジニアリングモデル。参考になるが実践未定 |
| android-clean-architecture | D | 339 | Android/Kotlin未使用。殿の技術スタック外 |
| article-writing | C | 85 | 長文コンテンツ作成。法律事務所ブログ等で可能性あるが現状未使用 |
| autonomous-loops | A | 612 | 自律ループパターン・マルチエージェントDAG設計の核。shogunシステム直結 |
| blueprint | B | 105 | 一行目標から多セッション・マルチエージェント構築計画生成。大型タスクに有用 |
| carrier-relationship-management | D | 212 | 運送キャリア管理。業務外 |
| claude-api | B | 337 | Anthropic Claude API/SDKパターン。Claudeを使ったアプリ開発に直接有用 |
| compose-multiplatform-patterns | D | 299 | Kotlin Compose Multiplatform未使用 |
| content-engine | C | 88 | X/LinkedIn等のコンテンツシステム。SNS運用開始時に有用 |
| content-hash-cache-pattern | B | 161 | SHA-256コンテンツハッシュキャッシュ。Python処理の高速化・冪等性確保に応用可 |
| continuous-agent-loop | B | 45 | 品質ゲート付き自律エージェントループ。shogunシステム改善に有用 |
| cost-aware-llm-pipeline | B | 183 | LLM APIコスト最適化・モデルルーティング。API費用削減に実用的 |
| cpp-coding-standards | D | 723 | C++コーディング標準。殿未使用 |
| crosspost | D | 192 | マルチプラットフォームSNS配信。SNS活動なし |
| customs-trade-compliance | D | 263 | 通関・貿易コンプライアンス。法律事務所業務外 |
| deep-research | B | 155 | firecrawl/exa MCPを使った深いリサーチ。法律調査・競合分析に応用可 |
| dmux-workflows | C | 191 | dmux（tmux+AI agent）多エージェントオーケストレーション。shogunと機能重複 |
| energy-procurement | D | 228 | 電力・ガス調達。業務外 |
| enterprise-agent-ops | C | 50 | 長時間エージェント監視・セキュリティ境界。大規模化時に参考 |
| exa-search | C | 175 | Exa MCPによるウェブ・コード・企業リサーチ。Exa MCP未設定が課題 |
| fal-ai-media | D | 284 | fal.ai メディア生成（画像/動画/音声）。未使用 |
| foundation-models-on-device | D | 243 | Apple FoundationModels（iOS/macOS on-device LLM）。殿未使用 |
| frontend-slides | C | 184 | HTMLスライド/プレゼン作成。法律事務所プレゼンで使える可能性あり |
| inventory-demand-planning | D | 247 | 在庫・需要計画。業務外 |
| investor-materials | D | 96 | ピッチデッキ・投資家向け資料。業務外 |
| investor-outreach | D | 76 | 投資家向けコールドメール・紹介文。業務外 |
| kotlin-coroutines-flows | D | 284 | Kotlin Coroutines/Flow。殿未使用 |
| kotlin-exposed-patterns | D | 719 | Kotlin Exposed ORM。殿未使用 |
| kotlin-ktor-patterns | D | 689 | Kotlin Ktor。殿未使用 |
| kotlin-patterns | D | 711 | Kotlin言語パターン。殿未使用 |
| kotlin-testing | D | 824 | Kotlin テスト（Kotest/MockK）。殿未使用 |
| liquid-glass-design | D | 279 | iOS 26 Liquid Glass UIデザイン。殿未使用 |
| logistics-exception-management | D | 222 | 物流例外管理（配送遅延・損傷等）。業務外 |
| market-research | C | 75 | 市場調査・競合分析。法律事務所の競合調査で活用可能性あり |
| nanoclaw-repl | C | 33 | NanoClaw v2 REPL操作・拡張。ECC内部ツール、使用実績なし |
| perl-patterns | D | 504 | Perl言語パターン。殿未使用 |
| perl-security | D | 503 | Perlセキュリティ。殿未使用 |
| perl-testing | D | 475 | Perlテスト。殿未使用 |
| plankton-code-quality | C | 239 | Planktonによるwrite-time品質強制。Python開発に応用可だが未使用 |
| production-scheduling | D | 238 | 生産スケジューリング（製造業）。業務外 |
| prompt-optimizer | B | 397 | プロンプト最適化・ECC活用最大化。日常的な指示改善に使える |
| quality-nonconformance | D | 260 | 品質管理・不適合管理（製造業QC）。業務外 |
| ralphinho-rfc-pipeline | C | 67 | RFC駆動マルチエージェントDAG実行。shogunシステム参考にはなるが直接は限定的 |
| regex-vs-llm-structured-text | B | 220 | 正規表現 vs LLMの構造テキスト解析判断フレームワーク。n8n開発・データ処理に有用 |
| returns-reverse-logistics | D | 240 | 返品・逆物流。業務外 |
| search-first | A | 161 | コーディング前リサーチワークフロー。非常に汎用的で殿の開発プロセス全体に適用可 |
| skill-stocktake | B | 193 | スキル・コマンド品質監査（Quick Scan/Full Stocktakeモード）。ECC資産管理に有用 |
| swift-actor-persistence | D | 143 | SwiftアクターによるThread-safeデータ永続化。殿未使用 |
| swift-concurrency-6-2 | D | 216 | Swift 6.2 Approachable Concurrency。殿未使用 |
| swift-protocol-di-testing | D | 190 | SwiftプロトコルDI/テスト。殿未使用 |
| swiftui-patterns | D | 259 | SwiftUIパターン。殿未使用 |
| video-editing | C | 310 | AI動画編集ワークフロー（FFmpeg/Remotion/ElevenLabs等）。コンテンツ制作で将来有用 |
| videodb | C | 376 | 動画/音声のインジェスト・分析・タイムライン編集。高機能だが現状未使用 |
| visa-doc-translate | C | 117 | ビザ申請書類の翻訳PDF作成。法律事務所でビザ案件があれば有用 |
| x-api | D | 209 | X/Twitter API統合（OAuth/レート制限等）。SNS活動なし |

### 新規コマンド（17件）

| 名前 | ランク | 行数 | 根拠 |
|------|--------|------|------|
| aside | B | 164 | 作業中断なしでサイドクエスチョンに回答。非常に汎用的で使いやすい |
| claw | C | 51 | NanoClaw v2 REPL起動。ECC内部ツール、使用実績なし |
| gradle-build | D | 70 | Android/KMPのGradleビルドエラー修正。殿未使用 |
| harness-audit | C | 58 | エージェントハーネス設定の監査。マルチエージェント管理で有用だが頻度低 |
| kotlin-build | D | 174 | Kotlinビルドエラー修正。殿未使用 |
| kotlin-review | D | 140 | Kotlinコードレビュー。殿未使用 |
| kotlin-test | D | 312 | KotlinのTDDワークフロー（Kotestテスト記述）。殿未使用 |
| learn-eval | B | 116 | セッションからパターン抽出・自己評価。継続学習・インスティンクト蓄積に有用 |
| loop-start | B | 32 | 管理された自律ループパターン起動。CI/自動化ワークフローで将来有用 |
| loop-status | B | 24 | ループ状態・進捗・障害シグナルの確認。loop-startとセットで有用 |
| model-route | B | 26 | タスク複雑度によるモデルルーティング推薦。コスト意識的な作業選択に有用 |
| projects | C | 39 | continuous-learning-v2プロジェクト一覧。continuous-learning未活用のため限定的 |
| promote | C | 41 | インスティンクトをグローバルスコープへ昇格。continuous-learning未活用のため限定的 |
| prompt-optimize | B | 38 | プロンプト最適化コマンド。複雑な指示作成前に分析・最適化に使える |
| quality-gate | B | 29 | 品質パイプラインをオンデマンド実行。PR前チェック・コードレビュー補助に有用 |
| resume-session | B | 155 | セッション状態復元。長時間作業の引き継ぎ・コンテキスト制限後の再開に必須 |
| save-session | B | 275 | セッション状態保存。コンテキスト限界前の状態保存・次セッションへの引き継ぎに必須 |

### 新規エージェント（5件）

| 名前 | ランク | 行数 | 根拠 |
|------|--------|------|------|
| chief-of-staff | B | 151 | 多チャネル通信管理（メール/Slack/LINE/Messenger等）。4段階トリアージで通信自動化に有用 |
| harness-optimizer | C | 35 | エージェントハーネス設定の分析・改善。マルチエージェント管理で有用だが頻度低 |
| kotlin-build-resolver | D | 118 | Kotlinビルド・コンパイルエラー修正専門。殿未使用 |
| kotlin-reviewer | D | 159 | Kotlinコードレビュー専門（慣用的パターン・並行処理等）。殿未使用 |
| loop-operator | C | 36 | 自律エージェントループ監視・介入。loop-startと組み合わせて有用だが頻度低 |

---

## 削除候補リスト（D ランク — 65件）

### Skills（46件） — 合計行数: 16,407行

**新規追加分（30件）— 10,167行**

| 名前 | 行数 | 削除理由 |
|------|------|----------|
| android-clean-architecture | 339 | Android/Kotlin未使用 |
| carrier-relationship-management | 212 | 運送キャリア管理。業務外 |
| compose-multiplatform-patterns | 299 | Kotlin Compose Multiplatform未使用 |
| cpp-coding-standards | 723 | C++未使用 |
| crosspost | 192 | SNS運用なし |
| customs-trade-compliance | 263 | 通関・貿易コンプライアンス。業務外 |
| energy-procurement | 228 | 電力・ガス調達。業務外 |
| fal-ai-media | 284 | fal.ai メディア生成未使用 |
| foundation-models-on-device | 243 | Apple FoundationModels未使用 |
| inventory-demand-planning | 247 | 在庫・需要計画。業務外 |
| investor-materials | 96 | ピッチデッキ・投資家資料。業務外 |
| investor-outreach | 76 | 投資家向けコールドメール。業務外 |
| kotlin-coroutines-flows | 284 | Kotlin未使用 |
| kotlin-exposed-patterns | 719 | Kotlin Exposed ORM未使用 |
| kotlin-ktor-patterns | 689 | Kotlin Ktor未使用 |
| kotlin-patterns | 711 | Kotlin未使用 |
| kotlin-testing | 824 | Kotlinテスト未使用 |
| liquid-glass-design | 279 | iOS 26 Liquid Glass UI未使用 |
| logistics-exception-management | 222 | 物流例外管理。業務外 |
| perl-patterns | 504 | Perl未使用 |
| perl-security | 503 | Perl未使用 |
| perl-testing | 475 | Perl未使用 |
| production-scheduling | 238 | 生産スケジューリング。業務外 |
| quality-nonconformance | 260 | 品質管理・不適合管理（製造業）。業務外 |
| returns-reverse-logistics | 240 | 返品・逆物流。業務外 |
| swift-actor-persistence | 143 | Swift未使用 |
| swift-concurrency-6-2 | 216 | Swift 6.2未使用 |
| swift-protocol-di-testing | 190 | Swift未使用 |
| swiftui-patterns | 259 | SwiftUI未使用 |
| x-api | 209 | X/Twitter API。SNS活動なし |

**cmd_148据置分（16件）— 6,240行**

| 名前 | 行数 | 削除理由 |
|------|------|----------|
| clickhouse-io | 438 | ClickHouse分析DB。全く無関係 |
| cpp-testing | 322 | C++未使用 |
| database-migrations | 334 | DB中心開発なし |
| django-patterns | 733 | Django未使用 |
| django-security | 592 | Django未使用 |
| django-tdd | 728 | Django未使用 |
| django-verification | 468 | Django未使用 |
| golang-patterns | 673 | Go未使用 |
| golang-testing | 719 | Go未使用 |
| java-coding-standards | 146 | Java未使用 |
| jpa-patterns | 150 | Java/JPA未使用 |
| nutrient-document-processing | 165 | APIキー未取得。PyPDF2で代替 |
| springboot-patterns | 313 | Spring Boot未使用 |
| springboot-security | 271 | Spring Boot未使用 |
| springboot-tdd | 157 | Spring Boot未使用 |
| springboot-verification | 230 | Spring Boot未使用 |

### Commands（13件） — 合計行数: 2,159行

**新規追加分（4件）— 696行**

| 名前 | 行数 | 削除理由 |
|------|------|----------|
| gradle-build | 70 | Android/KMPのGradleビルドエラー修正。殿未使用 |
| kotlin-build | 174 | Kotlinビルドエラー修正。殿未使用 |
| kotlin-review | 140 | Kotlinコードレビュー。殿未使用 |
| kotlin-test | 312 | KotlinのTDDワークフロー。殿未使用 |

**cmd_148据置分（9件）— 1,463行**

| 名前 | 行数 | 削除理由 |
|------|------|----------|
| evolve | 193 | continuous-learning未活用 |
| go-build | 183 | Go未使用 |
| go-review | 148 | Go未使用 |
| go-test | 268 | Go未使用 |
| instinct-export | 91 | continuous-learning未活用 |
| instinct-import | 142 | continuous-learning未活用 |
| instinct-status | 86 | continuous-learning未活用 |
| pm2 | 272 | Node.js向け。環境不一致 |
| setup-pm | 80 | Python中心でNode.js PM不要 |

### Agents（6件） — 合計行数: 652行

**新規追加分（2件）— 277行**

| 名前 | 行数 | 削除理由 |
|------|------|----------|
| kotlin-build-resolver | 118 | Kotlinビルドエラー修正専門。殿未使用 |
| kotlin-reviewer | 159 | Kotlinコードレビュー専門。殿未使用 |

**cmd_148据置分（4件）— 375行**

| 名前 | 行数 | 削除理由 |
|------|------|----------|
| build-error-resolver | 114 | TypeScriptプロジェクト未使用 |
| database-reviewer | 91 | DB使用なし |
| go-build-resolver | 94 | Go未使用 |
| go-reviewer | 76 | Go未使用 |

### コンテキスト削減効果

| カテゴリ | 削除件数 | 削除行数 | うち新規 |
|----------|----------|----------|----------|
| Skills | 46件 | 16,407行 | 30件・10,167行 |
| Commands | 13件 | 2,159行 | 4件・696行 |
| Agents | 6件 | 652行 | 2件・277行 |
| **合計** | **65件** | **19,218行** | **36件・11,140行** |

**全65件削除により、Claude Codeの起動時読み込み量が約19,200行（推定35-40%）削減可能。**

---

## 変動サマリー

### cmd_148からの変更（既存105件）

前回評価からの変更なし。105件は全て評価を据え置き。

### 新規追加分の内訳（79件）

| ランク | Skills | Commands | Agents | 合計 |
|--------|--------|----------|--------|------|
| S | 0 | 0 | 0 | 0 |
| A | 2 | 0 | 0 | **2** |
| B | 11 | 9 | 1 | **21** |
| C | 14 | 4 | 2 | **20** |
| D | 30 | 4 | 2 | **36** |
| **合計** | **57** | **17** | **5** | **79** |

### 新規Aランク昇格（特記）

1. **autonomous-loops**（Skill, 612行）: マルチエージェントDAGシステム・自律ループパターンの設計核。殿のshogunシステムと直接関連。
2. **search-first**（Skill, 161行）: コーディング前にGitHub/ライブラリ/パターン検索を強制するワークフロー。全開発タスクに汎用的に適用可能。

### 新規Bランク注目スキル（高潜在力）

- **claude-api**: AnthropicのClaude APIを使ったアプリ開発に直接有用（Python/TS対応）
- **prompt-optimizer**: 日常的なプロンプト改善に使える汎用スキル
- **deep-research**: 法律調査・競合分析にfirecrawl/exaを活用
- **resume-session / save-session**: セッション管理の新コマンドペア。コンテキスト制限後の復帰に必須

### 傾向

新規79件はDランク比率が高い（36/79 = 46%）。これは主に以下の理由:
1. 技術スタック外（Kotlin/Swift/Perl/PHP系）: 17件がDランク
2. 業務外（物流・製造・金融・投資関連）: 8件がDランク
3. SNS/メディア未使用: 6件がDランク

マルチエージェント・AI・自律ループ関連は積極的にB以上を付与（合計10件以上がA/Bランク）。

---

*レポート終*
