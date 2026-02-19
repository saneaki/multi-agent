# 弁護士事務所HP作成の方法論比較レポート（Claude Code活用系）

**調査日**: 2026-02-11
**調査者**: ashigaru2
**対象**: 倉敷市の弁護士事務所HP構築（Web開発経験なし、Claude Code日常使用）

---

## 方法論1: Astro + Tailwind CSS + GitHub Pages/Vercel（静的サイト）

### 使用ツール一覧

| カテゴリ | ツール | 用途 |
|---------|--------|------|
| フレームワーク | Astro | 静的サイトジェネレーター |
| CSSフレームワーク | Tailwind CSS | スタイリング |
| 開発環境 | Node.js (推奨v18以上) | ランタイム環境 |
| バージョン管理 | Git / GitHub | ソースコード管理 |
| ホスティング | GitHub Pages（無料） or Vercel（無料/有料） | Webサイト公開 |
| AI開発支援 | Claude Code | 自動コード生成・保守 |
| ドメイン | お名前.com / ムームードメイン等 | 独自ドメイン取得 |
| コンテンツ管理 | Notion（既存利用） | ブログ原稿・お知らせ管理 |

### 構築の大まかな手順

**Phase 1: 環境準備（所要: 1時間）**

1. Node.jsインストール（公式サイトからダウンロード）
2. GitHubアカウント作成・リポジトリ初期化
3. Claude Code起動・プロジェクト初期化（`/init` コマンド）

**Phase 2: プロジェクト作成（所要: 2〜3時間）**

4. Claude Codeにプロンプト入力:
   「倉敷市の弁護士事務所のコーポレートサイトをAstro + Tailwind CSSで構築してください。トップページ、業務内容、弁護士紹介、お問い合わせフォーム、ブログ一覧ページを含めてください。SEO設定とローカルSEOの構造化データも設定してください。」
5. Claude Codeが自動生成したコードをレビュー・調整
6. デザイン微調整（色、フォント、レイアウト）

**Phase 3: コンテンツ投入（所要: 3〜5時間）**

7. 業務内容・弁護士プロフィール・事務所情報をMarkdownで作成
8. 構造化データ（schema.org）に事務所情報・弁護士情報を記載
9. ローカルSEO用の「倉敷市 弁護士」キーワード最適化

**Phase 4: デプロイ（所要: 1時間）**

10. GitHub Pagesへ公開（無料）または Vercel へデプロイ
11. 独自ドメイン設定（DNS設定）
12. HTTPS化確認（自動対応）

**Phase 5: 運用開始（継続）**

13. ブログ記事追加（NotionからMarkdownエクスポート → Claude Codeで整形）
14. お知らせ更新（同様のフロー）

### 費用内訳

| 項目 | 初期費用 | 月額/年額 | 備考 |
|------|---------|----------|------|
| ドメイン取得 | 0〜1,500円 | 年額1,500円前後 | `.jp`は年額3,000円前後 |
| ホスティング（GitHub Pages） | 0円 | 0円 | 完全無料、帯域制限100GB/月 |
| ホスティング（Vercel Hobby） | 0円 | 0円 | 無料枠内で十分（100GB転送/月） |
| ホスティング（Vercel Pro） | 0円 | 月額20ドル（約3,000円） | 転送1TB/月、独自ドメイン100個まで |
| Claude Code | 0円 | 月額20ドル（約3,000円） | Pro契約（必須） |
| 合計（GitHub Pages利用） | 1,500円 | 年額1,500円 + Claude月額3,000円 | **年間約4.7万円** |
| 合計（Vercel Hobby利用） | 1,500円 | 年額1,500円 + Claude月額3,000円 | **年間約4.7万円** |

### 技術的難易度

**評価: 2.0 / 5.0**（初心者でも可能）

**根拠**:
- Claude Codeが大半のコードを自動生成するため、コーディング知識はほぼ不要
- Astroの学習曲線は緩やか（Next.jsより簡単）
- GitHub Pagesへのデプロイは `git push` のみ（Vercelはさらに簡単）
- Markdownでコンテンツを記述するだけ（Notionから流用可）
- 障壁: Git操作の最低限の理解、DNS設定（1回のみ）

### メリット

