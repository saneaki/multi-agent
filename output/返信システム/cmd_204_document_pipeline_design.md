# cmd_204: 文書受領→AI分析→案件紐付け→Drive自動整理 統合パイプライン設計

**作成**: 軍師（gunshi）
**作成日**: 2026-02-21
**ステータス**: 設計完了・殿の判断待ち

---

## 1. パイプライン全体アーキテクチャ

### 1.1 全体フロー

```
[受信BOXフォルダ]                        [Notion案件DB]
      |                                       |
      v                                       |
[Drive Trigger: 新ファイル検知]                |
      |                                       |
      v                                       |
[Gemini Flash: 文書→Markdown変換]             |
  → content.md 生成                           |
      |                                       |
      v                                       |
[Gemini Flash: 要約+反論生成]                  |
  → summary_rebuttal.md 生成                  |
      |                                       |
      v                                       v
[案件特定エンジン] ←←←←←←←←←←← [Notion API: 案件DB検索]
      |
      v
 [スコア判定]
   |         |
   v         v
 高確信    低確信/複数候補
   |         |
   v         v
[自動移動]  [通知→人間確認]
   |
   v
[Drive API: 原本+MD を案件フォルダに移動]
      |
      v
[通知: Telegram/LINE 完了報告]
```

### 1.2 コンポーネント構成

| コンポーネント | 実装方式 | 依存 |
|--------------|---------|------|
| ファイル検知 | n8n Google Drive Trigger | Google Drive API |
| 文書→MD変換 | n8n HTTP Request → Gemini 2.0 Flash | Gemini API (cmd_193推奨案A) |
| 要約+反論生成 | n8n HTTP Request → Gemini 2.0 Flash | Gemini API |
| 案件特定 | n8n Code node (マッチングロジック) | Notion API |
| ファイル移動 | n8n Google Drive node | Google Drive API |
| 通知 | 既存Telegram/LINE通知ノード再利用 | Telegram/LINE API |

---

## 2. Notion案件DB実構造（調査結果）

### 2.1 DB基本情報

| 項目 | 値 |
|------|-----|
| DB ID | `1a4e8d62e4aa81c7bdb4c3c0ea47633a` |
| DB名 | 案件DB |
| Data Source ID | `1a4e8d62-e4aa-8145-a95c-000bdde23244` |

### 2.2 案件特定に使用するフィールド

| フィールド名 | 型 | 用途 | 備考 |
|-------------|-----|------|------|
| **タイトル** | title | 案件名（検索キー） | 例: "大里_離婚調停" |
| **ドライブリンク** | email | Drive案件フォルダURL | **type=email だがURL格納に使用** |
| **顧客情報** | relation | 顧客DB連携 | collection://1aae8d62-e4aa-809d-a2c6-000b658e92e9 |
| **事件番号** | text | 裁判所事件番号 | 例: "令和6年(ワ)第1234号" |
| **ステータス** | status | 案件状態 | 要作業/待ち/完了 等 |
| **段階** | select | 案件段階 | 協議/調停/審判/訴訟 等 |
| **種別** | select | 事件種別 | 事務所事件/個人事件/法テラス |
| **現状メモ** | text | 自由記述メモ | 追加コンテキストとして使用可 |
| **担当事務** | multi_select | 担当事務員 | 信時統括, 山之口さん 等 |

### 2.3 関連DB

| DB | Data Source ID | 関係 |
|----|---------------|------|
| タスクDB | collection://1a4e8d62-e4aa-81ab-a2f9-000be5ad1d6f | 案件→タスク |
| メールDB | collection://306e8d62-e4aa-80eb-b51c-000b37f04f25 | 案件→メール |
| 顧客情報DB | collection://1aae8d62-e4aa-809d-a2c6-000b658e92e9 | 案件→顧客 |
| 会計DB | collection://20fe8d62-e4aa-80e2-9b23-000b289c7db0 | 案件→会計 |
| 請求内容DB | collection://1aae8d62-e4aa-8001-94bf-000b70caa2e2 | 案件→請求 |

### 2.4 重要な発見

