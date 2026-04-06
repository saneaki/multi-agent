# 構成員フィードバック収集→shogun自動依頼システム 方法論調査レポート

**cmd_462 / 軍師統合レポート**
**作成日**: 2026-04-07 JST
**統合担当**: 軍師(統合) / 足軽1号・2号・3号(調査)

---

## 1. 背景と調査目的

shogunプロジェクトにおいて、構成員(殿・利用者)からのフィードバックを継続的に収集し、改善依頼として自動的にshogunキューに投入する仕組みを構築したい。

**調査目的**:

1. フィードバック収集→shogun自動依頼の経路として最適な方法論を明らかにする
2. コスト・実装難易度・運用負荷・拡張性・shogun連携容易性・UX・既存インフラ親和性の7軸で評価する
3. 推奨案を選定し、段階的実装ロードマップを示す

**北極星**: プロジェクトの利用者から継続的にフィードバックを収集し、改善を自動化することで運用品質を向上させる

---

## 2. 調査した選択肢(全9案)

| ID | 選択肢 | 担当 | 概要 |
|---|---|---|---|
| A1 | Google Form + GAS | 足軽1号 | Google FormでフィードバックをSpreadsheetに収集→GASのonFormSubmit()で即時処理 |
| A2 | Email + 自動パース | 足軽1号 | 専用GmailアドレスにメールフィードバックをGAS/n8nでパース |
| B1 | n8n Form Trigger | 足軽2号 | n8n組み込みのForm Triggerノードで一貫実装 |
| B2a | Canny.io | 足軽2号 | 機能要望・バグ報告特化のSaaS |
| B2b | Typeform | 足軽2号 | インタラクティブフォームSaaS |
| B2c | Productboard | 足軽2号 | プロダクトロードマップ管理PMツール |
| C1 | Slack/Discord スラッシュコマンド | 足軽3号 | チャットツールのフォーム機能・Bot+Modal |
| C2 | Notion データベース+API | 足軽3号 | Notion Forms+API書込 |
| C3 | GitHub Issue テンプレート | 足軽3号 | Issue Forms+Actions自動化 |

---

## 3. 各選択肢の詳細

### A1. Google Form + GAS

**概要**: Google FormでフィードバックをSpreadsheetに収集し、GASのonFormSubmit()トリガーで即時処理。UrlFetchApp.fetch()でVPS WebhookにPOSTしてshogun queueに書込む方式。

**評価**:

- **コスト**: 初期¥0/月額¥0 (Google個人アカウント)
- **実装難易度**: 2/5 (GAS基本知識+VPS Webhook受信側実装)
- **運用負荷**: 低
- **拡張性**: 高 (フォーム項目変更がノーコード)
- **shogun連携**: 中 (GAS→UrlFetchApp→VPS Webhook→inbox_write.shの3段)
- **UX**: 優秀 (URLクリックのみ、スマホ対応)
- **既存インフラ親和性**: 高 (gas-mail-managerと同インフラ)

**主な利点**: gas-mail-manager(cmd_455〜461で構築済み)と同じGASエコシステム。Googleアカウント運用統一。

**主な欠点**: VPS Webhookへの認証付き受信エンドポイント実装が必要。

### A2. Email + 自動パース

**概要**: 専用GmailアドレスにフィードバックメールをGASのGmailサービスまたはn8nでパース。

**評価**:

- **コスト**: 初期¥0/月額¥0
- **実装難易度**: 3/5 (正規表現パース+フォーマット設計)
- **運用負荷**: 中 (フォーマット違反対応)
- **拡張性**: 中
- **shogun連携**: 中
- **UX**: 低〜中 (メーラー起動・フォーマット遵守)
- **既存インフラ親和性**: 高

**判断**: A1に劣る。送信ハードル+運用負荷で不利。

### B1. n8n Form Trigger

**概要**: n8n組み込みのForm Triggerノードでフォーム作成・ホスト。Code/Writeノードで`queue/inbox/*.yaml`を直接書込可能(中間層ゼロ)。VPS上のn8nが既稼働。

**評価**:

