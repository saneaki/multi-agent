# コマンド・スキル全調査レポート

**作成日時**: 2026-02-13
**調査対象**: ~/.claude/commands/ (34件) + multi-agent/skills/ (5件)
**作成者**: ashigaru2

---

## 1. コマンド一覧サマリー

| # | コマンド名 | 説明 | カテゴリ |
|---|-----------|------|---------|
| 1 | /build-fix | ビルド・型エラーを段階的に修正 | 開発 |
| 2 | /checkpoint | ワークフローのチェックポイント作成・検証 | セッション |
| 3 | /code-review | 未コミット変更の包括的レビュー | コード品質 |
| 4 | /e2e | Playwright E2Eテスト生成・実行 | テスト |
| 5 | /eval | Eval駆動開発ワークフロー管理 | 評価 |
| 6 | /evolve | Instinctをスキル/コマンド/エージェントに進化 | 学習・進化 |
| 7 | /go-build | Go ビルドエラーを段階的に修正 | 言語固有（Go） |
| 8 | /go-review | Go コードの包括的レビュー | 言語固有（Go） |
| 9 | /go-test | Go TDD ワークフロー実行 | 言語固有（Go） |
| 10 | /instinct-export | Instinctをエクスポート（共有用） | 学習・進化 |
| 11 | /instinct-import | Instinctをインポート | 学習・進化 |
| 12 | /instinct-status | 学習済みInstinct一覧表示 | 学習・進化 |
| 13 | /learn | セッションからパターン抽出・保存 | 学習・進化 |
| 14 | /multi-backend | バックエンド特化マルチモデル開発 | マルチモデル |
| 15 | /multi-execute | マルチモデル協調実行 | マルチモデル |
| 16 | /multi-frontend | フロントエンド特化マルチモデル開発 | マルチモデル |
| 17 | /multi-plan | マルチモデル協調計画 | マルチモデル |
| 18 | /multi-workflow | 6フェーズ構造化開発ワークフロー | マルチモデル |
| 19 | /orchestrate | マルチエージェント連携ワークフロー | 運用 |
| 20 | /plan | 実装計画作成（コード着手前） | 開発 |
| 21 | /pm2 | PM2サービス自動生成 | 運用 |
| 22 | /pub | ドキュメント更新→コミット→プッシュ | Git |
| 23 | /pull-build | リモートからプル→ビルド | Git |
| 24 | /python-review | Python コードの包括的レビュー | 言語固有（Python） |
| 25 | /refactor-clean | デッドコード安全削除 | コード品質 |
| 26 | /revise-claude-md | セッションから学びをCLAUDE.mdに反映 | ドキュメント |
| 27 | /sessions | セッション履歴管理 | セッション |
| 28 | /setup-pm | パッケージマネージャー設定 | 運用 |
| 29 | /skill-create | Git履歴からスキルファイル生成 | 学習・進化 |
| 30 | /tdd | TDD ワークフロー実行 | 開発 |
| 31 | /test-coverage | カバレッジ分析・不足テスト生成 | テスト |
| 32 | /update-codemaps | コードベースアーキテクチャ文書更新 | ドキュメント |
| 33 | /update-docs | ソースからドキュメント自動同期 | ドキュメント |
| 34 | /verify | ビルド・型・リント・テスト・セキュリティ包括検証 | テスト |

---

## 2. カテゴリ別分類

### 開発（5件）
- **/plan**: 実装計画作成（コード着手前）
- **/tdd**: TDD ワークフロー実行
- **/build-fix**: ビルド・型エラーを段階的に修正
- **/e2e**: Playwright E2Eテスト生成・実行
- **/orchestrate**: マルチエージェント連携ワークフロー

### Git（2件）
- **/pub**: ドキュメント更新→コミット→プッシュ
- **/pull-build**: リモートからプル→ビルド

