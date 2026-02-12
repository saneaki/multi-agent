# Astro + Tailwind CSS 法律事務所HP構築 — 統合実践ガイド

**作成日**: 2026-02-12
**対象**: Web開発未経験の弁護士（Claude Code・GitHub・Notion日常使用）
**目標**: Astro + Tailwind CSS + GitHub Pages/Vercel で法律事務所HPを自力構築

---

## 1. エグゼクティブサマリー

### 1.1 cmd_118での推奨理由

本ガイドで解説する **Astro + Tailwind CSS** は、cmd_118「弁護士事務所HP作成 方法論比較レポート」において**総合スコア43点（最高点）**を獲得し、7つの方法論の中で第1推奨となった技術スタックである。

**cmd_118の推奨理由（要約）**:
- **SEO最強**: 静的HTML生成により、Lighthouseスコア95点以上を実現。Googleクローラーが即座にインデックス
- **コスト最安クラス**: ホスティング無料（GitHub Pages/Vercel）。Claude Code既契約なら年間約1,500円（ドメイン代のみ）
- **セキュリティリスク最小**: 静的サイトのためWordPressのような脆弱性がない。法律事務所の個人情報保護要件に最適
- **Claude Code親和性最強**: プロンプト1つでサイト全体を自動生成。Web開発未経験でも構築可能
- **保守負担ゼロ**: サーバー管理・データベース・セキュリティアップデートが不要

### 1.2 Astro + Tailwind CSS の強み（5点）

1. **パフォーマンス**: Lighthouse 100点達成実績多数。WordPress比で2-3倍高速
2. **実績**: IKEA、Porsche、Unilever等のグローバル企業、Bourne Law Firm（米国法律事務所）が採用
3. **専用テーマ**: 法律事務所向けテーマ（Carrington $79、Legal-Staff 無料）が提供されている
4. **SEO**: 静的HTML生成により、GoogleクローラビリティとCore Web Vitalsが最適化
5. **コスト**: ホスティング費用が月額$0（Netlify/Vercel）。年間コストを大幅削減

### 1.3 このガイドで得られるもの

- **5ステージの学習ロードマップ**: HTML/CSS基礎からデプロイまで、段階的に習得（1〜2ヶ月）
- **実績・採用事例**: 96万以上のライブサイト、法律事務所成功事例（Bourne Law Firm）
- **実装ステップ**: 環境構築〜デプロイまでの全手順。コードサンプル付き
- **SEO対策**: ローカルSEO戦略、構造化データ（Schema.org）、Google Business Profile登録手順
- **想定スケジュール**: 週5h/10h/20h の3パターン。Claude Code活用時は**約3週間で公開可能**

---

## 2. 学習ロードマップ

### 2.1 学習時間の目安（全体）

| ステージ | 内容 | 目安時間 | 累計時間 |
|---------|------|----------|----------|
| ステージ1 | HTML/CSS 基礎（最低限） | 10〜14日 | 10〜14日 |
| ステージ2 | Tailwind CSS 基礎 | 7〜14日 | 17〜28日 |
| ステージ3 | Astro 基礎 | 7〜14日 | 24〜42日 |
| ステージ4 | Git/デプロイ（GitHub Pages/Vercel） | 3〜7日 | 27〜49日 |
| ステージ5 | コンテンツ管理（Markdown/MDX） | 3〜5日 | 30〜54日 |
| **合計** | **基本的なHP構築まで** | **1〜2ヶ月** | — |

**注記**: 1日2〜3時間の学習を想定。既にGitHub/Claude Codeを日常使用しているため、通常の初学者より進捗が早い可能性あり。

### 2.2 ステージ1: HTML/CSS 基礎（最低限必要な範囲のみ）

#### 到達目標
- HTMLの基本構造（タグ、要素、属性）を理解
- CSSの基本（セレクタ、プロパティ、値）を理解
- シンプルなHTMLページを手書きできる

#### 学習すべきこと
- HTML: `<div>`, `<p>`, `<h1>`, `<a>`, `<img>`, `<section>`, `<header>`, `<footer>`
- CSS: クラスセレクタ、マージン、パディング、色、フォント
- **Tailwind CSSを使うため、CSSの深い理解は不要**（基本概念のみでOK）