- **コスト**: ¥0 (既存n8n VPS流用)
- **実装難易度**: 2/5 (n8nノード設定30分以内)
- **運用負荷**: 低
- **拡張性**: 高
- **shogun連携**: **非常に高** (中間層ゼロ・YAML直書込)
- **UX**: 中 (シンプルなフォームUI)
- **既存インフラ親和性**: **非常に高**

**主な利点**: 即時性最高。既存n8n VPSフル活用。

**主な欠点**: フォームUIのカスタマイズ性が低い(構成員エンゲージメント面で不利)。

### B2a. Canny.io

**評価サマリー**: tracked user課金($79〜$5K/年)でコスト管理が難しい。機能要望特化で過剰。

**判断**: **非推奨**。MVP段階では除外。

### B2b. Typeform

**概要**: インタラクティブフォームSaaS。UX業界最高水準。Webhook+n8n公式Typeformノードで連携可。

**評価**:

- **コスト**: $28〜$91/月 (Free 10回答/月のみ)
- **実装難易度**: 2/5
- **shogun連携**: 中-高
- **UX**: **非常に高** (1質問ずつ表示・スマホ最適)
- **既存インフラ親和性**: 中-高

**判断**: UX重視時の第二推奨。

### B2c. Productboard

**評価**: PM向けロードマップ管理ツール。フィードバック収集には機能過多。**非推奨**。

### C1. Slack/Discord スラッシュコマンド

**概要**: Slack Workflow Builder or Bot + Modal、Discord Bot + slash command。

**スコア**: 17/35

**判断**: 既存インフラに含まれていない。新規導入コスト+運用負荷で他案に劣る。

### C2. Notion データベース + API

**概要**: Notion Forms(公式)でノーコード収集。Notion API完全無料(全プラン)。既存notionAPI MCP稼働中。n8n公式Notionノードあり。

**スコア**: **22/35 (パートC1位)**

**評価**:

- **コスト**: ¥0〜$10/ユーザー/月 (Free〜Plus)
- **実装難易度**: 1/5 (Native Automations 20分)
- **運用負荷**: 1/5 (ほぼゼロ)
- **shogun連携**: 4/5 (notion API → n8n → YAML書込)
- **UX**: 4/5 (アカウント不要でフォーム送信可)
- **既存インフラ親和性**: **5/5** (notionAPI MCP+n8n稼働中)

**主な利点**: 既存インフラ親和性最高・実装最速・運用負荷最低。

### C3. GitHub Issue テンプレート

**概要**: Issue Forms (YAML) + GitHub Actions でラベル自動付与+トリアージ自動化。

**スコア**: 21/35 (パートC2位)

**評価**:

- **コスト**: $0 (Public repo無制限)
- **実装難易度**: 2/5
- **運用負荷**: 1/5
- **拡張性**: 4/5 (Actions無限拡張)
- **shogun連携**: 3/5 (Actions→SSH/API経由でVPS書込)
- **UX**: 2/5 (GitHubアカウント必要・非技術者には高ハードル)
- **既存インフラ親和性**: 4/5 (github MCP稼働中)

**判断**: 開発者向け技術系フィードバック(バグ報告・PR提案)に特化した補助ツールとして並行運用候補。

---

## 4. 比較表(評価軸7項目 × 全9選択肢)

| 評価軸 | A1 GForm+GAS | A2 Email | **B1 n8n** | B2a Canny | B2b Typeform | B2c Pboard | C1 Slack/DC | **C2 Notion** | C3 GH Issue |
|---|---|---|---|---|---|---|---|---|---|
| a. コスト | ¥0 | ¥0 | **¥0** | $79〜 | $28〜 | $19〜 | $8〜 | ¥0〜$10 | **$0** |
| b. 実装難易度 | 2/5 | 3/5 | **2/5** | 3/5 | 2/5 | 4/5 | 2/5 | **1/5** | 2/5 |
| c. 運用負荷 | 低 | 中 | **低** | 中 | 低-中 | 中-高 | 中 | **最低** | 最低 |
| d. 拡張性 | 高 | 中 | 高 | 中 | 高 | 高 | 中 | 中 | **高** |
| e. shogun連携 | 中 | 中 | **最高(中間ゼロ)** | 中 | 中-高 | 低-中 | 低 | **高(既存n8n+MCP)** | 中 |
| f. 構成員UX | 優秀 | 低-中 | 中 | 高 | **最高** | 中 | 高 | 高 | 低 |
| g. インフラ親和性 | 高 | 高 | **最高** | 中 | 中-高 | 低 | 低 | **最高** | 高 |
| **総合判定** | ◯ | △ | **◎** | ✕ | ◯ | ✕ | △ | **◎** | ◯ |

