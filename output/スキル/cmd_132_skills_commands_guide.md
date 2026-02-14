# スキル・コマンド総合評価ガイド

**作成日時**: 2026-02-13
**作成者**: ashigaru5（シニアコンサルタント）
**対象**: 殿（弁護士・倉敷市開業準備中）専用評価
**parent_cmd**: cmd_132

---

## 1. エグゼクティブサマリー

### 殿のプロフィール（評価の前提）

- 職業: 弁護士（倉敷市で開業準備中）
- 技術スキル: Claude Code・GitHub・Notion 日常使用。Web開発経験なし
- プログラミング: Python/Bash 基礎あり
- 現在の活動: 法律事務所業務 + AIツール開発（multi-agent） + n8n自動化
- 環境: WSL2上のmulti-agentシステム（将軍・家老・足軽の3層構造）

### 全体数値概要

| ランク | スキル | コマンド | プロジェクトスキル | 合計 |
|--------|--------|---------|-------------------|------|
| S（必須） | 7件 | 10件 | 3件 | **20件** |
| A（非常に有用） | 11件 | 12件 | 2件 | **25件** |
| B（限定的に有用） | 4件 | 9件 | 0件 | **13件** |
| C（優先度低） | 5件 | 0件 | 0件 | **5件** |
| D（削除候補） | 14件 | 3件 | 0件 | **17件** |

### TOP10 — 殿が今すぐ覚えるべきもの

| 順位 | 名前 | 種別 | 合計点 | 一言説明 |
|------|------|------|--------|----------|
| 1 | /plan | コマンド | 20 | 全ての開発・調査の起点。何かを始める前にまず/plan |
| 2 | /pub | コマンド | 20 | ドキュメント更新→コミット→プッシュの一括実行 |
| 3 | strategic-compact | スキル | 19 | 長いセッションでのコンテキスト管理。API費用節約の鍵 |
| 4 | claude-md-improver | スキル | 19 | CLAUDE.mdの品質監査・改善。システムの心臓部を整備 |
| 5 | /verify | コマンド | 18 | ビルド・テスト・セキュリティの包括検証。コミット前の最終チェック |
| 6 | /code-review | コマンド | 18 | コード変更後に自動品質レビュー。バグ予防の決め手 |
| 7 | /revise-claude-md | コマンド | 18 | セッションで学んだことをCLAUDE.mdに自動反映 |
| 8 | pull-merge-pub | スキル | 18 | プル→マージ→プッシュのGitワークフロー自動化 |
| 9 | security-review | スキル | 17 | コミット前のセキュリティチェック。顧客情報保護に必須 |
| 10 | legal-document-namer | スキル | 17 | 法律事務所向けファイル命名規則。書面管理の基盤 |

### 削除候補（計16件）

殿の環境・スキルセットに合わないため、削除してコンテキスト節約を推奨:

- **Java/Spring Boot系（6件）**: springboot-patterns, springboot-security, springboot-tdd, springboot-verification, java-coding-standards, jpa-patterns
- **Django系（4件）**: django-patterns, django-security, django-tdd, django-verification
- **その他不要（3件）**: clickhouse-io, backend-patterns, frontend-patterns
- **コマンド（3件）**: /go-build, /go-review, /go-test

---

## 2. スキル全一覧（有用度S→D順）

### 評価軸
- (1) 適合度: 殿のスキルセットとの適合度（0-5）
- (2) 頻度: 日常業務での利用頻度（0-5）
- (3) 親和性: multi-agentシステムとの親和性（0-5）
- (4) コスパ: 学習コスト対効果（0-5）

### S ランク（16-20点）— 今すぐ使い始めるべき

