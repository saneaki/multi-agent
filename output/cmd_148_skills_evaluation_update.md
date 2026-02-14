# ECC スキル・コマンド・エージェント 有用度評価レポート（更新版）

**更新日**: 2026-02-14
**前回レポート**: cmd_132（2026-02-13）
**作成者**: ashigaru5（統合担当）
**評価担当**: ashigaru1〜4（予備評価） → ashigaru5（統合・調整）

---

## 差分サマリー（cmd_132 → cmd_148）

| 項目 | cmd_132 | cmd_148 | 差分 |
|------|---------|---------|------|
| 評価対象数 | 80件 | 105件 | +25件（Agents 13件新設＋新規Skills 10件＋Project Skills 2件） |
| カテゴリ数 | 3（Skills/Commands/Project） | 4（Skills/Commands/Agents/Project） | Agents追加 |
| 評価方法 | 4軸スコア（適合/頻度/親和/コスパ） | 実使用頻度ベースの直接ランク付け | より実践的 |
| S評価数 | 20件 | 11件 | -9（厳格化） |
| D評価数 | 17件 | 29件 | +12（削除候補増） |

**評価方針の変更**: cmd_132は「潜在的有用性」を重視し高ランクが多かったが、cmd_148は「実際の使用実績・即時必要性」を基準とし、未使用アイテムを厳しく評価した。

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

## ランク別サマリー

| ランク | Skills | Project | Commands | Agents | 合計 |
|--------|--------|---------|----------|--------|------|
| **S** | 0 | 4 | 3 | 4 | **11** |
| **A** | 11 | 2 | 4 | 1 | **18** |
| **B** | 13 | 0 | 7 | 2 | **22** |
| **C** | 12 | 0 | 11 | 2 | **25** |
| **D** | 16 | 0 | 9 | 4 | **29** |
| **合計** | **52** | **6** | **34** | **13** | **105** |

---

## ランク別一覧表

### S ランク（不可欠）— 11件

| 名前 | カテゴリ | 行数 | 根拠 | 新規/変更 |
|------|----------|------|------|-----------|
| astro-law-firm-starter | Project | 968 | 殿のAstro+TailwindプロジェクトのHP開発中核 | — (A→S昇格) |
| legal-office-research | Project | 671 | cmd_137で大幅拡張。法律事務所業務の中核リサーチスキル | 変更(245→671行) |
| n8n-automation-patterns | Project | 707 | n8n自動化設計指針。実運用ワークフロー基盤 | — |
| n8n-drive-notion-sync | Project | 515 | Google Drive→Notion自動連携。書面管理の核 | — |
| code-review | Command | 40 | 直近使用実績あり。セキュリティチェック必須 | — |
| plan | Command | 113 | 全開発・調査の起点。最頻使用コマンド | — |
| pub | Command | 85 | ドキュメント更新→コミット→プッシュの一括実行 | — |
| code-reviewer | Agent | 224 | コードレビュー必須。直近使用実績あり | 新規(評価) |
| planner | Agent | 212 | /plan経由で頻繁使用。実装計画策定必須 | 新規(評価) |
| python-reviewer | Agent | 98 | Python開発中心。直近使用実績あり | 新規(評価) |
| security-reviewer | Agent | 108 | 法律事務所業務でセキュリティ最重要 | 新規(評価) |

### A ランク（高頻度使用）— 18件

| 名前 | カテゴリ | 行数 | 根拠 | 新規/変更 |
|------|----------|------|------|-----------|
| continuous-learning-v2 | Skill | 292 | マルチエージェントでパターン学習活用 | — |
| legal-document-namer | Skill | 353 | hananoenリネーマー設計基盤。法律文書管理 | — (S→A) |
| n8n-code-javascript | Skill | 699 | n8n Codeノード頻繁使用。$json構文必須 | — |
| n8n-expression-syntax | Skill | 516 | n8n式構文必須。webhook body構造等の頻出エラー解決 | — (S→A) |
| n8n-node-configuration | Skill | 785 | n8nノード設定は頻出タスク | — |
| n8n-workflow-patterns | Skill | 411 | n8nワークフロー設計基盤。日常的に使用 | — |
| python-patterns | Skill | 749 | hananoenプロジェクトで頻繁参照 | — (B→A昇格) |
| python-testing | Skill | 815 | hananoenテスト整備に必須 | — (B→A昇格) |
| tdd-workflow | Skill | 409 | TDD推進の中核。Python/TS両方に適用 | — |
| tkinter-help-system | Skill | 490 | hananoenプロジェクトで直接使用 | — (C→A昇格) |
| verification-loop | Skill | 125 | PR前品質ゲート。汎用性高い | — |
| google-chat-bulk-sender | Project | 695 | マルチエージェント通知機能。実績あり | 新規 |
| skill-creator | Project | 133 | スキル自動生成メタスキル | 新規 |
| build-fix | Command | 62 | Python開発でのビルドエラー修正に有効 | — |
| python-review | Command | 297 | Python開発中心。直近使用実績あり | — (B→A昇格) |
| skill-create | Command | 174 | Git履歴からパターン抽出。直近使用実績 | — |
| tdd | Command | 326 | TDD品質確保に必須 | — |
| tdd-guide | Agent | 80 | TDD専門家。品質確保必須 | 新規(評価) |