1. **ドライブリンクの型がemail**: URLを格納するために`email`型フィールドを流用している。Notion APIの`filter`では`email`型として検索する必要がある。空でないレコードのみが案件フォルダ紐付け済み。
2. **タイトルに当事者名を含む慣例**: "大里_離婚調停" のように「当事者名_案件種別」の形式。これが案件特定の主要手がかりになる。
3. **顧客情報DBとの連携**: 顧客名の正式名称は顧客情報DBに格納。案件タイトルは略称の可能性あり。

---

## 3. 案件特定ロジック（選択肢比較）

### 3.1 比較表

| 方式 | 精度 | 実装コスト | 人間負担 | 自動化度 | 推奨度 |
|------|------|-----------|---------|---------|--------|
| A. ファイル名規則 | ★2 | ★5 | ★4 | ★3 | △ |
| B. Gemini内容分析 | ★4 | ★3 | ★5 | ★4 | ○ |
| C. サブフォルダ指定 | ★5 | ★5 | ★2 | ★2 | △ |
| **D. ハイブリッド (推奨)** | **★5** | **★3** | **★4** | **★5** | **◎** |

### 3.2 方式A: ファイル名規則

```
ファイル名: "大里_契約書.pdf"
 → "_" で分割 → 先頭 "大里" を抽出
 → Notion案件DB「タイトル」で部分一致検索
 → 候補: ["大里_離婚調停", "大里太郎_債務整理"]
```

**利点**: 実装が最もシンプル。Code nodeのみで完結。
**欠点**: ファイル命名規則の徹底が必要。規則外ファイルは検出不可。当事者名被りに弱い。

### 3.3 方式B: Gemini内容分析

```
[文書PDF] → Gemini Flash
  プロンプト: "この法律文書から以下を抽出せよ:
    1. 当事者名（原告/被告/申立人/相手方）
    2. 事件番号（例: 令和○年(○)第○号）
    3. 裁判所名
    4. 案件種別（離婚/債務/相続等）"
  → 抽出結果: {parties: ["大里太郎", "大里花子"], case_no: "令6(家)123号", type: "離婚"}
  → Notion検索: 事件番号 or タイトル部分一致
```

**利点**: ファイル名に依存しない。文書内容から正確に当事者・事件番号を特定。
**欠点**: Gemini API追加コスト（ただし微小）。抽出失敗のリスク（レイアウト依存）。

### 3.4 方式C: サブフォルダ手動指定

```
受信BOXフォルダ/
  ├── 大里_離婚/    ← サブフォルダ名 = 案件名
  │   └── 契約書.pdf
  └── 山田_相続/
      └── 遺産分割協議書.pdf
```

**利点**: 確実性100%。人間が判断するため誤りがない。
**欠点**: 殿の手間が増える。フォルダ作成→ファイルアップロードの2ステップが必要。

### 3.5 方式D: ハイブリッド（推奨）

```
[新ファイル検知]
    |
    v
[Phase 1: ファイル名分析] → 当事者名候補抽出
    |
    v
[Phase 2: Gemini内容分析] → 当事者名・事件番号・案件種別抽出
    |
    v
[Phase 3: Notion検索]
    ├── 事件番号一致 → 確信度100% → 自動移動
    ├── タイトル完全一致 → 確信度90% → 自動移動
    ├── タイトル部分一致（1件）→ 確信度70% → 自動移動
    ├── タイトル部分一致（複数）→ 確信度40% → 通知→人間選択
    └── 一致なし → 確信度0% → 通知→人間指定
```

**推奨理由**:
1. 事件番号がある文書は100%自動化（裁判所文書は必ず事件番号あり）
2. 事件番号がない文書もタイトル照合で高い成功率
3. 低確信時のみ人間に判断を仰ぐ→殿の負担最小化
4. Phase 1→2の段階処理でGemini APIコストも最適化（ファイル名だけで特定できれば内容分析をスキップ）

### 3.6 Notion検索のAPI設計