### テスト（3件）
- **/test-coverage**: カバレッジ分析・不足テスト生成
- **/verify**: ビルド・型・リント・テスト・セキュリティ包括検証
- **/e2e**: Playwright E2Eテスト生成・実行

### マルチモデル（5件）
- **/multi-plan**: マルチモデル協調計画
- **/multi-execute**: マルチモデル協調実行
- **/multi-backend**: バックエンド特化マルチモデル開発
- **/multi-frontend**: フロントエンド特化マルチモデル開発
- **/multi-workflow**: 6フェーズ構造化開発ワークフロー

### セッション（2件）
- **/sessions**: セッション履歴管理
- **/checkpoint**: ワークフローのチェックポイント作成・検証

### 運用（3件）
- **/pm2**: PM2サービス自動生成
- **/setup-pm**: パッケージマネージャー設定
- **/orchestrate**: マルチエージェント連携ワークフロー

### 言語固有（5件）
- **Go（3件）**: /go-review, /go-test, /go-build
- **Python（1件）**: /python-review
- **TypeScript（1件）**: /build-fix

### コード品質（2件）
- **/code-review**: 未コミット変更の包括的レビュー
- **/refactor-clean**: デッドコード安全削除

### ドキュメント（3件）
- **/update-codemaps**: コードベースアーキテクチャ文書更新
- **/update-docs**: ソースからドキュメント自動同期
- **/revise-claude-md**: セッションから学びをCLAUDE.mdに反映

### 学習・進化（6件）
- **/learn**: セッションからパターン抽出・保存
- **/evolve**: Instinctをスキル/コマンド/エージェントに進化
- **/instinct-status**: 学習済みInstinct一覧表示
- **/instinct-import**: Instinctをインポート
- **/instinct-export**: Instinctをエクスポート（共有用）
- **/skill-create**: Git履歴からスキルファイル生成

### 評価（1件）
- **/eval**: Eval駆動開発ワークフロー管理

---

## 3. コマンド詳細

### 3.1 開発系コマンド

#### /plan
- **説明**: 実装計画作成（コード着手前）
- **使用ツール**: Read, Glob, Grep
- **ユースケース**: 新機能開発、大規模リファクタリング
- **ワークフロー**: 要件再確認 → リスク特定 → 段階的計画作成 → ユーザー承認待ち
- **エージェント連携**: planner エージェント起動

#### /tdd
- **説明**: TDD ワークフロー実行
- **使用ツール**: Read, Write, Bash
- **ユースケース**: 新機能実装、バグ修正
- **ワークフロー**: インターフェース設計 → テスト先行作成（RED） → 最小実装（GREEN） → リファクタリング → カバレッジ検証（80%+）
- **エージェント連携**: tdd-guide エージェント起動

#### /build-fix
- **説明**: ビルド・型エラーを段階的に修正
- **使用ツール**: Bash, Read, Edit
- **ユースケース**: npm run build 失敗時
- **ワークフロー**: ビルド実行 → エラー分類 → ファイル単位で修正 → 再ビルド検証 → 新規エラー検出時停止

#### /e2e
- **説明**: Playwright E2Eテスト生成・実行
- **使用ツール**: Bash, Read, Write
- **ユースケース**: ログイン、決済等クリティカルフロー検証
- **ワークフロー**: テストジャーニー作成 → 実行 → スクリーンショット・トレース取得 → レポート生成 → フレーキーテスト隔離
- **エージェント連携**: e2e-runner エージェント起動

#### /orchestrate
- **説明**: マルチエージェント連携ワークフロー
- **使用ツール**: Task
- **ユースケース**: 複雑なタスクの段階的実行
- **ワークフローパターン**:
  - feature: planner → tdd-guide → code-reviewer → security-reviewer
  - bugfix: explorer → tdd-guide → code-reviewer

---

### 3.2 Git系コマンド