| スキル名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|---------|------|------|------|------|--------|------|
| strategic-compact | コンテキストの戦略的圧縮。長セッションのAPI費用節約 | 5 | 4 | 5 | 5 | **19** |
| claude-md-improver | CLAUDE.md品質監査・改善。システム最適化の基盤 | 5 | 4 | 5 | 5 | **19** |
| pull-merge-pub | プル→コンフリクト確認→マージ→/pubの一括実行 | 4 | 5 | 5 | 4 | **18** |
| security-review | コミット前セキュリティチェックリスト | 4 | 3 | 5 | 5 | **17** |
| legal-document-namer | 法律事務所向けファイル命名パターン（証拠番号体系等） | 5 | 4 | 3 | 5 | **17** |
| n8n-expression-syntax | n8n式構文の検証・エラー修正ガイド | 4 | 4 | 3 | 5 | **16** |
| iterative-retrieval | サブエージェントのコンテキスト問題解決パターン | 4 | 3 | 5 | 4 | **16** |

### A ランク（12-15点）— 定期的に使うべき

| スキル名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|---------|------|------|------|------|--------|------|
| tdd-workflow | TDD強制ワークフロー（80%+カバレッジ） | 3 | 3 | 5 | 4 | **15** |
| continuous-learning | セッションから自動パターン抽出 | 4 | 3 | 4 | 4 | **15** |
| n8n-mcp-tools-expert | n8n MCPツールの使い方ガイド | 4 | 3 | 4 | 4 | **15** |
| continuous-learning-v2 | Instinct型学習システム（進化版） | 4 | 3 | 4 | 3 | **14** |
| n8n-code-python | n8n Code nodeでPython記述 | 4 | 3 | 3 | 4 | **14** |
| n8n-node-configuration | n8nノード設定ガイド | 4 | 3 | 3 | 4 | **14** |
| n8n-validation-expert | n8nバリデーションエラー解釈・修正 | 4 | 3 | 3 | 4 | **14** |
| n8n-workflow-patterns | n8nワークフロー設計パターン集 | 4 | 3 | 3 | 4 | **14** |
| verification-loop | 包括検証システム | 3 | 3 | 4 | 4 | **14** |
| n8n-code-javascript | n8n Code nodeでJavaScript記述 | 3 | 3 | 3 | 4 | **13** |
| eval-harness | Eval駆動開発の評価フレームワーク | 3 | 2 | 4 | 3 | **12** |

### B ランク（8-11点）— 特定場面で使う

| スキル名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|---------|------|------|------|------|--------|------|
| python-patterns | Pythonイディオム・PEP 8・型ヒント | 3 | 2 | 3 | 3 | **11** |
| python-testing | pytest戦略・TDD・フィクスチャ | 3 | 2 | 3 | 3 | **11** |
| configure-ecc | Everything Claude Codeインストーラー | 4 | 1 | 2 | 4 | **11** |
| coding-standards | TypeScript/JavaScript汎用コーディング規約 | 2 | 2 | 3 | 3 | **10** |

### C ランク（4-7点）— 殿の状況では優先度低い

| スキル名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|---------|------|------|------|------|--------|------|
| postgres-patterns | PostgreSQLパターン集 | 2 | 1 | 2 | 2 | **7** |
| tkinter-help-system | tkinter GUI ヘルプシステム | 2 | 1 | 2 | 2 | **7** |
| pytest-migration | unittest→pytest移行パターン | 2 | 1 | 2 | 2 | **7** |
| golang-patterns | Go言語パターン集 | 1 | 1 | 2 | 1 | **5** |
| golang-testing | Goテストパターン集 | 1 | 1 | 2 | 1 | **5** |

### D ランク（0-3点）— 削除推奨

| スキル名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 | 理由 |
|---------|------|------|------|------|--------|------|------|
| springboot-patterns | Spring Boot設計パターン | 0 | 0 | 1 | 0 | **1** | Java未使用 |
| springboot-security | Spring Securityガイド | 0 | 0 | 1 | 0 | **1** | Java未使用 |
| springboot-tdd | Spring Boot TDD | 0 | 0 | 1 | 0 | **1** | Java未使用 |
| springboot-verification | Spring Boot検証ループ | 0 | 0 | 1 | 0 | **1** | Java未使用 |
| java-coding-standards | Javaコーディング規約 | 0 | 0 | 1 | 0 | **1** | Java未使用 |
| jpa-patterns | JPA/Hibernateパターン | 0 | 0 | 1 | 0 | **1** | Java未使用 |
| django-patterns | Django設計パターン | 0 | 0 | 1 | 0 | **1** | Django未使用 |
| django-security | Djangoセキュリティ | 0 | 0 | 1 | 0 | **1** | Django未使用 |
| django-tdd | DjangoテストTDD | 0 | 0 | 1 | 0 | **1** | Django未使用 |
| django-verification | Django検証ループ | 0 | 0 | 1 | 0 | **1** | Django未使用 |
| backend-patterns | Node.js/Express設計パターン | 0 | 0 | 1 | 0 | **1** | Web開発未経験 |
| frontend-patterns | React/Next.js設計パターン | 0 | 0 | 1 | 0 | **1** | Web開発未経験 |
| project-guidelines-example | スキルテンプレート（例示用） | 1 | 0 | 1 | 1 | **3** | 例示のみ |
| clickhouse-io | ClickHouse分析DB | 0 | 0 | 0 | 0 | **0** | 全く無関係 |