```javascript
// n8n Code node: 案件特定ロジック
const notionApiKey = $env.NOTION_BEARER_TOKEN;
const DB_ID = "1a4e8d62e4aa81c7bdb4c3c0ea47633a";

// Step 1: 事件番号で完全一致検索
async function searchByCaseNumber(caseNo) {
  return await notionQuery({
    database_id: DB_ID,
    filter: {
      property: " 事件番号",  // 注意: 先頭スペースあり
      rich_text: { equals: caseNo }
    }
  });
}

// Step 2: タイトル部分一致検索
async function searchByTitle(partyName) {
  return await notionQuery({
    database_id: DB_ID,
    filter: {
      and: [
        { property: "タイトル", title: { contains: partyName } },
        { property: "ステータス", status: {
          does_not_equal: "完了"  // 完了案件は除外（優先的に進行中を選択）
        }}
      ]
    }
  });
}

// Step 3: ドライブリンクが設定済みの案件のみ対象
// ドライブリンクが空の案件はフォルダ移動不可
async function searchWithDriveLink(partyName) {
  return await notionQuery({
    database_id: DB_ID,
    filter: {
      and: [
        { property: "タイトル", title: { contains: partyName } },
        { property: "ドライブリンク", email: { is_not_empty: true } }
      ]
    }
  });
}
```

---

## 4. MD出力の保存設計

### 4.1 推奨: _ai_analysis/ サブフォルダ方式

cmd_192の `_ai_text/` パターンを踏襲し、名前を区別する。

```
案件フォルダ/
  ├── 原本文書.pdf              ← 移動された原本（変更しない）
  ├── _ai_text/                 ← cmd_192: テキスト抽出キャッシュ
  │   └── 原本文書.md
  └── _ai_analysis/             ← cmd_204: AI分析成果物
       ├── 原本文書_content.md           ← 全文Markdown変換
       └── 原本文書_summary_rebuttal.md  ← 要約+反論
```

### 4.2 命名規則

| ファイル | 命名パターン | 内容 |
|---------|-------------|------|
| 全文MD | `{元ファイル名}_content.md` | 文書のMarkdown変換（忠実な抽出） |
| 要約+反論 | `{元ファイル名}_summary_rebuttal.md` | AI要約+反論ポイント |

### 4.3 _ai_text/ と _ai_analysis/ の違い

| 項目 | _ai_text/ (cmd_192) | _ai_analysis/ (cmd_204) |
|------|---------------------|------------------------|
| 目的 | テキストキャッシュ（Geminiプロンプト注入用） | AI分析成果物（人間が読む） |
| 生成元 | 文書→テキスト抽出 | 文書→要約・分析・反論 |
| 利用者 | Gmail WF（機械的に読取） | 殿・事務員（直接閲覧） |
| 重複 | content.md は _ai_text/ と同一内容になる可能性 | → **統合案あり（後述）** |

### 4.4 統合案（殿の判断ポイント）

_ai_text/ と _ai_analysis/ を1つのフォルダに統合する案:

```
案件フォルダ/
  ├── 原本文書.pdf
  └── _ai/
       ├── 原本文書.md                    ← テキスト抽出（cmd_192兼用）
       ├── 原本文書_summary_rebuttal.md   ← 要約+反論
       └── _manifest.json                ← メタデータ
```

**利点**: フォルダ構造がシンプル。`_ai_text/`のcontent.mdを再利用。
**欠点**: cmd_192のWF-1が`_ai/`を参照するよう変更が必要。

---

## 5. 段階的実装計画

### Phase 1: 受信BOX → Markdown変換（独立価値あり）

**価値**: 受信BOXにアップロードするだけで、文書のMarkdown版が自動生成される。案件紐付けなし。

```
[受信BOXフォルダ] → [Drive Trigger] → [Gemini: MD変換]
  → 同フォルダ内に _content.md / _summary_rebuttal.md を生成
  → Telegram/LINE通知: "新文書をAI分析しました"
```

| 項目 | 詳細 |
|------|------|
| n8n WF | 新規1本 |
| 必要API | Google Drive API, Gemini API |
| 前提条件 | 受信BOXフォルダID決定、Gemini credential |
| 実装工数 | 足軽1名 × 1タスク |
| テスト | PDF/Word各1件アップロード → MD生成確認 |