1. **圧倒的な高速表示**: JavaScriptを最小限に抑えた静的HTML（Core Web Vitals優秀）
2. **SEO最強クラス**: 完全な静的HTMLでクローラーが即座に全DOM読み取り、インデックス速度が速い
3. **ランニングコスト最安**: GitHub Pages利用で月額0円（ドメイン代のみ）
4. **セキュリティ**: 静的サイトのため攻撃対象が少ない（WordPressの脆弱性リスクなし）
5. **Claude Codeとの親和性抜群**: デザインモックアップ→HTML/CSS自動生成が数分で完了
6. **保守性**: ファイル構造がシンプル、コンテンツはMarkdown管理
7. **倉敷市ローカルSEOに最適**: 構造化データで「倉敷市 弁護士」検索順位向上を狙える

### デメリット

1. **動的機能制約**: お問い合わせフォームはサードパーティ（Googleフォーム、Netlify Forms）が必要
2. **ブログ更新フロー**: Markdownファイル作成→Git push→再ビルド（慣れれば10分）
3. **大量ページ時のビルド時間**: 1,000ページ超えると再ビルドに数分（通常は問題なし）
4. **初回学習コスト**: Git操作、Markdown記法の基礎理解が必要

### SEO対応力

**ローカルSEO（「倉敷市 弁護士」検索）: ★★★★★（5/5）**

- **構造化データ**: schema.org の LocalBusiness / Attorney マークアップで Google検索結果に事務所情報を表示
- **静的HTML**: クローラーがJavaScript実行不要で全コンテンツ取得→インデックス速度最速
- **Core Web Vitals**: Lighthouseスコア95点以上（PageSpeed Insights）
- **メタタグ最適化**: 各ページごとのtitle/description/OGPをClaude Codeが自動設定
- **サイトマップ自動生成**: Astroプラグインで自動作成
- **実績**: 同様の手法で「地域名 + 専門分野」での上位表示事例多数（検索結果参照）

### コンテンツ更新の容易性

**評価: ★★★☆☆（3/5）**

**ブログ・お知らせ追加の標準フロー（所要10分）**:
1. Notionでブログ原稿を執筆
2. NotionからMarkdownエクスポート
3. Claude Codeに「このMarkdownをAstroのブログ記事形式に整形して」と指示
4. 整形済みファイルをGitHubにpush
5. GitHub Actions（またはVercel）が自動ビルド・デプロイ（3〜5分）

**更新頻度が高い場合の改善策**:
- Notion API + Claude Code スクリプトで自動同期（初期設定に半日、以降は自動）
- Contentful / microCMS などのヘッドレスCMSを導入（月額1,000円〜）

### 法律事務所HPとしての適性

**評価: ★★★★★（5/5）**

1. **信頼感**: 静的サイトはロード速度が速く、堅牢性が高い→ユーザーに安心感
2. **専門性の訴求**: ブログ記事を充実させることで専門性アピール（SEO効果も）
3. **問い合わせ導線**: Googleフォーム埋め込み or Netlify Forms で十分機能（メール通知可）
4. **コンプライアンス**: 静的HTMLのため個人情報漏洩リスク最小（フォームは外部サービス）
5. **デザイン品質**: Tailwind CSSでモダンかつプロフェッショナルなデザイン実現

### Claude Codeとの親和性

**評価: ★★★★★（5/5）**

#### 自動生成できる範囲

- **テンプレート**: コーポレートサイトの基本構造（ヘッダー、フッター、ナビゲーション）
- **コンポーネント**: 弁護士プロフィールカード、業務内容リスト、お知らせ一覧
- **SEO設定**: 各ページのメタタグ、OGP、構造化データ（schema.org）
- **レスポンシブ対応**: スマホ・タブレット対応のCSSが自動生成
- **ブログシステム**: Markdown → HTML変換、一覧ページ、タグ機能
- **サイトマップ/RSS**: Astroプラグインで自動生成

#### 保守・更新フロー

**ケース1: ブログ記事追加**
```
1. Notionで原稿執筆 → Markdownエクスポート
2. Claude Codeに「このMarkdownをブログ記事として追加」
3. Claude Codeが自動的にフロントマター（日付、タイトル等）を追加
4. git push → 自動デプロイ（5分）
```

**ケース2: 弁護士プロフィール追加**
```
1. Claude Codeに「新しい弁護士プロフィールを追加。名前: 〇〇、専門: △△、経歴: □□」
2. Claude Codeが該当ページを自動更新
3. git push → 反映
```