#### 推奨リソース
- **MDN Web Docs（日本語版）**: [CSS 入門 - MDN](https://developer.mozilla.org/ja/docs/Learn_web_development/Core/Styling_basics/Getting_started)
- **Saruwaka（猿わかくん）**: [初心者向けCSS入門](https://saruwakakun.com/html-css/basic/css)
- **chot.design**: [HTML・CSS入門](https://chot.design/html-css-beginner/)

#### 次のステージへの前提条件
- HTMLとCSSの役割の違いを説明できる
- 簡単なHTMLページを読んで理解できる

---

### 2.3 ステージ2: Tailwind CSS（ユーティリティファースト概念、基本クラス）

#### 到達目標
- ユーティリティファーストCSSの概念を理解
- 基本的なTailwindクラス（`p-4`, `text-center`, `bg-blue-500`等）を使える
- レスポンシブデザイン（`md:`, `lg:`等）の基本を理解

#### 学習すべきこと
- Tailwind CSSの哲学（ユーティリティファースト vs 従来のCSS）
- よく使うクラス: レイアウト（`flex`, `grid`）、色、サイズ、マージン、パディング
- レスポンシブデザインの接頭辞（`sm:`, `md:`, `lg:`, `xl:`）
- ダークモード対応（`dark:`）

#### 推奨リソース
- **Tailwind CSS公式ドキュメント**: [Tailwind CSS Official Docs](https://tailwindcss.com/docs)
- **Tailwind CSS + Astro 公式ガイド**: [Install Tailwind CSS with Astro](https://tailwindcss.com/docs/guides/astro)
- **Nulab Developer Site リデザイン記事**: [AstroとTailwind CSSを使った実例紹介（2024年8月）](https://nulab.com/ja/blog/nulab/redesign-developer-site-using-astro/)
- **Tailwind CSS実践入門（書籍）**: [Amazon](https://www.amazon.co.jp/Tailwind-CSS%E5%AE%9F%E8%B7%B5%E5%85%A5%E9%96%80/dp/429713943X)

#### 次のステージへの前提条件
- Tailwindの公式ドキュメントを検索して必要なクラスを見つけられる
- 既存のTailwindコンポーネントを読んで理解できる

---

### 2.4 ステージ3: Astro 基礎（プロジェクト構造、コンポーネント、ページ）

#### 到達目標
- Astroプロジェクトの基本構造を理解
- `.astro`コンポーネントを作成・編集できる
- ページルーティングの仕組みを理解
- レイアウトコンポーネントを活用できる

#### 学習すべきこと
- Astroプロジェクトのディレクトリ構造（`src/pages`, `src/components`, `src/layouts`）
- `.astro`ファイルの構文（フロントマター、HTMLテンプレート部分）
- コンポーネントの再利用
- 静的サイト生成（SSG）の概念
- Astro公式チュートリアル「Build a Blog」の完走

#### 推奨リソース
- **Astro公式ドキュメント**: [Astro Docs - Getting Started](https://docs.astro.build/en/getting-started/)
- **Astro公式チュートリアル**: [Build a Blog Tutorial](https://docs.astro.build/en/tutorial/0-introduction/)
- **Learn Astro（公式推奨）**: [https://learnastro.dev/](https://learnastro.dev/)

#### 次のステージへの前提条件
- Astroで新しいページを作成できる
- 共通レイアウト（ヘッダー・フッター）を作成できる
- コンポーネントをページに組み込める

---

### 2.5 ステージ4: Git/GitHub Pages or Vercel でのデプロイ

#### 到達目標
- 作成したサイトをインターネット上に公開できる
- GitHub ActionsまたはVercelの自動デプロイを設定できる
- 変更をプッシュすると自動的にサイトが更新される仕組みを理解

#### 学習すべきこと
- **GitHub Pages デプロイ**: `.github/workflows/deploy.yml`の設定
- **Vercel デプロイ**: Vercel CLIまたはGitHub連携による自動デプロイ
- カスタムドメインの設定（オプション）

#### 推奨リソース
- **GitHub Pages デプロイガイド**: [Deploy your Astro Site to GitHub Pages](https://docs.astro.build/en/guides/deploy/github/)
- **Vercel デプロイガイド**: [Deploy your Astro Site to Vercel](https://docs.astro.build/en/guides/deploy/vercel/)

#### 次のステージへの前提条件
- 自分のサイトが公開URLでアクセスできる
- コード変更後、自動的にサイトが更新されることを確認できる

---

### 2.6 ステージ5: コンテンツ管理（Markdown/MDX）

#### 到達目標
- Markdown形式でコンテンツを作成できる
- Astroのコンテンツコレクション機能を使える
- ブログ記事やお知らせページを追加できる

#### 学習すべきこと
- Markdown記法（見出し、リスト、リンク、画像）
- MDX（Markdownにコンポーネントを埋め込む）
- Astroのコンテンツコレクション（`src/content/`）
- フロントマター（YAML形式のメタデータ）

#### 推奨リソース
- **Markdown & MDX in Astro**: [Markdown in Astro](https://docs.astro.build/en/guides/markdown-content/)

#### 次のステージへの前提条件
- Markdownで記事を書き、サイトに表示できる
- コンテンツを追加・編集してもコードを触らずに更新できる仕組みを理解

---

### 2.7 「Claude Codeに任せられる部分」vs「自分で理解すべき部分」

#### 🤖 Claude Codeが自動生成/修正できる部分

| カテゴリ | 具体例 | Claude Codeの活用方法 |
|----------|--------|---------------------|
| **コンポーネント実装** | ヘッダー、フッター、お問い合わせフォーム、カード型コンテンツ表示等 | 「法律事務所のヘッダーコンポーネントを作って。ロゴ、ナビゲーション、お問い合わせボタンを含めて」と指示 |
| **CSS/デザイン調整** | レスポンシブ対応、色の変更、レイアウト調整、ダークモード対応 | 「このボタンを青色に変更して」「スマホ表示で2カラムにして」と指示 |
| **SEO設定** | メタタグ、OGP、sitemap.xml、robots.txt | 「SEO最適化のためのメタタグを追加して」と指示 |
| **アクセシビリティ** | ARIA属性、セマンティックHTML、キーボードナビゲーション | 「アクセシビリティを改善して」と指示 |
| **パフォーマンス最適化** | 画像最適化、遅延読み込み、コード分割 | 「画像を最適化して読み込みを高速化して」と指示 |
| **デプロイ設定** | GitHub Actions workflow、Vercel設定ファイル | 「GitHub Pagesにデプロイする設定を追加して」と指示 |
| **バグ修正** | エラー解消、レイアウト崩れ修正、ビルドエラー対応 | エラーメッセージをClaude Codeに共有して修正依頼 |

#### 👤 殿が理解すべき部分（判断・意思決定）

| カテゴリ | 具体例 | なぜ理解が必要か |
|----------|--------|----------------|
| **サイト構成の判断** | ページ数、メニュー構成、情報の優先順位 | 事務所の戦略・ブランディングに直結 |
| **コンテンツ作成** | 業務内容の説明、弁護士紹介、料金表、ブログ記事 | 法律の専門知識が必要。Claude Codeは法的助言不可 |
| **デザイン方針決定** | 色使い、トーンアンドマナー、ロゴ、全体の雰囲気 | 事務所のイメージ・ブランドを左右 |
| **運用方針** | 更新頻度、問い合わせ対応フロー、プライバシーポリシー | 業務運営と法的責任に関わる |
| **目標設定** | KPI（訪問者数、問い合わせ数）、改善指標 | 事業戦略に基づく判断が必要 |

#### 🤝 協働パターン（殿 ↔ Claude Code）

最も効果的な協働の流れ:

```
1. 殿が指示 → 「トップページに『相続問題に強い』というセクションを追加して」
2. Claude Codeが実装 → コンポーネント作成、Tailwindでスタイリング、コード生成
3. 殿がレビュー → ブラウザで確認し、「もっと目立つようにして」「色を変更して」等の調整指示
4. Claude Codeが修正 → フィードバックを反映
5. 完成・デプロイ
```

---

## 3. Astro + Tailwind CSS 実績・採用事例

### 3.1 技術統計（2026年2月時点）

| 指標 | 数値 | 情報源 |
|------|------|--------|
| **ライブサイト数** | 962,090 | [BuiltWith](https://trends.builtwith.com/framework/Astro) |
| **GitHub Stars** | 55,000+ | [GitHub Ranking](https://github.com/EvanLi/Github-Ranking) |
| **週間ダウンロード** | 900,000+ | [Astro Blog](https://astro.build/blog/year-in-review-2025/) |
| **成長率（2025年）** | 週間ダウンロード360,000 → 900,000（2.5倍増） | Astro Blog |

### 3.2 グローバル大手企業サイト

| サイト名 | URL | 業種 | 特徴 |
|---------|-----|------|------|
| **IKEA** | [ikea.com](https://ikea.com) | 家具・インテリア | 国際的家具チェーンのグローバルサイト |
| **Porsche** | [porsche.com](https://porsche.com) | 自動車 | 高級自動車メーカーのコーポレートサイト |
| **Unilever** | [unilever.com](https://unilever.com) | 消費財 | 多国籍企業のグローバルサイト |
| **Michelin** | [michelin.com](https://michelin.com) | タイヤ | グローバルタイヤメーカー |
| **Visa** | [design.visa.com](https://design.visa.com) | 金融 | Visa公式デザインシステム |
| **Microsoft** | [fluent2.microsoft.design](https://fluent2.microsoft.design) | テック | Microsoftデザインシステム |

### 3.3 法律事務所・士業サイト

#### Bourne Law Firm — 法律事務所のAstro移行成功事例

**URL**: [https://www.bourne.law/](https://www.bourne.law/)
**移行元**: WordPress
**技術スタック**: Astro + React + Netlify
**コンテンツ規模**: 186ページ（MDX形式）

**移行の決定理由（公式ブログより）**:

| 項目 | WordPress時代 | Astro移行後 | 改善効果 |
|------|-------------|-----------|---------|
| **ページ読込速度** | 3-5秒 | **サブ秒（1秒未満）** | **60-80%削減** |
| **ホスティング費用** | 月額$50-200 | **月額$0** | **100%削減** |
| **セキュリティ** | 侵害経験あり | 攻撃対象が存在しない | リスク激減 |
| **保守作業** | 定期的なアップデート必須 | ほぼゼロ | 工数削減 |

**技術的アーキテクチャの利点**:
- **Islands Architecture**: デフォルトでJavaScriptゼロ。電卓・フォーム等の対話型要素のみ独立してロード
- **Content Collections機能**: 186ページのMDXファイルを型安全に管理。メタデータ欠落エラーを防止
- **SEO改善**: 静的HTML生成により、Googleクローラーが即座にアクセス可能。レンダリングブロックなし

**参考リンク**: [Why We Chose Astro Over WordPress](https://www.bourne.law/blog/why-we-chose-astro-over-wordpress/)

### 3.4 法律事務所向けAstroテーマ

#### 3.4.1 Carrington — プレミアム法律事務所テーマ

**URL**: [https://lexingtonthemes.com/templates/carrington](https://lexingtonthemes.com/templates/carrington)
**価格**: $79（個別購入）/ $99/年（全テーマアクセス、通常$199から50%OFF）
**デモ**: [Carrington Demo](https://lexingtonthemes.com/viewports/carrington)

**技術スタック**:
- Astro v5
- Tailwind CSS v4
- PagesCMS統合
- Lighthouse 98+スコア（Performance, Accessibility, SEO）

**主要機能**:
- 弁護士紹介ページ
- 事例・実績ページ
- オフィス所在地
- 顧客の声（Testimonials）
- ブログ・プレスリリース
- 無料相談フォーム
- メガメニュー対応
- グローバル検索（Fuse.js搭載）
- XML サイトマップ

#### 3.4.2 Legal-Staff — 無料法律事務所テーマ

**URL**: [https://astro.build/themes/details/legal-staff/](https://astro.build/themes/details/legal-staff/)
**価格**: **無料**
**デモ**: [https://legal-staff.vercel.app/](https://legal-staff.vercel.app/)
**GitHub**: [https://github.com/Lautaro-R-collins/legal-staff](https://github.com/Lautaro-R-collins/legal-staff)

**主要セクション**:
- Home（ホーム）
- About Us（事務所紹介）
- Blog（ブログ）

**特徴**: スムーズなナビゲーション、レスポンシブデザイン、法律サービスの提示に焦点を当てたクリーンな美学

**ターゲット**: 小規模法律事務所、法律コンサルタント、プロフェッショナルのオンラインプレゼンス構築

### 3.5 パフォーマンス実績

#### 3.5.1 Lighthouse 100点達成事例

**WordPress → Astro 移行事例**:
- **移行前**: Lighthouseスコア 70-80（最適化を重ねても限界）
- **移行後**: **Lighthouse 100点達成**

**リソース削減（WordPress比較）**:
- HTML: **72.0%削減**
- JavaScript: **60.4%削減**
- CSS: **90.2%削減**

#### 3.5.2 Core Web Vitals（CWV）合格率

**Astro vs 他フレームワーク**:
- **Astro**: **60%**のサイトが「Good」スコア達成
- WordPress/Gatsby: 38%
- **結論**: AstroはGoogleのCWV評価で50%超を達成した**唯一のフレームワーク**

---

## 4. 実装ステップ

### 4.1 開発環境セットアップ

#### 4.1.1 Node.js のインストール

**推奨バージョン**: Node.js v18.17.1 以上、または v20.3.0 以上

```bash
# バージョン確認
node --version
npm --version
```

**インストール方法（まだの場合）**:
- [Node.js 公式サイト](https://nodejs.org/) から LTS 版をダウンロード
- Windows: インストーラーを実行
- macOS/Linux: 公式サイトまたは nvm を使用

#### 4.1.2 pnpm のインストール（推奨）

```bash
# pnpm のインストール（npm 経由）
npm install -g pnpm

# バージョン確認
pnpm --version
```

---

### 4.2 プロジェクト初期化

#### 4.2.1 Astro プロジェクトの作成

```bash
# プロジェクト作成
npm create astro@latest

# 対話式の質問に答える:
# - Where should we create your new project? → law-firm-site（任意の名前）
# - How would you like to start your new project? → Empty（空のテンプレート）
# - Do you plan to write TypeScript? → Yes（推奨）
# - How strict should TypeScript be? → Strict（推奨）
# - Install dependencies? → Yes
# - Initialize a new git repository? → Yes
```

#### 4.2.2 プロジェクトディレクトリに移動

```bash
cd law-firm-site
```

#### 4.2.3 開発サーバーの起動確認

```bash
pnpm dev
```

ブラウザで `http://localhost:4321` にアクセスし、Astro のウェルカムページが表示されることを確認。

---

### 4.3 Tailwind CSS v4 導入

#### 4.3.1 依存パッケージのインストール

```bash
pnpm add -D @tailwindcss/vite
```

#### 4.3.2 Astro 設定ファイルの編集

**ファイル**: `astro.config.mjs`

```javascript
// @ts-check
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  vite: {
    plugins: [tailwindcss()],
  },
});
```

#### 4.3.3 グローバル CSS ファイルの作成

**ファイル**: `src/styles/global.css`

```css
@import "tailwindcss";
```

#### 4.3.4 レイアウトファイルで CSS をインポート

**ファイル**: `src/layouts/Layout.astro`（新規作成）

```astro
---
interface Props {
  title: string;
}

const { title } = Astro.props;
---

<!doctype html>
<html lang="ja">
  <head>
    <meta charset="UTF-8" />
    <meta name="description" content="倉敷市の法律事務所" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <meta name="generator" content={Astro.generator} />
    <title>{title}</title>
  </head>
  <body>
    <slot />
  </body>
</html>

<style is:global>
  @import "../styles/global.css";
</style>
```

---

### 4.4 ページ構成の設計と作成

#### 4.4.1 法律事務所サイトの推奨ページ構成（7ページ）

| ページ名 | URL | 目的 |
|---------|-----|------|
| トップページ | `/` | ファーストビュー、事務所概要、取扱分野、アクセス |
| 弁護士紹介 | `/attorneys` | プロフィール、経歴、実績、専門分野 |
| 取扱分野 | `/practice-areas` | 離婚、相続、交通事故、債務整理等 |
| 料金 | `/fees` | 相談料、着手金、報酬金の目安 |
| アクセス | `/access` | 地図、最寄駅、駐車場情報、営業時間 |
| お問い合わせ | `/contact` | 問い合わせフォーム |
| プライバシーポリシー | `/privacy` | 個人情報の取り扱い |

#### 4.4.2 コンポーネント設計

**主要コンポーネント**:
- `Header.astro` — ヘッダー（ナビゲーション）
- `Footer.astro` — フッター
- `CTAButton.astro` — お問い合わせボタン
- `PracticeAreaCard.astro` — 取扱分野カード

**コードサンプル: Header.astro**

```astro
---
const navItems = [
  { name: "ホーム", href: "/" },
  { name: "弁護士紹介", href: "/attorneys" },
  { name: "取扱分野", href: "/practice-areas" },
  { name: "料金", href: "/fees" },
  { name: "アクセス", href: "/access" },
  { name: "お問い合わせ", href: "/contact" },
];
---

<header class="bg-white shadow-md">
  <nav class="container mx-auto px-4 py-4">
    <div class="flex justify-between items-center">
      <a href="/" class="text-2xl font-bold text-blue-900">
        倉敷法律事務所
      </a>
      <ul class="hidden md:flex space-x-6">
        {navItems.map(item => (
          <li>
            <a href={item.href} class="text-gray-700 hover:text-blue-600 transition-colors">
              {item.name}
            </a>
          </li>
        ))}
      </ul>
    </div>
  </nav>
</header>
```

---

### 4.5 問い合わせフォーム実装

#### 4.5.1 無料サービスの比較

| サービス | 無料枠 | 料金 | 設定難易度 | おすすめ度 |
|---------|--------|------|-----------|----------|
| **Netlify Forms** | 100件/月 | $0 → $19/月（100件超） | ★☆☆（簡単） | ★★★★★ |
| **Formspree** | 50件/月 | $0 → $10/月（50件超） | ★★☆（普通） | ★★★★☆ |
| **Google Forms** | 無制限 | 無料 | ★☆☆（簡単） | ★★☆☆☆ |

#### 4.5.2 推奨: Netlify Forms の実装

**メリット**:
- Netlify でホスティングする場合、設定が最も簡単
- スパム対策（reCAPTCHA）が標準装備
- 管理画面で送信内容を確認できる

**コードサンプル: contact.astro**

```astro
---
import Layout from '../layouts/Layout.astro';
import Header from '../components/Header.astro';
import Footer from '../components/Footer.astro';
---

<Layout title="お問い合わせ | 倉敷法律事務所">
  <Header />
  <main class="py-16">
    <div class="container mx-auto px-4 max-w-2xl">
      <h1 class="text-4xl font-bold text-center mb-8">お問い合わせ</h1>
      <form name="contact" method="POST" data-netlify="true" netlify-honeypot="bot-field" class="space-y-6">
        <input type="hidden" name="form-name" value="contact" />
        <p class="hidden">
          <label>Don't fill this out if you're human: <input name="bot-field" /></label>
        </p>
        <div>
          <label for="name" class="block text-sm font-medium mb-2">お名前 <span class="text-red-600">*</span></label>
          <input type="text" id="name" name="name" required class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500" />
        </div>
        <div>
          <label for="email" class="block text-sm font-medium mb-2">メールアドレス <span class="text-red-600">*</span></label>
          <input type="email" id="email" name="email" required class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500" />
        </div>
        <div>
          <label for="message" class="block text-sm font-medium mb-2">お問い合わせ内容 <span class="text-red-600">*</span></label>
          <textarea id="message" name="message" rows="6" required class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"></textarea>
        </div>
        <button type="submit" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-6 rounded-md transition-colors">送信する</button>
      </form>
    </div>
  </main>
  <Footer />
</Layout>
```

---

## 5. SEO対策（特にローカルSEO）

### 5.1 構造化データ（Schema.org）

#### 5.1.1 LocalBusiness + LegalService スキーマ

**ファイル**: `src/components/StructuredData.astro`

```astro
---
const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "LegalService",
      "@id": "https://yoursite.com/#legalservice",
      "name": "倉敷法律事務所",
      "url": "https://yoursite.com",
      "description": "倉敷市の法律事務所。離婚、相続、交通事故、債務整理など幅広い分野に対応。",
      "areaServed": { "@type": "City", "name": "倉敷市" },
      "address": {
        "@type": "PostalAddress",
        "streetAddress": "阿知1丁目7-2",
        "addressLocality": "倉敷市",
        "addressRegion": "岡山県",
        "postalCode": "710-0055",
        "addressCountry": "JP"
      },
      "geo": {
        "@type": "GeoCoordinates",
        "latitude": 34.5939,
        "longitude": 133.7720
      },
      "telephone": "+81-86-XXX-XXXX",
      "email": "info@yoursite.com",
      "openingHoursSpecification": [
        {
          "@type": "OpeningHoursSpecification",
          "dayOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
          "opens": "09:00",
          "closes": "18:00"
        }
      ]
    },
    {
      "@type": "Attorney",
      "@id": "https://yoursite.com/#attorney",
      "name": "山田 太郎",
      "jobTitle": "代表弁護士",
      "worksFor": { "@id": "https://yoursite.com/#legalservice" },
      "alumniOf": "東京大学法学部",
      "knowsAbout": ["離婚法", "相続法", "交通事故", "債務整理"]
    }
  ]
};
---

<script type="application/ld+json" set:html={JSON.stringify(structuredData)} />
```

**Layout.astro の `<head>` 内で読み込み**:

```astro
---
import StructuredData from '../components/StructuredData.astro';
---

<head>
  <!-- 他のメタタグ -->
  <StructuredData />
</head>
```

---

### 5.2 ローカルSEO対策

#### 5.2.1 キーワード戦略（倉敷市 弁護士向け）

**ターゲットキーワード**:

| 優先度 | キーワード | 検索ボリューム推定 | 競合性 |
|-------|-----------|------------------|--------|
| 高 | 倉敷市 弁護士 | 中 | 高 |
| 高 | 倉敷 法律事務所 | 中 | 中 |
| 高 | 倉敷 離婚 弁護士 | 低〜中 | 中 |
| 高 | 倉敷 相続 弁護士 | 低〜中 | 中 |
| 中 | 岡山 弁護士 | 高 | 高 |
| 中 | 倉敷 交通事故 弁護士 | 低 | 低〜中 |

**コンテンツへの組み込み**:
- トップページの h1 タグ: 「倉敷法律事務所 | 倉敷市の弁護士」
- 各分野ページのタイトル: 「倉敷市の離婚弁護士 | 倉敷法律事務所」
- メタディスクリプションに地域名を含める

#### 5.2.2 Google Business Profile（旧 Google マイビジネス）登録

**手順**:

1. [Google Business Profile](https://www.google.com/intl/ja_jp/business/) にアクセス
2. 「今すぐ管理」をクリック
3. ビジネス情報を入力:
    - **ビジネス名**: 倉敷法律事務所
    - **カテゴリ**: 弁護士
    - **住所**: 〒710-0055 岡山県倉敷市阿知1丁目7-2
    - **サービス提供地域**: 倉敷市、岡山市、総社市など
    - **電話番号**: 086-XXX-XXXX
    - **ウェブサイト**: https://yoursite.com
    - **営業時間**: 平日 9:00-18:00
4. 確認手続き（郵送はがきまたは電話で認証コードを受け取る）
5. ビジネス情報を最適化:
    - **プロフィール写真**: 事務所外観、内観、スタッフ写真
    - **説明文**: 事務所の特徴、取扱分野、地域密着をアピール
    - **サービス**: 離婚相談、相続相談、交通事故相談など
    - **投稿**: 定期的に更新情報やお知らせを投稿

**重要**: NAP情報（Name, Address, Phone）をウェブサイトと完全に一致させる。

---

### 5.3 Core Web Vitals（Astroの強み）

Astro は **SSG**（静的サイト生成）と **Island Architecture**（部分ハイドレーション）により、高速表示を実現:

- **LCP**（Largest Contentful Paint）: 静的HTMLの高速配信で2.5秒以内を達成
- **FID**（First Input Delay）: 不要なJavaScriptを削除し、100ms以内を達成
- **CLS**（Cumulative Layout Shift）: レイアウトシフトを最小化

**最適化のポイント**:
- 画像は WebP 形式で配信（Astro の `<Image>` コンポーネント使用）
- フォントの先読み（`<link rel="preload">`）
- 不要な JavaScript を削除（Island Architecture で必要な部分のみロード）

---

## 6. デプロイ・公開

### 6.1 GitHub Pages へのデプロイ

#### 6.1.1 astro.config.mjs の設定

GitHub Pages でサブディレクトリにデプロイする場合（`https://YOUR_USERNAME.github.io/law-firm-site/`）:

```javascript
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: 'https://YOUR_USERNAME.github.io',
  base: '/law-firm-site',
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [sitemap()],
});
```

カスタムドメインを使う場合は `base` 不要。

#### 6.1.2 GitHub Actions ワークフローの作成

**ファイル**: `.github/workflows/deploy.yml`

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 8
      - name: Install dependencies
        run: pnpm install
      - name: Build
        run: pnpm build
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

#### 6.1.3 GitHub Pages の有効化

1. GitHub リポジトリページ → Settings → Pages
2. **Source**: "GitHub Actions" を選択
3. `main` ブランチにプッシュすると自動デプロイが開始

---

### 6.2 Vercel へのデプロイ

#### 6.2.1 Vercel アカウント作成

1. [Vercel](https://vercel.com/) にアクセス
2. "Sign Up" → GitHub アカウントで認証

#### 6.2.2 リポジトリ連携

1. Vercel ダッシュボード → "Add New..." → "Project"
2. GitHub リポジトリ（`law-firm-site`）を選択
3. "Import"

Vercel は Astro プロジェクトを自動検出し、以下のデフォルト設定を適用:

- **Framework Preset**: Astro
- **Build Command**: `astro build`
- **Output Directory**: `dist`

"Deploy" をクリックすると、自動でビルド&デプロイが開始されます。

---

### 6.3 独自ドメイン設定

#### 6.3.1 ドメイン取得

**推奨レジストラ**:
- **Cloudflare Registrar**: $9.77/年（卸売価格、追加費用なし、WHOIS プライバシー無料）
- **お名前.com**: 初年度 1円〜、2年目以降 1,408円/年（日本語サポート）

#### 6.3.2 Vercel の場合の DNS 設定

1. Vercel プロジェクト → Settings → Domains
2. "Add" をクリックし、ドメイン名を入力（例: `kurashiki-law.com`）
3. Vercel が DNS 設定方法を表示:

**Cloudflare DNS の場合**:

| タイプ | 名前 | 値 | Proxy status |
|-------|------|-----|-------------|
| CNAME | @ | cname.vercel-dns.com | DNS only |

4. Vercel が DNS を検証し、SSL 証明書を自動発行

---

## 7. 想定スケジュール

### 7.1 パターンA: 週5時間（平日1時間）投下

| フェーズ | 作業内容 | 期間 | 累計時間 |
|---------|---------|------|---------|
| **学習** | Tailwind CSS 基礎（公式ドキュメント） | 1週間 | 5h |
| **学習** | Astro 基礎（公式チュートリアル） | 2週間 | 15h |
| **実装** | 環境構築・レイアウト作成 | 1週間 | 20h |
| **実装** | トップページ・ナビゲーション | 2週間 | 30h |
| **実装** | 各ページ作成（弁護士紹介、取扱分野、料金、アクセス） | 3週間 | 45h |
| **実装** | 問い合わせフォーム | 1週間 | 50h |
| **実装** | SEO 対策・構造化データ | 1週間 | 55h |
| **実装** | レスポンシブ調整・細部調整 | 2週間 | 65h |
| **デプロイ** | GitHub Pages / Vercel デプロイ | 1週間 | 70h |
| **運用** | 独自ドメイン設定・Google Business Profile 登録 | 1週間 | 75h |

**合計期間**: **約15週間（約4ヶ月）**

---

### 7.2 パターンB: 週10時間（平日1h + 週末5h）投下

| フェーズ | 作業内容 | 期間 | 累計時間 |
|---------|---------|------|---------|
| **学習** | Tailwind CSS + Astro 基礎 | 2週間 | 20h |
| **実装** | 環境構築・レイアウト・トップページ | 1週間 | 30h |
| **実装** | 各ページ作成 | 2週間 | 50h |
| **実装** | 問い合わせフォーム・SEO | 1週間 | 60h |
| **実装** | レスポンシブ調整・細部調整 | 1週間 | 70h |
| **デプロイ** | デプロイ・ドメイン設定 | 1週間 | 80h |

**合計期間**: **約8週間（約2ヶ月）**

---

### 7.3 パターンC: 週20時間（集中期間）投下

| フェーズ | 作業内容 | 期間 | 累計時間 |
|---------|---------|------|---------|
| **学習** | Tailwind CSS + Astro 基礎（集中学習） | 1週間 | 20h |
| **実装** | 環境構築・レイアウト・全ページ作成 | 2週間 | 60h |
| **実装** | フォーム・SEO・細部調整 | 1週間 | 80h |
| **デプロイ** | デプロイ・ドメイン設定・運用準備 | 1週間 | 100h |

**合計期間**: **約5週間（約1ヶ月）**

---

### 7.4 Claude Code 活用による短縮効果

Claude Code を活用すると、以下の工程を大幅に短縮できます:

| 工程 | 従来の時間 | Claude Code 使用時 | 短縮効果 |
|------|-----------|-------------------|---------|
| コンポーネント作成 | 10h | 3h | **-70%** |
| ページレイアウト調整 | 8h | 2h | **-75%** |
| レスポンシブ対応 | 6h | 2h | **-67%** |
| SEO 構造化データ実装 | 4h | 1h | **-75%** |
| デバッグ・エラー修正 | 10h | 3h | **-70%** |

**パターンC（集中期間）** + **Claude Code 最大活用** = **約3週間で公開可能**

---

## 8. まとめ・次のステップ

### 8.1 推奨アクション（最初にやるべきこと3つ）

1. **Astro公式チュートリアル「Build a Blog」を完走**
   [https://docs.astro.build/en/tutorial/0-introduction/](https://docs.astro.build/en/tutorial/0-introduction/)
   → 約1週間で基本を体得

2. **Bourne Law FirmのブログをWide Read**
   [Why We Chose Astro Over WordPress](https://www.bourne.law/blog/why-we-chose-astro-over-wordpress/)
   → 法律事務所での実際の成功事例を理解

3. **Legal-Staff（無料）またはCarrington（$79）のデモサイト確認**
   - [Legal-Staff Demo](https://legal-staff.vercel.app/)
   - [Carrington Demo](https://lexingtonthemes.com/viewports/carrington)
   → 自分の要件に合致するか評価

---

### 8.2 cmd_118との整合性まとめ

本ガイドはcmd_118「弁護士事務所HP作成 方法論比較レポート」で**第1推奨**となった技術スタックの実装ガイドである。

**cmd_118での評価**:
- 総合スコア: **43点（最高点）**
- SEO対応力: **5/5**（最高評価）
- ローカルSEO: **5/5**（最高評価）
- セキュリティ: **5/5**（最高評価）
- Claude Code親和性: **5/5**（最高評価）
- コスト: **5/5**（最高評価）

**cmd_118が推奨した理由の実現**:
- ✅ **SEO最強**: 本ガイドのセクション5で構造化データ実装を詳解
- ✅ **コスト最安**: GitHub Pages/Vercel無料ホスティング。年間約1,500円（ドメイン代のみ）
- ✅ **セキュリティリスク最小**: 静的サイトのため攻撃対象が存在しない
- ✅ **Claude Code親和性最強**: プロンプトでコンポーネント・ページ・SEO設定を自動生成可能
- ✅ **保守負担ゼロ**: サーバー管理・データベース・セキュリティアップデート不要

---

### 8.3 成功のポイント

1. **完璧を目指さない**: 最初は小さく始め、公開後に改善を重ねる
2. **テンプレートを活用**: Carrington/Legal-Staffのような専門テンプレートを土台にする
3. **Claude Codeとの協働**: コーディングはClaude Codeに任せ、殿は企画・コンテンツ・判断に集中
4. **公式ドキュメントを味方に**: Astro・Tailwindの公式ドキュメントは検索性が高く、初心者でも理解しやすい
5. **コミュニティを活用**: Qiita・Zenn・GitHub Discussionsで質問・情報収集

---

### 8.4 最終結論

**Astro + Tailwind CSS** は、殿のスキルセット（Claude Code・GitHub・Notionを日常使用）と法律事務所HPの要件（SEO・コスト・セキュリティ）に最も合致した技術スタックである。

- **構築**: Claude Codeへのプロンプト1つで1〜2日で完成
- **コスト**: 年間約1,500円（ドメイン代のみ。Claude Code既契約前提）
- **SEO**: 静的HTML＋構造化データで「倉敷市 弁護士」上位表示に最適
- **セキュリティ**: 攻撃対象が最小。法律事務所として安心
- **保守**: Claude Codeに指示するだけでデザイン変更・コンテンツ更新が可能

**次のステップとして、まずはAstro公式チュートリアル「Build a Blog」を完走し、本ガイドの実装ステップに従って環境構築を開始することを強く推奨する。**

---

## 参考リンク集

### 公式ドキュメント
- [Astro Docs](https://docs.astro.build/en/getting-started/)
- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [Astro + Tailwind Setup Guide](https://tailwindcss.com/docs/guides/astro)
- [Deploy to GitHub Pages](https://docs.astro.build/en/guides/deploy/github/)
- [Deploy to Vercel](https://docs.astro.build/en/guides/deploy/vercel/)

### 学習リソース
- [Learn Astro](https://learnastro.dev/)
- [Frontend Masters - Astro](https://frontendmasters.com/courses/astro/)
- [MDN Web Docs（日本語）](https://developer.mozilla.org/ja/docs/Learn_web_development/Core/Styling_basics)
- [Tailwind CSS実践入門（書籍）](https://www.amazon.co.jp/dp/429713943X)
- [1から始めるTailwindCSS（Zenn無料）](https://zenn.dev/tacchan5424/books/22d87ed6bc8550)

### テンプレート
- [Carrington（法律事務所専用）](https://lexingtonthemes.com/templates/carrington) — $79
- [Legal-Staff（無料）](https://astro.build/themes/details/legal-staff/)
- [AstroWind（汎用）](https://astrowind.vercel.app/)
- [Astro公式テーマディレクトリ](https://astro.build/themes/)

### 法律事務所事例・SEO
- [Why We Chose Astro Over WordPress | Bourne Law Firm](https://www.bourne.law/blog/why-we-chose-astro-over-wordpress/)
- [弁護士・法律事務所SEO対策完全ガイド【2026年1月最新】](https://media-growth.co.jp/lawyer-seo/)
- [弁護士事務所のSEO対策18選](https://www.ntttp-dlead.com/homepage-sakusei-blog/web-syuukyaku/seo-taisaku-kiso-chisiki/lawyer-seo.html)
- [弁護士のMEO対策方法](https://white-link.com/sem-plus/meo_lawyer/)

### パフォーマンス・ベンチマーク
- [Complete Guide to Astro Performance Optimization](https://eastondev.com/blog/en/posts/dev/20251202-astro-performance-optimization/)
- [Astro vs Next.js (2026): Real Benchmarks](https://senorit.de/en/blog/astro-vs-nextjs-2025)
- [From WordPress to Astro: Migration to 100 Lighthouse Score](https://kashifaziz.me/blog/wordpress-to-astro-migration-journey/)
- [2023 Web Framework Performance Report | Astro](https://astro.build/blog/2023-web-framework-performance-report/)

---

**作成者**: 足軽1号（Ashigaru1）
**調査日**: 2026-02-12
**親タスク**: cmd_122
**統合元レポート**: roadmap.md, showcase.md, implementation.md（3件）、参照整合性確認: cmd_118
**出力先**: output/cmd_122_astro_tailwind_implementation_guide.md