### Phase 2: 案件特定 + 自動移動（コア機能）

**価値**: 文書が自動的に正しい案件フォルダに分類される。
**依存**: Phase 1完了

```
Phase 1の出力
  → [Gemini: 当事者名・事件番号抽出]
  → [Notion API: 案件DB検索]
  → [スコア判定]
    → 高確信: [Drive API: 案件フォルダに移動]
    → 低確信: [通知: 候補一覧 → 人間選択]
```

| 項目 | 詳細 |
|------|------|
| n8n WF | Phase 1 WFを拡張 |
| 必要API | Notion API（案件DB検索）、Google Drive API（移動） |
| 前提条件 | Phase 1完了、Notion API認証（cmd_203で設定済み） |
| 実装工数 | 足軽1名 × 2タスク（案件特定ロジック + Drive移動） |
| テスト | 事件番号あり文書 → 自動特定確認、曖昧文書 → 通知確認 |

### Phase 3: _ai_analysis/ 保存 + cmd_192統合

**価値**: 案件フォルダ内にAI分析成果物が自動整理。Gmail WFからも参照可能。
**依存**: Phase 2完了

```
Phase 2の移動先フォルダ内で:
  → [_ai_analysis/ サブフォルダ作成]
  → [content.md / summary_rebuttal.md を保存]
  → [_manifest.json 更新]
  → cmd_192 WF-1 と共用: _ai_text/ or _ai/ 統合
```

| 項目 | 詳細 |
|------|------|
| n8n WF | Phase 2 WFを拡張 + cmd_192 WF-1連携 |
| 前提条件 | Phase 2完了、cmd_192 Phase 3設計との整合 |
| 実装工数 | 足軽1名 × 1タスク |

### Phase 4: 人間確認フロー（UX最適化）

**価値**: 低確信時の候補選択をTelegram/LINE上で完結できる。
**依存**: Phase 2完了

```
[低確信通知]
  → Telegram: "新文書: 契約書.pdf\n候補: 1.大里_離婚 2.大里_相続 3.その他"
  → 人間が番号を返信
  → [Webhook: 返信受信] → [Drive移動実行]
```

| 項目 | 詳細 |
|------|------|
| n8n WF | 別WF（Webhook受信+Drive移動） |
| 前提条件 | Phase 2完了 |
| 実装工数 | 足軽1名 × 2タスク（通知フォーマット + Webhook処理） |

### Phase一覧と依存関係

```
Phase 1 ─────────────────→ Phase 2 ─────→ Phase 3
  （MD変換のみ）            （案件紐付け）    （Drive整理+cmd_192統合）
                              |
                              └────→ Phase 4
                                    （人間確認UX）
```

| Phase | 独立価値 | 前提 | 工数 |
|-------|---------|------|------|
| Phase 1 | 文書のAI分析が自動で手に入る | なし | 小 |
| Phase 2 | 文書が案件フォルダに自動分類される | Phase 1 | 中 |
| Phase 3 | Gmail WFから案件文書を参照できる | Phase 2 | 小 |
| Phase 4 | 曖昧な文書もチャットで解決 | Phase 2 | 中 |

---

## 6. cmd_192との関係整理

### 6.1 設計比較

| 項目 | cmd_192 (Gmail WF Phase 3) | cmd_204 (文書自動整理) |
|------|---------------------------|---------------------|
| トリガー | Gmail受信 | Driveアップロード |
| 主目的 | メール返信案にDrive文書内容を注入 | 文書の受領→分析→案件振分け |
| MD変換 | _ai_text/ にキャッシュ | _ai_analysis/ に分析結果 |
| Gemini使用 | テキスト抽出のみ | テキスト抽出 + 要約 + 反論 |
| 案件特定 | メール→人物DB→案件（既存フロー） | 文書内容→Notion案件DB検索（新規） |
| Drive操作 | _ai_text/からmd読取 | 原本+mdを案件フォルダに移動 |

### 6.2 推奨: 独立実装 + Phase 3で連携