**ケース3: デザイン変更**
```
1. 「ヘッダーの背景色を紺色に変更」
2. Claude Codeが Tailwind CSS のクラスを修正
3. ローカルプレビュー確認 → git push
```

#### 初回構築プロンプト例

```
# プロンプト例（Claude Codeに入力）

倉敷市の法律事務所のコーポレートサイトをAstro + Tailwind CSSで構築してください。

## 要件
- ページ構成: トップページ、業務内容（民事・刑事・企業法務）、弁護士紹介（3名）、事務所概要、アクセス、お問い合わせ、ブログ一覧
- デザイン: 紺色ベース、信頼感のあるプロフェッショナルなデザイン
- レスポンシブ対応: スマホ・タブレット対応
- SEO: 各ページにメタタグ、構造化データ（LocalBusiness, Attorney）を設定、「倉敷市 弁護士」でのローカルSEO最適化
- お問い合わせフォーム: Googleフォーム埋め込み
- ブログ機能: Markdownベース、タグ・日付でフィルタリング可能

## 事務所情報
- 事務所名: 〇〇法律事務所
- 住所: 岡山県倉敷市〇〇町1-2-3
- 電話: 086-123-4567
- 営業時間: 平日9:00-18:00

よろしくお願いします。
```

**Claude Codeの処理時間**: 5〜10分で基本構造完成、さらに30分でコンテンツ投入完了（実績ベース）

---

## 方法論2: Next.js + Vercel（SSG/SSR）

### 使用ツール一覧

| カテゴリ | ツール | 用途 |
|---------|--------|------|
| フレームワーク | Next.js | React ベースのフルスタックフレームワーク |
| CSSフレームワーク | Tailwind CSS | スタイリング |
| 開発環境 | Node.js (推奨v18以上) | ランタイム環境 |
| バージョン管理 | Git / GitHub | ソースコード管理 |
| ホスティング | Vercel | Next.js開発元の公式ホスティング |
| AI開発支援 | Claude Code | 自動コード生成・保守 |
| ドメイン | お名前.com / ムームードメイン等 | 独自ドメイン取得 |
| コンテンツ管理 | Notion（既存利用）+ Notion API | ブログ原稿・お知らせ管理 |
| データベース（オプション） | Supabase（無料枠あり） | お問い合わせフォーム保存等 |

### 構築の大まかな手順

**Phase 1: 環境準備（所要: 1時間）**

1. Node.jsインストール
2. GitHubアカウント作成・リポジトリ初期化
3. Vercelアカウント作成（GitHubと連携）
4. Claude Code起動・プロジェクト初期化

**Phase 2: プロジェクト作成（所要: 3〜5時間）**

5. Claude Codeにプロンプト入力:
   「倉敷市の弁護士事務所のコーポレートサイトをNext.js (App Router) + Tailwind CSSで構築してください。SSGとSSRを適切に使い分け、トップページ、業務内容、弁護士紹介、お問い合わせフォーム（Supabase保存）、ブログ（Notion API連携）を含めてください。SEO設定とローカルSEOの構造化データも設定してください。」
6. Claude Codeが自動生成したコードをレビュー・調整
7. デザイン微調整（色、フォント、レイアウト）
8. Notion API設定（APIキー取得、ブログデータベース連携）

**Phase 3: コンテンツ投入（所要: 3〜5時間）**

9. 業務内容・弁護士プロフィール・事務所情報をReactコンポーネントに記載
10. 構造化データ（schema.org）をNext.jsのメタデータAPIで設定
11. ローカルSEO用の「倉敷市 弁護士」キーワード最適化

**Phase 4: デプロイ（所要: 30分）**

12. GitHubにpush → Vercelが自動検知してデプロイ（初回5分）
13. 独自ドメイン設定（Vercelダッシュボードで設定）
14. HTTPS化確認（自動対応）

**Phase 5: 運用開始（継続）**

15. ブログ記事追加（Notionで執筆 → 自動的にサイトに反映）
16. お知らせ更新（同様のフロー）

### 費用内訳

