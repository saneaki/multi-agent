# cmd_207 残テスト項目一覧

**作成**: 家老（karo）
**作成日**: 2026-02-21
**関連cmd**: cmd_207（法律文書WF E2Eテスト）、cmd_205/206（Phase1+2実装）
**対象WF**: 法律文書自動分析 v1.0（ID: Cq0g3T60NfZGuO3t、22ノード）

---

## cmd_207 実施済みテスト（参考）

| テスト | 結果 | 実施日 |
|--------|------|--------|
| Notion API OR検索（池内/DUMMY事件番号） | ✅ PASS | 2026-02-21 |
| Gemini 2.5-flash 案件特定JSON抽出 | ✅ PASS | 2026-02-21 |
| Google Chat Webhook送信 | ✅ PASS | 2026-02-21 |
| WF構造確認（22ノード、Gemini 2.5-flash×3） | ✅ PASS | 2026-02-21 |

---

## 残テスト項目

### T-E2E-001: Drive Trigger → Phase1 フルパイプライン

| 項目 | 内容 |
|------|------|
| **優先度** | HIGH |
| **テスト名** | PDFアップロード → Phase1完全動作確認 |
| **目的** | トリガーフォルダへのPDFアップロードから _ai_analysis/ への2ファイル生成、Google Chat通知までの全Phase1フローを確認する |
| **前提条件** | Google Driveへの書き込み権限（OAuth2認証済みアカウント）。WFがactive=trueであること |
| **実行手順** | 1. トリガーフォルダ（ID: `1Shedqmmrt6IAg8VzZTiKex6lFCy9UG6X`）に任意のPDFをアップロード<br>2. WFが自動起動するまで待機（最大60秒）<br>3. `GET /api/v1/executions?workflowId=Cq0g3T60NfZGuO3t&limit=1` でexec確認<br>4. ステータスがsuccessで全ノードsuccess（ITEM_ERR=0）を確認<br>5. `_ai_analysis/` フォルダに `{ファイル名}_content.md` と `{ファイル名}_summary_rebuttal.md` が生成されていること確認<br>6. Google Chatに通知が届いていること確認 |
| **期待結果** | exec全ノードsuccess、_ai_analysis/に2ファイル生成、Chat通知受信 |
| **SKIP理由** | cmd_207時点：OAuth2認証済みアカウントからのDriveアップロードが家老環境では不可 |
| **解消方法** | 殿がGoogle DriveのブラウザUIから直接アップロード、またはOAuth2サービスアカウントの設定 |

---

### T-E2E-002: Word文書（.docx）フルパイプライン

| 項目 | 内容 |
|------|------|
| **優先度** | HIGH |
| **テスト名** | .docxアップロード → Phase1対応確認 |
| **目的** | Phase1で追加したWord形式対応（MIME: application/vnd.openxmlformats-officedocument.wordprocessingml.document）が実際に動作することを確認する |
| **前提条件** | T-E2E-001と同じ。加えて.docxファイルを用意 |
| **実行手順** | 1. トリガーフォルダに.docxファイルをアップロード<br>2. WF自動起動を確認<br>3. exec確認（全ノードsuccess）<br>4. _ai_analysis/に2ファイル生成確認 |
| **期待結果** | .docxがFilterノードを通過し、Phase1全体が正常動作 |
| **SKIP理由** | cmd_207時点：T-E2E-001と同様 |
| **解消方法** | T-E2E-001と同様 |

---

### T-E2E-003: 高確信ケース → Drive自動移動

| 項目 | 内容 |
|------|------|
| **優先度** | HIGH |
| **テスト名** | 当事者名一致文書 → 案件特定 → 自動移動 |
| **目的** | Phase2の案件特定→スコアリング→Drive自動移動フローを実際のファイルで確認する |
| **前提条件** | ①T-E2E-001が完了していること<br>②**Notion案件DBの「ドライブリンク」フィールドに案件フォルダURLが設定されていること**（現在設定済み：使途不明金_池内久美子様のみ）<br>③テスト対象文書に当事者名「池内」が含まれていること |
| **実行手順** | 1. 「池内久美子」を当事者名に含む法律文書（PDF）を作成<br>2. トリガーフォルダにアップロード<br>3. exec確認（全22ノードsuccess）<br>4. Gemini案件特定ノードの出力で `partyName: 池内久美子` が抽出されていること確認<br>5. Notionスコアリングで `confidence: high, score: 70, targetFolderId: 1AcW7HdQC4QbBsPaBrv2lxy6cmL1DfQud` が設定されていること確認<br>6. `Move Original File to 案件フォルダ` が実行され、元ファイルが案件フォルダに移動していること確認<br>7. Google Chatに「自動移動完了」通知が届いていること確認 |
| **期待結果** | ファイルが `1AcW7HdQC4QbBsPaBrv2lxy6cmL1DfQud`（使途不明金_池内久美子様フォルダ）に移動、Chat通知「✅ 法律文書 自動分類完了」 |
| **SKIP理由** | cmd_207時点：OAuth2制約 + 案件DBのDriveリンク未設定（池内のみ設定済みだが実ファイルアップロードができない） |
| **解消方法** | ①Driveアップロード権限確保<br>②Notion案件DBにDriveリンクを追加設定 |

---

### T-E2E-004: 低確信ケース → 候補通知 + 受信BOX留置

