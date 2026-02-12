# Astro + Tailwind CSS 法律事務所HP構築 — 学習ロードマップ

**作成日**: 2026-02-12
**対象**: Web開発未経験の弁護士（Claude Code・GitHub・Notion日常使用）
**目標**: Astro + Tailwind CSS + GitHub Pages/Vercel で法律事務所HPを自力構築

---

## 1. 学習ロードマップ

学習は5つのステージに分かれています。各ステージで「何ができるようになるか」と「次への前提条件」を明確にし、段階的にスキルを積み上げます。

### 学習時間の目安（全体）

| ステージ | 内容 | 目安時間 | 累計時間 |
|---------|------|----------|----------|
| ステージ1 | HTML/CSS 基礎（最低限） | 10〜14日 | 10〜14日 |
| ステージ2 | Tailwind CSS 基礎 | 7〜14日 | 17〜28日 |
| ステージ3 | Astro 基礎 | 7〜14日 | 24〜42日 |
| ステージ4 | Git/デプロイ（GitHub Pages/Vercel） | 3〜7日 | 27〜49日 |
| ステージ5 | コンテンツ管理（Markdown/MDX） | 3〜5日 | 30〜54日 |
| **合計** | **基本的なHP構築まで** | **1〜2ヶ月** | — |

**注記**: 1日2〜3時間の学習を想定。既にGitHub/Claude Codeを日常使用しているため、通常の初学者より進捗が早い可能性があります。

---

### ステージ1: HTML/CSS 基礎（最低限必要な範囲のみ）

#### 到達目標
- HTMLの基本構造（タグ、要素、属性）を理解できる
- CSSの基本（セレクタ、プロパティ、値）を理解できる
- シンプルなHTMLページを手書きできる

#### 学習すべきこと
- HTML: `<div>`, `<p>`, `<h1>`, `<a>`, `<img>`, `<section>`, `<header>`, `<footer>`
- CSS: クラスセレクタ、マージン、パディング、色、フォント
- **Tailwind CSSを使うため、CSSの深い理解は不要**（基本概念のみでOK）

#### 次のステージへの前提条件
- HTMLとCSSの役割の違いを説明できる
- 簡単なHTMLページを読んで理解できる

---

### ステージ2: Tailwind CSS（ユーティリティファースト概念、基本クラス）

#### 到達目標
- ユーティリティファーストCSSの概念を理解できる
- 基本的なTailwindクラス（`p-4`, `text-center`, `bg-blue-500`等）を使える
- レスポンシブデザイン（`md:`, `lg:`等）の基本を理解できる

#### 学習すべきこと
- Tailwind CSSの哲学（ユーティリティファースト vs 従来のCSS）
- よく使うクラス: レイアウト（`flex`, `grid`）、色、サイズ、マージン、パディング
- レスポンシブデザインの接頭辞（`sm:`, `md:`, `lg:`, `xl:`）
- ダークモード対応（`dark:`）

#### 次のステージへの前提条件
- Tailwindの公式ドキュメントを検索して必要なクラスを見つけられる
- 既存のTailwindコンポーネントを読んで理解できる

---

### ステージ3: Astro 基礎（プロジェクト構造、コンポーネント、ページ）

#### 到達目標
- Astroプロジェクトの基本構造を理解できる
- `.astro`コンポーネントを作成・編集できる
- ページルーティングの仕組みを理解できる
- レイアウトコンポーネントを活用できる

#### 学習すべきこと
- Astroプロジェクトのディレクトリ構造（`src/pages`, `src/components`, `src/layouts`）
- `.astro`ファイルの構文（フロントマター、HTMLテンプレート部分）
- コンポーネントの再利用
- 静的サイト生成（SSG）の概念
- Astro公式チュートリアル「Build a Blog」の完走

#### 次のステージへの前提条件
- Astroで新しいページを作成できる
- 共通レイアウト（ヘッダー・フッター）を作成できる
- コンポーネントをページに組み込める

---

### ステージ4: Git/GitHub Pages or Vercel でのデプロイ