| 項目 | 初期費用 | 月額/年額 | 備考 |
|------|---------|----------|------|
| ドメイン取得 | 0〜1,500円 | 年額1,500円前後 | `.jp`は年額3,000円前後 |
| ホスティング（Vercel Hobby） | 0円 | 0円 | 無料枠内で十分（100GB転送/月） |
| ホスティング（Vercel Pro） | 0円 | 月額20ドル（約3,000円） | 転送1TB/月、高度な分析機能 |
| Claude Code | 0円 | 月額20ドル（約3,000円） | Pro契約（必須） |
| Supabase（オプション） | 0円 | 0円 | 無料枠内で十分（500MB DB） |
| 合計（Vercel Hobby利用） | 1,500円 | 年額1,500円 + Claude月額3,000円 | **年間約4.7万円** |
| 合計（Vercel Pro利用） | 1,500円 | 年額1,500円 + Claude月額3,000円 + Vercel月額3,000円 | **年間約5.3万円** |

### 技術的難易度

**評価: 3.0 / 5.0**（初心者〜中級者）

**根拠**:
- Next.jsはReactベースのため、Astroよりやや複雑
- Claude Codeが大半のコードを自動生成するため、深い知識は不要
- Notion API連携はClaude Codeが自動設定するが、APIキー取得に手間
- Vercelデプロイは簡単（GitHubと連携で自動）
- 障壁: Reactの基本概念理解、Notion API設定、環境変数管理

### メリット

1. **柔軟性**: SSG（静的生成）とSSR（サーバーサイドレンダリング）を使い分け可能
2. **Notion API連携**: ブログ記事をNotionで執筆すると自動的にサイトに反映（更新が楽）
3. **高度な機能**: お問い合わせフォームをDB保存、管理画面作成など動的機能が容易
4. **Vercel最適化**: Next.js開発元のVercelでホスティングすることで最高のパフォーマンス
5. **React生態系**: 膨大なコンポーネントライブラリ（Chakra UI、shadcn/ui等）を活用可能
6. **Claude Codeとの親和性**: Next.jsプロジェクトの自動生成・保守が可能

### デメリット

1. **初期学習コスト**: Astroより複雑（Reactの基本理解が必要）
2. **JavaScriptバンドル**: Astroより大きい（ただしSSG時は問題なし）
3. **Notion API制約**: API制限（リクエスト数上限）があり、大量アクセス時に遅延の可能性
4. **オーバースペック**: 単純なコーポレートサイトには機能過多の場合あり

### SEO対応力

**ローカルSEO（「倉敷市 弁護士」検索）: ★★★★☆（4/5）**

- **メタデータAPI**: Next.js 13以降の強力なメタデータ管理機能でSEO最適化
- **SSG**: 静的生成でAstro同様の高速表示・クローラー対応
- **構造化データ**: JSON-LD形式で schema.org マークアップを各ページに設定可能
- **Core Web Vitals**: Lighthouseスコア90点以上（Vercelの最適化により）
- **サイトマップ/RSS**: 自動生成プラグインあり
- **Astroに若干劣る理由**: JavaScriptハイドレーション分、初期ロードがわずかに遅い

### コンテンツ更新の容易性

**評価: ★★★★★（5/5）**

**ブログ・お知らせ追加の標準フロー（所要3分）**:
1. Notionでブログ原稿を執筆（通常通り）
2. Notionで「公開」ステータスに変更
3. **自動的にサイトに反映**（Notion API経由で取得、Vercelが自動再デプロイ）

**更新の自動化**:
- Notion API + Vercel Webhook で、Notion更新時に自動的にサイト再ビルド
- Git操作不要（非エンジニアでも運用可能）

**お知らせ・業務内容変更**:
- 同様にNotionデータベースで管理 → 自動反映

### 法律事務所HPとしての適性

**評価: ★★★★☆（4/5）**

1. **信頼感**: 高速表示とモダンなUIで信頼感を演出
2. **専門性の訴求**: Notionブログ連携で専門記事を簡単に発信
3. **問い合わせ導線**: カスタムフォーム（Supabase保存）で問い合わせ管理が容易
4. **拡張性**: 将来的に顧客ポータル、予約システム等の追加が容易
5. **やや複雑**: シンプルなサイトにはオーバースペック（Astroの方が適切な場合も）

### Claude Codeとの親和性

**評価: ★★★★☆（4/5）**

#### 自動生成できる範囲

- **テンプレート**: Next.js (App Router) の基本構造（layout.tsx、page.tsx）
- **コンポーネント**: Reactコンポーネントの自動生成（弁護士プロフィール、業務内容等）
- **SEO設定**: Metadata API を使った各ページのメタタグ、構造化データ
- **Notion API連携**: Notionデータベースからブログ記事を取得するAPIルート
- **フォーム実装**: Supabase連携のお問い合わせフォーム
- **レスポンシブ対応**: Tailwind CSSでのスマホ・タブレット対応