| 項目 | 内容 |
|------|------|
| **優先度** | MEDIUM |
| **テスト名** | 未知当事者文書 → 候補通知フロー確認 |
| **目的** | Phase2でNotionに対応案件が見つからない、または低確信の場合に候補通知が送られ、ファイルが受信BOXに留置されることを確認する |
| **前提条件** | T-E2E-001が完了していること |
| **実行手順** | 1. Notion案件DBに存在しない当事者名を含む法律文書をアップロード<br>2. exec確認<br>3. `IF: 高確信/低確信` ノードで False（low）ルートが実行されていること確認<br>4. `Format 候補通知` ノードが実行され Chat通知「⚠️ 候補案件0件」が届いていること確認<br>5. 元ファイルが受信BOXに留置されていること（移動されていないこと）確認 |
| **期待結果** | IFノードFalseルート実行、候補通知Chat送信、ファイルは受信BOXに残留 |
| **SKIP理由** | cmd_207時点：OAuth2制約 |
| **解消方法** | Driveアップロード権限確保 |

---

### T-E2E-005: Driveリンク未設定案件での挙動確認

| 項目 | 内容 |
|------|------|
| **優先度** | MEDIUM |
| **テスト名** | Notionマッチあり・Driveリンク未設定 → 動作確認 |
| **目的** | 案件特定はできたがDriveリンク未設定（targetFolderId=null）の場合、低確信ルートに正しく流れるか確認する |
| **前提条件** | T-E2E-001が完了していること。Notion DBにDriveリンク未設定でタイトルマッチする案件があること（現状：池内以外の全案件が該当） |
| **実行手順** | 1. Driveリンク未設定案件の当事者名を含む文書をアップロード（例：「遺産分割_増永佳那」）<br>2. Notionスコアリングノードで `targetFolderId: null` となっていること確認<br>3. IFノードで `confidence=high && targetFolderId!=null` の条件がfalseとなること確認<br>4. 候補通知が送信されること確認 |
| **期待結果** | Driveリンク未設定のためIFノードFalseルート実行、「⚠️ 案件候補あり（Driveリンク未設定）」通知 |
| **備考** | Driveリンク未設定の案件が多数のため、実運用前にNotion案件DBの整備が推奨される |
| **SKIP理由** | cmd_207時点：OAuth2制約 |
| **解消方法** | Driveアップロード権限確保 |

---

### T-ERR-001: Gemini API障害時の挙動

| 項目 | 内容 |
|------|------|
| **優先度** | LOW |
| **テスト名** | Gemini API呼び出し失敗 → エラーハンドリング確認 |
| **目的** | Gemini APIが503等でエラーを返した場合、WFが適切にエラー処理するかを確認する |
| **前提条件** | テスト環境でGemini APIのモック or 無効なAPIキーでのテスト |
| **実行手順** | 1. WFのGemini APIキーを一時的に無効な値に変更<br>2. ファイルアップロードでWF起動<br>3. execのエラー内容を確認<br>4. APIキーを元に戻す |
| **期待結果** | WFがエラーで停止し、適切なエラーメッセージが記録される（現状はerrorHandling未設定のためエラー停止が想定） |
| **改善候補** | 「Call Gemini API」「Call Gemini API - Content MD」「Call Gemini API - 案件特定」の3ノードにcontinueOnFail設定とエラー通知ノードの追加 |

---

### T-ERR-002: Notion API障害時の挙動

| 項目 | 内容 |
|------|------|
| **優先度** | LOW |
| **テスト名** | Notion API検索失敗 → エラーハンドリング確認 |
| **目的** | Notion APIが503等でエラーを返した場合、Phase2フローが適切に処理されるかを確認する |
| **前提条件** | テスト環境でNotion APIのモックまたは無効なトークンでテスト |
| **実行手順** | 1. NOTION_BEARER_TOKENを一時的に無効化<br>2. ファイルアップロードでWF起動<br>3. execのエラー内容を確認 |
| **期待結果** | 「Notion案件DB検索」ノードでエラー停止。現状はフォールバックなし |
| **改善候補** | 「Notion案件DB検索」ノードにcontinueOnFail設定を追加し、Notion障害時は低確信ルートにフォールバックするロジックを実装 |

---

## 前提条件と解消方法まとめ

| 前提条件 | 影響テスト | 解消方法 |
|----------|-----------|---------|
| **Google Drive OAuth2アップロード権限** | T-E2E-001〜005 全件 | 殿がブラウザUIから直接アップロード、またはOAuth2サービスアカウント設定 |
| **Notion案件DBのDriveリンク設定** | T-E2E-003 | NotionのブラウザUIまたはAPIで各案件の「ドライブリンク」フィールドにGoogle DriveフォルダURLを設定。現在設定済み: 1件のみ（使途不明金_池内久美子様: `https://drive.google.com/drive/u/0/folders/1AcW7HdQC4QbBsPaBrv2lxy6cmL1DfQud`） |

---

## 実施推奨順序

```
Phase A（Driveリンク設定後すぐ実施可能）:
  T-E2E-001 → T-E2E-002 → T-E2E-004

Phase B（T-E2E-003の前提: 複数案件にDriveリンク設定後）:
  T-E2E-003 → T-E2E-005

Phase C（必要に応じて）:
  T-ERR-001 → T-ERR-002
```

---

*更新日: 2026-02-21*