#### 到達目標
- 作成したサイトをインターネット上に公開できる
- GitHub ActionsまたはVercelの自動デプロイを設定できる
- 変更をプッシュすると自動的にサイトが更新される仕組みを理解できる

#### 学習すべきこと
- **GitHub Pages デプロイ**: `.github/workflows/deploy.yml`の設定
- **Vercel デプロイ**: Vercel CLIまたはGitHub連携による自動デプロイ
- カスタムドメインの設定（オプション）

#### 次のステージへの前提条件
- 自分のサイトが公開URLでアクセスできる
- コード変更後、自動的にサイトが更新されることを確認できる

---

### ステージ5: コンテンツ管理（Markdown/MDX）

#### 到達目標
- Markdown形式でコンテンツを作成できる
- Astroのコンテンツコレクション機能を使える
- ブログ記事やお知らせページを追加できる

#### 学習すべきこと
- Markdown記法（見出し、リスト、リンク、画像）
- MDX（Markdownにコンポーネントを埋め込む）
- Astroのコンテンツコレクション（`src/content/`）
- フロントマター（YAML形式のメタデータ）

#### 次のステージへの前提条件
- Markdownで記事を書き、サイトに表示できる
- コンテンツを追加・編集してもコードを触らずに更新できる仕組みを理解している

---

## 2. 推奨学習リソース（URL付き）

### 【公式ドキュメント】