(◎=最優秀 / ◯=良好 / △=条件付き / ✕=非推奨)

---

## 5. 推奨案

### 主推奨: **Notion Forms + n8n ハイブリッド** (C2 + B1融合)

**構成**:

```
[構成員]
   ↓ Notion Form (URL公開・アカウント不要)
[Notion Database (フィードバックDB)]
   ↓ n8n Notion Trigger (新規行検知)
[n8n Workflow]
   ↓ Code/Writeノード (YAML整形)
[shogun queue/inbox/shogun.yaml]
```

### 推奨理由(5点)

1. **既存インフラ親和性が最高**: notionAPI MCP・n8n VPS が既に稼働中。新規SaaS契約・新規インフラ追加なし。
2. **実装最速**: Notion Forms 20分 + n8n Notion Trigger 30分 = 約1時間でMVPが完成。
3. **運用負荷最低**: Notion はSaaSのためインフラメンテ不要。n8n も既存運用に統合済み。
4. **UX良好**: 構成員はNotionアカウント不要でフォーム送信可。URLシェアだけで利用開始。
5. **shogun連携が中間層最少**: n8n Code ノードで直接 `queue/inbox/yaml` 書込が可能(VPS Webhook受信エンドポイントなど追加実装不要)。

### 補助推奨: **GitHub Issue Forms** (C3) — 技術系フィードバック専用

**用途**: バグ報告・PR提案・技術改善依頼など、開発者・技術者からのフィードバック専用チャネル。

**理由**: GitHub Actions+github MCPで既存インフラ親和性高。Issue Forms YAMLで構造化収集可能。コスト$0。

### 非推奨理由

| 案 | 非推奨理由 |
|---|---|
| A1 Google Form+GAS | C2 Notionの方が既存notionAPI MCPで親和性が上。VPS Webhook受信実装が不要。 |
| A2 Email+パース | 送信ハードル高・運用負荷大。 |
| B2a Canny | tracked user課金リスク。汎用フィードバックには過剰。 |
| B2b Typeform | UXは最高だが有料($28〜)。Notionで十分。 |
| B2c Productboard | PM向けで過剰設計。 |
| C1 Slack/Discord | 既存インフラに含まれず新規追加コスト発生。 |

---

## 6. 実装ロードマップ

### MVP (Phase 1: 約1時間)

**目標**: Notion Forms→n8n→shogun queue 一気通貫の最小動作を確立

1. **Notion DB作成** (10分)
   - フィールド: タイトル / 種別(バグ/要望/質問) / 詳細 / 送信者 / 緊急度 / 作成日時
   - Notion Forms設定 (DB → New Form → URL発行)

2. **n8n Workflow作成** (30分)
   - Notion Trigger ノード: 新規行検知 (3秒〜5分間隔)
   - Code ノード: フィードバックをYAMLに整形
   - Write Binary File ノード: `/home/ubuntu/shogun/queue/inbox/shogun.yaml` に追記
   - エラーハンドリング: 失敗時はntfy通知

3. **動作確認** (10分)
   - テストフィードバック送信
   - shogun.yaml反映確認
   - 殿のFrog管理画面での参照確認

4. **構成員への展開** (10分)
   - フォームURL共有
   - 簡易ガイド作成

**完了基準**: テストフィードバック1件がshogun.yamlに自動追記される

### Phase 2: 拡張 (約2-3時間)

**目標**: 補助チャネル追加+運用品質強化

1. **GitHub Issue Forms 補助チャネル** (1時間)
   - `.github/ISSUE_TEMPLATE/feedback.yml` 作成
   - GitHub Actions: Issue→shogun queue書込ワークフロー
   - github MCP活用

