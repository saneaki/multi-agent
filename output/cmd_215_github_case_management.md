# 弁護士業務における案件管理: Google ドライブ vs GitHub 比較レポート

## 1. はじめに

弁護士・法律事務所の業務において、複数案件の並行管理・文書版管理・期限追跡・守秘義務の維持は不可欠な要件である。多くの事務所は Google ドライブを中心としたクラウドストレージ運用（Notion 案件 DB との連携を含む）を行ってきたが、近年 GitHub が法務・契約書管理の領域でも注目されつつある。本レポートでは、両ツールの機能・メリット・デメリットを弁護士業務の観点から比較し、最適な運用戦略を提案する。

---

## 2. GitHub で利用可能な案件管理機能

### 2.1 Issues（案件トラッキング）

GitHub Issues は、案件単位でのタスク管理・議論記録・ファイル添付が可能なトラッキングシステムである。

**実務での活用イメージ：**
- 1 Issue = 1 案件（または 1 契約書レビュー依頼）
- Issue 本文に「なぜ契約するのか（Why）」「何を行うのか（What）」「想定リスク」「締結期限」を記載
- 契約書の Word ファイルを直接 Issue に添付
- コメントスレッドで顧問弁護士・担当者間の議論を記録

ウォンテッドリー社は実際にこのフローを導入しており、「要件が整理されてから相談するようになり自然に論理的なやり取りができるようになった」と報告している。

**期限管理の補完手段：**
GitHub Issues はネイティブには期限日フィールドを持たないが、GitHub Marketplace の「Issue DueDate Reminder」や「Due Date Notifications Via Comments」などの Actions を組み合わせることで、期限当日・1 週間前などに自動コメントやメール通知を送ることができる。

### 2.2 Projects（カンバン管理）

GitHub Projects はカンバンビュー・テーブルビュー・タイムラインビューを提供する。

- **カンバン列の例**：`相談受付` → `書類精査中` → `交渉中` → `締結待ち` → `完了`
- カスタムフィールド（日付・テキスト・セレクト）で案件種別・担当弁護士・期日などを付与可能
- Projects の built-in automation により、Issue クローズ時に自動でステータスを「完了」へ移動
- テーブルビューでは全案件を一覧・フィルタリング・ソートでき、期日管理に有効

### 2.3 Wiki・Discussions（ナレッジ管理）

- **Wiki**：判例・書式・法令解釈のナレッジベースとして活用可能。Markdown 形式で構造化でき、版管理も Git で自動記録される
- **Discussions**：案件固有でなく事務所横断的なテーマ（例：「特定商取引法改正対応方針」）の議論に適する。Issue よりも長期的・オープンな議論向け

過去の Issue・Discussions は検索可能なアーカイブとなるため、「以前の類似案件でどう判断したか」を新人弁護士でも即座に参照でき、オンボーディング効果が高い。

### 2.4 Actions（自動化）

GitHub Actions は YAML ベースの CI/CD 基盤だが、法務ワークフローでも以下の自動化が実現できる。

| 自動化例 | 実装方法 |
|---------|---------|
| 期限 N 日前に担当者へ通知コメント | `Issue DueDate Reminder` Action |
| 新規 Issue 作成時にラベル自動付与 | `issue-labeler` Action |
| 月次でオープン案件サマリーを生成 | カスタム Python スクリプト + Actions |
| Issue クローズ時に報告書テンプレートを自動投稿 | カスタム Action |
| Google Drive への文書自動バックアップ | n8n 連携（後述） |

### 2.5 セキュリティ・プライバシー機能

**プライベートリポジトリ：**
- アクセス可能なユーザーをコラボレーターとして個別招待（最小権限の原則）
- 外部クライアントには「外部コラボレーター」として特定リポジトリのみアクセス付与可能

**GitHub Enterprise のコンプライアンス対応：**
- GDPR 準拠（Data Protection Agreement / Standard Contractual Clauses）
- 組織の監査ログ（誰がいつ何を操作したか）
- IP 許可リスト（特定 IP 以外からのアクセスをブロック）
- SAML シングルサインオン（事務所の ID プロバイダー統合）

**守秘義務の観点：**
GitHub は捜索令状なしに private リポジトリのコンテンツを開示しないことを明言している。ただし GitHub.com はサーバーが米国にあるため、データ主権が厳格に問われる場合は GitHub Enterprise Server（オンプレミス）の検討が必要。

