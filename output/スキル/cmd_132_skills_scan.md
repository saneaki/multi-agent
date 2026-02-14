# ユーザーレベルスキル一覧

調査日時: 2026-02-13
調査対象: ~/.claude/skills/
総スキル数: 42件（learned除く）

## サマリー表

| # | スキル名 | 説明（抜粋） | ツール | 対象 | カテゴリ |
|---|---------|-------------|--------|------|---------|
| 1 | backend-patterns | Backend architecture patterns, API design, database optimization... | - | Node.js/Express/Next.js | 開発 |
| 2 | claude-md-improver | Audit and improve CLAUDE.md files... | Read, Glob, Grep, Bash, Edit | 汎用 | ドキュメント |
| 3 | clickhouse-io | ClickHouse database patterns, query optimization, analytics... | - | ClickHouse | データベース |
| 4 | coding-standards | Universal coding standards, best practices... | - | TypeScript/JavaScript | 開発 |
| 5 | configure-ecc | Interactive installer for Everything Claude Code... | - | 汎用 | ワークフロー |
| 6 | continuous-learning | Automatically extract reusable patterns from sessions... | - | 汎用 | ワークフロー |
| 7 | continuous-learning-v2 | Instinct-based learning system with confidence scoring... | - | 汎用 | ワークフロー |
| 8 | django-patterns | Django architecture patterns, REST API design with DRF... | - | Django | 開発 |
| 9 | django-security | Django security best practices, authentication, authorization... | - | Django | セキュリティ |
| 10 | django-tdd | Django testing strategies with pytest-django... | - | Django | テスト |
| 11 | django-verification | Verification loop for Django projects... | - | Django | ワークフロー |
| 12 | eval-harness | Formal evaluation framework for Claude Code sessions... | Read, Write, Edit, Bash, Grep, Glob | 汎用 | ワークフロー |
| 13 | frontend-patterns | Frontend development patterns for React, Next.js... | - | React/Next.js | 開発 |
| 14 | golang-patterns | Idiomatic Go patterns, best practices... | - | Go | 開発 |
| 15 | golang-testing | Go testing patterns including table-driven tests... | - | Go | テスト |
| 16 | iterative-retrieval | Pattern for progressively refining context retrieval... | - | 汎用 | ワークフロー |
| 17 | java-coding-standards | Java coding standards for Spring Boot services... | - | Java/Spring Boot | 開発 |
| 18 | jpa-patterns | JPA/Hibernate patterns for entity design, relationships... | - | Java/JPA | データベース |
| 19 | legal-document-namer | 法律事務所向けファイル命名パターン... | - | ドメイン固有 | ドキュメント |
| 20 | n8n-code-javascript | Write JavaScript code in n8n Code nodes... | - | n8n | 開発 |
| 21 | n8n-code-python | Write Python code in n8n Code nodes... | - | n8n | 開発 |
| 22 | n8n-expression-syntax | Validate n8n expression syntax and fix common errors... | - | n8n | 開発 |
| 23 | n8n-mcp-tools-expert | Expert guide for using n8n-mcp MCP tools... | - | n8n | ワークフロー |
| 24 | n8n-node-configuration | Operation-aware node configuration guidance... | - | n8n | 開発 |
| 25 | n8n-validation-expert | Interpret validation errors and guide fixing them... | - | n8n | ワークフロー |
| 26 | n8n-workflow-patterns | Proven workflow architectural patterns from real n8n workflows... | - | n8n | ワークフロー |
| 27 | postgres-patterns | PostgreSQL database patterns for query optimization... | - | PostgreSQL | データベース |
| 28 | project-guidelines-example | Example of project-specific skill (Zenith project)... | - | 例示 | 開発 |
| 29 | pull-merge-pub | Workflow for pull, conflict check, merge, and /pub... | - | 汎用 | ワークフロー |
| 30 | pytest-migration | Patterns for unittest-to-pytest conversion... | - | Python | テスト |
| 31 | python-patterns | Pythonic idioms, PEP 8 standards, type hints... | - | Python | 開発 |
| 32 | python-testing | Python testing strategies using pytest, TDD methodology... | - | Python | テスト |
| 33 | security-review | Comprehensive security checklist and patterns... | - | 汎用 | セキュリティ |
| 34 | springboot-patterns | Spring Boot architecture patterns, REST API design... | - | Java/Spring Boot | 開発 |
| 35 | springboot-security | Spring Security best practices for authn/authz... | - | Java/Spring Boot | セキュリティ |
| 36 | springboot-tdd | Test-driven development for Spring Boot... | - | Java/Spring Boot | テスト |
| 37 | springboot-verification | Verification loop for Spring Boot projects... | - | Java/Spring Boot | ワークフロー |
| 38 | strategic-compact | Manual context compaction at logical intervals... | - | 汎用 | ワークフロー |
| 39 | tdd-workflow | Enforces test-driven development with 80%+ coverage... | - | 汎用 | ワークフロー |
| 40 | tkinter-help-system | Patterns for building ToolTip, collapsible help panels... | - | Python/tkinter | 開発 |
| 41 | verification-loop | Comprehensive verification system for Claude Code sessions... | - | 汎用 | ワークフロー |
| 42 | learned | (自動生成スキル格納用ディレクトリ — 現在空) | - | 汎用 | - |

