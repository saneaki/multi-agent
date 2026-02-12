# Astro + Tailwind CSS 法律事務所HP構築ガイド

**作成日**: 2026-02-12
**対象者**: Web開発初心者（Claude Code、GitHub、Notion は使える方）
**用途**: 倉敷市の弁護士事務所ホームページ

---

## 目次

1. [開発環境セットアップ](#1-開発環境セットアップ)
2. [プロジェクト初期化](#2-プロジェクト初期化)
3. [Tailwind CSS v4 導入](#3-tailwind-css-v4-導入)
4. [ページ構成の設計と作成](#4-ページ構成の設計と作成)
5. [コンポーネント設計](#5-コンポーネント設計)
6. [コンテンツ作成（Markdown/MDX）](#6-コンテンツ作成markdownmdx)
7. [問い合わせフォーム実装](#7-問い合わせフォーム実装)
8. [SEO対策（特にローカルSEO）](#8-seo対策特にローカルseo)
9. [デプロイ手順](#9-デプロイ手順)
10. [独自ドメイン設定](#10-独自ドメイン設定)
11. [想定スケジュール](#11-想定スケジュール)

---

## 1. 開発環境セットアップ

### 必要なツール

#### 1.1 Node.js のインストール

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

#### 1.2 パッケージマネージャーの選択

Astro では npm、pnpm、yarn が使用可能。**pnpm を推奨**（高速・ディスク容量節約）。

```bash
# pnpm のインストール（npm 経由）
npm install -g pnpm

# バージョン確認
pnpm --version
```

#### 1.3 VS Code 拡張機能（推奨）

- **Astro** - Astro ファイルのシンタックスハイライト
- **Tailwind CSS IntelliSense** - Tailwind クラス名の自動補完
- **Prettier - Code formatter** - コード整形
- **ESLint** - コード品質チェック

VS Code で拡張機能タブを開き、上記を検索してインストール。

---

## 2. プロジェクト初期化

### 2.1 Astro プロジェクトの作成

```bash
# プロジェクト作成
npm create astro@latest

# 対話式の質問に答える:
# - Where should we create your new project? → 任意のプロジェクト名（例: law-firm-site）
# - How would you like to start your new project? → Empty（空のテンプレート）
# - Do you plan to write TypeScript? → Yes（推奨）
# - How strict should TypeScript be? → Strict（推奨）
# - Install dependencies? → Yes
# - Initialize a new git repository? → Yes
```

### 2.2 プロジェクトディレクトリに移動

```bash
cd law-firm-site
```

### 2.3 開発サーバーの起動確認

```bash
npm run dev
# または pnpm を使う場合
pnpm dev
```

ブラウザで `http://localhost:4321` にアクセスし、Astro のウェルカムページが表示されることを確認。

---

## 3. Tailwind CSS v4 導入

### 3.1 Tailwind v4 を Vite プラグイン経由で導入（2026年推奨方法）

**重要**: `@astrojs/tailwind` インテグレーションは Tailwind v3 向けで非推奨。Tailwind v4 では **Vite プラグイン** を使用。

#### 3.1.1 依存パッケージのインストール

```bash
npm install -D @tailwindcss/vite
# または
pnpm add -D @tailwindcss/vite
```

#### 3.1.2 Astro 設定ファイルの編集

**ファイル**: `astro.config.mjs`

```javascript
// @ts-check
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

// https://astro.build/config
export default defineConfig({
  vite: {
    plugins: [tailwindcss()],
  },
});
```

#### 3.1.3 グローバル CSS ファイルの作成

**ファイル**: `src/styles/global.css`

```css
@import "tailwindcss";
```

#### 3.1.4 レイアウトファイルで CSS をインポート

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

#### 3.1.5 動作確認

`src/pages/index.astro` を編集して Tailwind が動作するか確認:

```astro
---
import Layout from '../layouts/Layout.astro';
---

<Layout title="倉敷法律事務所">
  <main class="min-h-screen bg-gray-100 flex items-center justify-center">
    <h1 class="text-4xl font-bold text-blue-600">
      倉敷法律事務所
    </h1>
  </main>
</Layout>
```

開発サーバーを再起動し、`http://localhost:4321` で青色の大きな見出しが表示されればOK。

---

## 4. ページ構成の設計と作成

### 4.1 法律事務所サイトの推奨ページ構成

法律事務所のウェブサイトに必要なページ:

| ページ名 | URL | 目的 |
|---------|-----|------|
| トップページ | `/` | ファーストビュー、事務所概要、取扱分野、アクセス |
| 弁護士紹介 | `/attorneys` | プロフィール、経歴、実績、専門分野 |
| 取扱分野 | `/practice-areas` | 離婚、相続、交通事故、債務整理等 |
| 料金 | `/fees` | 相談料、着手金、報酬金の目安 |
| アクセス | `/access` | 地図、最寄駅、駐車場情報、営業時間 |
| お問い合わせ | `/contact` | 問い合わせフォーム |
| プライバシーポリシー | `/privacy` | 個人情報の取り扱い |

### 4.2 ディレクトリ構造

```
law-firm-site/
├── src/
│   ├── pages/
│   │   ├── index.astro          # トップページ
│   │   ├── attorneys.astro      # 弁護士紹介
│   │   ├── practice-areas.astro # 取扱分野
│   │   ├── fees.astro           # 料金
│   │   ├── access.astro         # アクセス
│   │   ├── contact.astro        # お問い合わせ
│   │   └── privacy.astro        # プライバシーポリシー
│   ├── components/
│   │   ├── Header.astro         # ヘッダー（ナビゲーション）
│   │   ├── Footer.astro         # フッター
│   │   ├── CTAButton.astro      # お問い合わせボタン
│   │   └── PracticeAreaCard.astro # 取扱分野カード
│   ├── layouts/
│   │   └── Layout.astro         # 基本レイアウト
│   └── styles/
│       └── global.css           # グローバルCSS
└── public/
    ├── images/                  # 画像ファイル
    └── favicon.svg              # ファビコン
```

### 4.3 各ページの作成サンプル

#### 4.3.1 トップページ（index.astro）

```astro
---
import Layout from '../layouts/Layout.astro';
import Header from '../components/Header.astro';
import Footer from '../components/Footer.astro';
import CTAButton from '../components/CTAButton.astro';
---

<Layout title="倉敷法律事務所 | 倉敷市の弁護士">
  <Header />

  <!-- ファーストビュー -->
  <section class="bg-blue-900 text-white py-20">
    <div class="container mx-auto px-4 text-center">
      <h1 class="text-5xl font-bold mb-4">
        倉敷法律事務所
      </h1>
      <p class="text-xl mb-8">
        地域の皆様に寄り添い、最善の解決を目指します
      </p>
      <CTAButton href="/contact">
        無料相談予約
      </CTAButton>
    </div>
  </section>

  <!-- 事務所概要 -->
  <section class="py-16 bg-gray-50">
    <div class="container mx-auto px-4">
      <h2 class="text-3xl font-bold text-center mb-8">
        事務所概要
      </h2>
      <p class="text-center max-w-2xl mx-auto text-lg">
        当事務所は倉敷市で20年以上、地域の皆様の法律問題を解決してまいりました。
        離婚、相続、交通事故、債務整理など、幅広い分野に対応しています。
      </p>
    </div>
  </section>

  <!-- 取扱分野 -->
  <section class="py-16">
    <div class="container mx-auto px-4">
      <h2 class="text-3xl font-bold text-center mb-8">
        取扱分野
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
        <!-- 離婚 -->
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h3 class="text-xl font-bold mb-4">離婚・男女問題</h3>
          <p>離婚調停、財産分与、親権、養育費など</p>
        </div>
        <!-- 相続 -->
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h3 class="text-xl font-bold mb-4">相続・遺言</h3>
          <p>遺産分割、遺言書作成、相続放棄など</p>
        </div>
        <!-- 交通事故 -->
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h3 class="text-xl font-bold mb-4">交通事故</h3>
          <p>後遺障害認定、損害賠償請求など</p>
        </div>
      </div>
    </div>
  </section>

  <!-- アクセス -->
  <section class="py-16 bg-gray-50">
    <div class="container mx-auto px-4 text-center">
      <h2 class="text-3xl font-bold mb-4">アクセス</h2>
      <p class="mb-2">〒710-0055 岡山県倉敷市阿知1丁目7-2</p>
      <p class="mb-2">JR倉敷駅 徒歩5分</p>
      <p>TEL: 086-XXX-XXXX</p>
    </div>
  </section>

  <Footer />
</Layout>
```

#### 4.3.2 弁護士紹介ページ（attorneys.astro）

```astro
---
import Layout from '../layouts/Layout.astro';
import Header from '../components/Header.astro';
import Footer from '../components/Footer.astro';

const attorneys = [
  {
    name: "山田 太郎",
    title: "代表弁護士",
    experience: "弁護士歴25年",
    specialties: ["離婚・男女問題", "相続・遺言"],
    bio: "東京大学法学部卒業。大手法律事務所を経て倉敷法律事務所を開設。地域密着型の法律サービスを提供しています。",
    image: "/images/attorney1.jpg"
  },
  // 他の弁護士を追加
];
---

<Layout title="弁護士紹介 | 倉敷法律事務所">
  <Header />

  <main class="py-16">
    <div class="container mx-auto px-4">
      <h1 class="text-4xl font-bold text-center mb-12">弁護士紹介</h1>

      {attorneys.map(attorney => (
        <div class="bg-white rounded-lg shadow-md p-8 mb-8 flex flex-col md:flex-row gap-6">
          <img
            src={attorney.image}
            alt={attorney.name}
            class="w-48 h-48 rounded-full object-cover"
          />
          <div class="flex-1">
            <h2 class="text-2xl font-bold mb-2">{attorney.name}</h2>
            <p class="text-gray-600 mb-2">{attorney.title} | {attorney.experience}</p>
            <div class="mb-4">
              <strong>専門分野:</strong> {attorney.specialties.join(", ")}
            </div>
            <p>{attorney.bio}</p>
          </div>
        </div>
      ))}
    </div>
  </main>

  <Footer />
</Layout>
```

---

## 5. コンポーネント設計

### 5.1 ヘッダーコンポーネント（Header.astro）

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
      <!-- ロゴ -->
      <a href="/" class="text-2xl font-bold text-blue-900">
        倉敷法律事務所
      </a>

      <!-- デスクトップナビゲーション -->
      <ul class="hidden md:flex space-x-6">
        {navItems.map(item => (
          <li>
            <a
              href={item.href}
              class="text-gray-700 hover:text-blue-600 transition-colors"
            >
              {item.name}
            </a>
          </li>
        ))}
      </ul>

      <!-- モバイルメニューボタン -->
      <button
        id="mobile-menu-button"
        class="md:hidden p-2"
        aria-label="メニューを開く"
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
        </svg>
      </button>
    </div>

    <!-- モバイルメニュー -->
    <ul id="mobile-menu" class="hidden md:hidden mt-4 space-y-2">
      {navItems.map(item => (
        <li>
          <a
            href={item.href}
            class="block py-2 text-gray-700 hover:text-blue-600"
          >
            {item.name}
          </a>
        </li>
      ))}
    </ul>
  </nav>
</header>

<script>
  // モバイルメニューのトグル
  const button = document.getElementById('mobile-menu-button');
  const menu = document.getElementById('mobile-menu');

  button?.addEventListener('click', () => {
    menu?.classList.toggle('hidden');
  });
</script>
```

### 5.2 フッターコンポーネント（Footer.astro）

```astro
<footer class="bg-gray-900 text-white py-8">
  <div class="container mx-auto px-4">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
      <!-- 事務所情報 -->
      <div>
        <h3 class="text-xl font-bold mb-4">倉敷法律事務所</h3>
        <p class="text-gray-400">
          〒710-0055<br />
          岡山県倉敷市阿知1丁目7-2<br />
          TEL: 086-XXX-XXXX<br />
          営業時間: 平日 9:00-18:00
        </p>
      </div>

      <!-- リンク -->
      <div>
        <h3 class="text-xl font-bold mb-4">サイトマップ</h3>
        <ul class="space-y-2 text-gray-400">
          <li><a href="/" class="hover:text-white">ホーム</a></li>
          <li><a href="/attorneys" class="hover:text-white">弁護士紹介</a></li>
          <li><a href="/practice-areas" class="hover:text-white">取扱分野</a></li>
          <li><a href="/fees" class="hover:text-white">料金</a></li>
          <li><a href="/contact" class="hover:text-white">お問い合わせ</a></li>
          <li><a href="/privacy" class="hover:text-white">プライバシーポリシー</a></li>
        </ul>
      </div>

      <!-- SNS・その他 -->
      <div>
        <h3 class="text-xl font-bold mb-4">お問い合わせ</h3>
        <p class="text-gray-400 mb-4">
          初回相談無料<br />
          お気軽にご相談ください
        </p>
        <a
          href="/contact"
          class="inline-block bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-md transition-colors"
        >
          無料相談予約
        </a>
      </div>
    </div>

    <div class="border-t border-gray-700 mt-8 pt-8 text-center text-gray-400">
      <p>&copy; 2026 倉敷法律事務所. All rights reserved.</p>
    </div>
  </div>
</footer>
```

### 5.3 CTAボタンコンポーネント（CTAButton.astro）

```astro
---
interface Props {
  href: string;
  variant?: 'primary' | 'secondary';
}

const { href, variant = 'primary' } = Astro.props;

const baseClasses = "inline-block px-8 py-4 rounded-md font-bold text-lg transition-colors";
const variantClasses = {
  primary: "bg-blue-600 hover:bg-blue-700 text-white",
  secondary: "bg-white hover:bg-gray-100 text-blue-900 border-2 border-blue-900",
};
---

<a href={href} class={`${baseClasses} ${variantClasses[variant]}`}>
  <slot />
</a>
```

### 5.4 レスポンシブ対応の考え方

Tailwind CSS のレスポンシブプレフィックスを活用:

```html
<!-- モバイル: 1列、タブレット以上: 2列、デスクトップ: 3列 -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <!-- カード要素 -->
</div>

<!-- モバイル: テキストサイズ小、デスクトップ: テキストサイズ大 -->
<h1 class="text-3xl md:text-5xl font-bold">
  見出し
</h1>

<!-- モバイル: 縦並び、タブレット以上: 横並び -->
<div class="flex flex-col md:flex-row gap-4">
  <!-- 要素 -->
</div>
```

---

## 6. コンテンツ作成（Markdown/MDX）

### 6.1 コンテンツコレクションの活用

Astro のコンテンツコレクション機能を使うと、Markdown/MDX でコンテンツを管理できます。

#### 6.1.1 コンテンツコレクションの設定

**ディレクトリ構造**:

```
src/
├── content/
│   ├── config.ts
│   └── practice-areas/
│       ├── divorce.md
│       ├── inheritance.md
│       ├── traffic-accident.md
│       └── debt-restructuring.md
```

**ファイル**: `src/content/config.ts`

```typescript
import { defineCollection, z } from 'astro:content';

const practiceAreasCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    icon: z.string(),
    order: z.number(),
  }),
});

export const collections = {
  'practice-areas': practiceAreasCollection,
};
```

#### 6.1.2 Markdown ファイルの作成例

**ファイル**: `src/content/practice-areas/divorce.md`

```markdown
---
title: "離婚・男女問題"
description: "離婚調停、財産分与、親権、養育費など、離婚に関するあらゆる問題に対応します。"
icon: "⚖️"
order: 1
---

## 離婚・男女問題について

当事務所では、離婚に関する以下の問題に対応しています。

### 取り扱い内容

- **離婚調停・訴訟**: 協議離婚が難しい場合、調停や裁判をサポート
- **財産分与**: 夫婦の財産を公平に分割
- **親権・養育費**: お子様の親権や養育費の適正額を決定
- **慰謝料請求**: 不貞行為やDVによる慰謝料請求

### 解決事例

過去に100件以上の離婚事件を解決してきました。依頼者様の立場に立ち、最善の解決策を提案いたします。

### 料金の目安

- 相談料: 初回無料（2回目以降 5,500円/30分）
- 着手金: 330,000円〜
- 報酬金: 330,000円〜
```

#### 6.1.3 コンテンツコレクションをページで表示

**ファイル**: `src/pages/practice-areas.astro`

```astro
---
import { getCollection } from 'astro:content';
import Layout from '../layouts/Layout.astro';
import Header from '../components/Header.astro';
import Footer from '../components/Footer.astro';

const practiceAreas = await getCollection('practice-areas');
const sortedAreas = practiceAreas.sort((a, b) => a.data.order - b.data.order);
---

<Layout title="取扱分野 | 倉敷法律事務所">
  <Header />

  <main class="py-16">
    <div class="container mx-auto px-4">
      <h1 class="text-4xl font-bold text-center mb-12">取扱分野</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {sortedAreas.map(area => (
          <a
            href={`/practice-areas/${area.slug}`}
            class="bg-white p-6 rounded-lg shadow-md hover:shadow-xl transition-shadow"
          >
            <div class="text-4xl mb-4">{area.data.icon}</div>
            <h2 class="text-2xl font-bold mb-2">{area.data.title}</h2>
            <p class="text-gray-600">{area.data.description}</p>
          </a>
        ))}
      </div>
    </div>
  </main>

  <Footer />
</Layout>
```

#### 6.1.4 個別ページの動的生成

**ファイル**: `src/pages/practice-areas/[...slug].astro`

```astro
---
import { getCollection } from 'astro:content';
import Layout from '../../layouts/Layout.astro';
import Header from '../../components/Header.astro';
import Footer from '../../components/Footer.astro';

export async function getStaticPaths() {
  const practiceAreas = await getCollection('practice-areas');
  return practiceAreas.map(area => ({
    params: { slug: area.slug },
    props: { area },
  }));
}

const { area } = Astro.props;
const { Content } = await area.render();
---

<Layout title={`${area.data.title} | 倉敷法律事務所`}>
  <Header />

  <main class="py-16">
    <div class="container mx-auto px-4 max-w-4xl">
      <div class="mb-8">
        <a href="/practice-areas" class="text-blue-600 hover:underline">
          ← 取扱分野一覧に戻る
        </a>
      </div>

      <article class="prose lg:prose-xl max-w-none">
        <div class="text-5xl mb-4">{area.data.icon}</div>
        <h1>{area.data.title}</h1>
        <Content />
      </article>
    </div>
  </main>

  <Footer />
</Layout>
```

---

## 7. 問い合わせフォーム実装

### 7.1 無料サービスの比較

| サービス | 無料枠 | 料金 | 設定難易度 | おすすめ度 |
|---------|--------|------|-----------|----------|
| **Netlify Forms** | 100件/月 | $0 → $19/月（100件超） | ★☆☆（簡単） | ★★★★★ |
| **Formspree** | 50件/月 | $0 → $10/月（50件超） | ★★☆（普通） | ★★★★☆ |
| **Google Forms** | 無制限 | 無料 | ★☆☆（簡単） | ★★☆☆☆ |

### 7.2 推奨: Netlify Forms の実装

**メリット**:
- Netlify でホスティングする場合、設定が最も簡単
- スパム対策（reCAPTCHA）が標準装備
- 管理画面で送信内容を確認できる
- Zapier 連携で通知を自動化可能

#### 7.2.1 実装手順

**ファイル**: `src/pages/contact.astro`

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

      <div class="bg-blue-50 p-6 rounded-lg mb-8">
        <p class="text-lg">
          <strong>初回相談無料</strong><br />
          お気軽にご相談ください。通常1営業日以内にご返信いたします。
        </p>
      </div>

      <form
        name="contact"
        method="POST"
        data-netlify="true"
        netlify-honeypot="bot-field"
        class="space-y-6"
      >
        <!-- Netlify Forms に必要な hidden input -->
        <input type="hidden" name="form-name" value="contact" />

        <!-- ハニーポット（スパム対策） -->
        <p class="hidden">
          <label>
            Don't fill this out if you're human: <input name="bot-field" />
          </label>
        </p>

        <!-- お名前 -->
        <div>
          <label for="name" class="block text-sm font-medium mb-2">
            お名前 <span class="text-red-600">*</span>
          </label>
          <input
            type="text"
            id="name"
            name="name"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>

        <!-- メールアドレス -->
        <div>
          <label for="email" class="block text-sm font-medium mb-2">
            メールアドレス <span class="text-red-600">*</span>
          </label>
          <input
            type="email"
            id="email"
            name="email"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>

        <!-- 電話番号 -->
        <div>
          <label for="phone" class="block text-sm font-medium mb-2">
            電話番号
          </label>
          <input
            type="tel"
            id="phone"
            name="phone"
            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>

        <!-- 相談内容 -->
        <div>
          <label for="subject" class="block text-sm font-medium mb-2">
            相談内容 <span class="text-red-600">*</span>
          </label>
          <select
            id="subject"
            name="subject"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">選択してください</option>
            <option value="離婚・男女問題">離婚・男女問題</option>
            <option value="相続・遺言">相続・遺言</option>
            <option value="交通事故">交通事故</option>
            <option value="債務整理">債務整理</option>
            <option value="その他">その他</option>
          </select>
        </div>

        <!-- メッセージ -->
        <div>
          <label for="message" class="block text-sm font-medium mb-2">
            お問い合わせ内容 <span class="text-red-600">*</span>
          </label>
          <textarea
            id="message"
            name="message"
            rows="6"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          ></textarea>
        </div>

        <!-- プライバシーポリシー同意 -->
        <div class="flex items-start">
          <input
            type="checkbox"
            id="privacy"
            name="privacy"
            required
            class="mt-1 mr-2"
          />
          <label for="privacy" class="text-sm">
            <a href="/privacy" class="text-blue-600 hover:underline" target="_blank">
              プライバシーポリシー
            </a>
            に同意します <span class="text-red-600">*</span>
          </label>
        </div>

        <!-- 送信ボタン -->
        <button
          type="submit"
          class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-6 rounded-md transition-colors"
        >
          送信する
        </button>
      </form>
    </div>
  </main>

  <Footer />
</Layout>
```

#### 7.2.2 送信完了ページの作成

**ファイル**: `src/pages/contact-success.astro`

```astro
---
import Layout from '../layouts/Layout.astro';
import Header from '../components/Header.astro';
import Footer from '../components/Footer.astro';
---

<Layout title="お問い合わせありがとうございます | 倉敷法律事務所">
  <Header />

  <main class="py-16">
    <div class="container mx-auto px-4 max-w-2xl text-center">
      <div class="text-6xl mb-4">✅</div>
      <h1 class="text-4xl font-bold mb-4">送信完了</h1>
      <p class="text-lg mb-8">
        お問い合わせありがとうございます。<br />
        通常1営業日以内にご返信いたします。
      </p>
      <a href="/" class="text-blue-600 hover:underline">
        トップページに戻る
      </a>
    </div>
  </main>

  <Footer />
</Layout>
```

#### 7.2.3 Netlify Forms 設定（netlify.toml）

プロジェクトルートに `netlify.toml` を作成:

```toml
[[redirects]]
  from = "/contact"
  to = "/contact-success"
  status = 200
  force = false
  conditions = {Role = ["form-submission"]}
```

### 7.3 代替案: Formspree の実装

**メリット**: プラットフォームに依存しない（GitHub Pages でも使用可能）

#### 実装手順

1. [Formspree](https://formspree.io/) でアカウント作成（無料）
2. 新規フォームを作成し、エンドポイント URL を取得（例: `https://formspree.io/f/YOUR_FORM_ID`）
3. フォームの `action` 属性を変更:

```astro
<form
  action="https://formspree.io/f/YOUR_FORM_ID"
  method="POST"
  class="space-y-6"
>
  <!-- Netlify 固有の属性を削除 -->
  <!-- フォーム要素はそのまま -->
</form>
```

### 7.4 代替案: Google Forms 埋め込み

**メリット**: 完全無料、簡単
**デメリット**: デザインの自由度が低い、ブランディングに不向き

1. Google Forms で問い合わせフォームを作成
2. 「送信」→「埋め込みコード」をコピー
3. `contact.astro` に `<iframe>` として埋め込む

---

## 8. SEO対策（特にローカルSEO）

### 8.1 メタタグ設定

#### 8.1.1 基本レイアウトの SEO メタタグ

**ファイル**: `src/layouts/Layout.astro`（拡張版）

```astro
---
interface Props {
  title: string;
  description?: string;
  image?: string;
  type?: 'website' | 'article';
}

const {
  title,
  description = "倉敷市の法律事務所。離婚、相続、交通事故、債務整理など幅広い分野に対応。初回相談無料。",
  image = "/images/og-image.jpg",
  type = 'website'
} = Astro.props;

const canonicalURL = new URL(Astro.url.pathname, Astro.site);
const siteTitle = "倉敷法律事務所";
const fullTitle = title.includes(siteTitle) ? title : `${title} | ${siteTitle}`;
---

<!doctype html>
<html lang="ja">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <meta name="generator" content={Astro.generator} />

    <!-- SEO基本 -->
    <title>{fullTitle}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonicalURL} />

    <!-- Open Graph (Facebook, LinkedIn) -->
    <meta property="og:type" content={type} />
    <meta property="og:url" content={canonicalURL} />
    <meta property="og:title" content={fullTitle} />
    <meta property="og:description" content={description} />
    <meta property="og:image" content={new URL(image, Astro.site)} />
    <meta property="og:site_name" content={siteTitle} />
    <meta property="og:locale" content="ja_JP" />

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={fullTitle} />
    <meta name="twitter:description" content={description} />
    <meta name="twitter:image" content={new URL(image, Astro.site)} />

    <!-- ローカルSEO用キーワード -->
    <meta name="keywords" content="倉敷市,弁護士,法律事務所,離婚,相続,交通事故,債務整理,岡山県" />

    <!-- Google検証（Google Search Console 登録後に追加） -->
    <!-- <meta name="google-site-verification" content="YOUR_VERIFICATION_CODE" /> -->
  </head>
  <body>
    <slot />
  </body>
</html>

<style is:global>
  @import "../styles/global.css";
</style>
```

### 8.2 構造化データ（Schema.org）

#### 8.2.1 LocalBusiness + LegalService スキーマ

法律事務所向けの構造化データを追加します。

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
      "logo": "https://yoursite.com/images/logo.png",
      "image": "https://yoursite.com/images/office.jpg",
      "description": "倉敷市の法律事務所。離婚、相続、交通事故、債務整理など幅広い分野に対応。",
      "areaServed": {
        "@type": "City",
        "name": "倉敷市"
      },
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
      ],
      "priceRange": "$$",
      "sameAs": [
        "https://www.facebook.com/yourpage",
        "https://twitter.com/yourpage"
      ]
    },
    {
      "@type": "Attorney",
      "@id": "https://yoursite.com/#attorney",
      "name": "山田 太郎",
      "jobTitle": "代表弁護士",
      "worksFor": {
        "@id": "https://yoursite.com/#legalservice"
      },
      "alumniOf": "東京大学法学部",
      "knowsAbout": ["離婚法", "相続法", "交通事故", "債務整理"]
    },
    {
      "@type": "WebSite",
      "@id": "https://yoursite.com/#website",
      "url": "https://yoursite.com",
      "name": "倉敷法律事務所",
      "publisher": {
        "@id": "https://yoursite.com/#legalservice"
      }
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

### 8.3 ローカルSEO対策

#### 8.3.1 キーワード戦略（倉敷市 弁護士向け）

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

#### 8.3.2 Google Business Profile（旧 Google マイビジネス）登録

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

#### 8.3.3 地域ポータルサイトへの登録

**無料で登録できる主要サイト**:

- **弁護士ドットコム**: https://www.bengo4.com/
- **日本弁護士連合会**: https://www.nichibenren.or.jp/
- **エキテン**: https://www.ekiten.jp/
- **Yahoo!ロコ**: https://loco.yahoo.co.jp/
- **Bing Places**: https://www.bingplaces.com/

すべてのサイトで NAP 情報を統一する。

#### 8.3.4 ローカル被リンク獲得

- 倉敷市の商工会議所
- 地域のビジネス団体
- 地域ブログやニュースサイト（プレスリリース配信）

### 8.4 サイトマップ自動生成

#### 8.4.1 @astrojs/sitemap インテグレーションの導入

```bash
npx astro add sitemap
# または
pnpm astro add sitemap
```

#### 8.4.2 astro.config.mjs に site URL を追加

```javascript
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: 'https://yoursite.com', // 実際のドメインに変更
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [sitemap()],
});
```

ビルド時に `dist/sitemap-index.xml` と `dist/sitemap-0.xml` が自動生成されます。

#### 8.4.3 robots.txt の作成

**ファイル**: `public/robots.txt`

```
User-agent: *
Allow: /

Sitemap: https://yoursite.com/sitemap-index.xml
```

### 8.5 Core Web Vitals（Astroの強み）

Astro は **SSG**（静的サイト生成）と **Island Architecture**（部分ハイドレーション）により、高速表示を実現:

- **LCP**（Largest Contentful Paint）: 静的HTMLの高速配信で2.5秒以内を達成
- **FID**（First Input Delay）: 不要なJavaScriptを削除し、100ms以内を達成
- **CLS**（Cumulative Layout Shift）: レイアウトシフトを最小化

**最適化のポイント**:
- 画像は WebP 形式で配信（Astro の `<Image>` コンポーネント使用）
- フォントの先読み（`<link rel="preload">`）
- 不要な JavaScript を削除（Island Architecture で必要な部分のみロード）

---

## 9. デプロイ手順

### 9.1 GitHub Pages へのデプロイ

#### 9.1.1 事前準備

1. GitHub でリポジトリを作成（例: `law-firm-site`）
2. ローカルリポジトリを GitHub にプッシュ:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/law-firm-site.git
git push -u origin main
```

#### 9.1.2 astro.config.mjs の設定

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

カスタムドメインを使う場合（後述）は `base` 不要。

#### 9.1.3 GitHub Actions ワークフローの作成

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

#### 9.1.4 GitHub Pages の有効化

1. GitHub リポジトリページ → Settings → Pages
2. **Source**: "GitHub Actions" を選択
3. `main` ブランチにプッシュすると自動デプロイが開始

デプロイ完了後、`https://YOUR_USERNAME.github.io/law-firm-site/` でサイトが公開されます。

### 9.2 Vercel へのデプロイ

#### 9.2.1 Vercel アカウント作成

1. [Vercel](https://vercel.com/) にアクセス
2. "Sign Up" → GitHub アカウントで認証

#### 9.2.2 リポジトリ連携

1. Vercel ダッシュボード → "Add New..." → "Project"
2. GitHub リポジトリ（`law-firm-site`）を選択
3. "Import"

#### 9.2.3 自動デプロイ設定

Vercel は Astro プロジェクトを自動検出し、以下のデフォルト設定を適用:

- **Framework Preset**: Astro
- **Build Command**: `astro build`
- **Output Directory**: `dist`
- **Install Command**: `pnpm install`（pnpm 使用時）

"Deploy" をクリックすると、自動でビルド&デプロイが開始されます。

#### 9.2.4 デプロイ完了

デプロイ完了後、Vercel が自動生成した URL（例: `https://law-firm-site.vercel.app`）でサイトが公開されます。

`main` ブランチへのプッシュごとに自動デプロイされます。

---

## 10. 独自ドメイン設定

### 10.1 ドメイン取得

#### 10.1.1 推奨レジストラ

| サービス | 料金目安（.com） | 特徴 |
|---------|----------------|------|
| **Cloudflare Registrar** | $9.77/年 | 卸売価格、追加費用なし、WHOIS プライバシー無料 |
| **お名前.com** | 初年度 1円〜、2年目以降 1,408円/年 | 日本語サポート、更新料に注意 |
| **Google Domains** | $12/年 | シンプル、WHOIS プライバシー無料 |

**推奨**: **Cloudflare Registrar**（コスパ最強、DNS も Cloudflare で一元管理）

#### 10.1.2 ドメイン名の例

- `kurashiki-law.com`
- `kurashiki-legal.jp`
- `kurashiki-bengoshi.jp`

.jp ドメインは日本の法人・個人のみ取得可能で、信頼性が高い。

### 10.2 DNS 設定

#### 10.2.1 GitHub Pages の場合

**手順**:

1. DNS プロバイダー（Cloudflare、お名前.com など）で以下のレコードを追加:

**Apex ドメイン（例: `kurashiki-law.com`）を使う場合**:

| タイプ | 名前 | 値 | TTL |
|-------|------|-----|-----|
| A | @ | 185.199.108.153 | Auto |
| A | @ | 185.199.109.153 | Auto |
| A | @ | 185.199.110.153 | Auto |
| A | @ | 185.199.111.153 | Auto |

**サブドメイン（例: `www.kurashiki-law.com`）を使う場合**:

| タイプ | 名前 | 値 | TTL |
|-------|------|-----|-----|
| CNAME | www | YOUR_USERNAME.github.io | Auto |

2. GitHub リポジトリ → Settings → Pages → Custom domain に `kurashiki-law.com` を入力
3. "Enforce HTTPS" にチェック（SSL 証明書が自動発行されます）
4. `public/CNAME` ファイルを作成し、ドメイン名を記述:

```
kurashiki-law.com
```

DNS 反映には最大48時間かかる場合があります（通常は数分〜数時間）。

#### 10.2.2 Vercel の場合

**手順**:

1. Vercel プロジェクト → Settings → Domains
2. "Add" をクリックし、ドメイン名を入力（例: `kurashiki-law.com`）
3. Vercel が DNS 設定方法を表示:

**Cloudflare DNS の場合**:

| タイプ | 名前 | 値 | Proxy status |
|-------|------|-----|-------------|
| CNAME | @ | cname.vercel-dns.com | DNS only |

**お名前.com の場合**:

ネームサーバーを Cloudflare に変更するか、お名前.com の DNS 設定で CNAME レコードを追加:

| タイプ | 名前 | 値 |
|-------|------|-----|
| CNAME | www | cname.vercel-dns.com |

4. Vercel が DNS を検証し、SSL 証明書を自動発行

#### 10.2.3 Cloudflare 経由の設定（推奨）

**メリット**:
- 高速な CDN
- DDoS 攻撃対策
- 無料の SSL 証明書
- キャッシュ最適化

**手順**:

1. Cloudflare でドメインを取得（または既存ドメインを追加）
2. DNS レコードを設定（上記参照）
3. Cloudflare の SSL/TLS 設定 → "Full" または "Full (strict)" を選択
4. "Always Use HTTPS" を有効化

---

## 11. 想定スケジュール

### 11.1 スケジュールの前提

- **学習曲線**: HTML/CSS の基礎知識がある場合、学習期間は短縮可能
- **Claude Code の活用**: コード生成・デバッグを Claude Code に任せることで大幅に短縮
- **コンテンツ準備**: 事務所情報、弁護士プロフィール、取扱分野の文章を事前準備

### 11.2 パターンA: 週5時間（平日1時間）投下

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

### 11.3 パターンB: 週10時間（平日1h + 週末5h）投下

| フェーズ | 作業内容 | 期間 | 累計時間 |
|---------|---------|------|---------|
| **学習** | Tailwind CSS + Astro 基礎 | 2週間 | 20h |
| **実装** | 環境構築・レイアウト・トップページ | 1週間 | 30h |
| **実装** | 各ページ作成 | 2週間 | 50h |
| **実装** | 問い合わせフォーム・SEO | 1週間 | 60h |
| **実装** | レスポンシブ調整・細部調整 | 1週間 | 70h |
| **デプロイ** | デプロイ・ドメイン設定 | 1週間 | 80h |

**合計期間**: **約8週間（約2ヶ月）**

### 11.4 パターンC: 週20時間（集中期間）投下

| フェーズ | 作業内容 | 期間 | 累計時間 |
|---------|---------|------|---------|
| **学習** | Tailwind CSS + Astro 基礎（集中学習） | 1週間 | 20h |
| **実装** | 環境構築・レイアウト・全ページ作成 | 2週間 | 60h |
| **実装** | フォーム・SEO・細部調整 | 1週間 | 80h |
| **デプロイ** | デプロイ・ドメイン設定・運用準備 | 1週間 | 100h |

**合計期間**: **約5週間（約1ヶ月）**

### 11.5 Claude Code 活用による短縮効果

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

## まとめ

このガイドに従えば、Web開発初心者でも **Astro + Tailwind CSS** で法律事務所のホームページを構築できます。

### 重要なポイント

1. **高速表示**: Astro の SSG により Core Web Vitals を最適化
2. **ローカルSEO**: Google Business Profile、構造化データ、地域キーワード戦略
3. **無料デプロイ**: GitHub Pages または Vercel で無料ホスティング
4. **問い合わせフォーム**: Netlify Forms で簡単に実装
5. **Claude Code 活用**: 開発時間を大幅に短縮

### 次のステップ

1. このガイドを参考に開発を開始
2. 不明点は Claude Code に質問しながら進める
3. コンテンツを充実させ、定期的に更新
4. Google Business Profile の口コミを集める
5. アクセス解析（Google Analytics）を導入し、改善を継続

---

## 参考リンク

### 公式ドキュメント

- [Astro Documentation](https://docs.astro.build/)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Astro + Tailwind v4 Setup Guide](https://tailkits.com/blog/astro-tailwind-setup/)
- [Deploy Astro to GitHub Pages](https://docs.astro.build/en/guides/deploy/github/)
- [Deploy Astro to Vercel](https://docs.astro.build/en/guides/deploy/vercel/)

### SEO・構造化データ

- [Schema Markup for Law Firms](https://bigdogict.com/seo/semantic-search-engine-optimization/schema/)
- [Local SEO Schema Guide](https://www.searchenginejournal.com/how-to-use-schema-for-local-seo-a-complete-guide/294973/)
- [弁護士のMEO対策方法](https://white-link.com/sem-plus/meo_lawyer/)
- [弁護士・司法書士向けGoogleビジネスプロフィール活用法](https://www.samurai-lab.jp/googleplace/)

### フォーム実装

- [Netlify Forms vs Formspree Comparison](https://vanillawebsites.co.uk/blog/netlify-forms-vs-formspree/)
- [Formspree Official Site](https://formspree.io/)

### デプロイ・ドメイン

- [お名前.comからCloudflareへの移管](https://zenn.dev/muchoco/articles/9039762136e15c)
- [Cloudflare DNS設定ガイド](https://shukapin.com/blog/change-ns-from-onamae-com)

---

**作成者**: 足軽3号（Technical Writer）
**タスクID**: subtask_122c
**親コマンド**: cmd_122
**作成日**: 2026-02-12