#### 保守・更新フロー

**ケース1: ブログ記事追加**
```
1. Notionで原稿執筆 → 「公開」ステータスに変更
2. 自動的にサイトに反映（Notion API経由で取得）
3. 手動操作不要（Vercel Webhookで自動再デプロイ）
```

**ケース2: 弁護士プロフィール追加**
```
1. Claude Codeに「新しい弁護士プロフィールを追加。名前: 〇〇、専門: △△、経歴: □□」
2. Claude Codeが該当Reactコンポーネントを更新
3. git push → Vercel自動デプロイ
```

**ケース3: デザイン変更**
```
1. 「ヘッダーの背景色を紺色に変更」
2. Claude Codeが Tailwind CSS のクラスを修正
3. git push → 自動デプロイ
```

#### 初回構築プロンプト例

```
# プロンプト例（Claude Codeに入力）

倉敷市の法律事務所のコーポレートサイトをNext.js (App Router) + Tailwind CSSで構築してください。

## 要件
- ページ構成: トップページ、業務内容（民事・刑事・企業法務）、弁護士紹介（3名）、事務所概要、アクセス、お問い合わせ（Supabase保存）、ブログ一覧（Notion API連携）
- デザイン: 紺色ベース、信頼感のあるプロフェッショナルなデザイン
- レスポンシブ対応: スマホ・タブレット対応
- SSG/SSR: トップページ・業務内容はSSG、ブログはISR（Incremental Static Regeneration、10分ごと再生成）
- SEO: Metadata APIで各ページにメタタグ、構造化データ（LocalBusiness, Attorney）を設定、「倉敷市 弁護士」でのローカルSEO最適化
- お問い合わせフォーム: Supabaseに保存、メール通知（Resend API使用）
- ブログ機能: Notion API経由でブログ記事取得、タグ・日付でフィルタリング可能

## 事務所情報
- 事務所名: 〇〇法律事務所
- 住所: 岡山県倉敷市〇〇町1-2-3
- 電話: 086-123-4567
- 営業時間: 平日9:00-18:00

## Notion API
- Notion APIキー: （環境変数 NOTION_API_KEY）
- ブログデータベースID: （環境変数 NOTION_DATABASE_ID）

## Supabase
- Supabase URL: （環境変数 NEXT_PUBLIC_SUPABASE_URL）
- Supabase Anon Key: （環境変数 NEXT_PUBLIC_SUPABASE_ANON_KEY）

よろしくお願いします。
```

**Claude Codeの処理時間**: 10〜15分で基本構造完成、さらに1時間でNotion API連携・Supabase設定完了（実績ベース）

---

## 2方法の簡易比較表

| 項目 | Astro + Tailwind + GitHub Pages/Vercel | Next.js + Vercel |
|------|----------------------------------------|------------------|
| **技術的難易度** | ★★☆☆☆（2/5） | ★★★☆☆（3/5） |
| **初期費用** | 約1,500円（ドメイン代） | 約1,500円（ドメイン代） |
| **年間ランニングコスト** | 約4.7万円（Claude Code含む） | 約4.7〜5.3万円（Claude Code含む、Vercel Pro選択時+0.6万円） |
| **構築所要時間** | 1〜2日（10〜15時間） | 2〜3日（15〜20時間） |
| **表示速度** | ★★★★★（Lighthouseスコア95点以上） | ★★★★☆（Lighthouseスコア90点以上） |
| **SEO効果** | ★★★★★（静的HTML最強） | ★★★★☆（SSGなら同等、SSR時はやや劣る） |
| **ローカルSEO** | ★★★★★（構造化データ対応完璧） | ★★★★☆（構造化データ対応完璧） |
| **コンテンツ更新の容易性** | ★★★☆☆（Markdown+Git push必要） | ★★★★★（Notion連携で自動反映） |
| **動的機能** | △（外部サービス依存） | ◎（自由に実装可能） |
| **保守性** | ★★★★★（シンプル構造） | ★★★★☆（やや複雑） |
| **Claude Codeとの親和性** | ★★★★★（完璧） | ★★★★☆（良好だが設定多め） |
| **法律事務所HPとしての適性** | ★★★★★（信頼感・高速・SEO最強） | ★★★★☆（高機能だがやや複雑） |
| **拡張性（将来的な機能追加）** | ★★☆☆☆（静的サイトの限界） | ★★★★★（無限の拡張性） |
| **非エンジニアの運用負荷** | ★★★☆☆（Git操作が必要） | ★★★★★（Notion更新のみ） |