---

## 3. Google ドライブ管理の評価

### 3.1 メリット

**1. 導入障壁の低さと普及率**
Google ドライブは弁護士・クライアント双方にとって馴染み深いツールであり、アカウント作成不要・ブラウザのみで利用可能。クライアントへのファイル共有が極めて容易。

**2. ファイル形式の自由度**
Word（.docx）・PDF・Excel・画像など、あらゆる法的文書の書式をそのまま保存・プレビュー可能。Google ドキュメントでのリアルタイム共同編集にも対応。

**3. Google Workspace エコシステムとの統合**
Gmail・Google カレンダー・Google Meet との連携が強力。案件メール・期日・打合せ記録が一元的に管理しやすい。

**4. Notion 案件 DB との連携**
Notion の案件データベースから Google ドライブのフォルダ URL をプロパティとして参照する運用（現行運用）は、案件メタデータの管理（ステータス・担当者・期日・依頼者情報）と実文書の保管を分離できるという合理性がある。

**5. 段階的なアクセス制御**
閲覧者・コメント者・編集者・オーナーの 4 段階の権限設定。フォルダ単位の共有でクライアントに案件ファイルのみを開示する運用が容易。

### 3.2 デメリット

**1. バージョン管理の不十分さ**
Google ドキュメントには版履歴機能があるが、Word ファイル（.docx）を直接アップロードした場合は自動バージョン管理が働かない。「最終版」「最終版_修正後」「最終版_本当に最後」といったファイル名の乱立が起きやすい。

**2. 案件横断の検索・追跡が弱い**
ファイルはフォルダ構造に格納されるが、「クライアント A の全訴訟案件を横断して期限が近い書類を抽出する」といった動的クエリが Google ドライブ単体では難しい（Notion 連携でカバーするが設計コストが発生）。

**3. 守秘義務リスク（無料版）**
弁護士・士業向けのオンラインストレージ要件として「利用規約に秘密保持条項が含まれること」が必須とされる。Google ドライブの個人アカウント（無料版）には守秘義務条項がなく、弁護士の守秘義務規定に抵触するリスクがある。Google Workspace for Business / Enterprise プランでは DPA が締結できるため有料プラン必須。

**4. コミュニケーション分散**
文書レビューのフィードバックはメール・Slack・コメント機能など複数チャネルに分散しやすく、「誰がどの版にどのコメントをしたか」の履歴追跡が困難になりがち。

**5. 自動化の制限**
Google Apps Script で一定の自動化は可能だが、複雑なワークフロー（期限管理・担当者通知・ステータス更新の連動）を構築するにはカスタム開発が必要。

---

## 4. GitHub 管理の評価

### 4.1 メリット

**1. 完全な変更履歴（Git ログ）**
すべての変更がコミット単位で記録され、「いつ・誰が・何を変更したか」が不変の監査証跡として残る。電子証拠開示（e-Discovery）や紛争時の証跡確保に有効。契約書の条項集管理では Word の修正履歴よりも Git のほうが管理しやすいという実務者の評価がある。

**2. 案件ごとのコンテキスト集約**
1 Issue に「依頼背景・リスク分析・弁護士コメント・最終方針」が時系列で蓄積される。新人弁護士が過去の類似案件の経緯を Issue アーカイブから検索できるため、ナレッジ共有と引き継ぎ効率が向上する。

**3. Issues + Projects の組み合わせによる高度な進捗管理**
カンバン・テーブル・タイムラインビューを活用することで、「全案件のステータス一覧」「期日が近い順でのソート」「担当弁護士別フィルタリング」が実現できる。Notion 案件 DB と同等以上の管理機能を GitHub 単体で構築可能。

**4. 差分表示（diff）による文書比較**
テキスト形式（Markdown・プレーンテキスト）の法的文書であれば、版間の差分を行単位で可視化できる。契約書の修正箇所の確認作業に直接活用できる。

**5. 自動化の柔軟性（Actions + API）**
GitHub Actions の豊富なエコシステムと REST/GraphQL API により、複雑なワークフロー自動化を宣言的な YAML で実装できる。n8n との連携も公式サポートされており、外部システムとの橋渡しが容易。

### 4.2 デメリット

**1. 学習コスト（弁護士・事務スタッフ向け）**
Git の概念（リポジトリ・Issue・PR・コミット）は IT エンジニアに親しいが、弁護士・事務スタッフには馴染みがない。導入時のトレーニングコストが発生する。