```
cmd_192 WF-1: テキスト変換WF（案件フォルダ監視→_ai_text/生成）
cmd_204 WF:   文書整理WF（受信BOX監視→分析→案件特定→移動）
                ↓ (Phase 3で連携)
cmd_204がファイルを案件フォルダに移動
  → cmd_192 WF-1のDrive Triggerが発火
  → _ai_text/ にテキストキャッシュ自動生成
  → Gmail WFがmd読取可能に
```

**判断**: 独立実装を推奨。理由:
1. cmd_204のトリガー（受信BOX）とcmd_192のトリガー（案件フォルダ変更）は異なる
2. cmd_204で案件フォルダに移動 → cmd_192 WF-1が自動で_ai_text/を生成、という自然な連鎖が成立
3. Phase 3の`_ai/`統合は、両WFが安定稼働した後に実施（リスク最小化）

### 6.3 _ai_text/ の重複問題

cmd_204のcontent.mdとcmd_192の_ai_text/内mdは内容が類似する。

**解決案（Phase 3で対応）**:
- cmd_204はcontent.mdを`_ai_analysis/`に保存
- cmd_192 WF-1は`_ai_text/`にテキストキャッシュを独立生成
- Phase 3でフォルダ統合を検討（`_ai/`に一本化）
- 当面はストレージコストが微小のため重複許容

---

## 7. エラーハンドリング方針

### 7.1 案件不一致時

| 状況 | アクション | 理由 |
|------|----------|------|
| 候補0件 | 受信BOXに残留 + 通知「案件不明」 | 人間が判断すべき |
| 候補1件（確信度70%+） | 自動移動 + 通知「自動分類しました」 | 事後確認可能 |
| 候補2件以上 | 受信BOXに残留 + 通知「候補N件」 | Phase 4で選択UI提供 |
| ドライブリンク空 | 受信BOXに残留 + 通知「案件フォルダ未設定」 | Notionにフォルダ登録が先 |

### 7.2 変換失敗時

| 状況 | アクション | リトライ |
|------|----------|---------|
| Gemini API 429 (Rate Limit) | 5分後リトライ | 最大3回 |
| Gemini API 500 (Server Error) | 10分後リトライ | 最大2回 |
| ファイルサイズ超過（>20MB） | スキップ + 通知「大容量ファイル」 | なし |
| 非対応形式 | スキップ + 通知「非対応形式」 | なし |
| Drive API エラー | エラーWF(ntfy)で通知 | n8n標準リトライ |

### 7.3 フォールバックフォルダ

受信BOXに「_unmatched/」サブフォルダを設置:

```
受信BOX/
  ├── 新規アップロード.pdf     ← 処理待ち
  ├── _unmatched/              ← 案件不明で自動分類不可
  │   ├── 不明文書A.pdf
  │   └── _log.json           ← 不一致ログ（Gemini抽出結果含む）
  └── _processed/              ← 処理済み（自動移動成功）移動ログ
      └── _log.json
```

---

## 8. コスト試算

### 8.1 1ファイルあたり

| 処理 | API | コスト |
|------|-----|--------|
| MD変換（10p PDF） | Gemini Flash | ~$0.004 |
| 要約+反論生成 | Gemini Flash | ~$0.003 |
| 案件特定（内容分析） | Gemini Flash | ~$0.002 |
| Notion案件DB検索 | Notion API | 無料 |
| Drive移動 | Drive API | 無料 |
| **合計** | | **~$0.009/ファイル** |

### 8.2 月間試算

| 想定 | ファイル数/月 | 月額 |
|------|------------|------|
| 少量（個人利用） | 30件 | ~$0.27（約40円） |
| 中量（法律事務所） | 100件 | ~$0.90（約135円） |
| 大量 | 300件 | ~$2.70（約400円） |

---

## 9. 殿の判断を仰ぐべきポイント

### 9.1 最優先（Phase 1着手前に決定必要）