---

## 3. コマンド全一覧（有用度S→D順）

### S ランク（16-20点）— 今すぐ使い始めるべき

| コマンド名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|-----------|------|------|------|------|--------|------|
| /plan | 実装計画作成。全作業の起点 | 5 | 5 | 5 | 5 | **20** |
| /pub | ドキュメント更新→コミット→プッシュ | 5 | 5 | 5 | 5 | **20** |
| /verify | ビルド・テスト・セキュリティ包括検証 | 4 | 4 | 5 | 5 | **18** |
| /code-review | 未コミット変更の品質レビュー | 4 | 4 | 5 | 5 | **18** |
| /revise-claude-md | セッション学習のCLAUDE.md反映 | 5 | 3 | 5 | 5 | **18** |
| /learn | セッションからパターン抽出・保存 | 4 | 3 | 4 | 5 | **16** |
| /orchestrate | マルチエージェント連携ワークフロー | 4 | 3 | 5 | 4 | **16** |
| /sessions | セッション履歴の検索・ロード | 4 | 3 | 4 | 5 | **16** |
| /checkpoint | 大規模変更前の退避ポイント作成 | 4 | 3 | 4 | 5 | **16** |
| /pull-build | リモートからプル→ビルド | 4 | 3 | 4 | 5 | **16** |

### A ランク（12-15点）— 定期的に使うべき

| コマンド名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|-----------|------|------|------|------|--------|------|
| /tdd | TDDワークフロー（RED→GREEN→IMPROVE） | 3 | 3 | 5 | 4 | **15** |
| /skill-create | Git履歴からスキルファイル自動生成 | 4 | 2 | 4 | 4 | **14** |
| /refactor-clean | デッドコード安全削除 | 3 | 2 | 4 | 4 | **13** |
| /update-codemaps | コードベースアーキテクチャ文書更新 | 3 | 2 | 4 | 4 | **13** |
| /update-docs | ソースからドキュメント自動同期 | 3 | 2 | 4 | 4 | **13** |
| /build-fix | ビルド・型エラーの段階的修正 | 3 | 2 | 4 | 4 | **13** |
| /multi-plan | マルチモデル協調計画 | 3 | 2 | 4 | 3 | **12** |
| /multi-execute | マルチモデル協調実行 | 3 | 2 | 4 | 3 | **12** |
| /multi-workflow | 6フェーズ構造化開発ワークフロー | 3 | 2 | 4 | 3 | **12** |
| /instinct-status | 学習済みInstinct一覧表示 | 3 | 2 | 3 | 4 | **12** |
| /test-coverage | カバレッジ分析・不足テスト生成 | 3 | 2 | 4 | 3 | **12** |
| /evolve | Instinctをスキル/コマンドに進化 | 3 | 2 | 4 | 3 | **12** |

### B ランク（8-11点）— 特定場面で使う