---

## カテゴリ別集計

- **開発**: 18件（backend-patterns, coding-standards, django-patterns, frontend-patterns, golang-patterns, java-coding-standards, n8n-code-javascript, n8n-code-python, n8n-expression-syntax, n8n-node-configuration, project-guidelines-example, python-patterns, springboot-patterns, tkinter-help-system, legal-document-namer除外時）
- **テスト**: 6件（django-tdd, golang-testing, pytest-migration, python-testing, springboot-tdd, tdd-workflow）
- **セキュリティ**: 3件（django-security, security-review, springboot-security）
- **ワークフロー**: 11件（configure-ecc, continuous-learning, continuous-learning-v2, django-verification, eval-harness, iterative-retrieval, n8n-mcp-tools-expert, n8n-validation-expert, n8n-workflow-patterns, pull-merge-pub, springboot-verification, strategic-compact, verification-loop）
- **データベース**: 3件（clickhouse-io, jpa-patterns, postgres-patterns）
- **ドキュメント**: 2件（claude-md-improver, legal-document-namer）
- **その他**: 1件（project-guidelines-example）

---

## 言語/フレームワーク別集計

- **汎用**: 11件
- **TypeScript/JavaScript**: 2件（coding-standards, backend-patterns）
- **React/Next.js**: 2件（frontend-patterns, backend-patternsと重複）
- **Python**: 4件（python-patterns, python-testing, pytest-migration, tkinter-help-system）
- **Django**: 4件（django-patterns, django-security, django-tdd, django-verification）
- **Go**: 2件（golang-patterns, golang-testing）
- **Java/Spring Boot**: 5件（java-coding-standards, jpa-patterns, springboot-patterns, springboot-security, springboot-tdd, springboot-verification）
- **n8n**: 6件（n8n-code-javascript, n8n-code-python, n8n-expression-syntax, n8n-mcp-tools-expert, n8n-node-configuration, n8n-validation-expert, n8n-workflow-patterns）
- **データベース**: 3件（clickhouse-io, postgres-patterns, jpa-patterns）

---

## 詳細（スキルごと）

### 1. backend-patterns
- **説明**: Backend architecture patterns, API design, database optimization, and server-side best practices for Node.js, Express, and Next.js API routes.
- **トリガー**: Backend development for Node.js/Express/Next.js
- **ツール**: なし（パターン集）
- **対象**: Node.js, Express, Next.js API routes
- **カテゴリ**: 開発

### 2. claude-md-improver
- **説明**: Audit and improve CLAUDE.md files in repositories. Use when user asks to check, audit, update, improve, or fix CLAUDE.md files.
- **トリガー**: CLAUDE.md maintenance, project memory optimization
- **ツール**: Read, Glob, Grep, Bash, Edit
- **対象**: 汎用
- **カテゴリ**: ドキュメント