| # | 判断事項 | 選択肢 | 軍師の推奨 |
|---|---------|--------|----------|
| **D1** | 受信BOXフォルダの場所 | A. 既存の共有フォルダ内に新規作成 / B. マイドライブ直下 | A（共有フォルダ内） |
| **D2** | 受信BOXフォルダのGoogle Drive ID | 殿が作成して共有 / 足軽がAPI経由で作成 | 殿が作成（権限の確実性） |
| **D3** | 要約+反論のプロンプト内容 | 法律文書用のカスタムプロンプトが必要 | 殿の法律実務知見に基づくプロンプト設計 |

### 9.2 中優先（Phase 2着手前に決定）

| # | 判断事項 | 選択肢 | 軍師の推奨 |
|---|---------|--------|----------|
| **D4** | 案件特定の自動移動閾値 | A. 確信度70%以上で自動 / B. 90%以上で自動 / C. 常に人間確認 | A（70%以上で自動、通知付き） |
| **D5** | _ai_analysis/ と _ai_text/ の統合 | A. 別フォルダ維持 / B. _ai/ に統合 | A（まず別フォルダ、安定後に統合検討） |
| **D6** | 低確信時の人間確認手段 | A. Telegram / B. LINE / C. 両方 | A（Telegram、既存インフラ活用） |

### 9.3 低優先（Phase 3以降）

| # | 判断事項 | 選択肢 | 軍師の推奨 |
|---|---------|--------|----------|
| **D7** | cmd_192との統合タイミング | A. Phase 3で即統合 / B. 両方安定後に統合 | B（安定後） |
| **D8** | 過去文書の一括処理 | A. 既存案件フォルダの文書も一括変換 / B. 新規アップロードのみ | B（新規のみ、一括は別タスク） |

---

## 10. 技術的補足

### 10.1 Notion API フィルタの注意点

```javascript
// 「事件番号」フィールドは先頭にスペースがある（" 事件番号"）
// Notion APIでは正確なプロパティ名を使用する必要がある
filter: {
  property: " 事件番号",  // ← 先頭スペースに注意
  rich_text: { contains: caseNumber }
}

// 「ドライブリンク」はtype=emailだがURL格納に使用
// is_not_empty フィルタで案件フォルダ設定済みを検索
filter: {
  property: "ドライブリンク",
  email: { is_not_empty: true }
}

// DriveフォルダURLからフォルダIDを抽出
// 形式: https://drive.google.com/drive/folders/{folderId}
const folderId = driveLink.match(/folders\/([a-zA-Z0-9_-]+)/)?.[1];
```

### 10.2 Gemini プロンプト設計（案件特定用）

```
あなたは法律文書分析アシスタントです。
以下の文書から、次の情報を抽出してJSON形式で返してください:

{
  "parties": ["当事者名1", "当事者名2"],
  "case_number": "事件番号（あれば）",
  "court": "裁判所名（あれば）",
  "document_type": "文書種別（契約書/準備書面/判決文/通知書/その他）",
  "case_type": "案件種別（離婚/相続/債務/不動産/労働/その他）",
  "key_dates": ["重要な日付（期日等）"],
  "confidence": 0.0-1.0
}

抽出できない項目はnullとしてください。推測は行わず、文書に記載された情報のみを抽出してください。
```

### 10.3 n8n WFノード構成（Phase 1+2概要）

```
Schedule/Drive Trigger
  → [IF: 新ファイルか？]
  → [IF: 対応形式か？（PDF/Word/Excel/画像）]
  → [HTTP Request: Gemini Flash — MD変換]
  → [HTTP Request: Gemini Flash — 要約+反論]
  → [HTTP Request: Gemini Flash — 案件情報抽出]
  → [Code: 案件特定スコアリング]
  → [HTTP Request: Notion API — 案件DB検索]
  → [IF: 確信度70%以上？]
    → YES: [Google Drive: 案件フォルダに移動] → [通知: 自動分類完了]
    → NO:  [通知: 候補一覧 → 人間確認待ち]
```

---

## 参考資料

- cmd_193 統合レポート: `output/cmd_193_drive_to_md_methods_report.md`
- cmd_192 Phase 3設計書: `output/cmd_192_gmail_v5_phase3_drive_content.md`
- n8n運用ガイド: `context/n8n-operations.md`
- Notion案件DB: `1a4e8d62e4aa81c7bdb4c3c0ea47633a`