#### /pub
- **説明**: ドキュメント更新→コミット→プッシュ
- **使用ツール**: Bash, Read, Edit
- **ユースケース**: 変更のプッシュ前
- **ワークフロー**:
  1. ドキュメント更新チェック（README.md等）
  2. git commit（日本語コミットメッセージ、Co-Authored-Byなし）
  3. git push

#### /pull-build
- **説明**: リモートからプル→ビルド
- **使用ツール**: Bash
- **ユースケース**: リモート更新の取得・反映
- **ワークフロー**:
  1. 未コミット変更確認
  2. git pull
  3. 変更があればビルド実行

---

### 3.3 テスト系コマンド

#### /test-coverage
- **説明**: カバレッジ分析・不足テスト生成
- **使用ツール**: Bash, Read, Write
- **ユースケース**: 80%未満のカバレッジ改善
- **ワークフロー**: テスト実行（--coverage） → 未カバーファイル特定 → ユニット/統合/E2Eテスト生成 → 検証 → Before/After比較

#### /verify
- **説明**: ビルド・型・リント・テスト・セキュリティ包括検証
- **使用ツール**: Bash
- **ユースケース**: コミット前、マージ前
- **ワークフロー**: ビルドチェック → 型チェック → リントチェック → テスト実行 → セキュリティスキャン → 全てパスでOK

#### /e2e
（開発系に記載）

---

### 3.4 マルチモデル系コマンド