2. **AI分類自動化** (1時間)
   - n8n OpenAIノード or Claude APIで自動カテゴリ分類
   - 緊急度自動判定 (high/medium/low)
   - shogun自動依頼の優先度付け

3. **ダッシュボード可視化** (30分)
   - dashboard.md にフィードバック件数・処理状況追記
   - 日次/週次サマリー自動生成

### Phase 3: 高度化 (将来)

- **多言語対応**: フィードバックの多言語自動翻訳
- **構成員エンゲージメント**: 処理結果通知 (Notion→送信者へメール返信)
- **分析ダッシュボード**: フィードバック傾向分析・トピックモデリング

---

## 7. セキュリティ・プライバシー考慮事項

| 項目 | 対策 |
|---|---|
| **認証** | Notion Form は公開URLだが、IPフィルタ・reCAPTCHA設定検討 |
| **スパム対策** | n8n側で送信頻度制限・キーワードフィルタ実装 |
| **個人情報** | 必須フィールド最小化(氏名・メールはオプション扱い) |
| **トークン管理** | Notion API トークンは環境変数管理、ローテーション運用 |
| **データ保持** | フィードバックDBの保持期間ポリシー定義(例: 6ヶ月) |
| **GDPR対応** | EU構成員想定なら削除リクエスト対応フロー整備 |
| **shogun queue権限** | n8n書込ユーザーをshogun queueディレクトリ書込専用に制限 |

---

## 8. 参考文献(URL一覧)

### Notion関連 (推奨案の根拠)

- [Notion Forms 公式ガイド](https://www.notion.com/help/guides/use-forms-to-collect-organize-and-act-on-responses-in-notion)
- [Notion API 入門](https://developers.notion.com/docs/getting-started)
- [Notion 公式価格](https://www.notion.com/pricing)
- [n8n Notion Integration](https://n8n.io/integrations/notion/)

### n8n関連

- [n8n Form Trigger 公式ドキュメント](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.formtrigger/)
- [n8n フィードバック自動分析テンプレート](https://n8n.io/workflows/4686-automate-customer-feedback-analysis-with-forms-ai-google-sheets-and-whatsapp/)
- [n8n Email Parse テンプレート](https://n8n.io/workflows/1453-parse-email-body-message/)

### GitHub関連 (補助推奨)

- [GitHub Issue Forms 構文リファレンス](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
- [GitHub AI トリアージ](https://docs.github.com/en/issues/tracking-your-work-with-issues/administering-issues/triaging-an-issue-with-ai)
- [IssueOps: GitHub Actions自動化](https://github.blog/engineering/issueops-automate-ci-cd-and-more-with-github-issues-and-actions/)

### Google Form/GAS関連

- [Google Apps Script onFormSubmit サンプル](https://developers.google.com/apps-script/samples/automations/course-feedback-response)
- [UrlFetchApp 公式リファレンス](https://developers.google.com/apps-script/reference/url-fetch/url-fetch-app)

### SaaS比較

- [Canny vs Productboard 2026比較](https://theroadmapai.com/blog/canny-vs-productboard-which-feedback-tool-is-better-in-2026)
- [Typeform Webhooks 公式](https://www.typeform.com/developers/webhooks/)
- [Slack Workflow Builder 公式](https://slack.com/help/articles/360035692513-Guide-to-Slack-Workflow-Builder)

---

## 9. 殿の意思決定要素

本レポートの推奨案を採用するかどうか、以下を確認されたい:

1. **Notion Forms の利用承諾**: 既存Notionワークスペースにフィードバック専用DBを作成してよいか?
2. **n8n Workflow追加の承諾**: 既存n8n VPSに新規ワークフローを追加してよいか? (リソース影響は微小)
3. **MVP着手の承諾**: 上記Phase 1実装に約1時間の作業を割り当ててよいか?
4. **補助チャネル(GitHub Issue Forms)の方針**: 開発者向け技術系フィードバック専用として並行運用するか?
5. **構成員範囲**: 当面は殿1名のみか、複数構成員に拡大予定か? (拡大時のセキュリティ要件に影響)

---

**レポート終わり**
**統合: 軍師 / 調査: 足軽1号(A系)・2号(B系)・3号(C系)**