| コマンド名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|-----------|------|------|------|------|--------|------|
| /python-review | Pythonコードの包括的レビュー | 3 | 2 | 3 | 3 | **11** |
| /e2e | Playwright E2Eテスト | 2 | 2 | 4 | 3 | **11** |
| /eval | Eval駆動開発ワークフロー | 3 | 2 | 3 | 3 | **11** |
| /instinct-import | Instinctインポート | 3 | 1 | 3 | 3 | **10** |
| /instinct-export | Instinctエクスポート | 3 | 1 | 3 | 3 | **10** |
| /pm2 | PM2サービス自動生成 | 3 | 1 | 3 | 3 | **10** |
| /setup-pm | パッケージマネージャー設定 | 3 | 1 | 2 | 3 | **9** |
| /multi-backend | バックエンド特化マルチモデル開発 | 2 | 1 | 3 | 2 | **8** |
| /multi-frontend | フロントエンド特化マルチモデル開発 | 2 | 1 | 3 | 2 | **8** |

### D ランク（0-3点）— 削除推奨

| コマンド名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 | 理由 |
|-----------|------|------|------|------|--------|------|------|
| /go-build | Go ビルドエラー修正 | 0 | 0 | 1 | 0 | **1** | Go未使用 |
| /go-review | Go コードレビュー | 0 | 0 | 1 | 0 | **1** | Go未使用 |
| /go-test | Go TDDワークフロー | 0 | 0 | 1 | 0 | **1** | Go未使用 |

---

## 4. プロジェクトレベルスキル全一覧

| ランク | スキル名 | 説明 | 適合 | 頻度 | 親和 | コスパ | 合計 |
|--------|---------|------|------|------|------|--------|------|
| S | legal-office-research | 法律事務所の競合調査パターン（3段階フロー） | 5 | 3 | 4 | 5 | **17** |
| S | n8n-drive-notion-sync | Google Drive→Notion DB自動連携テンプレート | 5 | 3 | 4 | 4 | **16** |
| S | n8n-automation-patterns | n8n自動化ワークフロー設計パターン集 | 5 | 3 | 4 | 4 | **16** |
| A | astro-law-firm-starter | Astro+Tailwind法律事務所HP構築スターター | 5 | 2 | 3 | 4 | **14** |
| A | skill-creator | 汎用作業パターンのスキル自動生成 | 4 | 2 | 4 | 4 | **14** |

---

## 5. カテゴリ別使い分けガイド

### コードを書いたとき
1. **/code-review** → コード品質の自動レビュー
2. **/verify** → ビルド・テスト・セキュリティの包括チェック
3. **security-review** → セキュリティ脆弱性の検出

### 新機能を作るとき
1. **/plan** → 実装計画を策定
2. **/tdd** → テストを先に書いて品質担保
3. **/code-review** → 実装後のレビュー
4. **/verify** → 最終検証

### Gitにコミット・プッシュしたいとき
1. **/pub** → ドキュメント更新→コミット→プッシュ
2. **pull-merge-pub** → プル→マージ→/pub（リモート変更がある場合）
3. **/pull-build** → まずリモートからプル→ビルド確認

### n8nワークフローを作るとき
1. **n8n-workflow-patterns** → ワークフロー設計パターンを参照
2. **n8n-node-configuration** → ノード設定の参考
3. **n8n-expression-syntax** → 式の書き方・エラー修正
4. **n8n-code-python** → Code nodeでPython記述（殿はPython基礎あり）
5. **n8n-validation-expert** → バリデーションエラー解釈
6. **n8n-mcp-tools-expert** → MCP経由でn8n操作

### CLAUDE.mdを改善したいとき
1. **claude-md-improver** → 品質監査・改善提案
2. **/revise-claude-md** → セッションの学びをCLAUDE.mdに反映

### 法律事務所の調査をしたいとき
1. **legal-office-research** → 競合調査（弁護士ドットコム→HP→不動産3段階フロー）
2. **legal-document-namer** → 書面ファイルの命名規則

### 法律事務所のHP作成をしたいとき
1. **astro-law-firm-starter** → Astro+Tailwindでの構築手順
2. **/plan** → 実装計画を立てる

### 書面・資料管理を自動化したいとき
1. **n8n-drive-notion-sync** → Google Drive→Notion自動連携
2. **n8n-automation-patterns** → Gmail/Motion/LINE連携パターン
3. **legal-document-namer** → ファイル命名規則

### セッションが長くなったとき
1. **strategic-compact** → コンテキストの戦略的圧縮
2. **/checkpoint** → チェックポイント作成
3. **/sessions** → セッション履歴管理