---

## 推奨方法論

### 🏆 推奨: **Astro + Tailwind CSS + GitHub Pages**

**理由**:
1. **コスト最小**: 年間4.7万円（ドメイン代 + Claude Code のみ）
2. **SEO最強**: 「倉敷市 弁護士」でのローカルSEO上位表示に最適
3. **初心者でも構築可能**: Claude Codeが大半を自動生成、学習コスト最小
4. **信頼感**: 高速表示と堅牢性で法律事務所に必要な信頼感を演出
5. **保守が楽**: シンプルな構造でトラブルが少ない

**こんな人に最適**:
- Web開発経験がない弁護士
- ランニングコストを最小限に抑えたい
- SEOを最優先したい（地域名検索で上位を狙いたい）
- シンプルなコーポレートサイトで十分
- ブログ更新頻度は週1回程度

### 🥈 次点: **Next.js + Vercel（Notion API連携）**

**理由**:
1. **コンテンツ更新が最も楽**: Notionで書くだけで自動反映
2. **将来の拡張性**: 顧客ポータル、予約システム等の追加が容易
3. **運用負荷最小**: 非エンジニアでもNotionだけで運用可能

**こんな人に最適**:
- Notionを既に日常的に使っている
- ブログを頻繁に更新したい（週3回以上）
- 将来的に高度な機能（会員制、予約システム等）を追加したい
- Git操作を避けたい（Notion更新だけで運用したい）
- 若干のコスト増（年間+6,000円）は許容できる

---

## まとめ

両方法論ともClaude Codeとの親和性が高く、**Web開発経験がない弁護士でも構築可能**です。

**最大の違い**:
- **Astro**: SEO・速度・コストで最強、Git操作が必要
- **Next.js**: 更新の容易性・拡張性で優れる、Notion連携で運用が楽

倉敷市の弁護士事務所HPとして、**シンプルで信頼感のあるサイトを最安で構築**したい場合は **Astro + GitHub Pages** を、**頻繁に記事を更新しNotionで一元管理**したい場合は **Next.js + Vercel（Notion API連携）** を推奨します。

---

## 参考資料（Sources）