### 3. clickhouse-io
- **説明**: ClickHouse database patterns, query optimization, analytics, and data engineering best practices for high-performance analytical workloads.
- **トリガー**: ClickHouse database work
- **ツール**: なし（パターン集）
- **対象**: ClickHouse
- **カテゴリ**: データベース

### 4. coding-standards
- **説明**: Universal coding standards, best practices, and patterns for TypeScript, JavaScript, React, and Node.js development.
- **トリガー**: General code quality review
- **ツール**: なし（ガイドライン）
- **対象**: TypeScript, JavaScript, React, Node.js
- **カテゴリ**: 開発

### 5. configure-ecc
- **説明**: Interactive installer for Everything Claude Code — guides users through selecting and installing skills and rules.
- **トリガー**: "configure ecc", "install ecc", "setup everything claude code"
- **ツール**: なし（インタラクティブインストーラー）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 6. continuous-learning
- **説明**: Automatically extract reusable patterns from Claude Code sessions and save them as learned skills.
- **トリガー**: Session end (Stop hook)
- **ツール**: なし（自動学習システム）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 7. continuous-learning-v2
- **説明**: Instinct-based learning system that observes sessions via hooks, creates atomic instincts with confidence scoring, and evolves them into skills/commands/agents.
- **トリガー**: PreToolUse/PostToolUse hooks
- **ツール**: なし（学習システム v2）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 8. django-patterns
- **説明**: Django architecture patterns, REST API design with DRF, ORM best practices, caching, signals, middleware, and production-grade Django apps.
- **トリガー**: Building Django applications
- **ツール**: なし（パターン集）
- **対象**: Django
- **カテゴリ**: 開発

### 9. django-security
- **説明**: Django security best practices, authentication, authorization, CSRF protection, SQL injection prevention, XSS prevention, and secure deployment configurations.
- **トリガー**: Django authentication, security review
- **ツール**: なし（セキュリティガイドライン）
- **対象**: Django
- **カテゴリ**: セキュリティ

### 10. django-tdd
- **説明**: Django testing strategies with pytest-django, TDD methodology, factory_boy, mocking, coverage, and testing Django REST Framework APIs.
- **トリガー**: Writing new Django code
- **ツール**: なし（テストパターン集）
- **対象**: Django
- **カテゴリ**: テスト

### 11. django-verification
- **説明**: Verification loop for Django projects: migrations, linting, tests with coverage, security scans, and deployment readiness checks.
- **トリガー**: Before PRs, after major changes
- **ツール**: なし（検証ワークフロー）
- **対象**: Django
- **カテゴリ**: ワークフロー

### 12. eval-harness
- **説明**: Formal evaluation framework for Claude Code sessions implementing eval-driven development (EDD) principles.
- **トリガー**: Running formal evaluations
- **ツール**: Read, Write, Edit, Bash, Grep, Glob
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 13. frontend-patterns
- **説明**: Frontend development patterns for React, Next.js, state management, performance optimization, and UI best practices.
- **トリガー**: Frontend development
- **ツール**: なし（パターン集）
- **対象**: React, Next.js
- **カテゴリ**: 開発

### 14. golang-patterns
- **説明**: Idiomatic Go patterns, best practices, and conventions for building robust, efficient, and maintainable Go applications.
- **トリガー**: Writing Go code
- **ツール**: なし（パターン集）
- **対象**: Go
- **カテゴリ**: 開発

### 15. golang-testing
- **説明**: Go testing patterns including table-driven tests, subtests, benchmarks, fuzzing, and test coverage. Follows TDD methodology.
- **トリガー**: Writing new Go functions
- **ツール**: なし（テストパターン集）
- **対象**: Go
- **カテゴリ**: テスト