### B ランク（時々使用）— 22件

| 名前 | カテゴリ | 行数 | 根拠 | 新規/変更 |
|------|----------|------|------|-----------|
| claude-md-improver | Skill | 179 | CLAUDE.md監査。日常的ではないが重要 | — (S→B) |
| coding-standards | Skill | 529 | Astro+Tailwindで関連。時々使用 | — |
| e2e-testing | Skill | 325 | 将来のHP開発でE2E必要 | 新規 |
| iterative-retrieval | Skill | 210 | マルチエージェントコンテキスト管理 | — (S→B) |
| n8n-api-deploy | Skill | 213 | API経由デプロイ。将来有用 | — |
| n8n-google-sheets-rate-limit | Skill | 173 | Sheets連携時のレート制限対策 | — |
| n8n-pipeline-cut-guard | Skill | 163 | 0件出力時のパイプライン停止防止 | — |
| n8n-validation-expert | Skill | 689 | n8n検証エラー対応。頻度中程度 | — (A→B) |
| pull-merge-pub | Skill | 188 | Git操作は家老が担当。殿は直接使用少 | — (S→B) |
| pytest-migration | Skill | 808 | 将来のunittest→pytest移行時に必須 | — (C→B昇格) |
| security-review | Skill | 494 | セキュリティチェック。部分的にPython適用可 | — (S→B) |
| security-scan | Skill | 164 | 設定セキュリティ衛生管理 | 新規 |
| strategic-compact | Skill | 102 | 長時間セッションで有用だが頻度低 | — (S→B) |
| e2e | Command | 363 | Astro HP開発で将来有用 | — |
| learn | Command | 70 | ナレッジ蓄積に有用。意識的に使えば効果的 | — (S→B) |
| orchestrate | Command | 172 | 複雑タスクで有用。将来活用可能 | — (S→B) |
| pull-build | Command | 40 | PyInstallerプロジェクトで有用 | — (S→B) |
| revise-claude-md | Command | 54 | ドキュメント保守に有用 | — (S→B) |
| test-coverage | Command | 69 | 品質保証に有用。定期実行推奨 | — (A→B) |
| verify | Command | 59 | PR前品質確認。定期実行推奨 | — (S→B) |
| architect | Agent | 211 | アーキテクチャ判断時に有用 | 新規(評価) |
| e2e-runner | Agent | 107 | Astro HP開発で将来有用 | 新規(評価) |

### C ランク（まれに使用）— 25件