**2. Word/PDF 文書の管理の限界**
GitHub はテキストファイルのバージョン管理を前提として設計されており、バイナリファイル（.docx・.pdf）は差分表示が不可。大容量ファイルには Git LFS（Large File Storage）の追加設定が必要。

**3. クライアント共有の難しさ**
クライアントが GitHub アカウントを持っていない場合、リポジトリへの招待が困難。Google ドライブのように「リンクを共有するだけ」という手軽さがない。

**4. ネイティブの期限管理機能の欠如**
Issues には標準の「期限日」フィールドがなく、Projects のカスタムフィールドか外部 Actions での補完が必要。専用法務管理ツール（LEALA、loioz 等）と比べると期限・タイムチャージ管理が弱い。

**5. 請求・工数管理との統合がない**
弁護士業務に必要なタイムチャージ記録・請求書発行・報酬計算の機能が GitHub にはなく、別ツールとの組み合わせが必須。

---

## 5. 併用戦略（推奨）

### 5.1 役割分担

両ツールの強みを活かして「管理レイヤー」と「保管レイヤー」を明確に分担する。

| 役割 | 担当ツール | 内容 |
|------|-----------|------|
| 案件ライフサイクル管理 | GitHub Issues + Projects | ステータス・担当者・期限・コミュニケーション履歴 |
| 文書ナレッジベース | GitHub Wiki + Discussions | 書式・判例整理・法令解釈・事務所ポリシー |
| 自動化・通知 | GitHub Actions | 期限リマインダー・ラベル付け・月次サマリー |
| 原本文書保管（Word/PDF） | Google Drive | 契約書原本・証拠書類・裁判所提出文書 |
| クライアント共有 | Google Drive（共有リンク） | クライアントへの文書開示 |
| 案件メタデータ DB | Notion（現行維持） | 依頼者情報・費用・タイムチャージ |
| プロセス連携 | n8n | GitHub ↔ Drive ↔ Notion の自動同期 |

### 5.2 運用フロー

**案件開始フロー：**

```
1. 依頼受付
   └→ GitHub Issues に案件 Issue を作成
       └→ タイトル: [案件番号] クライアント名 - 案件種別
       └→ 本文: 依頼背景・リスク・期限・担当弁護士
       └→ ラベル付与: 案件種別（契約・訴訟・M&A 等）、優先度

2. Google Drive に案件フォルダ作成
   └→ フォルダ名: [案件番号]_クライアント名
   └→ Issue のコメントにドライブ URL を貼り付け

3. GitHub Projects のカンバンに自動追加
   └→ ステータス: 「受付済」

4. n8n ワークフロー起動
   └→ Notion 案件 DB に自動エントリー作成
   └→ Google カレンダーに期限イベントを登録
```

**文書レビューフロー：**

```
文書をドライブに保存
└→ Issue コメントに「@弁護士名 レビュー依頼: [Drive URL]」を投稿
    └→ 担当弁護士がコメントにレビュー結果を記入
    └→ 修正反映後「修正済み」ラベルを付与
    └→ 合意完了で Issue を Close → Projects が「完了」に自動移動
```

**期限管理フロー：**

```
GitHub Actions（毎日 09:00 JST 実行）
└→ Projects の期限カスタムフィールドをスキャン
    └→ 3 日以内に期限が来る Issue にコメントを自動投稿
    └→ 担当弁護士にメール通知
    └→ 超過した Issue に「Overdue」ラベルを自動付与
```

### 5.3 n8n 連携の可能性

n8n は GitHub および Google Drive の両公式統合ノードを提供しており、以下の自動化が設定なしのコーディング不要で実現できる。

**実現可能な n8n ワークフロー例：**

1. **新規 Issue 作成 → Drive フォルダ自動生成**
   GitHub Trigger（Issue opened）→ Google Drive（Create Folder）→ GitHub（Add Comment with Drive URL）

2. **Drive ファイル追加 → Issue 自動コメント**
   Google Drive Trigger（File created）→ GitHub（Add Issue Comment）で「新しい文書がアップロードされました: [URL]」を通知

3. **定期バックアップ**
   GitHub Issues の全データを週次で Google Drive に JSON エクスポート

4. **法的 AI リサーチ統合**
   法的案件調査の自動化テンプレートを活用し、調査結果を GitHub Issue に自動サマリー投稿するワークフローが構築できる