### 16. iterative-retrieval
- **説明**: Pattern for progressively refining context retrieval to solve the subagent context problem.
- **トリガー**: Multi-agent workflow with context issues
- **ツール**: なし（パターン）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 17. java-coding-standards
- **説明**: Java coding standards for Spring Boot services: naming, immutability, Optional usage, streams, exceptions, generics, and project layout.
- **トリガー**: Writing Java code
- **ツール**: なし（ガイドライン）
- **対象**: Java, Spring Boot
- **カテゴリ**: 開発

### 18. jpa-patterns
- **説明**: JPA/Hibernate patterns for entity design, relationships, query optimization, transactions, auditing, indexing, pagination, and pooling.
- **トリガー**: Data modeling, repositories
- **ツール**: なし（パターン集）
- **対象**: Java, JPA/Hibernate
- **カテゴリ**: データベース

### 19. legal-document-namer
- **説明**: 法律事務所向けファイル命名パターン — フォルダ種別ごとの命名規則、日付・枝番、証拠番号体系
- **トリガー**: 法律文書管理システム構築
- **ツール**: なし（ドメイン知識）
- **対象**: 法律事務所（ドメイン固有）
- **カテゴリ**: ドキュメント

### 20. n8n-code-javascript
- **説明**: Write JavaScript code in n8n Code nodes. Use when writing JavaScript in n8n.
- **トリガー**: n8n Code node (JavaScript)
- **ツール**: なし（ガイド）
- **対象**: n8n
- **カテゴリ**: 開発

### 21. n8n-code-python
- **説明**: Write Python code in n8n Code nodes.
- **トリガー**: n8n Code node (Python)
- **ツール**: なし（ガイド）
- **対象**: n8n
- **カテゴリ**: 開発

### 22. n8n-expression-syntax
- **説明**: Validate n8n expression syntax and fix common errors.
- **トリガー**: n8n expression troubleshooting
- **ツール**: なし（ガイド）
- **対象**: n8n
- **カテゴリ**: 開発

### 23. n8n-mcp-tools-expert
- **説明**: Expert guide for using n8n-mcp MCP tools effectively.
- **トリガー**: n8n-mcp tool usage
- **ツール**: なし（ツールガイド）
- **対象**: n8n
- **カテゴリ**: ワークフロー

### 24. n8n-node-configuration
- **説明**: Operation-aware node configuration guidance.
- **トリガー**: Configuring n8n nodes
- **ツール**: なし（ガイド）
- **対象**: n8n
- **カテゴリ**: 開発

### 25. n8n-validation-expert
- **説明**: Interpret validation errors and guide fixing them.
- **トリガー**: n8n validation errors
- **ツール**: なし（ガイド）
- **対象**: n8n
- **カテゴリ**: ワークフロー

### 26. n8n-workflow-patterns
- **説明**: Proven workflow architectural patterns from real n8n workflows.
- **トリガー**: Building n8n workflows
- **ツール**: なし（パターン集）
- **対象**: n8n
- **カテゴリ**: ワークフロー

### 27. postgres-patterns
- **説明**: PostgreSQL database patterns for query optimization, schema design, indexing, and security. Based on Supabase best practices.
- **トリガー**: Writing SQL, database work
- **ツール**: なし（パターン集）
- **対象**: PostgreSQL
- **カテゴリ**: データベース

### 28. project-guidelines-example
- **説明**: Example of project-specific skill (Zenith project).
- **トリガー**: N/A（例示用）
- **ツール**: なし（テンプレート）
- **対象**: 例示
- **カテゴリ**: 開発

### 29. pull-merge-pub
- **説明**: Workflow for pull from remote, conflict check, merge, and /pub.
- **トリガー**: Integrating remote changes
- **ツール**: なし（ワークフロー）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 30. pytest-migration
- **説明**: Patterns for unittest-to-pytest conversion, conftest design, environment-dependent skipping.
- **トリガー**: Migrating to pytest
- **ツール**: なし（パターン集）
- **対象**: Python
- **カテゴリ**: テスト

### 31. python-patterns
- **説明**: Pythonic idioms, PEP 8 standards, type hints, and best practices.
- **トリガー**: Writing Python code
- **ツール**: なし（パターン集）
- **対象**: Python
- **カテゴリ**: 開発