#### /multi-plan
- **説明**: マルチモデル協調計画
- **使用ツール**: Read, Write, Bash
- **ユースケース**: 複雑なタスクの計画段階
- **マルチモデル連携**: Codex + Gemini 並列呼び出し（run_in_background: true）
- **制約**: .claude/plan/* のみ書き込み可、本番コード変更不可

#### /multi-execute
- **説明**: マルチモデル協調実行
- **使用ツール**: Read, Write, Edit, Bash
- **ユースケース**: /multi-plan承認後の実装フェーズ
- **マルチモデル連携**: Codex/Geminiがプロトタイプ生成 → Claude Code がリファクタリング・実装
- **前提条件**: /multi-plan出力にユーザーが「Y」承認済み

#### /multi-backend
- **説明**: バックエンド特化マルチモデル開発
- **使用ツール**: Read, Write, Bash
- **ユースケース**: API設計、アルゴリズム実装、DB最適化
- **マルチモデル連携**: Codex主導、Gemini補助
- **ワークフロー**: Research → Ideation → Plan → Execute → Optimize → Review

#### /multi-frontend
- **説明**: フロントエンド特化マルチモデル開発
- **使用ツール**: Read, Write, Bash
- **ユースケース**: コンポーネント設計、レスポンシブレイアウト、UIアニメーション
- **マルチモデル連携**: Gemini主導、Codex補助
- **ワークフロー**: Research → Ideation → Plan → Execute → Optimize → Review

#### /multi-workflow
- **説明**: 6フェーズ構造化開発ワークフロー
- **使用ツール**: Read, Write, Bash
- **ユースケース**: 大規模開発タスク
- **マルチモデル連携**: Codex（バックエンド）+ Gemini（フロントエンド）+ Claude（オーケストレーション）
- **ワークフロー**: Research → Ideation → Plan → Execute → Optimize → Review

---

### 3.5 セッション系コマンド

#### /sessions
- **説明**: セッション履歴管理
- **使用ツール**: Read, Bash
- **ユースケース**: 過去セッション検索・ロード
- **機能**:
  - list: 全セッション一覧（フィルタ・ページング対応）
  - load: セッションロード
  - alias: セッションへのエイリアス設定
  - info: セッション詳細表示

#### /checkpoint
- **説明**: ワークフローのチェックポイント作成・検証
- **使用ツール**: Bash
- **ユースケース**: 大規模変更前の退避ポイント作成
- **ワークフロー**: /verify quick → git stash/commit → .claude/checkpoints.log記録

---

### 3.6 運用系コマンド

#### /pm2
- **説明**: PM2サービス自動生成
- **使用ツール**: Bash, Read, Write
- **ユースケース**: プロジェクト構成からPM2設定自動生成
- **機能**: サービス検出（frontend/backend/database） → PM2設定ファイル生成 → 個別コマンドファイル生成

#### /setup-pm
- **説明**: パッケージマネージャー設定
- **使用ツール**: Bash
- **ユースケース**: npm/pnpm/yarn/bunの設定
- **機能**: 検出・グローバル設定・プロジェクト設定

#### /orchestrate
（開発系に記載）

---

### 3.7 言語固有コマンド

#### Go（3件）

##### /go-review
- **説明**: Go コードの包括的レビュー
- **使用ツール**: Bash, Read
- **ユースケース**: .go ファイル変更後
- **ワークフロー**: go vet → staticcheck → golangci-lint → セキュリティスキャン → 並行性レビュー → Go慣用句チェック
- **エージェント連携**: go-reviewer エージェント起動

##### /go-test
- **説明**: Go TDD ワークフロー実行
- **使用ツール**: Bash, Read, Write
- **ユースケース**: Go新機能実装、バグ修正
- **ワークフロー**: 型/インターフェース定義 → テーブル駆動テスト作成 → 実装 → go test -cover（80%+検証）

##### /go-build
- **説明**: Go ビルドエラーを段階的に修正
- **使用ツール**: Bash, Read, Edit
- **ユースケース**: go build ./... 失敗時
- **ワークフロー**: 診断実行 → エラー分類 → 段階的修正 → 再ビルド検証
- **エージェント連携**: go-build-resolver エージェント起動

#### Python（1件）

##### /python-review
- **説明**: Python コードの包括的レビュー
- **使用ツール**: Bash, Read
- **ユースケース**: .py ファイル変更後
- **ワークフロー**: ruff → mypy → pylint → black --check → セキュリティスキャン → 型安全レビュー → Pythonic コードチェック
- **エージェント連携**: python-reviewer エージェント起動

---

### 3.8 コード品質系コマンド

#### /code-review
- **説明**: 未コミット変更の包括的レビュー
- **使用ツール**: Bash, Read
- **ユースケース**: コード変更後（コミット前）
- **チェック項目**:
  - CRITICAL: ハードコード認証情報、SQLインジェクション、XSS、入力バリデーション欠落
  - HIGH: 50行超関数、800行超ファイル、4階層超ネスト
- **エージェント連携**: code-reviewer エージェント起動

#### /refactor-clean
- **説明**: デッドコード安全削除
- **使用ツール**: Bash, Read, Edit
- **ユースケース**: コード整理
- **ワークフロー**: デッドコード分析（knip, depcheck, ts-prune） → レポート生成 → 重要度分類（SAFE/CAUTION/DANGER） → 削除提案 → テスト実行 → 削除実行
- **エージェント連携**: refactor-cleaner エージェント起動

---

### 3.9 ドキュメント系コマンド

#### /update-codemaps
- **説明**: コードベースアーキテクチャ文書更新
- **使用ツール**: Read, Write, Bash
- **ユースケース**: アーキテクチャ変更時
- **出力ファイル**: codemaps/{architecture,backend,frontend,data}.md
- **ワークフロー**: インポート/エクスポート/依存スキャン → 差分計算 → 30%超変更時ユーザー承認 → タイムスタンプ付き更新

#### /update-docs
- **説明**: ソースからドキュメント自動同期
- **使用ツール**: Read, Write
- **ユースケース**: package.json, .env.example 変更時
- **生成ドキュメント**: docs/CONTRIB.md, docs/RUNBOOK.md
- **抽出データ**: スクリプト参照、環境変数、開発ワークフロー、デプロイ手順

#### /revise-claude-md
- **説明**: セッションから学びをCLAUDE.mdに反映
- **使用ツール**: Read, Edit, Glob
- **ユースケース**: セッション終了時、重要な発見があった時
- **反映内容**: Bashコマンド、コードスタイル、テストアプローチ、環境/設定の癖、注意事項

---

### 3.10 学習・進化系コマンド

#### /learn
- **説明**: セッションからパターン抽出・保存
- **使用ツール**: Read, Write
- **ユースケース**: 非自明な問題を解決した時
- **抽出対象**: エラー解決パターン、デバッグ技法、ワークフロー、フレームワーク特有の癖

#### /evolve
- **説明**: Instinctをスキル/コマンド/エージェントに進化
- **使用ツール**: Bash
- **ユースケース**: 関連Instinctが蓄積された時
- **実装**: continuous-learning-v2 の instinct-cli.py evolve 呼び出し

#### /instinct-status
- **説明**: 学習済みInstinct一覧表示
- **使用ツール**: Bash
- **ユースケース**: 現在のInstinct状況確認
- **実装**: continuous-learning-v2 の instinct-cli.py status 呼び出し

#### /instinct-import
- **説明**: Instinctをインポート
- **使用ツール**: Bash
- **ユースケース**: チームメイトやSkill Creatorからのインポート
- **実装**: continuous-learning-v2 の instinct-cli.py import 呼び出し

#### /instinct-export
- **説明**: Instinctをエクスポート（共有用）
- **使用ツール**: Bash
- **ユースケース**: チーム共有、他マシン移行
- **実装**: continuous-learning-v2 の instinct-cli.py export 呼び出し

#### /skill-create
- **説明**: Git履歴からスキルファイル生成
- **使用ツール**: Bash, Read, Write, Grep, Glob
- **ユースケース**: リポジトリのコーディングパターン抽出
- **ワークフロー**: git log 分析 → パターン検出 → SKILL.md 生成

---

### 3.11 評価系コマンド

#### /eval
- **説明**: Eval駆動開発ワークフロー管理
- **使用ツール**: Bash, Read, Write
- **ユースケース**: Eval定義・チェック・レポート・一覧
- **サブコマンド**: define, check, report, list
- **出力**: .claude/evals/{feature-name}.md

---

## 4. プロジェクトレベルスキル一覧

| # | スキル名 | 説明 | 対象 | ファイルパス |
|---|---------|------|------|-------------|
| 1 | legal-office-research | 法律事務所の競合調査パターン。弁護士数、取扱分野、物件規模を3段階フローで収集 | 法律事務所 | skills/legal-office-research.md |
| 2 | n8n-drive-notion-sync | Google Drive → Notion DB 自動連携。ファイル名パース→書面DB登録 | n8n自動化 | skills/n8n-drive-notion-sync.md |
| 3 | n8n-automation-patterns | n8n自動化ワークフロー設計パターン。Gmail→Notion、Motion API連携等 | n8n自動化 | skills/n8n-automation-patterns.md |
| 4 | astro-law-firm-starter | Astro + Tailwind CSS で法律事務所HP構築。環境構築→デプロイ→SEO対策 | 法律事務所Web開発 | skills/astro-law-firm-starter.md |
| 5 | skill-creator | 汎用作業パターンを再利用可能スキルとして自動生成 | Claude Code スキル開発 | skills/skill-creator/SKILL.md |

---

## 5. プロジェクトレベルスキル詳細

### 5.1 legal-office-research
- **説明**: 法律事務所の競合調査パターン
- **対象**: 法律事務所開業・市場分析
- **調査フロー**:
  1. 弁護士ドットコムで事務所一覧＋弁護士数取得
  2. Google Mapsで所在地・物件規模確認
  3. 各事務所HPで取扱分野詳細収集
- **取得データ**: 事務所名、所在地、弁護士数、取扱分野、物件規模
- **出力形式**: Markdown表形式レポート
- **足軽割り当て**: 地域別に並列実行可能

### 5.2 n8n-drive-notion-sync
- **説明**: Google Drive → Notion DB 自動連携
- **対象**: 法律事務所の書面管理自動化
- **ワークフロー**: Google Drive Trigger（ファイル作成） → Function Node（ファイル名パース） → IF Node（パース成功判定） → Notion Node（書面DB作成）
- **ファイル命名規則**: YYYYMMDD_種別番号_書面名
- **自動抽出項目**: 書面種別、証拠番号、案件ID
- **応用範囲**: 他業種でも命名規則を変更すれば適用可能

### 5.3 n8n-automation-patterns
- **説明**: n8n自動化ワークフロー設計パターン
- **対象**: Gmail、Notion、Motion、Slack、LINE連携
- **パターン例**:
  1. Gmail → Notion 自動連携（メール受信→DB登録→添付ファイルDrive保存）
  2. Motion API連携（タスク自動作成・完了通知）
  3. Webhook受信→データベース登録
  4. 定期実行レポート生成・通知
- **ベストプラクティス**: 認証設定、エラーハンドリング、リトライ戦略、セルフホスト vs Cloud選択

### 5.4 astro-law-firm-starter
- **説明**: Astro + Tailwind CSS で法律事務所HP構築
- **対象**: 法律事務所（弁護士、司法書士、行政書士等）
- **環境**: Node.js v18.17.1+, pnpm推奨, VS Code, Claude Code活用
- **ワークフロー**: プロジェクト初期化 → ページ作成 → SEO対策（Lighthouse 100点目標） → デプロイ（月額$0ホスティング実現）
- **特徴**: 静的サイト生成（高速・セキュア）、WordPressからの移行も対応

### 5.5 skill-creator
- **説明**: 汎用作業パターンを再利用可能スキルとして自動生成
- **対象**: Claude Code スキル開発
- **スキル化条件**: 再利用性、複雑性、安定性、価値
- **生成構造**: skill-name/{SKILL.md, scripts/, resources/}
- **活用場面**: 非自明な問題解決時、繰り返し作業のパターン化

---

## 6. 全体考察

### 6.1 コマンドの充実度
- **総数**: 34コマンド
- **最も充実**: マルチモデル系（5件）、学習・進化系（6件）
- **言語カバレッジ**: Go（3件）、Python（1件）、TypeScript暗黙（build-fix）
- **特徴**: TDD・コード品質・セキュリティに強い重点

### 6.2 プロジェクトスキルの特徴
- **総数**: 5スキル
- **対象ドメイン**: 法律事務所（2件）、n8n自動化（2件）、汎用（1件）
- **特徴**: 実務直結型、業務自動化特化
- **再利用性**: 高（他業種への横展開可能）

### 6.3 使用頻度が高いと思われるコマンド（推定）
1. **/plan**: 全開発の起点
2. **/tdd**: TDD強制でコード品質担保
3. **/code-review**: コミット前必須
4. **/verify**: マージ前最終チェック
5. **/pub**: 変更のプッシュ標準フロー

### 6.4 今後の拡張候補
- **Rust対応**: /rust-review, /rust-test
- **デプロイ系**: /deploy-staging, /deploy-production
- **CI/CD系**: /ci-setup, /github-actions
- **監視系**: /monitor-setup, /alert-config

---

## 7. まとめ

**調査完了項目**:
- ✅ ~/.claude/commands/ 全34件調査完了
- ✅ multi-agent/skills/ 全5件調査完了
- ✅ カテゴリ分類・詳細情報収集完了
- ✅ 構造化レポート作成完了

**発見事項**:
- Everything Claude Code プラグインは非常に包括的
- TDD・セキュリティ・マルチモデル協調に特化
- プロジェクトスキルは実務ドメイン特化型（法律事務所、n8n自動化）
- 継続学習機構（Instinct→Skill→Command→Agent進化）が実装済み

**スキル候補性**: ⭕ （この調査パターン自体を `command-skill-survey` スキルとして抽出可能）
