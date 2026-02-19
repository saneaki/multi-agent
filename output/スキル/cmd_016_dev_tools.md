# Gmail自動管理システム 開発・デプロイツール調査レポート

**cmd_016 | subtask_016b | 足軽6号**
**調査日: 2026-02-12**

---

## 目次

1. [clasp（Command Line Apps Script Projects）](#1-claspcommand-line-apps-script-projects)
2. [Google Workspace Studio](#2-google-workspace-studio)
3. [GitHub Actions との CI/CD連携](#3-github-actions-との-cicd連携)
4. [ローカルテスト環境](#4-ローカルテスト環境)
5. [バージョン管理とデプロイフロー](#5-バージョン管理とデプロイフロー)
6. [Apps Script API](#6-apps-script-api)
7. [その他のツール・手法](#7-その他のツール手法)
8. [比較表](#8-比較表)
9. [推奨構成の提案](#9-推奨構成の提案)

---

## 1. clasp（Command Line Apps Script Projects）

### 概要・基本機能

clasp は Google 公式の Apps Script CLI ツール。Apps Script プロジェクトをローカル環境で開発・管理できる。

- **リポジトリ**: <https://github.com/google/clasp>
- **インストール**: `npm install -g @google/clasp`
- **現行バージョン**: clasp 3.x（2025〜2026年時点の最新メジャー）

主要機能:

- ローカルでの Apps Script 開発（ソースコード管理・エディタ自由選択）
- 複数デプロイメントの作成・更新・表示
- フラットなプロジェクトを自動的にフォルダ構造に変換
- MCP（Model Context Protocol）モード対応（Gemini CLI / Claude Code 連携）

### ローカル開発ワークフロー

```bash
# 1. ログイン
clasp login

# 2. 既存プロジェクトのクローン
clasp clone <scriptId>

# 3. ローカルで編集後にプッシュ
clasp push

# 4. リモートの変更をプル
clasp pull

# 5. 新規プロジェクト作成
clasp create --type standalone --title "Gmail Manager"
```

### TypeScript対応（clasp 3.x での変更点）

**重要な破壊的変更**: clasp 3.x では TypeScript の組み込みトランスパイルが廃止された。

- clasp 2.x: clasp 自体が `.ts` → `.gs` 変換を実行
- clasp 3.x: **外部バンドラー（Rollup 等）との併用が必須**

```bash
# clasp 3.x でのTypeScriptワークフロー
npm run build   # Rollup/webpack で ts → js 変換
clasp push       # 変換済みファイルをプッシュ
```

メリット:

- ESM モジュールと NPM パッケージの完全サポート
- より堅牢な TypeScript 機能のサポート
- バンドラーの柔軟な選択（Rollup, webpack, esbuild）

### Git連携

- `.clasp.json`: プロジェクト設定ファイル（scriptId, rootDir 等）
- `.claspignore`: プッシュから除外するファイルを指定（.gitignore と同様の構文）
- `.clasprc.json`: 認証情報（**Git に含めない** → `.gitignore` に追加必須）

```json
// .clasp.json の例
{
  "scriptId": "1234567890abcdef",
  "rootDir": "./dist",
  "projectId": "my-project-id"
}
```

### 複数環境管理

clasp 3.x では `--project` オプションと `--user` オプションで複数環境を管理:

```bash
# 開発環境
clasp push --project .clasp.dev.json

# 本番環境
clasp push --project .clasp.prod.json

# ユーザー切り替え
clasp push --user production-account
```

### 制約・注意点

- Apps Script API の有効化が必要（Google Cloud Console で設定）
- サービスアカウントでは動作しない（OAuth 2.0 ユーザー認証が必須）
- Rhino ランタイムは 2026年1月31日で完全停止済み → V8 ランタイム必須
- clasp 3.x では TypeScript の直接プッシュ不可（バンドラー必須）
- `.clasprc.json` のトークンは有効期限あり（定期的な再認証が必要）

**出典**: [Google 公式ドキュメント](https://developers.google.com/apps-script/guides/clasp) / [clasp GitHub](https://github.com/google/clasp)

---

## 2. Google Workspace Studio

### 概要・現在の活用可能性

Google Workspace Studio は 2025〜2026年に登場した **ノーコード AI エージェントビルダー**。Gemini Alpha プログラムの一部として提供。

主要機能:

- **自然言語でのエージェント構築**: プロンプトを入力するだけで AI エージェントを数分で作成
- **Google Workspace ネイティブ連携**: Gmail, Drive, Docs, Sheets, Calendar, Chat にネイティブアクセス
- **テンプレート**: ミーティングブリーフィング、リード分類、自動フォローアップ等のテンプレート提供
- **拡張性**: Salesforce, Jira, Asana 等のサードパーティ連携、Apps Script によるカスタムロジック

### GASプロジェクトとの連携

- Workspace Studio のアドオン拡張は **限定プレビュー** 段階
- 実行タイムアウト: 2分
- Apps Script でカスタムロジックを組み込み可能

### メリット・デメリット

**メリット**:

- IT 知識不要でエージェント構築可能
- Google Workspace との深い統合
- Gemini 3 による高度な自然言語処理

**デメリット**:

- Gemini Alpha プログラム限定（一般提供未定）
- 細かいロジック制御が困難
- 本格的な GAS 開発ワークフローの代替にはならない
- Gmail 自動管理のような複雑なルールベース処理には不向き

### 本プロジェクトへの適用性

Gmail自動管理システムの開発ツールとしては **不適切**。Workspace Studio は汎用的なワークフロー自動化向けであり、GAS ベースの本格的な開発・テスト・デプロイフローの代替にはならない。ただし、**将来的なエンドユーザー向けインターフェース**としての活用可能性はある。

**出典**: [Google Workspace Studio](https://workspace.google.com/products/apps-script/) / [6 Automations](https://www.bitcot.com/google-workspace-studio-automations/)

---

## 3. GitHub Actions との CI/CD連携

### clasp + GitHub Actions での自動デプロイフロー

#### 基本アーキテクチャ

```
ローカル開発 → git push → GitHub Actions → clasp push → Apps Script デプロイ
```

#### ワークフロー例

```yaml
# .github/workflows/deploy.yaml
name: Deploy to Apps Script

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Build (TypeScript → JavaScript)
        run: npm run build

      - name: Install clasp
        run: npm install -g @google/clasp

      - name: Setup clasp credentials
        run: echo '${{ secrets.CLASPRC_JSON }}' > ~/.clasprc.json

      - name: Verify login
        run: clasp login --status

      - name: Push to Apps Script
        run: clasp push -f

      - name: Deploy
        run: clasp deploy --description "Auto-deploy from ${{ github.sha }}"
```

### シークレット管理

`.clasprc.json` に含まれるトークンの管理方法:

**方法1: GitHub Secrets に直接保存（推奨）**

```bash
# ローカルで clasp login 後、.clasprc.json の内容をコピー
cat ~/.clasprc.json
# → GitHub リポジトリの Settings > Secrets に CLASPRC_JSON として保存
```

**方法2: GPG 暗号化**

```bash
# 暗号化
gpg --symmetric --cipher-algo AES256 .clasprc.json
# → .clasprc.json.gpg をリポジトリにコミット
# → 復号パスワードを GitHub Secrets に CLASP_SECRET として保存
```

**注意事項**:

- `access_token` は有効期限あり（`expiry_date` で管理）
- `refresh_token` で自動更新されるが、長期間未使用で失効する場合あり
- 週次の認証チェックワークフロー（`schedule` トリガー）を設定すると安全

### テスト自動実行との統合

```yaml
# テストが失敗したらデプロイを中断
- name: Run unit tests
  run: npm test -- --coverage --ci

- name: Check coverage threshold
  run: |
    npx nyc check-coverage --lines 80 --functions 80 --branches 80
```

### ブランチ戦略

| ブランチ | 用途 | デプロイ先 |
|---------|------|-----------|
| `main` | 本番コード | 本番環境（自動デプロイ） |
| `develop` | 開発統合 | ステージング環境（自動デプロイ） |
| `feature/*` | 機能開発 | デプロイなし（テストのみ） |

```yaml
# ブランチ別デプロイ設定
- name: Deploy to staging
  if: github.ref == 'refs/heads/develop'
  run: clasp push --project .clasp.staging.json

- name: Deploy to production
  if: github.ref == 'refs/heads/main'
  run: clasp push --project .clasp.prod.json && clasp deploy
```

### 利用可能な GitHub Actions

| Action | 概要 | URL |
|--------|------|-----|
| Clasp Action | clasp push/deploy の自動化 | [daikikatsuragawa/clasp-action](https://github.com/marketplace/actions/clasp-action) |
| Clasp Tokens | CI/CD 環境での clasp 認証支援 | [GitHub Marketplace](https://github.com/marketplace/actions/clasp-tokens) |
| deploy-google-app-script-action | 完全な CI/CD サンプル | [ericanastas/deploy-google-app-script-action](https://github.com/ericanastas/deploy-google-app-script-action) |

### clasp 3.x の新機能（CI/CD向け）

- `--adc` オプション: Application Default Credentials からの認証（CI環境向け）
- `--project <file>`: 複数の `.clasp.json` を指定可能（マルチ環境対応）

**出典**: [clasp GitHub](https://github.com/google/clasp) / [clasp-action](https://github.com/marketplace/actions/clasp-action) / [deploy-google-app-script-action](https://github.com/ericanastas/deploy-google-app-script-action)

---

## 4. ローカルテスト環境

### gas-local（GASのローカル模擬実行）

GAS プロジェクトを **Node.js 環境でそのまま実行** できるツール。

```bash
npm install gas-local --save-dev
```

```javascript
// test-setup.js
const gas = require('gas-local');

// GASグローバルオブジェクトのモック
const mocks = {
  MailApp: {
    getRemainingDailyQuota: () => 100,
    sendEmail: jest.fn()
  },
  GmailApp: {
    search: jest.fn(),
    getInboxThreads: jest.fn()
  }
};

const gasProject = gas.require('./src', mocks);
```

特徴:

- Logger と Utilities はデフォルトでモック済み
- カスタムモックを注入可能
- プロジェクトの書き換え不要で Node.js 実行可能

**リポジトリ**: [mzagorny/gas-local](https://github.com/mzagorny/gas-local)

### Jest / Mocha でのユニットテスト

**推奨: Jest** — 高速、watchモード、スナップショットテスト、カバレッジ内蔵。

```javascript
// gmail-manager.test.js
describe('Gmail Manager', () => {
  beforeEach(() => {
    // GASグローバルのモック
    global.GmailApp = {
      search: jest.fn().mockReturnValue([]),
      getInboxThreads: jest.fn().mockReturnValue([]),
      createLabel: jest.fn()
    };
    global.Logger = {
      log: jest.fn()
    };
  });

  test('should search emails with correct query', () => {
    const { searchEmails } = require('./gmail-manager');
    searchEmails('from:client@example.com');
    expect(GmailApp.search).toHaveBeenCalledWith('from:client@example.com');
  });

  test('should create label if not exists', () => {
    const { ensureLabel } = require('./gmail-manager');
    ensureLabel('重要クライアント');
    expect(GmailApp.createLabel).toHaveBeenCalledWith('重要クライアント');
  });
});
```

### GASモックライブラリ

| ライブラリ | 対象 | 特徴 |
|-----------|------|------|
| gasmask | SpreadsheetApp 中心 | 型サポート、コミュニティ主導 |
| app-script-mock | FormApp, DriveApp, SpreadsheetApp | アサーション内でモック構築 |
| excol | SpreadsheetApp | getActiveSheet, getRange, setValues 対応 |
| UnitTestingApp | 汎用 | GAS内/ローカル両方で実行可能 |

**リポジトリ**: [gasmask](https://github.com/vlucas/gasmask) / [app-script-mock](https://github.com/matheusmr13/app-script-mock)

### TypeScriptでのテスト記述

```typescript
// gmail-manager.test.ts
import { processInbox, EmailRule } from './gmail-manager';

// GmailApp の型定義モック
const mockThread = {
  getMessages: jest.fn().mockReturnValue([{
    getFrom: () => 'client@example.com',
    getSubject: () => '契約書の件',
    getDate: () => new Date('2026-02-12')
  }]),
  addLabel: jest.fn(),
  moveToArchive: jest.fn()
};

beforeEach(() => {
  (global as any).GmailApp = {
    search: jest.fn().mockReturnValue([mockThread]),
    getUserLabelByName: jest.fn().mockReturnValue({ getName: () => '重要' })
  };
});

test('should apply rules to matching emails', () => {
  const rules: EmailRule[] = [
    { from: 'client@example.com', labelName: '重要', archive: false }
  ];
  processInbox(rules);
  expect(mockThread.addLabel).toHaveBeenCalled();
});
```

### テストカバレッジツール

```bash
# Jest 内蔵カバレッジ
npx jest --coverage

# nyc (Istanbul) でカバレッジ閾値チェック
npx nyc check-coverage --lines 80 --functions 80 --branches 80
```

### テスト設計のベストプラクティス

1. **ビジネスロジックを GAS グローバルから分離**: `GmailApp` 等の呼び出しを薄いラッパーに閉じ込め、ロジック部分は純粋関数にする
2. **手動モックで十分**: GAS の柔軟なオブジェクトモデルにより、`jest.fn()` での手動モックが最も実用的
3. **テスト実行速度**: ローカル Jest テストは数秒で完了（GAS IDE でのテストは数十秒〜数分）

**出典**: [gas-local](https://github.com/mzagorny/gas-local) / [gasmask](https://github.com/vlucas/gasmask) / [Unit Testing in GAS (Medium)](https://medium.com/geekculture/taking-away-the-pain-from-unit-testing-in-google-apps-script-98f2feee281d)

---

## 5. バージョン管理とデプロイフロー

### clasp version / clasp deploy の使い方

#### バージョン作成

```bash
# バージョン一覧
clasp versions

# 新しいバージョンを作成（イミュータブルなスナップショット）
clasp version "v1.0.0 - 初期リリース"
```

バージョンは **イミュータブル**（読み取り専用のスナップショット）。Git のタグに相当する概念。

#### デプロイメント作成

```bash
# デプロイメント一覧
clasp deployments

# 新規デプロイメント作成（最新バージョンを使用）
clasp deploy --description "Production v1.0.0"

# 特定バージョンでデプロイ（clasp 3.x）
clasp create-deployment --version-number 3 --description "v1.2.0"
```

### デプロイメントID管理

- 各デプロイメントには一意の **Deployment ID** が付与される
- Web アプリの URL は Deployment ID に紐づく
- Deployment ID を固定すれば URL を変えずにバージョンのみ更新可能

```bash
# デプロイメントIDの確認
clasp deployments
# 出力例:
# - AKfycbx... @1 - Production v1.0.0
# - AKfycby... @2 - Staging v1.1.0-beta

# 既存デプロイメントを新バージョンで更新
clasp redeploy <deploymentId> <versionNumber> "Updated description"
```

### ロールバック手順

clasp に直接の「ロールバック」コマンドはないが、バージョン管理で実現:

```bash
# 1. 現在のデプロイメントとバージョンを確認
clasp deployments
clasp versions

# 2. 前バージョンのバージョン番号を特定（例: 2）
# 3. デプロイメントを前バージョンに更新
clasp redeploy <deploymentId> 2 "Rollback to v1.0.0"
```

### 本番反映のワークフロー

```
開発 → レビュー → テスト → バージョン作成 → デプロイ
  |                                              |
  └──── ロールバック ← 問題検知 ←── 監視 ←────────┘
```

推奨フロー:

1. `feature` ブランチで開発
2. PR 作成 → コードレビュー
3. `develop` ブランチにマージ → ステージング自動デプロイ
4. ステージング検証
5. `main` ブランチにマージ → 本番自動デプロイ（バージョン自動作成）
6. 問題発生時 → `clasp redeploy` で前バージョンにロールバック

**出典**: [clasp 公式ドキュメント](https://developers.google.com/apps-script/guides/clasp) / [Deployments ガイド](https://developers.google.com/apps-script/concepts/deployments)

---

## 6. Apps Script API

### 概要・用途

Apps Script API は Google Apps Script プロジェクトを **REST API でプログラム的に管理** するためのインターフェース。

- **エンドポイント**: `https://script.googleapis.com/v1/`
- **主要リソース**: projects, deployments, versions, processes

### プログラム的なプロジェクト管理

| 操作 | メソッド | エンドポイント |
|------|---------|---------------|
| プロジェクト作成 | POST | `/v1/projects` |
| プロジェクト取得 | GET | `/v1/projects/{scriptId}` |
| コンテンツ取得 | GET | `/v1/projects/{scriptId}/content` |
| コンテンツ更新 | PUT | `/v1/projects/{scriptId}/content` |
| バージョン作成 | POST | `/v1/projects/{scriptId}/versions` |
| デプロイメント作成 | POST | `/v1/projects/{scriptId}/deployments` |
| デプロイメント更新 | PUT | `/v1/projects/{scriptId}/deployments/{deploymentId}` |
| 関数実行 | POST | `/v1/scripts/{scriptId}:run` |

### CI/CDでの活用場面

- **自動化スクリプト**: clasp が内部的に使用している API と同一
- **カスタム CI/CD ツール**: clasp では対応できない複雑なデプロイフローを構築
- **モニタリング**: `processes` リソースで実行中のスクリプトを監視
- **プログラム的なバージョン管理**: 複数プロジェクトの一括更新

### 認証・権限設定

```bash
# 必要なOAuthスコープ
https://www.googleapis.com/auth/script.projects
https://www.googleapis.com/auth/script.deployments
https://www.googleapis.com/auth/script.external_request
```

**重要な制約**:

- **サービスアカウントでは動作しない**（OAuth 2.0 ユーザー認証が必須）
- Google Cloud Console で Apps Script API の有効化が必要
- サードパーティアプリのアクセス許可が必要

### 本プロジェクトでの活用

通常は **clasp が Apps Script API のラッパーとして機能** するため、直接 API を叩く必要性は低い。ただし以下の場合に有用:

- 複数の GAS プロジェクトを一括管理するツールの構築
- カスタムダッシュボードでの実行状況モニタリング
- clasp では実現できない高度なデプロイ自動化

**出典**: [Apps Script API リファレンス](https://developers.google.com/apps-script/api/reference/rest) / [プロジェクト管理ガイド](https://developers.google.com/apps-script/api/how-tos/manage-projects)

---

## 7. その他のツール・手法

### Google Apps Script GitHub Assistant（GasHub）

Chrome 拡張機能。Apps Script IDE から直接 GitHub/GitLab/Bitbucket と同期。

- **機能**: push/pull、diff表示、ファイル選択、コミットコメント
- **対応**: GitHub, GitHub Enterprise, Bitbucket, GitLab
- **バウンドスクリプト対応**: Sheets, Docs, Forms に紐づくスクリプトも管理可能
- **制約**: OAuth 認証が未検証のため 100ユーザー制限あり（要確認）

**用途**: clasp を使わない場合の簡易 Git 連携。ただし CI/CD との統合は不可。

**リポジトリ**: [leonhartX/gas-github](https://github.com/leonhartX/gas-github) / [Chrome Web Store](https://chromewebstore.google.com/detail/google-apps-script-github/lfjcgcmkmjjlieihflfhjopckgpelofo)

### webpack / Rollup でのバンドル

clasp 3.x では TypeScript バンドルが必須のため、バンドラーの選択が重要。

#### Rollup（推奨）

```javascript
// rollup.config.js
import typescript from '@rollup/plugin-typescript';
import resolve from '@rollup/plugin-node-resolve';

export default {
  input: 'src/index.ts',
  output: {
    dir: 'dist',
    format: 'cjs'  // GAS は CommonJS 相当
  },
  plugins: [
    resolve(),
    typescript()
  ]
};
```

#### webpack

```javascript
// webpack.config.js
const GasPlugin = require('gas-webpack-plugin');

module.exports = {
  mode: 'production',
  entry: './src/index.ts',
  output: {
    filename: 'Code.js',
    path: __dirname + '/dist'
  },
  module: {
    rules: [
      { test: /\.ts$/, use: 'ts-loader', exclude: /node_modules/ }
    ]
  },
  plugins: [new GasPlugin()]
};
```

#### 比較

| 項目 | Rollup | webpack |
|------|--------|---------|
| Tree-shaking | 優秀 | 良好 |
| 設定の簡潔さ | シンプル | やや複雑 |
| GAS 向けプラグイン | 標準的 | gas-webpack-plugin |
| バンドルサイズ | 小さい | やや大きい |
| 推奨度 | ★★★★★ | ★★★★ |

### ESLint / Prettier でのコード品質管理

```bash
# インストール
npm install --save-dev eslint prettier eslint-plugin-googleappsscript \
  @typescript-eslint/eslint-plugin @typescript-eslint/parser \
  eslint-config-prettier
```

```javascript
// .eslintrc.js
module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'googleappsscript'],
  env: {
    'googleappsscript/googleappsscript': true  // GAS グローバル変数を認識
  },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'prettier'
  ]
};
```

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

### @google/aside（Apps Script in IDE）

Google 公式の開発フレームワーク。ESLint, Prettier, Jest を自動セットアップ。

```bash
npx @google/aside init
```

含まれるツール:

- TypeScript コンパイル + バンドル
- ESLint + Prettier（自動設定）
- Jest テスト環境
- clasp 連携

**リポジトリ**: [google/aside](https://github.com/google/aside)

### ドキュメント自動生成

```bash
# TypeDoc（TypeScript向け）
npm install --save-dev typedoc
npx typedoc --entryPoints src/index.ts --out docs

# JSDoc
npm install --save-dev jsdoc
npx jsdoc src/ -d docs
```

**出典**: [gas-clasp-starter](https://github.com/howdy39/gas-clasp-starter) / [eslint-plugin-googleappsscript](https://github.com/selectnull/eslint-plugin-googleappsscript) / [@google/aside](https://github.com/google/aside)

---

## 8. 比較表

| ツール名 | 主要機能 | メリット | デメリット | 学習コスト | 推奨度 | 備考 |
|---------|---------|---------|-----------|-----------|--------|------|
| **clasp** | CLI でのGAS開発・デプロイ | Google公式、ローカル開発可能、Git連携、MCP対応 | サービスアカウント非対応、トークン管理が煩雑 | 低 | ★★★★★ | **必須ツール** |
| **Google Workspace Studio** | ノーコードAIエージェント構築 | コーディング不要、Google製品と深い統合 | 限定プレビュー、細かい制御不可、GAS開発の代替にならない | 低 | ★★ | 本プロジェクトには不適 |
| **GitHub Actions + clasp** | CI/CD自動デプロイ | 自動化、テスト統合、チーム開発対応 | トークン管理の複雑さ、初期設定コスト | 中 | ★★★★★ | **強く推奨** |
| **Jest + モック** | ローカルユニットテスト | 高速、watchモード、カバレッジ内蔵 | GASモックの手動構築が必要 | 低〜中 | ★★★★★ | **テスト基盤として必須** |
| **gas-local** | GASプロジェクトのNode.js実行 | 書き換え不要、デフォルトモック付き | メンテナンス頻度が低い | 低 | ★★★ | 補助的に使用 |
| **gasmask** | SpreadsheetApp モック | 型サポート、専門的 | SpreadsheetApp中心、GmailApp非対応 | 低 | ★★★ | Sheets操作がある場合に |
| **Rollup** | TypeScript バンドル | 小さいバンドル、優れたTree-shaking | clasp 3.x 必須のため追加学習 | 中 | ★★★★★ | clasp 3.x では**必須** |
| **webpack** | TypeScript バンドル | エコシステム充実、gas-webpack-plugin | 設定が複雑、バンドルが大きい | 中〜高 | ★★★★ | Rollupの代替 |
| **@google/aside** | GAS開発フレームワーク | Google公式、オールインワン | 柔軟性が低い | 低 | ★★★★ | 新規プロジェクトに最適 |
| **Apps Script API** | REST APIでのGAS管理 | プログラム的な制御 | サービスアカウント非対応、直接使用は稀 | 高 | ★★★ | 高度な自動化時のみ |
| **GasHub（Chrome拡張）** | IDEからGit同期 | 手軽、ビジュアル | CI/CD非対応、ユーザー制限あり | 低 | ★★ | clasp代替（非推奨） |
| **ESLint + Prettier** | コード品質管理 | 自動フォーマット、静的解析 | GAS固有プラグインのメンテナンス | 低 | ★★★★★ | **品質管理に必須** |
| **TypeDoc / JSDoc** | ドキュメント自動生成 | コードからドキュメント生成 | 初期設定が必要 | 低 | ★★★ | 規模に応じて導入 |

---

## 9. 推奨構成の提案

### 初期開発環境の推奨セットアップ

```
プロジェクト構造:
gmail-client-manager/
├── src/                    # TypeScriptソースコード
│   ├── index.ts           # エントリーポイント（GAS公開関数）
│   ├── gmail-manager.ts   # Gmail操作ロジック
│   ├── rules.ts           # メール振り分けルール
│   └── utils.ts           # ユーティリティ
├── test/                   # テストファイル
│   ├── gmail-manager.test.ts
│   ├── rules.test.ts
│   └── mocks/             # GASグローバルのモック
│       └── gmail-app.ts
├── dist/                   # ビルド出力（clasp pushはここから）
├── .clasp.json            # clasp設定
├── .claspignore           # push除外設定
├── appsscript.json        # GASマニフェスト
├── rollup.config.js       # バンドラー設定
├── tsconfig.json          # TypeScript設定
├── jest.config.js         # テスト設定
├── .eslintrc.js           # ESLint設定
├── .prettierrc            # Prettier設定
└── package.json
```

**セットアップ手順**:

```bash
# 1. プロジェクト初期化
mkdir gmail-client-manager && cd gmail-client-manager
npm init -y

# 2. 開発ツールインストール
npm install --save-dev typescript @google/clasp \
  rollup @rollup/plugin-typescript @rollup/plugin-node-resolve \
  jest ts-jest @types/jest \
  eslint prettier eslint-plugin-googleappsscript \
  @typescript-eslint/eslint-plugin @typescript-eslint/parser

# 3. GAS型定義
npm install --save-dev @types/google-apps-script

# 4. clasp設定
clasp login
clasp create --type standalone --title "Gmail Client Manager" --rootDir ./dist

# 5. ビルド・テスト実行
npm run build    # rollup で ts → js
npm test         # jest でテスト
clasp push       # dist/ をGASにプッシュ
```

### CI/CDパイプラインの推奨構成

```
[開発者] → git push → [GitHub Actions]
                          ├── Lint (ESLint)
                          ├── Format Check (Prettier)
                          ├── Unit Tests (Jest, カバレッジ80%以上)
                          ├── Build (Rollup: ts→js)
                          └── Deploy
                              ├── develop → Staging (clasp push --project .clasp.staging.json)
                              └── main → Production (clasp push + clasp deploy)
```

**推奨GitHub Actions構成**:

- `on: push` → main/develop ブランチで自動デプロイ
- `on: pull_request` → テスト・リント・ビルドチェックのみ
- `on: schedule` → 週次で clasp 認証トークンの有効性チェック
- シークレット: `CLASPRC_JSON`, `CLASP_SCRIPT_ID`

### テスト戦略の推奨

| テスト種別 | ツール | 対象 | カバレッジ目標 |
|-----------|--------|------|---------------|
| ユニットテスト | Jest + 手動モック | ビジネスロジック、ルールエンジン | 80%以上 |
| 統合テスト | Jest + gas-local | GASグローバルとの連携 | 主要フロー |
| 手動テスト | GAS IDE / ログ | 実際のGmail操作 | デプロイ後の動作確認 |

**テスト設計原則**:

1. GASグローバル（GmailApp等）への依存を **薄いアダプター層** に分離
2. ビジネスロジックは **純粋関数** として実装（テスト容易性向上）
3. モックは `jest.fn()` で手動構築（外部ライブラリ依存を最小化）

### デプロイフローの推奨ステップ

```
1. 機能開発（feature ブランチ）
   ↓
2. PR 作成 → 自動テスト実行
   ↓
3. コードレビュー → 承認
   ↓
4. develop マージ → ステージング自動デプロイ
   ↓
5. ステージング検証（実際のGmailで動作確認）
   ↓
6. main マージ → 本番自動デプロイ
   ├── clasp version で自動バージョン作成
   └── clasp deploy で本番反映
   ↓
7. 問題検知時
   └── clasp redeploy <id> <prev-version> でロールバック
```

### 最終推奨: 最小構成（初期導入向け）

最小限のツールセットで始め、必要に応じて拡張する戦略:

| フェーズ | 導入ツール | 目的 |
|---------|-----------|------|
| Phase 1 | clasp + TypeScript + Rollup | ローカル開発基盤 |
| Phase 2 | Jest + ESLint + Prettier | テスト・品質管理 |
| Phase 3 | GitHub Actions CI/CD | 自動デプロイ |
| Phase 4 | TypeDoc + カバレッジレポート | ドキュメント・品質可視化 |

---

**以上**