| 項目 | リソース | URL |
|------|----------|-----|
| Astro公式ドキュメント | Astro Docs - Getting Started | [https://docs.astro.build/en/getting-started/](https://docs.astro.build/en/getting-started/) |
| Astro公式チュートリアル | Build a Blog Tutorial | [https://docs.astro.build/en/tutorial/0-introduction/](https://docs.astro.build/en/tutorial/0-introduction/) |
| Tailwind CSS公式ドキュメント | Tailwind CSS Official Docs | [https://tailwindcss.com/docs](https://tailwindcss.com/docs) |
| Tailwind CSS + Astro 公式ガイド | Install Tailwind CSS with Astro | [https://tailwindcss.com/docs/guides/astro](https://tailwindcss.com/docs/guides/astro) |
| GitHub Pages デプロイガイド | Deploy your Astro Site to GitHub Pages | [https://docs.astro.build/en/guides/deploy/github/](https://docs.astro.build/en/guides/deploy/github/) |
| Vercel デプロイガイド | Deploy your Astro Site to Vercel | [https://docs.astro.build/en/guides/deploy/vercel/](https://docs.astro.build/en/guides/deploy/vercel/) |
| Markdown & MDX in Astro | Markdown in Astro | [https://docs.astro.build/en/guides/markdown-content/](https://docs.astro.build/en/guides/markdown-content/) |

---

### 【HTML/CSS 基礎学習（日本語）】

| リソース | 説明 | URL |
|----------|------|-----|
| MDN Web Docs（日本語版） | Mozilla提供の包括的なWeb技術ドキュメント。HTML/CSSの基礎から応用まで網羅 | [CSS 入門 - MDN](https://developer.mozilla.org/ja/docs/Learn_web_development/Core/Styling_basics/Getting_started) |
| Saruwaka（猿わかくん） | 初心者向けCSS入門。視覚的でわかりやすい解説 | [初心者向けCSS入門](https://saruwakakun.com/html-css/basic/css) |
| chot.design | はじめてのWebデザイン『HTML・CSS』入門 | [HTML・CSS入門](https://chot.design/html-css-beginner/) |
| Qiita記事（2024年版） | 2024年永久保存版！超初心者、未経験者向けHTMLとCSSのチュートリアル | [Qiita チュートリアル](https://qiita.com/automation2025/items/366ce35ee8222e6f3f1a) |

---

### 【Tailwind CSS 日本語リソース】

| リソース | 説明 | URL |
|----------|------|-----|
| Nulab Developer Site リデザイン記事 | AstroとTailwind CSSを使った実例紹介（2024年8月） | [Nulab記事](https://nulab.com/ja/blog/nulab/redesign-developer-site-using-astro/) |
| neputa note チュートリアル | AstroとTailwindで静的サイトを作成する実践的ガイド（2024年5月） | [neputa note](https://www.neputa-note.net/2024/05/astro-tailwind.html) |
| Qiita - TailwindCSS v4導入 | Astro.js サイトにTailwindCSS(v4)を導入する手順（2025年4月） | [Qiita記事](https://qiita.com/takeshi_du/items/32167a88a9d1e3402ff2) |
| オレインデザイン | AstroをTailwind CSSが利用できるようにセットアップする方法 | [オレインデザイン](https://olein-design.com/blog/get-started-tailwind-css-on-astro) |
| Tailkits 2026クイックガイド | Astro + Tailwind v4 Setup: 2026 Quick Guide | [Tailkits](https://tailkits.com/blog/astro-tailwind-setup/) |

---

### 【Astro + Tailwind CSS 学習コース】

| リソース | 説明 | URL |
|----------|------|-----|
| Learn Astro（公式推奨） | プロジェクトベースのオンラインコース。Astroの基礎から応用まで網羅 | [https://learnastro.dev/](https://learnastro.dev/) |
| Frontend Masters | Astro + 複数フレームワーク（React, SolidJS）を学べる実践的コース | [Frontend Masters](https://frontendmasters.com/courses/astro/) |
| Udemy - Astro Complete Guide | GraphQL, REST APIsを含むAstroの包括的ガイド | [Udemy](https://www.udemy.com/course/astro-the-complete-guide/) |
| freeCodeCamp | Learn the Astro Web Framework（無料） | [freeCodeCamp](https://www.freecodecamp.org/news/learn-the-astro-web-framework/) |
| Coursera - Build Fast Websites with Astro | Astroで高速Webサイトを構築する入門コース | [Coursera](https://www.coursera.org/learn/build-fast-websites-with-astro) |

---

### 【YouTube 動画チュートリアル】

| チャンネル/動画 | 説明 | URL（検索推奨）|
|----------------|------|----------------|
| YouTube検索推奨 | "Astro tutorial 2024 beginner" で検索 | [YouTube](https://www.youtube.com/) |
| YouTube検索推奨 | "Tailwind CSS crash course 2024" で検索 | [YouTube](https://www.youtube.com/) |
| YouTube検索推奨 | "Astro Tailwind CSS tutorial" で検索 | [YouTube](https://www.youtube.com/) |

**推奨チャンネル**:
- Traversy Media（英語、初心者向け）
- Academind（英語、体系的）
- The Net Ninja（英語、シリーズ形式）
- Programming with Mosh（英語、わかりやすい）

**注記**: YouTubeの動画は検索結果で直接リンクが出にくいため、上記キーワードで検索し、再生回数・日付・評価を基に選ぶことを推奨します。

---

### 【書籍（日本語）】

| 書籍名 | 著者 | 出版社 | 発行年 | URL |
|--------|------|--------|--------|-----|
| Tailwind CSS実践入門 | 工藤智祥 | 技術評論社 | 2024年1月 | [Amazon](https://www.amazon.co.jp/Tailwind-CSS%E5%AE%9F%E8%B7%B5%E5%85%A5%E9%96%80/dp/429713943X) |
| 基礎から学ぶ Tailwind CSS | — | C&R研究所 | 2024年 | [C&R研究所](https://www.c-r.com/book/detail/1536) |
| これだけで基本がしっかり身につく HTML/CSS&Webデザイン1冊目の本 | Capybara Design, 竹内直人, 竹内瑠美 | 翔泳社 | — | [Amazon](https://www.amazon.co.jp/dp/4798170119) |
| 1から始めるTailwindCSS（Zenn無料） | tacchan5424 | Zenn | 2025年6月更新 | [Zenn](https://zenn.dev/tacchan5424/books/22d87ed6bc8550) |

**Astro専門の日本語書籍**: 2026年2月時点では確認できませんでした。公式ドキュメント・Zenn・Qiita記事が主な日本語リソースです。

---

### 【テンプレート・スターターキット】

| テンプレート名 | 説明 | URL |
|---------------|------|-----|
| Carrington | **法律事務所専用テンプレート**（Astro + Tailwind CSS）。プロフェッショナルなデザイン、高速、カスタマイズ容易 | [Lexington Themes](https://lexingtonthemes.com/templates/carrington) |
| AstroWind | 無料のAstro 5.0 + Tailwind CSSテンプレート。SaaS、ポートフォリオ、ブログに対応 | [AstroWind](https://astrowind.vercel.app/) |
| Astroship | Astro + Tailwind CSSスターターテンプレート。シンプルで拡張しやすい | [Astroship](https://astroship.web3templates.com/) |

**推奨**: Carringtonは法律事務所向けに特化しており、最も目的に合致しています。デモサイトを確認し、構造を学ぶことで実装のイメージが掴めます。

---

## 3. 「Claude Codeに任せられる部分」vs「自分で理解すべき部分」

Astro + Tailwind CSSでのHP構築において、Claude Codeとの協働パターンを整理します。

### 🤖 Claude Codeが自動生成/修正できる部分

| カテゴリ | 具体例 | Claude Codeの活用方法 |
|----------|--------|---------------------|
| **コンポーネント実装** | ヘッダー、フッター、お問い合わせフォーム、カード型コンテンツ表示等 | 「法律事務所のヘッダーコンポーネントを作って。ロゴ、ナビゲーション、お問い合わせボタンを含めて」と指示 |
| **CSS/デザイン調整** | レスポンシブ対応、色の変更、レイアウト調整、ダークモード対応 | 「このボタンを青色に変更して」「スマホ表示で2カラムにして」と指示 |
| **SEO設定** | メタタグ、OGP、sitemap.xml、robots.txt | 「SEO最適化のためのメタタグを追加して」と指示 |
| **アクセシビリティ** | ARIA属性、セマンティックHTML、キーボードナビゲーション | 「アクセシビリティを改善して」と指示 |
| **パフォーマンス最適化** | 画像最適化、遅延読み込み、コード分割 | 「画像を最適化して読み込みを高速化して」と指示 |
| **デプロイ設定** | GitHub Actions workflow、Vercel設定ファイル | 「GitHub Pagesにデプロイする設定を追加して」と指示 |
| **バグ修正** | エラー解消、レイアウト崩れ修正、ビルドエラー対応 | エラーメッセージをClaude Codeに共有して修正依頼 |

---

### 👤 殿が理解すべき部分（判断・意思決定）

| カテゴリ | 具体例 | なぜ理解が必要か |
|----------|--------|----------------|
| **サイト構成の判断** | ページ数、メニュー構成、情報の優先順位 | 事務所の戦略・ブランディングに直結するため |
| **コンテンツ作成** | 業務内容の説明、弁護士紹介、料金表、ブログ記事 | 法律の専門知識が必要。Claude Codeは法的助言不可 |
| **デザイン方針決定** | 色使い、トーンアンドマナー、ロゴ、全体の雰囲気 | 事務所のイメージ・ブランドを左右するため |
| **運用方針** | 更新頻度、問い合わせ対応フロー、プライバシーポリシー | 業務運営と法的責任に関わるため |
| **目標設定** | KPI（訪問者数、問い合わせ数）、改善指標 | 事業戦略に基づく判断が必要 |

---

### 🤝 協働パターン（殿 ↔ Claude Code）

最も効果的な協働の流れ:

```
1. 殿が指示 → 「トップページに『相続問題に強い』というセクションを追加して」
2. Claude Codeが実装 → コンポーネント作成、Tailwindでスタイリング、コード生成
3. 殿がレビュー → ブラウザで確認し、「もっと目立つようにして」「色を変更して」等の調整指示
4. Claude Codeが修正 → フィードバックを反映
5. 完成・デプロイ
```

---

### 📊 役割分担の比率イメージ

| フェーズ | 殿の作業 | Claude Codeの作業 |
|----------|---------|------------------|
| **企画・設計** | 90% | 10%（アドバイス・提案） |
| **実装・コーディング** | 10% | 90%（コード生成） |
| **コンテンツ作成** | 100% | 0%（法律知識不可） |
| **デザイン調整** | 30%（指示・判断） | 70%（実装） |
| **デバッグ・修正** | 10%（報告） | 90%（修正実装） |
| **運用・更新** | 50%（コンテンツ） | 50%（技術サポート） |

---

### 🎯 実践例: 「弁護士紹介ページ」を作る場合

| ステップ | 殿の役割 | Claude Codeの役割 |
|----------|---------|------------------|
| 1. 企画 | 「各弁護士の顔写真、経歴、専門分野を載せたい」と決定 | — |
| 2. 指示 | 「弁護士3名分のプロフィールカードを作って。写真、名前、専門分野、経歴の順で」 | — |
| 3. 実装 | — | `.astro`コンポーネントを生成、Tailwindでスタイリング |
| 4. レビュー | ブラウザで確認「写真を左寄せにして、経歴を箇条書きに」 | — |
| 5. 調整 | — | レイアウト変更、箇条書き対応 |
| 6. コンテンツ追加 | 実際の弁護士情報（写真、テキスト）を記入 | — |
| 7. 最終チェック | 誤字脱字、レイアウト崩れを確認 | バグがあれば修正 |

---

### ✅ 学習の優先順位（Claude Code活用前提）

Claude Codeを活用する前提では、以下の優先順位で学習することを推奨します:

**優先度 高（必須）**:
1. **Astroの基本構造を理解する** — どのファイルが何をするか（`pages/`, `components/`, `layouts/`）
2. **Tailwindの基本クラスを理解する** — 公式ドキュメントで検索できればOK
3. **Markdownでコンテンツを書く** — 記事・お知らせの追加方法

**優先度 中（推奨）**:
4. **GitHub PagesまたはVercelへのデプロイ手順** — 自動デプロイの仕組み
5. **基本的なHTML/CSSの読み方** — Claude Codeが生成したコードを読んで理解できる程度

**優先度 低（オプション）**:
6. **JavaScriptの詳細** — インタラクティブな要素が不要なら深く学ぶ必要なし
7. **CSSの深い知識** — Tailwindを使うため、カスタムCSSは最小限でOK

---

## まとめ

### 最短ルート（Claude Code活用型）

1. **HTML/CSS基礎（1週間）**: MDN Web Docsで基本を押さえる
2. **Tailwind CSS（1週間）**: 公式ドキュメント + 日本語記事で基本クラスを理解
3. **Astro公式チュートリアル完走（1週間）**: Build a Blogを最後まで完了
4. **テンプレート（Carrington）を使って構築開始（1週間）**: Claude Codeに指示してカスタマイズ
5. **デプロイ（1日）**: GitHub PagesまたはVercelに公開
6. **コンテンツ追加・運用開始**: Markdownで記事を書き、Claude Codeでデザイン調整

**合計: 約1ヶ月で基本的な法律事務所HPを公開可能**

---

### 成功のポイント

1. **完璧を目指さない**: 最初は小さく始め、公開後に改善を重ねる
2. **テンプレートを活用**: Carringtonのような専門テンプレートを土台にする
3. **Claude Codeとの協働**: コーディングはClaude Codeに任せ、殿は企画・コンテンツ・判断に集中
4. **公式ドキュメントを味方に**: Astro・Tailwindの公式ドキュメントは検索性が高く、初心者でも理解しやすい
5. **コミュニティを活用**: Qiita・Zenn・GitHub Discussionsで質問・情報収集

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

### テンプレート
- [Carrington（法律事務所専用）](https://lexingtonthemes.com/templates/carrington)
- [AstroWind（汎用）](https://astrowind.vercel.app/)
- [Astro公式テーマディレクトリ](https://astro.build/themes/)

---

**作成者**: 足軽1号（Ashigaru1）
**調査日**: 2026-02-12
**親タスク**: cmd_122