### 32. python-testing
- **説明**: Python testing strategies using pytest, TDD methodology, fixtures, mocking.
- **トリガー**: Writing new Python code (TDD)
- **ツール**: なし（テストパターン集）
- **対象**: Python
- **カテゴリ**: テスト

### 33. security-review
- **説明**: Comprehensive security checklist and patterns.
- **トリガー**: Authentication, user input, API endpoints
- **ツール**: なし（セキュリティガイドライン）
- **対象**: 汎用
- **カテゴリ**: セキュリティ

### 34. springboot-patterns
- **説明**: Spring Boot architecture patterns, REST API design, layered services.
- **トリガー**: Java Spring Boot backend work
- **ツール**: なし（パターン集）
- **対象**: Java, Spring Boot
- **カテゴリ**: 開発

### 35. springboot-security
- **説明**: Spring Security best practices for authn/authz, validation, CSRF, secrets.
- **トリガー**: Spring Security work
- **ツール**: なし（セキュリティガイドライン）
- **対象**: Java, Spring Boot
- **カテゴリ**: セキュリティ

### 36. springboot-tdd
- **説明**: Test-driven development for Spring Boot using JUnit 5, Mockito, MockMvc.
- **トリガー**: New features, bug fixes
- **ツール**: なし（テストパターン集）
- **対象**: Java, Spring Boot
- **カテゴリ**: テスト

### 37. springboot-verification
- **説明**: Verification loop for Spring Boot projects: build, static analysis, tests, security scans.
- **トリガー**: Before PRs, pre-deploy
- **ツール**: なし（検証ワークフロー）
- **対象**: Java, Spring Boot
- **カテゴリ**: ワークフロー

### 38. strategic-compact
- **説明**: Manual context compaction at logical intervals.
- **トリガー**: Context management
- **ツール**: なし（ワークフロー提案）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 39. tdd-workflow
- **説明**: Enforces test-driven development with 80%+ coverage.
- **トリガー**: New features, bug fixes, refactoring
- **ツール**: なし（ワークフロー）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 40. tkinter-help-system
- **説明**: Patterns for building ToolTip, collapsible help panels using tkinter.
- **トリガー**: tkinter GUI help system
- **ツール**: なし（パターン集）
- **対象**: Python, tkinter
- **カテゴリ**: 開発

### 41. verification-loop
- **説明**: Comprehensive verification system for Claude Code sessions.
- **トリガー**: After completing features, before PRs
- **ツール**: なし（検証ワークフロー）
- **対象**: 汎用
- **カテゴリ**: ワークフロー

### 42. learned
- **説明**: 自動生成スキル格納用ディレクトリ（現在空）
- **トリガー**: N/A（自動生成）
- **ツール**: N/A
- **対象**: 汎用
- **カテゴリ**: N/A

---

## 調査メモ

- 全スキルにYAMLフロントマター形式でname/descriptionが定義されている
- toolsフィールドは一部のスキルのみ（claude-md-improver, eval-harness）に記載
- learned/ディレクトリは現在空（自動生成スキル格納用）
- project-guidelines-exampleは例示用テンプレート
- Everything Claude Codeプロジェクトに由来するスキル群が多数含まれる
- n8n関連スキルが7件と充実
- Java/Spring Boot関連が6件、Django関連が4件と主要フレームワークをカバー

---

## 統合タスク向け情報

**スキル総数**: 42件（learned除く）
**SKILL.md存在率**: 100%（learned除く）
**YAMLフロントマター**: 全スキルで統一フォーマット
**命名規則**: kebab-case（ハイフン区切り）
**ディレクトリ構造**: 単一階層（サブディレクトリなし、learned除く）

**推奨される統合方法**:
- カテゴリ別整理（開発/テスト/セキュリティ/ワークフロー/データベース）
- 言語/フレームワーク別整理
- 汎用スキルと特化スキルの分離
- learned/への自動生成スキル対応