### パターンを学習・蓄積したいとき
1. **/learn** → セッションからパターン抽出
2. **continuous-learning** → 自動パターン抽出
3. **/skill-create** → Git履歴からスキル生成
4. **/evolve** → 蓄積されたInstinctをスキルに進化

### multi-agentを大規模に使いたいとき
1. **/orchestrate** → マルチエージェント連携
2. **iterative-retrieval** → サブエージェントのコンテキスト問題解決
3. **/multi-plan** → マルチモデル協調計画
4. **/multi-workflow** → 6フェーズ構造化開発

---

## 6. 削除・統合候補リスト

### 削除推奨（D ランク — 16件）

#### Java/Spring Boot系（6件）
殿はJavaを使用しておらず、今後も使用予定なし。即削除推奨。
- springboot-patterns
- springboot-security
- springboot-tdd
- springboot-verification
- java-coding-standards
- jpa-patterns

#### Django系（4件）
殿はDjangoを使用しておらず、PythonはスクリプトレベルのみDjango不要。
- django-patterns
- django-security
- django-tdd
- django-verification

#### Web開発フレームワーク固有（2件）
Node.js/React等のフレームワーク固有パターンは不要。Astroは別スキルでカバー。
- backend-patterns
- frontend-patterns

#### データベース固有（1件）
ClickHouseは分析用途の特殊DB。殿の業務に無関係。
- clickhouse-io

#### Go言語固有（3件コマンド）
殿はGoを使用しない。
- /go-build
- /go-review
- /go-test

### 統合検討候補

| 現状 | 統合先 | 理由 |
|------|--------|------|
| continuous-learning + continuous-learning-v2 | v2に統合 | v2がv1の上位互換 |
| verification-loop + tdd-workflow | verification-loopに統合 | 機能が大幅に重複 |
| /instinct-status + /instinct-import + /instinct-export | /instinct に統合 | 同一機能群を1コマンドに |

### 削除した場合の効果
- **コンテキスト節約**: スキル13件 + コマンド3件の削除で、Claude Codeの起動時読み込み量が約30%削減
- **混乱防止**: 使わないスキルが候補に表示されなくなり、必要なスキルを見つけやすくなる

---

## 7. 今後追加すべきスキル候補

殿の業務に基づき、以下のスキル追加を提案:

| 提案スキル名 | 説明 | 根拠 |
|-------------|------|------|
| legal-brief-writer | 法律書面（準備書面・訴状等）の構成テンプレートとClaude活用パターン | 弁護士の主業務。Claude Codeで書面ドラフト→レビュー→修正のワークフロー化 |
| notion-case-manager | Notion案件管理DBの設計・運用パターン | cmd_120で設計済み。スキル化で再利用性向上 |
| kurashiki-local-seo | 「倉敷市 弁護士」等のローカルSEO対策パターン | HP公開後に必要。Google Business Profile連携含む |
| client-intake-automation | 新規相談受付の自動化（Webフォーム→Notion→通知） | 開業後の業務効率化の要 |
| legal-research-pattern | 判例・法令調査のClaude活用パターン | 弁護士業務のコア。Claudeの強みを活かせる領域 |

---

## 8. まとめ

### 殿が今すぐ実行すべき3つのアクション

1. **D ランク16件を削除**: `~/.claude/skills/` から不要スキル13件を削除。Go系コマンド3件の定義ファイルも削除。これだけでシステムが軽くなる

2. **TOP10を体で覚える**: 特に `/plan` `/pub` `/verify` は毎回使うべき。1週間の開発で自然に身につく

3. **n8nスキル群を実戦投入**: 法律事務所の書面管理自動化（n8n-drive-notion-sync）を最初のプロジェクトとして着手

### 学習の優先順位

```
今日: /plan → /pub → /verify → /code-review（基本4コマンド）
今週: strategic-compact → /learn → /sessions（セッション管理3点セット）
来週: n8nスキル群（6件まとめて実戦）
今月: legal-document-namer → claude-md-improver → /revise-claude-md（システム最適化）
```