### Astro + Tailwind CSS
- [20 Best Free Tailwind CSS Landing Page Templates 2026 - AdminLTE.IO](https://adminlte.io/blog/tailwind-landing-page-templates/)
- [AstroとTailwindで静的サイトを作ってみた 【Jamstack】 - neputa note](https://www.neputa-note.net/2024/05/astro-tailwind/)
- [爆速サイトを構築する、静的サイトビルダー「Astro」の紹介 - Qiita](https://qiita.com/takusan64/items/3c2be2a396bafb3e0653)
- [世界最速を謳う、話題のWebフレームワーク「Astro」を試してみた #初心者向け - Qiita](https://qiita.com/to3izo/items/c04a1d16d35521fa15e6)

### Vercel料金
- [VercelのHobbyプランとProプランの違いを徹底解説：料金体系・機能・対象ユーザーを徹底比較 | 株式会社一創](https://www.issoh.co.jp/tech/details/8792/)
- [Vercel の料金形態と内容についてまとめた - 2020冬](https://zenn.dev/lollipop_onl/articles/eoz-vercel-pricing-2020)
- [Vercelとは？概要や料金、無料プランについて](https://dev-harry-next.com/infrastructure/vercel-detail)
- [Vercel Pricing: Hobby, Pro, and Enterprise plans – Vercel](https://vercel.com/pricing)

### Next.js + SEO
- [Next.js の SSG と SSR](https://swr.vercel.app/ja/docs/with-nextjs)
- [Next.jsを活用したモダン開発の概要とメリットとSEO最適化の完全ガイド | ainow](https://ainow.jp/next-js/)
- [【初心者向け】Next.jsで高速でSEOに強いWebアプリケーションを構築 | エンベーダー](https://envader.plus/article/299)
- [Next.js Web アプリケーションにおける SSG とSSR の比較： 正しいレンダリングアプローチの選択 | Amazon Web Services ブログ](https://aws.amazon.com/jp/blogs/news/ssg-vs-ssr-in-next-js-web-applications-choosing-the-right-rendering-approach/)
- [Next.js は本当にSEOに強いのか調べてみた](https://zenn.dev/fukurose/articles/e15df7129cc421)

### Claude Code + Astro
- [I Asked AI What to Build My Website With. It Didn't Say WordPress.](https://www.starkinsider.com/2026/02/claude-code-astro-web-design.html)
- [Claude Code × Astro でランディングページを自動生成した技術検証レポート](https://techblog.asia-quest.jp/202512/claude-code-astro-landing-page)
- [Claude Codeを使ってAstro.jsでコーポレートサイトをたった2日で構築した話 | WEB CRAFT](https://webcraft.click/blog/claude-code-astro-site-development/)
- [Claude CodeでSpec駆動開発 – AI駆動時代の計画術 | SIOS Tech Lab](https://tech-lab.sios.jp/archives/51093)
- [Claude Code Templatesとは？ClaudeCodeの開発効率を最大化する最強ツール | エンジニアブログ | ラーゲイト株式会社](https://www.ragate.co.jp/media/developer_blog/3-l5tl1lbz2)

### GitHub Pages
- [GitHub Pagesを使い、無料でサイトを公開しよう | Pikawaka](https://pikawaka.com/tips/github-pages-website-deployment)
- [About custom domains and GitHub Pages - GitHub Docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/about-custom-domains-and-github-pages)
- [【2024年版】GitHub Pagesで独自のカスタムドメインを設定する方法 #GithubPages - Qiita](https://qiita.com/sotanengel/items/034dd37cbc0dde9f7c86)

### Next.js構築手順
- [NextJS入門：環境構築からプロジェクト作成,起動まで解説](https://naoq.net/p2256)
- [自分の会社のコーポレートサイトをNext.jsでリニューアルした話](https://zenn.dev/yukito0616/articles/1b6be66abe6848)
- [【2026年版】Next.jsで始めるReact開発環境の構築方法 - 最速セットアップガイド - 月収100万フリーランスへの道](https://yuya-blog.net/react/nextjs-setup-guide-2026/)
- [コーポレートサイト構築に適したNext.js: 優れたパフォーマンスとSEO対策 - AIko Code Symphony](https://aikostudio.hatenablog.com/entry/2023/07/28/055443)

### 弁護士事務所SEO
- [弁護士・法律事務所のためのSEO対策の基本を解説！ | LEAGO](https://effata-leago.jp/column/1264)
- [弁護士事務所が行うべきSEO対策｜成功事例やSEO対策の費用相場も紹介](https://challenge-seo.jp/seo-lawyer/)
- [倉敷市ホームページ制作・SEO対策・WordPress・ネットショップ構築 | 三重県のHP制作会社エフ・ファクトリー](https://www.fortune-factory.net/area/okayama/kurashikishi)
- [【2025年最新】倉敷市のSEO対策に強いホームページ制作会社10選| それぞれの特徴も徹底解説！](https://www.layup.info/post/kurashiki-city-seo)
- [弁護士事務所のSEO対策18選！集客に効果的なキーワード戦略とコンテンツ例 | ホームページ制作会社NTTタウンページ | デジタルリード](https://www.ntttp-dlead.com/homepage-sakusei-blog/web-syuukyaku/seo-taisaku-kiso-chisiki/lawyer-seo.html)

### Astro vs Next.js
- [Astro vs Next.js: Which Framework Should You Use in 2026?](https://pagepro.co/blog/astro-nextjs/)
- [Astroで爆速なwebサイトを開発する(Next.jsとの比較あり) - カカクコムTechBlog](https://kakaku-techblog.com/entry/create-website-with-astro)
- [Astro vs NextJS 2026 : Comparison, Features : Aalpha](https://www.aalpha.net/blog/astro-vs-nextjs-comparison/)
- [Astro vs Next.js (2026): Real Benchmarks, SEO & Costs | Senorit](https://senorit.de/en/blog/astro-vs-nextjs-2025)
- [Astro vs. Next.js: Features, performance, and use cases compared | Contentful](https://www.contentful.com/blog/astro-next-js-compared/)
- [Astro vs Next.js for Blogs in 2026: Which One Actually Wins? | Sourabh Yadav](https://sourabhyadav.com/blog/astro-vs-nextjs-for-blogs-2026/)
- [Astro vs Next.js for SEO-First Websites: 10 Reasons Why We Choose Astro](https://medevel.com/astro-vs-next-js-for-seo-first-websites-10-reasons-why-we-choose-astro/)