5. **法律事務所向け自動化テンプレート**
   n8n のコミュニティには弁護士業務向けのリード管理・スケジュール調整・初回相談予約の自動化テンプレートが公開されている

---

## 6. 結論・推奨

### 短期的推奨（導入ハードルが低い順）

**Step 1（即時実施）**: 現行の Google Drive + Notion 運用を維持しつつ、GitHub を「案件コミュニケーション・議論記録」専用で試験導入する。まず契約書レビュー依頼の管理に Issue を使い始める（ウォンテッドリー方式）。

**Step 2（1〜2 ヶ月後）**: GitHub Projects でカンバンを構築し、Notion 案件 DB から案件ステータス管理を段階的に移行する。期限管理 Actions を設定し、期限通知を自動化する。

**Step 3（3〜6 ヶ月後）**: n8n で GitHub ↔ Drive ↔ Notion の自動連携を実装する。ドライブへのファイル追加通知・Issue 自動作成・バックアップ同期を稼働させる。

### セキュリティ・守秘義務への対処

- GitHub は組織プランの Private リポジトリを使用（無料プランは不可）
- Google Drive は Google Workspace Business Plus 以上（DPA 締結可能なプラン）を使用
- 機密レベルの高い文書は Drive の外部共有を無効化し、GitHub リポジトリは invite-only で管理
- GitHub Enterprise Server（オンプレミス）の導入で、データを事務所サーバー内に完全に保持することも選択肢となる

### 最終評価

| 評価軸 | Google Drive | GitHub |
|--------|-------------|--------|
| 文書保管（バイナリ） | 優 | 劣 |
| バージョン管理（テキスト） | 可 | 優 |
| 案件トラッキング | 劣（要 Notion） | 優 |
| クライアント共有 | 優 | 劣 |
| 自動化 | 可 | 優 |
| 守秘義務対応 | 可（有料プラン） | 可（組織プラン） |
| 学習コスト | 低 | 中〜高 |
| 監査証跡 | 可 | 優 |

**総合推奨：Google ドライブ（原本保管）+ GitHub（案件管理・コミュニケーション）+ n8n（自動連携）の三層構成**が、弁護士業務の守秘義務・文書管理・期限管理・ナレッジ共有をバランスよく満たす最適解である。

---

## 参考情報

- [ウォンテッドリーが実践するGitHubによる契約書管理 - BUSINESS LAWYERS](https://www.businesslawyers.jp/articles/310)
- [契約書のバージョン管理を「GitHub」のように実現する「Hubble」の誕生秘話 - BUSINESS LAWYERS](https://www.businesslawyers.jp/articles/516)
- [GitHub契約条項集「katax contract-manuals」にプルリクしてタコツボ法務から脱出しよう - クラウドサイン](https://www.cloudsign.jp/media/20180413-katax-contract-manuals/)
- [Git Document Management: Git for Legal Document Control - Athennian](https://www.athennian.com/post/how-we-use-git-to-scale-automation-of-legal-documents)
- [GitHub Guidelines for Legal Requests of User Data - GitHub Docs](https://docs.github.com/en/site-policy/other-site-policies/guidelines-for-legal-requests-of-user-data)
- [Issue DueDate Reminder - GitHub Marketplace](https://github.com/marketplace/actions/issue-duedate-reminder)
- [GitHub and Google Drive: Automate Workflows with n8n](https://n8n.io/integrations/github/and/google-drive/)
- [Automated Law Firm Lead Management with n8n](https://n8n.io/workflows/9383-automated-law-firm-lead-management-and-scheduling-with-ai-jotform-and-calendar/)
- [士業のためのオンラインストレージ入門 - 岬研究室](https://misaki-institute.com/%E5%A3%AB%E6%A5%AD%E3%81%AE%E3%81%9F%E3%82%81%E3%81%AE%E3%82%AA%E3%83%B3%E3%83%A9%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%AC%E3%83%BC%E3%82%B8%E5%85%A5%E9%96%80/)
- [弁護士事務所におけるクラウドサービス利用の落とし穴と対策 - note](https://note.com/noble_moose2572/n/n6f4e94fa6124)
- [Comprehensive legal department automation with OpenAI - n8n](https://n8n.io/workflows/6904-comprehensive-legal-department-automation-with-openai-o3-clo-and-specialist-agents/)

---
*作成日: 2026-02-22 | cmd_215*