| 名前 | カテゴリ | 行数 | 根拠 | 新規/変更 |
|------|----------|------|------|-----------|
| api-design | Skill | 522 | 将来HP向けAPI開発で必要になる可能性 | 新規 |
| backend-patterns | Skill | 597 | フロントエンド中心で限定的 | — |
| configure-ecc | Skill | 298 | 初回セットアップ専用 | — (B→C) |
| continuous-learning | Skill | 118 | v2が上位互換。冗長 | — (A→C) |
| deployment-patterns | Skill | 426 | 将来HP公開時に有用だが未使用 | 新規 |
| docker-patterns | Skill | 363 | 将来デプロイで関連する可能性 | 新規 |
| eval-harness | Skill | 235 | eval-driven開発を未実践 | — (A→C) |
| frontend-patterns | Skill | 641 | Reactベースで現在未使用 | — |
| n8n-code-python | Skill | 748 | Python得意でもn8nではJS推奨 | — (A→C) |
| n8n-mcp-tools-expert | Skill | 642 | MCP経由構築は未実践 | — (A→C) |
| postgres-patterns | Skill | 146 | PostgreSQL未使用 | — |
| project-guidelines-example | Skill | 348 | テンプレート例示のみ | — |
| checkpoint | Command | 74 | 使用実績なし。git操作で代替可 | — (S→C) |
| eval | Command | 120 | 通常TDDで十分 | — (B→C) |
| multi-backend | Command | 158 | Codex/Gemini連携未使用 | — (B→C) |
| multi-execute | Command | 310 | 複雑設定が必要。現状不要 | — (A→C) |
| multi-frontend | Command | 158 | マルチモデル連携不要 | — (B→C) |
| multi-plan | Command | 261 | 通常/planで十分 | — (A→C) |
| multi-workflow | Command | 183 | codeagent-wrapperインフラ必要 | — (A→C) |
| refactor-clean | Command | 80 | プロジェクト成熟時に有用 | — (A→C) |
| sessions | Command | 305 | 通常不要 | — (S→C) |
| update-codemaps | Command | 72 | プロジェクト規模小で不要 | — (A→C) |
| update-docs | Command | 84 | 現状不要 | — (A→C) |
| doc-updater | Agent | 153 | 大規模プロジェクトで有用 | 新規(評価) |
| refactor-cleaner | Agent | 85 | プロジェクト成熟時に有用 | 新規(評価) |

### D ランク（削除候補）— 29件

| 名前 | カテゴリ | 行数 | 削除理由 | 新規/変更 |
|------|----------|------|----------|-----------|
| clickhouse-io | Skill | 438 | ClickHouse未使用。全く無関係 | — |
| cpp-testing | Skill | 322 | C++未使用 | 新規 |
| database-migrations | Skill | 334 | DB中心開発なし | 新規 |
| django-patterns | Skill | 733 | Django未使用 | — |
| django-security | Skill | 592 | Django未使用 | — |
| django-tdd | Skill | 728 | Django未使用 | — |
| django-verification | Skill | 468 | Django未使用 | — |
| golang-patterns | Skill | 673 | Go未使用 | — (C→D) |
| golang-testing | Skill | 719 | Go未使用 | — (C→D) |
| java-coding-standards | Skill | 146 | Java未使用 | — |
| jpa-patterns | Skill | 150 | Java/JPA未使用 | — |
| nutrient-document-processing | Skill | 165 | APIキー未取得。PyPDF2使用中 | 新規 |
| springboot-patterns | Skill | 313 | Spring Boot未使用 | — |
| springboot-security | Skill | 271 | Spring Boot未使用 | — |
| springboot-tdd | Skill | 157 | Spring Boot未使用 | — |
| springboot-verification | Skill | 230 | Spring Boot未使用 | — |
| evolve | Command | 193 | continuous-learning未活用 | — (A→D) |
| go-build | Command | 183 | Go未使用 | — |
| go-review | Command | 148 | Go未使用 | — |
| go-test | Command | 268 | Go未使用 | — |
| instinct-export | Command | 91 | continuous-learning未活用 | — (B→D) |
| instinct-import | Command | 142 | continuous-learning未活用 | — (B→D) |
| instinct-status | Command | 86 | continuous-learning未活用 | — (A→D) |
| pm2 | Command | 272 | Node.js向け。環境不一致 | — (B→D) |
| setup-pm | Command | 80 | Python中心でNode.js PM不要 | — (B→D) |
| build-error-resolver | Agent | 114 | TypeScriptプロジェクト未使用 | 新規(評価) |
| database-reviewer | Agent | 91 | DB使用なし | 新規(評価) |
| go-build-resolver | Agent | 94 | Go未使用 | 新規(評価) |
| go-reviewer | Agent | 76 | Go未使用 | 新規(評価) |

---

## 新規追加分の個別評価（9件）

### 1. api-design（Skill, 522行, Cランク）

- **追加理由**: REST API設計パターン集（リソース命名、ステータスコード、ページネーション等）
- **推奨ランク**: C
- **根拠**: 殿は現在バックエンドAPI開発を積極的に行っていない。将来Astro+TailwindのHP向けに必要になる可能性はあるが、現時点では限定的
- **殿の業務との関連**: HP公開後のフォーム処理やAPI連携時に有用になる可能性

### 2. cpp-testing（Skill, 322行, Dランク）

- **追加理由**: C++テストスキル（GoogleTest/CTest、TDDワークフロー）
- **推奨ランク**: D（削除候補）
- **根拠**: 殿はC++を使用しておらず、使用予定もない
- **殿の業務との関連**: なし

