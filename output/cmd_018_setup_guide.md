# Gmail自動管理システム 開発環境セットアップ手順書

**cmd_018 | subtask_018a | 足軽5号**
**作成日: 2026-02-12**

> 本手順書は `cmd_016_dev_tools.md`（推奨構成）および `cmd_016_requirements.md`（要件定義書）に基づく。
> 別のマシンでこの手順書だけを見て環境構築できるレベルの詳しさを目指す。

---

## 目次

1. [前提条件](#第1章-前提条件)
2. [プロジェクト初期化](#第2章-プロジェクト初期化)
3. [clasp セットアップ](#第3章-clasp-セットアップ)
4. [TypeScript + Rollup 設定](#第4章-typescript--rollup-設定)
5. [テスト環境（Jest）](#第5章-テスト環境jest)
6. [コード品質（ESLint + Prettier）](#第6章-コード品質eslint--prettier)
7. [Git + GitHub 設定](#第7章-git--github-設定)
8. [GitHub Actions CI/CD](#第8章-github-actions-cicd)
9. [複数環境の管理](#第9章-複数環境の管理)
10. [package.json スクリプト一覧](#第10章-packagejson-スクリプト一覧)
11. [日常の開発ワークフロー](#第11章-日常の開発ワークフロー)
12. [トラブルシューティング](#第12章-トラブルシューティング)

---

## 第1章: 前提条件

### 1.1 必要なソフトウェア

| ソフトウェア | 必須バージョン | 確認コマンド | 備考 |
|------------|-------------|------------|------|
| Node.js | 20.x LTS 以上 | `node -v` | 22.x LTS も可 |
| npm | 10.x 以上 | `npm -v` | Node.js に同梱 |
| Git | 2.30 以上 | `git --version` | — |

**インストール確認手順**:

```bash
# Step 1: Node.js バージョン確認
node -v
# 期待される結果: v20.x.x または v22.x.x

# Step 2: npm バージョン確認
npm -v
# 期待される結果: 10.x.x

# Step 3: Git バージョン確認
git --version
# 期待される結果: git version 2.30 以上
```

**Node.js がインストールされていない場合**:

```bash
# 方法1: 公式インストーラ（推奨）
# https://nodejs.org/ から LTS 版をダウンロード

# 方法2: nvm（Node Version Manager）を使用
# macOS / Linux / WSL2
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc  # または source ~/.zshrc
nvm install 20
nvm use 20

# Windows（PowerShell管理者）
winget install CoreyButler.NVMforWindows
# 新しいターミナルを開いてから
nvm install 20
nvm use 20
```

### 1.2 必要なアカウント

| アカウント | 用途 | 取得先 |
|-----------|------|--------|
| Google アカウント | clasp認証、Apps Script | https://accounts.google.com/ |
| GitHub アカウント | ソースコード管理、CI/CD | https://github.com/ |

- Google Workspace アカウント（法律事務所ドメイン）が望ましいが、個人 Google アカウントでも開発可能
- GitHub の無料プランで十分（Private リポジトリ + GitHub Actions 無料枠）

### 1.3 Apps Script API の有効化手順

> **重要**: clasp を使用するには Apps Script API を有効にする必要がある。

```
Step 1: ブラウザで以下の URL にアクセス
        https://script.google.com/home/usersettings

Step 2: 「Google Apps Script API」のトグルを「オン」に切り替え

Step 3: 設定が保存されたことを確認（トグルがオンの状態）
```

**Google Cloud Console での API 有効化**（CI/CD で必要な場合）:

```
Step 1: https://console.cloud.google.com/ にアクセス

Step 2: 上部の「プロジェクトを選択」 → 対象プロジェクトを選択
        （プロジェクトがない場合は「新しいプロジェクト」で作成）

Step 3: 左メニュー「APIとサービス」→「ライブラリ」

Step 4: 検索バーに「Apps Script API」と入力

Step 5: 「Google Apps Script API」をクリック →「有効にする」ボタンをクリック

Step 6: 有効化されたことを確認（「APIが有効です」と表示）
```

### 1.4 OS別の注意点

| OS | 注意事項 |
|----|---------|
| **Windows** | WSL2 の使用を強く推奨。PowerShell/cmd でも動作するが、シェルスクリプトとの互換性に問題あり |
| **WSL2** | `/mnt/c/` 下でなく WSL ファイルシステム（`~/`）で作業すること。I/O パフォーマンスが大幅に異なる |
| **macOS** | Xcode Command Line Tools が必要: `xcode-select --install` |
| **Linux** | 特別な注意事項なし。Node.js は nvm 経由でのインストールを推奨 |

---

## 第2章: プロジェクト初期化

### 2.1 ディレクトリ作成

```bash
# Step 1: プロジェクトディレクトリを作成
mkdir gmail-client-manager
cd gmail-client-manager

# 期待される結果: 空のディレクトリが作成される
```

### 2.2 npm init（package.json 生成）

```bash
# Step 2: package.json を生成
npm init -y

# 期待される結果:
# Wrote to /path/to/gmail-client-manager/package.json:
# {
#   "name": "gmail-client-manager",
#   "version": "1.0.0",
#   ...
# }
```

### 2.3 全依存パッケージのインストール

```bash
# Step 3: 開発ツール一括インストール
npm install --save-dev \
  @google/clasp@^3.1.3 \
  typescript@^5.7.0 \
  @types/google-apps-script@^1.0.83 \
  rollup@^4.30.0 \
  @rollup/plugin-typescript@^12.1.0 \
  @rollup/plugin-node-resolve@^16.0.0 \
  rollup-plugin-gas@^2.0.2 \
  tslib@^2.8.0 \
  jest@^29.7.0 \
  ts-jest@^29.2.0 \
  @types/jest@^29.5.0 \
  eslint@^9.18.0 \
  @typescript-eslint/eslint-plugin@^8.20.0 \
  @typescript-eslint/parser@^8.20.0 \
  eslint-plugin-googleappsscript@^1.0.1 \
  eslint-config-prettier@^10.0.0 \
  prettier@^3.4.0

# 期待される結果:
# added XXX packages, and audited XXX packages in XXs
# found 0 vulnerabilities
```

> **注意**: バージョン番号は 2026年2月時点の推奨値。実際のインストール時に最新の互換バージョンが解決される。`npm outdated` で最新版を確認可能。

### 2.4 ディレクトリ構造の作成

```bash
# Step 4: ディレクトリ構造を作成
mkdir -p src test/mocks dist .github/workflows

# 期待される結果: 以下の構造が完成
```

**プロジェクト全体のディレクトリ構造と各ファイルの役割**:

```
gmail-client-manager/
├── src/                           # TypeScript ソースコード
│   ├── index.ts                   # エントリーポイント（GAS 公開関数を定義）
│   ├── gmail-manager.ts           # Gmail 操作ロジック（メール取得・フィルタ）
│   ├── pdf-converter.ts           # HTML→PDF 変換モジュール
│   ├── drive-manager.ts           # Google Drive フォルダ管理・ファイル保存
│   ├── sheet-recorder.ts          # スプレッドシート記録モジュール
│   ├── gemini-summarizer.ts       # Gemini API 要約生成
│   ├── rules.ts                   # メール振り分けルール定義
│   └── utils.ts                   # ユーティリティ関数
├── test/                          # テストファイル
│   ├── gmail-manager.test.ts      # Gmail 操作のテスト
│   ├── pdf-converter.test.ts      # PDF 変換のテスト
│   ├── rules.test.ts              # ルールエンジンのテスト
│   └── mocks/                     # GAS グローバルのモック
│       └── gas-globals.ts         # GmailApp, DriveApp 等のモック定義
├── dist/                          # ビルド出力（clasp push はここから）
│   ├── Code.js                    # Rollup ビルド出力（自動生成）
│   └── appsscript.json            # GAS マニフェスト（手動配置）
├── .clasp.json                    # clasp 設定（scriptId, rootDir）
├── .claspignore                   # clasp push 除外設定
├── appsscript.json                # GAS マニフェスト（ソース管理用）
├── rollup.config.mjs              # Rollup バンドラー設定
├── tsconfig.json                  # TypeScript コンパイラ設定
├── jest.config.js                 # Jest テスト設定
├── eslint.config.mjs              # ESLint 設定（Flat Config）
├── .prettierrc                    # Prettier 設定
├── .gitignore                     # Git 除外設定
├── .github/
│   └── workflows/
│       └── deploy.yaml            # GitHub Actions CI/CD
└── package.json                   # プロジェクト設定・依存関係
```

### 2.5 appsscript.json の作成

GAS マニフェストファイル。OAuth スコープとランタイムを定義する。

```bash
# Step 5: appsscript.json を作成
```

**appsscript.json の完全な内容**:

```json
{
  "timeZone": "Asia/Tokyo",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "oauthScopes": [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.labels",
    "https://www.googleapis.com/auth/drive.file",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/script.external_request"
  ]
}
```

> **各スコープの説明**:
>
> | スコープ | 用途 | 分類 |
> |---------|------|------|
> | `gmail.readonly` | メール本文・添付ファイルの読み取り | Restricted |
> | `gmail.labels` | 処理済みラベルの付与 | Non-sensitive |
> | `drive.file` | スクリプトが作成したファイルのみアクセス | Sensitive |
> | `spreadsheets` | スプレッドシートの読み書き | Sensitive |
> | `script.external_request` | Gemini API 呼び出し（UrlFetchApp） | Non-sensitive |

```bash
# Step 6: dist/ にもコピー（clasp push 用）
cp appsscript.json dist/appsscript.json
```

---

## 第3章: clasp セットアップ

### 3.1 clasp login（ブラウザ認証フロー）

```bash
# Step 1: clasp にログイン
npx clasp login

# 期待される動作:
# 1. ターミナルに「Logging in globally...」と表示
# 2. デフォルトブラウザが自動的に開く
# 3. Google アカウント選択画面が表示
# 4. 使用するアカウントを選択
# 5. 「clasp – The Apps Script CLI がアクセスをリクエストしています」画面
#    → 「許可」をクリック
# 6. ブラウザに「Logged in! You may close this page.」と表示
# 7. ターミナルに戻ると「Authorization successful.」と表示

# Step 2: ログイン状態を確認
npx clasp login --status
# 期待される結果: You are logged in as <your-email@example.com>
```

**ブラウザ画面の遷移**:

```
[1] Google アカウント選択
    ↓ アカウントをクリック
[2] 権限確認画面
    「clasp – The Apps Script CLI が Google アカウントへのアクセスをリクエストしています」
    - Google Apps Script のプロジェクトを参照、編集
    - Google Apps Script のデプロイメントを管理
    ↓ 「許可」をクリック
[3] 認証完了
    「Logged in! You may close this page.」
```

**認証情報の保存先**: `~/.clasprc.json` に OAuth トークンが保存される。このファイルは **絶対に Git にコミットしない**こと。

### 3.2 Apps Script API の有効化手順（再確認）

前提条件（第1章）で未実施の場合:

```
Step 1: https://script.google.com/home/usersettings にアクセス
Step 2: 「Google Apps Script API」を「オン」に切り替え
```

API が無効のまま clasp コマンドを実行すると以下のエラーが発生する:

```
Error: User has not enabled the Apps Script API. Enable it by visiting
https://script.google.com/home/usersettings then retry.
```

### 3.3 clasp create / clasp clone

**新規プロジェクト作成の場合**:

```bash
# Step 3a: 新規 Apps Script プロジェクトを作成
npx clasp create-script --title "Gmail Client Manager" --type standalone --rootDir ./dist

# 期待される結果:
# Created new script: https://script.google.com/d/xxxxxxx/edit
# .clasp.json が自動生成される
```

**既存プロジェクトをクローンする場合**:

```bash
# Step 3b: 既存のスクリプトIDでクローン
# スクリプトIDの確認方法:
#   Apps Script エディタ → 左メニュー「プロジェクトの設定」→「スクリプト ID」

npx clasp clone-script <your-script-id> --rootDir ./dist

# 期待される結果:
# Cloned X files.
# .clasp.json が自動生成される
```

### 3.4 .clasp.json の完全な内容

clasp create/clone 後に自動生成されるが、`rootDir` の設定を確認・修正する。

```json
{
  "scriptId": "ここに実際のスクリプトIDが入る",
  "rootDir": "./dist"
}
```

| フィールド | 説明 |
|-----------|------|
| `scriptId` | Apps Script プロジェクトの一意識別子。Apps Script エディタ → プロジェクトの設定 → スクリプト ID で確認可能 |
| `rootDir` | clasp push 時にアップロードするディレクトリ。Rollup のビルド出力先 `./dist` を指定 |

> **重要**: `rootDir` を `./dist` に設定することで、Rollup がビルドした JavaScript ファイルのみが Apps Script にプッシュされる。`src/` 配下の TypeScript ファイルは直接プッシュされない。

### 3.5 .claspignore の完全な内容

clasp push 時に除外するファイルを指定する。

```
# テストファイル
**/*.test.js
**/*.test.ts
**/*.spec.js
**/*.spec.ts

# 設定ファイル
node_modules/**
.git/**
test/**
src/**

# ビルド関連
rollup.config.mjs
tsconfig.json
jest.config.js
eslint.config.mjs
.prettierrc

# ドキュメント
*.md
LICENSE

# OS生成ファイル
.DS_Store
Thumbs.db
```

### 3.6 clasp push / clasp pull の動作確認

```bash
# Step 4: まずビルドしてから push（TypeScript → JavaScript → GAS）
npm run build   # この時点ではまだ設定していないため第4章で実施
npx clasp push

# 期待される結果:
# └─ dist/Code.js
# └─ dist/appsscript.json
# Pushed 2 files.

# Step 5: リモートの変更を pull
npx clasp pull

# 期待される結果:
# Pulled X files.
# （dist/ 配下にファイルがダウンロードされる）
```

> **注意**: clasp 3.x では `clasp push` は `rootDir`（= `./dist`）配下のファイルのみをアップロードする。TypeScript ファイルの直接プッシュはサポートされない。

---

## 第4章: TypeScript + Rollup 設定

### 4.1 tsconfig.json の完全な内容

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "strict": true,
    "esModuleInterop": true,
    "forceConsistentCasingInImports": true,
    "skipLibCheck": true,
    "declaration": false,
    "declarationMap": false,
    "sourceMap": false,
    "outDir": "./dist",
    "rootDir": "./src",
    "types": ["google-apps-script", "jest"]
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist", "test"]
}
```

**各オプションの説明**:

| オプション | 値 | 説明 |
|-----------|-----|------|
| `target` | `ES2022` | V8 ランタイムが ES2022 をサポート |
| `module` | `ESNext` | Rollup が ESM モジュールを処理するため |
| `moduleResolution` | `bundler` | バンドラー環境での解決戦略 |
| `lib` | `["ES2022"]` | 使用する標準ライブラリ（DOM は不要） |
| `strict` | `true` | 厳密な型チェックを有効化 |
| `esModuleInterop` | `true` | CommonJS モジュールとの互換性 |
| `types` | `["google-apps-script", "jest"]` | GAS グローバル型 + Jest テスト型 |
| `outDir` | `./dist` | コンパイル出力先（Rollup が使用） |
| `rootDir` | `./src` | ソースコードのルート |

### 4.2 rollup.config.mjs の完全な内容

```javascript
import typescript from '@rollup/plugin-typescript';
import resolve from '@rollup/plugin-node-resolve';
import gas from 'rollup-plugin-gas';

export default {
  input: 'src/index.ts',
  output: {
    dir: 'dist',
    entryFileNames: 'Code.js',
    format: 'umd',
    name: 'GmailClientManager',
  },
  plugins: [
    resolve(),
    typescript({
      tsconfig: './tsconfig.json',
    }),
    gas(),
  ],
};
```

**各プラグインの説明**:

| プラグイン | 役割 |
|-----------|------|
| `@rollup/plugin-node-resolve` | `node_modules` 内の NPM パッケージを解決する。外部ライブラリを使用する場合に必要 |
| `@rollup/plugin-typescript` | TypeScript → JavaScript のトランスパイル。`tsconfig.json` の設定に従う |
| `rollup-plugin-gas` | GAS 互換の出力を生成。`global` に代入された関数をトップレベル関数宣言に変換する。GAS はトップレベル関数のみをトリガーや `google.script.run` から呼び出せるため必須 |

**出力設定の説明**:

| 設定 | 値 | 説明 |
|------|-----|------|
| `dir` | `dist` | 出力ディレクトリ。clasp の `rootDir` と一致させる |
| `entryFileNames` | `Code.js` | 出力ファイル名。GAS の慣例に従う |
| `format` | `umd` | UMD（Universal Module Definition）形式。`rollup-plugin-gas` が要求 |
| `name` | `GmailClientManager` | UMD モジュール名 |

### 4.3 @types/google-apps-script の導入

第2章のインストールで導入済み。このパッケージにより、以下のグローバルオブジェクトの型補完が有効になる:

- `GmailApp` — Gmail 操作
- `DriveApp` — Google Drive 操作
- `SpreadsheetApp` — スプレッドシート操作
- `UrlFetchApp` — HTTP リクエスト（Gemini API 呼び出し）
- `PropertiesService` — スクリプトプロパティ管理
- `Utilities` — Blob 変換、Base64 エンコード等
- `Logger` — ログ出力
- `ScriptApp` — トリガー管理

**VSCode での型補完確認**:

```typescript
// src/index.ts に以下を入力
GmailApp.  // ← ドット入力で補完候補が表示されることを確認
```

### 4.4 ビルドコマンド（npm run build）の設定

`package.json` の `scripts` に追加:

```json
{
  "scripts": {
    "build": "rollup -c rollup.config.mjs"
  }
}
```

### 4.5 エントリーポイント（src/index.ts）のサンプル

GAS で呼び出し可能な関数は `global` オブジェクトに代入する:

```typescript
// src/index.ts
// GAS のエントリーポイント — global に代入した関数がトップレベル関数としてエクスポートされる

/**
 * メイン処理: 未処理メールを取得し、処理する
 * トリガーから呼び出される関数
 */
function processEmails(): void {
  Logger.log('processEmails started');
  // TODO: Phase 1 で実装
}

/**
 * 日次メンテナンス: 古い処理済みIDの削除、ログ整理
 */
function dailyMaintenance(): void {
  Logger.log('dailyMaintenance started');
  // TODO: 実装
}

/**
 * 初期セットアップ: トリガー登録
 * 手動で1回だけ実行する関数
 */
function setup(): void {
  // 既存のトリガーを削除
  const triggers = ScriptApp.getProjectTriggers();
  for (const trigger of triggers) {
    ScriptApp.deleteTrigger(trigger);
  }

  // 5分間隔のメイン処理トリガー
  ScriptApp.newTrigger('processEmails')
    .timeBased()
    .everyMinutes(5)
    .create();

  // 日次メンテナンストリガー（毎日午前2時）
  ScriptApp.newTrigger('dailyMaintenance')
    .timeBased()
    .atHour(2)
    .everyDays(1)
    .create();

  Logger.log('Triggers created successfully');
}

// rollup-plugin-gas が認識するためにグローバルに公開
declare const global: Record<string, unknown>;
global.processEmails = processEmails;
global.dailyMaintenance = dailyMaintenance;
global.setup = setup;
```

### 4.6 ビルド→push の一連のフロー確認

```bash
# Step 1: ビルド（TypeScript → JavaScript）
npm run build

# 期待される結果:
# （エラーなく完了）
# dist/Code.js が生成される

# Step 2: ビルド出力を確認
ls dist/
# 期待される結果:
# Code.js  appsscript.json

# Step 3: Apps Script にプッシュ
npx clasp push

# 期待される結果:
# └─ dist/Code.js
# └─ dist/appsscript.json
# Pushed 2 files.

# Step 4: Apps Script エディタで確認
npx clasp open-script
# 期待される結果: ブラウザでApps Scriptエディタが開き、
#                Code.js にビルドされたコードが表示される
```

---

## 第5章: テスト環境（Jest）

### 5.1 jest.config.js の完全な内容

```javascript
/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/index.ts',
  ],
  coverageDirectory: 'coverage',
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
  setupFiles: ['<rootDir>/test/mocks/gas-globals.ts'],
};
```

**各設定の説明**:

| 設定 | 値 | 説明 |
|------|-----|------|
| `preset` | `ts-jest` | TypeScript テストを直接実行 |
| `testEnvironment` | `node` | Node.js 環境（ブラウザ DOM 不要） |
| `roots` | `['<rootDir>/test']` | テストファイルの検索ディレクトリ |
| `testMatch` | `['**/*.test.ts']` | テストファイルのパターン |
| `collectCoverageFrom` | `src/**/*.ts` | カバレッジ計測対象 |
| `coverageThreshold` | 80% | 最低カバレッジ閾値 |
| `setupFiles` | `gas-globals.ts` | GAS グローバルのモックセットアップ（テスト実行前に読み込み） |

### 5.2 GAS グローバルのモック方法

**test/mocks/gas-globals.ts の完全な内容**:

```typescript
// test/mocks/gas-globals.ts
// GAS グローバルオブジェクトのモック定義
// Jest の setupFilesAfterSetup で自動読み込みされる

// --- GmailApp ---
const mockGmailApp = {
  search: jest.fn().mockReturnValue([]),
  getInboxThreads: jest.fn().mockReturnValue([]),
  getUserLabelByName: jest.fn().mockReturnValue(null),
  createLabel: jest.fn(),
};

// --- DriveApp ---
const mockFolder = {
  createFile: jest.fn().mockReturnValue({
    getUrl: jest.fn().mockReturnValue('https://drive.google.com/file/d/xxx/view'),
    getId: jest.fn().mockReturnValue('file-id-123'),
    setName: jest.fn(),
  }),
  getFoldersByName: jest.fn().mockReturnValue({
    hasNext: jest.fn().mockReturnValue(false),
    next: jest.fn(),
  }),
  createFolder: jest.fn(),
};

const mockDriveApp = {
  getFolderById: jest.fn().mockReturnValue(mockFolder),
  getRootFolder: jest.fn().mockReturnValue(mockFolder),
};

// --- SpreadsheetApp ---
const mockRange = {
  getValues: jest.fn().mockReturnValue([[]]),
  setValues: jest.fn(),
  setValue: jest.fn(),
  getValue: jest.fn(),
};

const mockSheet = {
  getRange: jest.fn().mockReturnValue(mockRange),
  getLastRow: jest.fn().mockReturnValue(1),
  appendRow: jest.fn(),
  getName: jest.fn().mockReturnValue('メール一覧'),
};

const mockSpreadsheet = {
  getSheetByName: jest.fn().mockReturnValue(mockSheet),
  getActiveSheet: jest.fn().mockReturnValue(mockSheet),
  insertSheet: jest.fn().mockReturnValue(mockSheet),
};

const mockSpreadsheetApp = {
  openById: jest.fn().mockReturnValue(mockSpreadsheet),
  getActiveSpreadsheet: jest.fn().mockReturnValue(mockSpreadsheet),
};

// --- UrlFetchApp ---
const mockUrlFetchApp = {
  fetch: jest.fn().mockReturnValue({
    getContentText: jest.fn().mockReturnValue('{}'),
    getResponseCode: jest.fn().mockReturnValue(200),
  }),
};

// --- PropertiesService ---
const mockProperties = {
  getProperty: jest.fn().mockReturnValue(null),
  setProperty: jest.fn(),
  deleteProperty: jest.fn(),
  getProperties: jest.fn().mockReturnValue({}),
};

const mockPropertiesService = {
  getScriptProperties: jest.fn().mockReturnValue(mockProperties),
  getUserProperties: jest.fn().mockReturnValue(mockProperties),
};

// --- Utilities ---
const mockUtilities = {
  newBlob: jest.fn().mockReturnValue({
    getAs: jest.fn().mockReturnValue({
      getBytes: jest.fn().mockReturnValue([]),
      setName: jest.fn(),
    }),
    setName: jest.fn(),
    getContentType: jest.fn().mockReturnValue('application/pdf'),
  }),
  formatDate: jest.fn().mockReturnValue('2026/02/12 10:00'),
  base64Encode: jest.fn().mockReturnValue('base64string'),
  sleep: jest.fn(),
};

// --- Logger ---
const mockLogger = {
  log: jest.fn(),
};

// --- ScriptApp ---
const mockScriptApp = {
  getProjectTriggers: jest.fn().mockReturnValue([]),
  deleteTrigger: jest.fn(),
  newTrigger: jest.fn().mockReturnValue({
    timeBased: jest.fn().mockReturnValue({
      everyMinutes: jest.fn().mockReturnValue({
        create: jest.fn(),
      }),
      atHour: jest.fn().mockReturnValue({
        everyDays: jest.fn().mockReturnValue({
          create: jest.fn(),
        }),
      }),
    }),
  }),
};

// グローバルに登録
Object.assign(global, {
  GmailApp: mockGmailApp,
  DriveApp: mockDriveApp,
  SpreadsheetApp: mockSpreadsheetApp,
  UrlFetchApp: mockUrlFetchApp,
  PropertiesService: mockPropertiesService,
  Utilities: mockUtilities,
  Logger: mockLogger,
  ScriptApp: mockScriptApp,
});
```

### 5.3 サンプルテストファイルの作成と実行

**test/rules.test.ts の例**:

```typescript
// test/rules.test.ts
import { matchClient, EmailRule } from '../src/rules';

describe('matchClient', () => {
  const rules: EmailRule[] = [
    {
      clientId: 'CL001',
      clientName: '株式会社ABC',
      emailPattern: '*@abc-corp.co.jp',
      spreadsheetId: 'sheet-id-001',
      driveFolderId: 'folder-id-001',
    },
    {
      clientId: 'CL002',
      clientName: '○○法律事務所',
      emailPattern: 'tanaka@lawfirm.jp',
      spreadsheetId: 'sheet-id-002',
      driveFolderId: 'folder-id-002',
    },
  ];

  test('should match client by domain pattern', () => {
    const result = matchClient('info@abc-corp.co.jp', rules);
    expect(result).toBeDefined();
    expect(result?.clientId).toBe('CL001');
  });

  test('should match client by exact email', () => {
    const result = matchClient('tanaka@lawfirm.jp', rules);
    expect(result).toBeDefined();
    expect(result?.clientId).toBe('CL002');
  });

  test('should return null for unknown sender', () => {
    const result = matchClient('unknown@example.com', rules);
    expect(result).toBeNull();
  });
});
```

**対応する src/rules.ts のスタブ**（テストファースト — まず型定義のみ）:

```typescript
// src/rules.ts
export interface EmailRule {
  clientId: string;
  clientName: string;
  emailPattern: string;
  spreadsheetId: string;
  driveFolderId: string;
}

export function matchClient(
  senderEmail: string,
  rules: EmailRule[]
): EmailRule | null {
  // TODO: 実装
  return null;
}
```

### 5.4 テスト実行の確認

```bash
# Step 1: テスト実行
npx jest

# 期待される結果（TDD: RED フェーズ — 一部テストが失敗）:
# FAIL  test/rules.test.ts
#   matchClient
#     ✕ should match client by domain pattern
#     ✕ should match client by exact email
#     ✓ should return null for unknown sender
#
# Tests:       2 failed, 1 passed, 3 total

# Step 2: 実装後にテスト再実行（GREEN フェーズ）
npx jest

# 期待される結果:
# PASS  test/rules.test.ts
#   matchClient
#     ✓ should match client by domain pattern
#     ✓ should match client by exact email
#     ✓ should return null for unknown sender
#
# Tests:       3 passed, 3 total
```

### 5.5 カバレッジ計測

```bash
# Step 3: カバレッジ付きでテスト実行
npx jest --coverage

# 期待される結果:
# -----------|---------|----------|---------|---------|
# File       | % Stmts | % Branch | % Funcs | % Lines |
# -----------|---------|----------|---------|---------|
# All files  |   85.71 |    83.33 |     100 |   85.71 |
#  rules.ts  |   85.71 |    83.33 |     100 |   85.71 |
# -----------|---------|----------|---------|---------|
#
# 80% 以上であることを確認
```

---

## 第6章: コード品質（ESLint + Prettier）

### 6.1 eslint.config.mjs の完全な内容

> **注意**: ESLint 9.x では Flat Config 形式（`eslint.config.mjs`）が標準。従来の `.eslintrc.js` は非推奨。

```javascript
// eslint.config.mjs
import tseslint from '@typescript-eslint/eslint-plugin';
import tsparser from '@typescript-eslint/parser';
import prettierConfig from 'eslint-config-prettier';

export default [
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 2022,
        sourceType: 'module',
      },
      globals: {
        // GAS グローバル変数を認識させる
        GmailApp: 'readonly',
        DriveApp: 'readonly',
        SpreadsheetApp: 'readonly',
        UrlFetchApp: 'readonly',
        PropertiesService: 'readonly',
        Utilities: 'readonly',
        Logger: 'readonly',
        ScriptApp: 'readonly',
        ContentService: 'readonly',
        HtmlService: 'readonly',
        Session: 'readonly',
        CacheService: 'readonly',
        LockService: 'readonly',
        console: 'readonly',
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {
      ...tseslint.configs.recommended.rules,
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/explicit-function-return-type': 'warn',
      '@typescript-eslint/no-explicit-any': 'warn',
      'no-console': 'warn',
    },
  },
  {
    files: ['test/**/*.ts'],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 2022,
        sourceType: 'module',
      },
      globals: {
        jest: 'readonly',
        describe: 'readonly',
        test: 'readonly',
        expect: 'readonly',
        beforeEach: 'readonly',
        afterEach: 'readonly',
        beforeAll: 'readonly',
        afterAll: 'readonly',
        GmailApp: 'readonly',
        DriveApp: 'readonly',
        SpreadsheetApp: 'readonly',
        UrlFetchApp: 'readonly',
        PropertiesService: 'readonly',
        Utilities: 'readonly',
        Logger: 'readonly',
        ScriptApp: 'readonly',
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {
      ...tseslint.configs.recommended.rules,
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
  prettierConfig,
];
```

### 6.2 .prettierrc の完全な内容

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100,
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

| 設定 | 値 | 説明 |
|------|-----|------|
| `semi` | `true` | セミコロンあり |
| `singleQuote` | `true` | シングルクォート使用 |
| `tabWidth` | `2` | インデント2スペース |
| `trailingComma` | `es5` | ES5 互換の末尾カンマ |
| `printWidth` | `100` | 行の最大文字数 |
| `endOfLine` | `lf` | 改行コード LF（Unix/macOS/WSL2 標準） |

### 6.3 package.json の scripts 設定

```json
{
  "scripts": {
    "lint": "eslint 'src/**/*.ts' 'test/**/*.ts'",
    "lint:fix": "eslint 'src/**/*.ts' 'test/**/*.ts' --fix",
    "format": "prettier --write 'src/**/*.ts' 'test/**/*.ts'",
    "format:check": "prettier --check 'src/**/*.ts' 'test/**/*.ts'"
  }
}
```

**実行確認**:

```bash
# Step 1: リント実行
npm run lint

# 期待される結果（問題がない場合）:
# （出力なし — エラーも警告もない）

# Step 2: フォーマットチェック
npm run format:check

# 期待される結果（フォーマット済みの場合）:
# Checking formatting...
# All matched files use Prettier code style!

# Step 3: 自動修正
npm run lint:fix
npm run format
```

### 6.4 VSCode 連携（推奨拡張機能リスト）

以下の拡張機能を VSCode にインストールすることを推奨:

| 拡張機能 | ID | 用途 |
|---------|-----|------|
| ESLint | `dbaeumer.vscode-eslint` | リアルタイムのリントエラー表示 |
| Prettier | `esbenp.prettier-vscode` | 保存時の自動フォーマット |
| TypeScript Importer | `pmneo.tsimporter` | import 文の自動補完 |

**VSCode 設定（.vscode/settings.json）の推奨内容**:

```json
{
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "typescript.tsdk": "node_modules/typescript/lib"
}
```

---

## 第7章: Git + GitHub 設定

### 7.1 .gitignore の完全な内容

```
# 依存関係
node_modules/

# ビルド出力
dist/

# カバレッジ
coverage/

# clasp 認証情報（絶対にコミットしない）
.clasprc.json

# 環境変数・シークレット
.env
.env.local
.env.*.local

# エディタ設定
.vscode/
.idea/
*.swp
*.swo
*~

# OS 生成ファイル
.DS_Store
Thumbs.db

# ログ
npm-debug.log*
yarn-debug.log*
yarn-error.log*
```

> **重要**: `.clasprc.json` は OAuth トークンを含むため、`.gitignore` への記載は**必須**。万が一コミットした場合は、即座にトークンを失効させ（`clasp logout` → `clasp login`）、Git 履歴から削除すること。

### 7.2 リポジトリ作成と初回コミットのコマンド

```bash
# Step 1: Git リポジトリ初期化
git init

# Step 2: 初回コミット用にファイルをステージング
git add .gitignore package.json package-lock.json \
  tsconfig.json rollup.config.mjs jest.config.js \
  eslint.config.mjs .prettierrc \
  appsscript.json .clasp.json .claspignore \
  src/ test/

# Step 3: 初回コミット
git commit -m "feat: プロジェクト初期構成（TypeScript + Rollup + Jest + ESLint）"

# Step 4: GitHub リポジトリ作成（gh CLI 使用）
gh repo create gmail-client-manager --private --source=. --remote=origin

# 期待される結果:
# ✓ Created repository <username>/gmail-client-manager on GitHub
# ✓ Added remote origin

# Step 5: プッシュ
git push -u origin main
```

> **GitHub CLI (`gh`) がない場合**: GitHub Web UI でリポジトリを作成し、`git remote add origin <URL>` で手動設定する。

### 7.3 ブランチ戦略

| ブランチ | 用途 | デプロイ先 | 保護ルール |
|---------|------|-----------|-----------|
| `main` | 本番コード | 本番 Apps Script（自動デプロイ） | PR 必須、レビュー必須 |
| `develop` | 開発統合 | ステージング Apps Script（自動デプロイ） | PR 必須 |
| `feature/*` | 機能開発 | デプロイなし（テストのみ） | なし |

```bash
# develop ブランチの作成
git checkout -b develop
git push -u origin develop
```

---

## 第8章: GitHub Actions CI/CD

### 8.1 .github/workflows/deploy.yaml の完全な内容

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

permissions:
  contents: read

jobs:
  # ===== テスト・リント・ビルドチェック =====
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Format check
        run: npm run format:check

      - name: Run tests with coverage
        run: npm test -- --coverage --ci

      - name: Build
        run: npm run build

  # ===== ステージングデプロイ（develop ブランチ） =====
  deploy-staging:
    needs: test
    if: github.ref == 'refs/heads/develop' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Setup clasp credentials
        run: echo '${{ secrets.CLASPRC_JSON }}' > ~/.clasprc.json

      - name: Verify clasp login
        run: npx clasp login --status

      - name: Push to staging
        run: npx clasp push --project .clasp.staging.json --force

  # ===== 本番デプロイ（main ブランチ） =====
  deploy-production:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Setup clasp credentials
        run: echo '${{ secrets.CLASPRC_JSON }}' > ~/.clasprc.json

      - name: Verify clasp login
        run: npx clasp login --status

      - name: Push to production
        run: npx clasp push --project .clasp.prod.json --force

      - name: Create version and deploy
        run: |
          npx clasp create-version --project .clasp.prod.json "Auto-deploy from ${{ github.sha }}"
          npx clasp create-deployment --project .clasp.prod.json --description "Production deploy - ${{ github.sha }}"
```

### 8.2 GitHub Secrets の設定手順

#### CLASPRC_JSON の取得方法と登録手順

```bash
# Step 1: ローカルで clasp にログイン済みであることを確認
npx clasp login --status
# 期待される結果: You are logged in as <your-email>

# Step 2: .clasprc.json の内容を確認
cat ~/.clasprc.json
# 期待される結果（以下のような JSON）:
# {
#   "token": {
#     "access_token": "ya29.xxxxx...",
#     "refresh_token": "1//xxxxx...",
#     "scope": "https://www.googleapis.com/auth/...",
#     "token_type": "Bearer",
#     "expiry_date": 1234567890000
#   },
#   "oauth2ClientSettings": {
#     "clientId": "xxxxx.apps.googleusercontent.com",
#     "clientSecret": "xxxxx",
#     "redirectUri": "http://localhost"
#   },
#   "isLocalCreds": false
# }

# Step 3: 内容をクリップボードにコピー
# macOS:
cat ~/.clasprc.json | pbcopy
# Linux/WSL2:
cat ~/.clasprc.json | xclip -selection clipboard
# Windows (PowerShell):
Get-Content ~/.clasprc.json | Set-Clipboard
```

```
Step 4: GitHub リポジトリの Settings ページを開く
        https://github.com/<username>/gmail-client-manager/settings

Step 5: 左メニュー「Secrets and variables」→「Actions」をクリック

Step 6: 「New repository secret」ボタンをクリック

Step 7: 以下を入力:
        Name: CLASPRC_JSON
        Secret: （Step 3 でコピーした .clasprc.json の内容を貼り付け）

Step 8: 「Add secret」ボタンをクリック
```

#### その他必要な Secrets

| Secret 名 | 内容 | 必須 |
|-----------|------|------|
| `CLASPRC_JSON` | `.clasprc.json` の内容全体 | 必須 |

> **注意**: `access_token` には有効期限がある。`refresh_token` で自動更新されるが、長期間（6ヶ月以上）未使用で失効する場合がある。週次の認証チェック（下記）を設定すると安全。

#### 週次認証チェック（オプション）

```yaml
# .github/workflows/auth-check.yaml
name: Weekly Auth Check

on:
  schedule:
    - cron: '0 0 * * 1'  # 毎週月曜日 00:00 UTC

jobs:
  check-auth:
    runs-on: ubuntu-latest
    steps:
      - name: Setup clasp credentials
        run: echo '${{ secrets.CLASPRC_JSON }}' > ~/.clasprc.json

      - name: Install clasp
        run: npm install -g @google/clasp

      - name: Verify login
        run: clasp login --status
```

### 8.3 ブランチ別デプロイ設定

deploy.yaml（上記）に記載済み:

| ブランチ | トリガー | 動作 |
|---------|---------|------|
| `feature/*` | PR 作成時 | テスト + リント + ビルドチェックのみ |
| `develop` | push 時 | テスト → ステージングデプロイ |
| `main` | push 時 | テスト → 本番デプロイ + バージョン作成 |

### 8.4 ワークフローの動作確認方法

```bash
# Step 1: feature ブランチで作業後、develop に PR を作成
git checkout -b feature/initial-setup
git add .
git commit -m "feat: 初期セットアップ完了"
git push -u origin feature/initial-setup

# Step 2: GitHub で PR 作成
gh pr create --base develop --title "feat: 初期セットアップ" --body "プロジェクト初期構成"

# Step 3: GitHub Actions タブで CI の実行を確認
#         https://github.com/<username>/gmail-client-manager/actions

# 期待される結果:
# ✓ test  — Lint, Format check, Tests, Build すべて通過
```

---

## 第9章: 複数環境の管理

### 9.1 環境構成の概要

| 環境 | 用途 | Apps Script プロジェクト | clasp 設定ファイル |
|------|------|----------------------|------------------|
| 開発 | ローカル開発・テスト | 開発用プロジェクト | `.clasp.json`（デフォルト） |
| ステージング | 統合テスト・受入テスト | ステージング用プロジェクト | `.clasp.staging.json` |
| 本番 | 実運用 | 本番用プロジェクト | `.clasp.prod.json` |

### 9.2 各環境の Apps Script プロジェクト作成手順

```bash
# Step 1: 開発環境（既に作成済み）
# .clasp.json が存在することを確認

# Step 2: ステージング環境を作成
npx clasp create-script --title "Gmail Client Manager [STAGING]" --type standalone --rootDir ./dist
# 生成された .clasp.json を .clasp.staging.json にリネーム
mv .clasp.json .clasp.staging.json

# Step 3: 本番環境を作成
npx clasp create-script --title "Gmail Client Manager [PRODUCTION]" --type standalone --rootDir ./dist
# 生成された .clasp.json を .clasp.prod.json にリネーム
mv .clasp.json .clasp.prod.json

# Step 4: 開発環境の .clasp.json を復元
# （事前にバックアップした開発用の scriptId を使用）
```

> **注意**: 各環境で別々の Apps Script プロジェクト（= 別々の scriptId）を使用する。これにより、ステージングでの動作確認が本番に影響しない。

### 9.3 .clasp.staging.json の完全な内容

```json
{
  "scriptId": "ステージング環境のスクリプトID",
  "rootDir": "./dist"
}
```

### 9.4 .clasp.prod.json の完全な内容

```json
{
  "scriptId": "本番環境のスクリプトID",
  "rootDir": "./dist"
}
```

### 9.5 開発環境用 .clasp.json（デフォルト）の完全な内容

```json
{
  "scriptId": "開発環境のスクリプトID",
  "rootDir": "./dist"
}
```

### 9.6 環境別の appsscript.json

基本構成は全環境共通。環境固有の差分がある場合のみ分離する。

**全環境共通の appsscript.json**:

```json
{
  "timeZone": "Asia/Tokyo",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "oauthScopes": [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.labels",
    "https://www.googleapis.com/auth/drive.file",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/script.external_request"
  ]
}
```

> 全環境で同じ OAuth スコープを使用する（権限の差異による予期しない動作を防ぐため）。環境ごとの設定差異（Gemini API キー、対象スプレッドシート ID 等）は GAS の Script Properties で管理する。

### 9.7 環境切り替えコマンド

```bash
# 開発環境に push（デフォルト）
npx clasp push

# ステージング環境に push
npx clasp push --project .clasp.staging.json

# 本番環境に push
npx clasp push --project .clasp.prod.json

# 本番環境からバージョン作成 + デプロイ
npx clasp create-version --project .clasp.prod.json "v1.0.0 初期リリース"
npx clasp create-deployment --project .clasp.prod.json --description "Production v1.0.0"
```

---

## 第10章: package.json スクリプト一覧

### 10.1 全 npm scripts の一覧と説明

| スクリプト | コマンド | 説明 |
|-----------|---------|------|
| `build` | `rollup -c rollup.config.mjs` | TypeScript → JavaScript ビルド |
| `push` | `npm run build && npx clasp push` | ビルド + 開発環境へ push |
| `push:staging` | `npm run build && npx clasp push --project .clasp.staging.json` | ビルド + ステージングへ push |
| `push:prod` | `npm run build && npx clasp push --project .clasp.prod.json` | ビルド + 本番へ push |
| `deploy` | `npm run push:prod && npx clasp create-version --project .clasp.prod.json && npx clasp create-deployment --project .clasp.prod.json` | 本番デプロイ（push + version + deploy） |
| `test` | `jest` | テスト実行 |
| `test:watch` | `jest --watch` | テスト監視モード |
| `test:coverage` | `jest --coverage` | カバレッジ付きテスト |
| `lint` | `eslint 'src/**/*.ts' 'test/**/*.ts'` | リント実行 |
| `lint:fix` | `eslint 'src/**/*.ts' 'test/**/*.ts' --fix` | リント自動修正 |
| `format` | `prettier --write 'src/**/*.ts' 'test/**/*.ts'` | コードフォーマット |
| `format:check` | `prettier --check 'src/**/*.ts' 'test/**/*.ts'` | フォーマットチェック |
| `open` | `npx clasp open-script` | Apps Script エディタを開く |
| `pull` | `npx clasp pull` | リモートからファイルを取得 |
| `logs` | `npx clasp tail-logs --watch --simplified` | ログのリアルタイム表示 |

### 10.2 package.json の完全な内容

```json
{
  "name": "gmail-client-manager",
  "version": "1.0.0",
  "description": "Gmail自動管理システム — クライアント別メール処理・PDF変換・Gemini要約",
  "private": true,
  "scripts": {
    "build": "rollup -c rollup.config.mjs",
    "push": "npm run build && npx clasp push",
    "push:staging": "npm run build && npx clasp push --project .clasp.staging.json",
    "push:prod": "npm run build && npx clasp push --project .clasp.prod.json",
    "deploy": "npm run push:prod && npx clasp create-version --project .clasp.prod.json && npx clasp create-deployment --project .clasp.prod.json",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint 'src/**/*.ts' 'test/**/*.ts'",
    "lint:fix": "eslint 'src/**/*.ts' 'test/**/*.ts' --fix",
    "format": "prettier --write 'src/**/*.ts' 'test/**/*.ts'",
    "format:check": "prettier --check 'src/**/*.ts' 'test/**/*.ts'",
    "open": "npx clasp open-script",
    "pull": "npx clasp pull",
    "logs": "npx clasp tail-logs --watch --simplified"
  },
  "devDependencies": {
    "@google/clasp": "^3.1.3",
    "@rollup/plugin-node-resolve": "^16.0.0",
    "@rollup/plugin-typescript": "^12.1.0",
    "@types/google-apps-script": "^1.0.83",
    "@types/jest": "^29.5.0",
    "@typescript-eslint/eslint-plugin": "^8.20.0",
    "@typescript-eslint/parser": "^8.20.0",
    "eslint": "^9.18.0",
    "eslint-config-prettier": "^10.0.0",
    "eslint-plugin-googleappsscript": "^1.0.1",
    "jest": "^29.7.0",
    "prettier": "^3.4.0",
    "rollup": "^4.30.0",
    "rollup-plugin-gas": "^2.0.2",
    "ts-jest": "^29.2.0",
    "tslib": "^2.8.0",
    "typescript": "^5.7.0"
  },
  "engines": {
    "node": ">=20.0.0"
  }
}
```

> **注意**: バージョン番号は 2026年2月時点の推奨値。`npm install` 時に semver 範囲内の最新版が解決される。バージョンを固定したい場合は `package-lock.json` を Git にコミットし、`npm ci` でインストールする。

---

## 第11章: 日常の開発ワークフロー

### 11.1 新機能開発の流れ

```bash
# Step 1: develop ブランチを最新に更新
git checkout develop
git pull origin develop

# Step 2: feature ブランチを作成
git checkout -b feature/email-filtering

# Step 3: テストファーストで開発（TDD）
# 3a: テストを書く（RED）
# test/gmail-manager.test.ts にテストケースを追加

# 3b: テスト実行 → 失敗を確認
npm test
# 期待: FAIL（まだ実装していないため）

# 3c: 最小限の実装（GREEN）
# src/gmail-manager.ts に実装を追加

# 3d: テスト実行 → 成功を確認
npm test
# 期待: PASS

# 3e: リファクタリング（IMPROVE）
# コードを整理

# Step 4: リント + フォーマット
npm run lint:fix
npm run format

# Step 5: ビルド確認
npm run build

# Step 6: ローカルで push（開発環境）
npm run push

# Step 7: Apps Script エディタで動作確認
npm run open
# エディタ上で関数を手動実行して動作確認

# Step 8: コミット + プッシュ
git add .
git commit -m "feat: メールフィルタリング機能を追加"
git push -u origin feature/email-filtering

# Step 9: PR 作成（develop ブランチ向け）
gh pr create --base develop --title "feat: メールフィルタリング機能" \
  --body "## 概要
- メールの送信者アドレスでクライアントを判定
- マスタースプレッドシートのルールに基づいて振り分け

## テスト
- matchClient のユニットテスト追加（カバレッジ 85%）"
```

### 11.2 ステージングでの動作確認手順

```bash
# Step 1: develop ブランチに PR をマージ
# GitHub UI で PR をマージ、または:
git checkout develop
git merge feature/email-filtering
git push origin develop

# Step 2: GitHub Actions が自動でステージングにデプロイ
# Actions タブで deploy-staging ジョブの成功を確認

# Step 3: ステージング環境で動作確認
# ステージング用の Apps Script エディタを開く
npx clasp open-script --project .clasp.staging.json

# Step 4: エディタ上で関数を手動実行
# 「実行」ボタン → processEmails() を選択 → 実行
# 「実行ログ」で結果を確認

# Step 5: トリガーを設定して自動実行を確認
# エディタ上で setup() を手動実行 → トリガーが登録される
# 5分後にトリガーが発火し、processEmails() が自動実行される

# Step 6: ログの確認
npx clasp tail-logs --project .clasp.staging.json --watch --simplified
```

### 11.3 本番デプロイの手順

```bash
# Step 1: develop → main の PR を作成
gh pr create --base main --head develop \
  --title "release: v1.0.0 初期リリース" \
  --body "ステージングで動作確認済み"

# Step 2: PR をマージ（GitHub UI）

# Step 3: GitHub Actions が自動で本番デプロイ
# Actions タブで deploy-production ジョブの成功を確認

# Step 4: 本番環境の Apps Script エディタで動作確認
npx clasp open-script --project .clasp.prod.json

# Step 5: デプロイメント一覧を確認
npx clasp list-deployments --project .clasp.prod.json
```

### 11.4 ロールバック手順

```bash
# Step 1: 現在のデプロイメントとバージョンを確認
npx clasp list-deployments --project .clasp.prod.json
npx clasp list-versions --project .clasp.prod.json

# 出力例:
# Deployments:
# - AKfycbx... @3 - Production deploy - abc1234
# - AKfycby... @2 - Production deploy - def5678
#
# Versions:
# 1 - v1.0.0 初期リリース
# 2 - v1.1.0 フィルタリング機能追加
# 3 - v1.2.0 PDF変換追加（← 問題のあるバージョン）

# Step 2: 前バージョンにロールバック
# デプロイメントIDと戻したいバージョン番号を指定
npx clasp create-deployment --project .clasp.prod.json \
  --versionNumber 2 \
  --description "Rollback to v1.1.0"

# Step 3: ロールバック後の動作確認
npx clasp open-script --project .clasp.prod.json

# Step 4: Git でも revert
git revert HEAD
git push origin main
```

---

## 第12章: トラブルシューティング

### 12.1 clasp login が失敗する場合

**症状**: `clasp login` でブラウザが開かない、または認証エラーが発生する

**原因と解決策**:

| 原因 | 解決策 |
|------|--------|
| ポートが使用中 | `clasp login --redirect-port 3000` で別ポートを指定 |
| WSL2 でブラウザが開かない | `clasp login --no-localhost` を使用。URL が表示されるので手動でブラウザに貼り付け |
| Google アカウントの2段階認証 | 通常の認証フローで対応可能。アプリパスワードは不要 |
| 組織ポリシーでブロック | Google Workspace 管理者にサードパーティアプリのアクセス許可を依頼 |

```bash
# WSL2 での代替手順
npx clasp login --no-localhost
# 表示された URL をブラウザに貼り付け → 認証 → リダイレクト URL をコピー
# ターミナルに貼り付けて Enter
```

### 12.2 clasp push でエラーが出る場合

**症状**: `clasp push` が失敗する

| 症状 | 原因 | 解決策 |
|------|------|--------|
| `Error: User has not enabled the Apps Script API` | API 未有効化 | https://script.google.com/home/usersettings で API をオンにする |
| `Error: Script API executable not published` | デプロイ設定の問題 | Apps Script エディタ → デプロイ → API 実行ファイルとしてデプロイ |
| `Error: Files to upload: ...` が空 | `rootDir` が間違っている | `.clasp.json` の `rootDir` が `./dist` であること、`dist/` にファイルがあることを確認 |
| `Error: Unauthorized` | トークン期限切れ | `clasp logout` → `clasp login` で再認証 |
| `Push failed` (一般的) | ファイル内容の問題 | `clasp push --force` を試す。構文エラーがないか確認 |

```bash
# 診断手順
# 1. ログイン状態確認
npx clasp login --status

# 2. rootDir の内容確認
ls -la dist/

# 3. 強制 push
npx clasp push --force
```

### 12.3 TypeScript のコンパイルエラー

**症状**: `npm run build` でコンパイルエラーが発生する

| 症状 | 原因 | 解決策 |
|------|------|--------|
| `Cannot find name 'GmailApp'` | 型定義が見つからない | `npm install --save-dev @types/google-apps-script` を実行。`tsconfig.json` の `types` に `"google-apps-script"` が含まれているか確認 |
| `Cannot find module '...'` | import パスの誤り | 相対パスを確認（`./gmail-manager` 等）。拡張子は不要 |
| `Property 'xxx' does not exist on type 'yyy'` | GAS API の型不一致 | `@types/google-apps-script` を最新版に更新: `npm update @types/google-apps-script` |
| `error TS5109: Option 'moduleResolution' must be set to 'bundler'...` | tsconfig 設定の不整合 | `module` と `moduleResolution` の組み合わせを確認 |

```bash
# 型定義のバージョン確認
npm list @types/google-apps-script

# 最新版に更新
npm update @types/google-apps-script
```

### 12.4 GitHub Actions のデプロイが失敗する場合

**症状**: GitHub Actions のワークフローが失敗する

| 症状 | 原因 | 解決策 |
|------|------|--------|
| `clasp login --status` が失敗 | `CLASPRC_JSON` シークレットが未設定または不正 | GitHub Settings → Secrets → `CLASPRC_JSON` の内容を確認・再設定 |
| `clasp push` が失敗 | トークンの有効期限切れ | ローカルで `clasp logout` → `clasp login` → `~/.clasprc.json` の内容で GitHub Secrets を更新 |
| テストが CI で失敗（ローカルでは成功） | 環境差異 | `node -v` のバージョン、`npm ci` vs `npm install` の差異を確認。CI のログで詳細エラーを確認 |
| `Permission denied` | GitHub Environment の承認が未設定 | GitHub Settings → Environments → Required reviewers を確認 |

```bash
# シークレットの再設定手順
# 1. ローカルで再ログイン
npx clasp logout
npx clasp login

# 2. 新しいトークンを取得
cat ~/.clasprc.json

# 3. GitHub Secrets を更新
# GitHub UI: Settings → Secrets → CLASPRC_JSON → Update
```

### 12.5 GAS の実行時エラー

**症状**: Apps Script エディタや実行ログでエラーが発生する

| 症状 | 原因 | 解決策 |
|------|------|--------|
| `TypeError: Cannot read properties of undefined` | GAS オブジェクトへのアクセスエラー | `null` チェックを追加。スプレッドシート ID やフォルダ ID が正しいか確認 |
| `Exception: Service invoked too many times` | API クォータ超過 | バッチサイズを小さくする（1回あたり処理件数の上限を下げる）。`Utilities.sleep()` で間隔を空ける |
| `Exception: Access denied` | OAuth スコープ不足 | `appsscript.json` の `oauthScopes` を確認。スコープ追加後は再承認が必要 |
| `Exceeded maximum execution time` | 6分の実行時間制限超過 | バッチ処理を導入。1回あたりの処理件数を制限し、残りは次回トリガーで処理 |
| `ScriptError: Authorization is required` | 初回認証未実施 | Apps Script エディタで手動実行 → 認証ダイアログで「許可」をクリック |

```
# GAS 実行ログの確認方法
Step 1: Apps Script エディタを開く（npx clasp open-script）
Step 2: 左メニュー「実行」をクリック
Step 3: 実行履歴が表示される（日時、関数名、ステータス、実行時間）
Step 4: 失敗した実行をクリック → スタックトレースを確認
```

### 12.6 トークンの有効期限切れ

**症状**: `Unauthorized` または `Invalid Credentials` エラー

**原因**: `.clasprc.json` の `access_token` が期限切れ。通常は `refresh_token` で自動更新されるが、以下の場合に失効する:

- Google アカウントのパスワード変更
- セキュリティイベント（不審なログイン検出等）
- 6ヶ月以上 clasp を使用しなかった場合
- Google Workspace 管理者によるトークン失効

**解決策**:

```bash
# Step 1: 現在のログイン状態を確認
npx clasp login --status
# Error が表示される場合はトークンが無効

# Step 2: ログアウト
npx clasp logout

# Step 3: 再ログイン
npx clasp login
# ブラウザで再認証

# Step 4: ログイン成功を確認
npx clasp login --status
# 期待される結果: You are logged in as <your-email>

# Step 5: CI/CD を使用している場合、GitHub Secrets も更新
cat ~/.clasprc.json
# 内容をコピーして GitHub Settings → Secrets → CLASPRC_JSON を更新
```

**予防策**:

- 週次の認証チェックワークフロー（第8章参照）を設定する
- 定期的に `clasp login --status` で有効性を確認する
- チーム開発の場合、共有 Google アカウントではなく、サービス用アカウントの使用を検討する

---

## 付録: クイックスタートチェックリスト

全手順を完了した後、以下のチェックリストで確認する:

- [ ] Node.js 20.x 以上がインストールされている
- [ ] `npm install` が正常に完了した
- [ ] `npx clasp login --status` でログイン済み
- [ ] `.clasp.json` に正しい `scriptId` と `rootDir` が設定されている
- [ ] `npm run build` がエラーなく完了する
- [ ] `npx clasp push` で Apps Script にファイルがプッシュされる
- [ ] `npm test` でテストが実行される
- [ ] `npm run lint` でリントエラーがない
- [ ] `.gitignore` に `.clasprc.json` が含まれている
- [ ] GitHub リポジトリが作成され、コードがプッシュされている
- [ ] （オプション）GitHub Actions が正常に動作する
- [ ] （オプション）ステージング/本番の `.clasp.*.json` が設定されている

---

## 付録: 参考リンク

| 項目 | URL |
|------|-----|
| clasp 公式リポジトリ | https://github.com/google/clasp |
| clasp 公式ドキュメント | https://developers.google.com/apps-script/guides/clasp |
| clasp npm パッケージ | https://www.npmjs.com/package/@google/clasp |
| rollup-plugin-gas | https://github.com/mato533/rollup-plugin-gas |
| apps-script-typescript-rollup-starter | https://github.com/sqrrrl/apps-script-typescript-rollup-starter |
| @types/google-apps-script | https://www.npmjs.com/package/@types/google-apps-script |
| Apps Script API 有効化 | https://script.google.com/home/usersettings |
| GAS クォータ一覧 | https://developers.google.com/apps-script/guides/services/quotas |
| Gemini API 料金 | https://ai.google.dev/gemini-api/docs/pricing |

---

*本手順書は 2026年2月12日時点の情報に基づく。各ツールのバージョン・コマンド体系は予告なく変更される場合がある。実際のセットアップ時は公式ドキュメントで最新情報を確認すること。*

*特に clasp 3.x はアクティブに開発中であり、コマンド名やオプションが変更される可能性がある（例: `create-deployment` / `deploy` のエイリアス関係）。不確実な箇所は `npx clasp --help` で最新のコマンド一覧を確認すること。*