### 3. database-migrations（Skill, 334行, Dランク）

- **追加理由**: DBマイグレーション（PostgreSQL/MySQL、Prisma/Django等）のベストプラクティス
- **推奨ランク**: D（削除候補）
- **根拠**: 殿はDB中心の開発をしておらず、Notion DBで管理。RDBマイグレーション不要
- **殿の業務との関連**: なし

### 4. deployment-patterns（Skill, 426行, Cランク）

- **追加理由**: デプロイワークフロー、CI/CD、Docker、ヘルスチェック等
- **推奨ランク**: C
- **根拠**: 将来HP公開時に必要になる可能性があるが、現時点では未使用
- **殿の業務との関連**: Astro HP公開時に参照価値あり

### 5. docker-patterns（Skill, 363行, Cランク）

- **追加理由**: Docker & Docker Composeパターン（ローカル開発、セキュリティ、ネットワーク）
- **推奨ランク**: C
- **根拠**: マルチエージェント開発や将来のデプロイで関連する可能性があるが、現時点では限定的
- **殿の業務との関連**: VPS環境でのコンテナ化検討時に有用

### 6. e2e-testing（Skill, 325行, Bランク）

- **追加理由**: Playwright E2Eテスト（Page Object Model、CI統合、flaky対策）
- **推奨ランク**: B
- **根拠**: マルチエージェントシステムのテストや将来のHP開発でE2Eが必要になる可能性
- **殿の業務との関連**: Astro HP公開後のユーザーフロー検証に有用

### 7. nutrient-document-processing（Skill, 165行, Dランク）

- **追加理由**: Nutrient DWS APIでPDF/DOCX等の変換・OCR・データ抽出
- **推奨ランク**: D（削除候補）
- **根拠**: PDF操作は有用だが当API未使用。pdfmergedプロジェクトではPyPDF2を利用中。APIキー未取得
- **殿の業務との関連**: PDF処理需要はあるが別ツールで代替済み

### 8. security-scan（Skill, 164行, Bランク）

- **追加理由**: AgentShieldでClaude Code設定をスキャン（CLAUDE.md、settings.json、MCP、hooks）
- **推奨ランク**: B
- **根拠**: 新規設定後のセキュリティ衛生管理に有用。日常的ではないが定期チェックに使える
- **殿の業務との関連**: マルチエージェントシステムの設定変更後にセキュリティ確認

### 9. skill-creator（Project Skill, 133行, Aランク）

- **追加理由**: 汎用的パターンを発見した際に、再利用可能なClaude Codeスキルを自動生成
- **推奨ランク**: A
- **根拠**: マルチエージェントシステムでのスキル生成に使用。メタスキルとして有用。実績あり
- **殿の業務との関連**: 業務パターンの蓄積・標準化に直結

---

## 再評価分

### legal-office-research（245→671行、Sランク維持）

- **拡張内容**: cmd_137で競合調査・制度調査・裁判例調査の3パターンに統合拡張
- **再評価結果**: S（不可欠）を維持。拡張により実用性が大幅に向上
- **実績**: cmd_133（未払賃金立替払制度調査）、cmd_134（書面なし労働者性認定の裁判例調査）で実際に使用
- **特記**: 弁護士品質レポートの生成能力が向上。3パターン統合で法律リサーチの網羅性が確保

### google-chat-bulk-sender（新規プロジェクトスキル、695行、Aランク）

- **評価理由**: cmd_142で作成された大容量テキスト分割送信パターン
- **ランク**: A（高頻度使用）
- **根拠**: マルチエージェントシステムの通知機能として実運用中。4096バイト制限を考慮した自動分割ロジックは汎用性高い
- **実績**: cmd_138e（17パート送信）、その後の複数タスクで使用実績あり

---

## 削除候補リスト（D ランク — 29件）

### Skills（16件） — 合計行数: 6,240行

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

### Commands（9件） — 合計行数: 1,463行

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

### Agents（4件） — 合計行数: 375行

| 名前 | 行数 | 削除理由 |
|------|------|----------|
| build-error-resolver | 114 | TypeScriptプロジェクト未使用 |
| database-reviewer | 91 | DB使用なし |
| go-build-resolver | 94 | Go未使用 |
| go-reviewer | 76 | Go未使用 |

### コンテキスト削減効果

| カテゴリ | 削除件数 | 削除行数 |
|----------|----------|----------|
| Skills | 16件 | 6,240行 |
| Commands | 9件 | 1,463行 |
| Agents | 4件 | 375行 |
| **合計** | **29件** | **8,078行** |

全29件削除により、Claude Codeの起動時読み込み量が約8,000行（推定25-30%）削減される。

---

## cmd_132からの変動サマリー

### 昇格（6件）

| 名前 | カテゴリ | 旧ランク | 新ランク | 昇格理由 |
|------|----------|----------|----------|----------|
| astro-law-firm-starter | Project | A | **S** | HP開発中核として実用中 |
| python-patterns | Skill | B | **A** | hananoenプロジェクトで頻繁参照 |
| python-testing | Skill | B | **A** | テスト整備に必須 |
| tkinter-help-system | Skill | C | **A** | hananoenプロジェクトで直接使用 |
| pytest-migration | Skill | C | **B** | 将来のunittest→pytest移行に必須 |
| python-review | Command | B | **A** | Python開発中心。直近使用実績 |

### 降格（主要なもの — 計28件）

| 名前 | カテゴリ | 旧ランク | 新ランク | 降格理由 |
|------|----------|----------|----------|----------|
| strategic-compact | Skill | S | **B** | 長時間セッションで有用だが頻度低い |
| claude-md-improver | Skill | S | **B** | 日常的に監査するわけではない |
| pull-merge-pub | Skill | S | **B** | Git操作は家老が担当 |
| security-review | Skill | S | **B** | TS/React中心でPythonは部分的 |
| legal-document-namer | Skill | S | **A** | 高頻度だがS→A微調整 |
| n8n-expression-syntax | Skill | S | **A** | 同上 |
| iterative-retrieval | Skill | S | **B** | まだ実装していない |
| verify | Command | S | **B** | 未使用だが有用 |
| sessions | Command | S | **C** | 通常不要 |
| checkpoint | Command | S | **C** | git操作で代替可能 |
| instinct-status | Command | A | **D** | continuous-learning未活用 |
| evolve | Command | A | **D** | continuous-learning未活用 |
| pm2 | Command | B | **D** | Node.js向け |
| setup-pm | Command | B | **D** | Python中心 |
| instinct-import | Command | B | **D** | continuous-learning未活用 |
| instinct-export | Command | B | **D** | continuous-learning未活用 |

### 新規追加（12件）

| 名前 | カテゴリ | ランク | 種別 |
|------|----------|--------|------|
| api-design | Skill | C | ECC新規追加 |
| cpp-testing | Skill | D | ECC新規追加 |
| database-migrations | Skill | D | ECC新規追加 |
| deployment-patterns | Skill | C | ECC新規追加 |
| docker-patterns | Skill | C | ECC新規追加 |
| e2e-testing | Skill | B | ECC新規追加 |
| nutrient-document-processing | Skill | D | ECC新規追加 |
| security-scan | Skill | B | ECC新規追加 |
| google-chat-bulk-sender | Project | A | プロジェクトスキル新規 |
| skill-creator | Project | A | プロジェクトスキル新規 |

### 新規評価対象（Agents 13件）

cmd_132では未評価だったエージェント13件を新たに評価対象に追加:
- S: code-reviewer, planner, python-reviewer, security-reviewer
- A: tdd-guide
- B: architect, e2e-runner
- C: doc-updater, refactor-cleaner
- D: build-error-resolver, database-reviewer, go-build-resolver, go-reviewer

---

## 評価の一貫性チェック（統合担当の調整結果）

### 調整なし（4報告間で一貫）

全4名の評価者間で大きな矛盾はなく、以下の傾向が一致:
1. **Python系スキルの昇格**: hananoenプロジェクト進行に伴い、Python関連の重要度が上昇
2. **未使用技術の厳格化**: Java/Spring Boot、Django、Go、C++関連は一貫してD評価
3. **n8n系スキルの安定**: n8n関連は引き続き高評価を維持（A〜B）
4. **法律事務所系の不変**: legal-office-research（S）、legal-document-namer（A）は安定

### 特記事項

- cmd_132と比較して全体的に「実使用ベース」の評価に移行したため、「潜在的に有用」だったS/Aランクの多くがB/Cに降格。これは評価基準の厳格化であり、品質の低下ではない
- Agents 13件の追加評価により、どのエージェントが実際に稼働しているかが明確化

---

*レポート終*
