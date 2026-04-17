# cmd_521 スキル候補精査レポート

作成: 軍師 (subtask_521a)
日付: 2026-04-17
north_star: dashboard🛠️スキル候補12件を4区分分類し、殿がGO/NO-GO判断できる精査報告

## 1. 一覧表

| ID | 候補名 | 分類 | 根拠 | ��奨 | 優先度 |
|----|--------|------|------|------|--------|
| C1 | csm軍師ペイン高さ確保パタ���ン | **(d) 却下** | 再���用シーン1未満。shutsujin_departure.sh修正で対処済(47a2a0c) | 🛠️欄から削除 | - |
| C2 | shogun-decision-notify-pattern | **(a) 新規** | ntfy+atomic append+cooldown+fail-safe 4要��テンプレ。再利用4シーン以上。既存重複0% | 独立SKILL.md作成 | medium |
| C3 | shogun-precompact-snapshot-e2e-pattern | **(c) CLAUDE.md** | Hook E2E検証は15行チェックリストで完結。独立skill密度不足 | CLAUDE.md Test Rules節に追記 | low |
| C4 | shogun-snapshot-schema-multi-source-fallback | **(a) 新規** | multi-source fallback chain。3スクリプトで実績あり。既存重複0% | 独立SKILL.md作成 | low |
| C5 | shogun-n8n-notion-trigger-v1-flat-access | **(b) 統合** | Notion Trigger v1のflat access特性。shogun-n8n-notion-property-sync §X追加で吸収 | 既存skillに15行追加 | low |
| C6 | pandoc-gha-multiformat-docs | **(a) 新規** | GHA+pandoc+CJK multi-format生成。github-actions-release-artifactと異スコープ | 独立SKILL.md作成 | low |
| C7 | n8n-code-yaml-regex-parse | **(b) 統合** | n8n-code-javascript(347L)に§追加で自然吸収。統合後377L | 既存skillに30行追加 | low |
| C8 | shogun-n8n-gcal-synctoken-date-guard | **(b) 統合** | n8n-gcal-api-pagination-guard(277L)にsyncToken節追加。統合後317L | 既存skillに40行追加 | low |
| C9 | shogun-systemd-user-cron-healthcheck-pattern | **(a) 新規** | systemd+healthcheck+通知の定番構成。既存skill無し。再利用3シーン以上 | 独立SKILL.md作成 | medium |
| C10 | pdfmerged-release-version-consistency-pattern | **(b) 統合** | pdfmerged-feature-release-workflow(384L)に§追加。統合後399L | 既存skillに15行追加 | low |
| C11 | legal-ivr-flow-design-pattern | **(a) 新規** | 士業IVRフロー設計。legal-document-namer/obsidian-legal-templaterと異スコープ | 独立SKILL.md作成 | low |
| C12 | artifact-registration-pattern | **(d) 却下** | cmd_519振り返りでskill化不要判断済。CLAUDE.md既存記載で十�� | 🛠️欄から削除 | - |

**集計**: (a)新規 5件 / (b)統合 4件 / (c)CLAUDE.md 1件 / (d)却下 2件

## 2. 各候補の詳細分析

### C1: csm軍師ペイン高さ確保パターン → (d) 却下

**内容**: shutsujin_departure.shでグリッド構築後にresize-pane -y 17を軍���ペインに適用する恒久対策。

**却下理由**: tmux resize-paneの1コマンドが本質であり、skill密度が150行に満たない。shutsujin_departure.sh L708-710に既に恒久対策が実装済(commit 47a2a0c)。新エージェント追加時はshutsujin_departure.sh修正時に自然と気づく。単発事象の域を出ない。

### C2: shogun-decision-notify-pattern → (a) 新規独立化

**内容**: ntfy push + queue/decision_requests.yaml atomic append + 5分cooldown重複抑制 + exit 0フェイルセーフの4要素通知テンプレート。

**新規判断根拠**:
- 再利用シーン: (1)Frog Reset Reminder (2)朝のストリーク通知 (3)未撃破リマインド (4)定期バックアップ通知 (5)stall_detector通知 → **5シーン以上**
- 既存重複: 0% (ntfy直叩きスクリプトは複数あるがテンプレート化されていない)
- 密度: 4要素×各20行+事例+テスト = 150L以上見込み

**推奨skill名**: `shogun-decision-notify-pattern` (現名維持)

**SKILL.md節構成案**:
1. Trigger / When to use
2. 4-Element Template (ntfy push / atomic append / cooldown / fail-safe)
3. notify_decision.sh 実装詳細
4. 横展開パターン (リマインダー/ヘルスチェック/アラート)
5. Testing & Debugging

### C3: shogun-precompact-snapshot-e2e-pattern → (c) CLAUDE.md記載

**内容**: PreCompact hook E2E検証パターン。テスト前backup → TMUX_PANE切替 → 4シナリオ → diff -q復元。

**CLAUDE.md判断根拠**: Hook E2E検証の本質は「backup→操作→verify→restore」の4ステップチェックリスト。独立skill密度(150L)に達しないが、再発防止として記録は必要。

**記載位置**: CLAUDE.md「Test Rules」セクション末尾

**草案**(15行):
```
## Hook E2E Testing Checklist

Hook (PreCompact/PostToolUse等) の E2E 検証手順:
1. テスト前: 対象ファイル(snapshot等)をバックアップ (cp -a)
2. 環境設定: TMUX_PANE で対象エージェント切替
3. 4シナリオ��行:
   (a) 能動書込み (context_snapshot.sh write)
   (b) Hook 発動 (対象操作トリガー)
   (c) 復旧確認 (snapshot 内容照合)
   (d) ロールバック (diff -q でバックアップ復元)
4. 各シナリオで PASS/FAIL 記録
5. テスト後: バックアップから復元 (READ-ONLY 原則)
```

### C4: shogun-snapshot-schema-multi-source-fallback → (a) 新規独立化

**内容**: snapshot/report YAMLのschema差異をscript側で吸収する多段フォールバックパターン。nested.primary → top.primary → nested.secondary → top.secondary → 推論 → safety net。

**新規判断根拠**:
- 再利用シーン: (1)context_snapshot.sh (2)pre_compact_snapshot.sh (3)qc_auto_check.sh (4)update_dashboard.sh (5)将来の新script → **5シーン**
- 既存重複: 0% (YAML処理パターンをskill化したものは未存在)
- 密度: fallback chain設計+正規化+config化 = 150L以上

**推奨skill名**: `shogun-snapshot-schema-multi-source-fallback` (現名維持)

**SKILL.md節構成案**:
1. Problem Statement (schema差異の発生パターン)
2. Fallback Chain Design (優先順位定義)
3. cmd_XXX Normalization (文字列正規化)
4. Script Examples (context_snapshot/qc_auto_check)
5. Configuration (鮮度閾値等のconfig化)

### C5: shogun-n8n-notion-trigger-v1-flat-access → (b) 既存統合

**内容**: n8n Notion Trigger v1はpropertiesをトップレベルにフラット展開する。`page.properties?.['X']?.select?.name`ではなく`page['X']`で直接アクセス。

**統合判断根拠**: shogun-n8n-notion-property-sync (459L)のスコープ内。Trigger v1のフラット構造はProperty Syncの「API形式差異」の一種。独立skillにする密度なし。

**統合先**: `shogun-n8n-notion-property-sync`
**追加節**: `## Trigger v1 Flat Access (注意事項)` (~15行)
**統合後行数見込**: 459 + 15 = 474L (400L超だが内容的に分離不適切。既存skillが大きい前提で許容)

### C6: pandoc-gha-multiformat-docs → (a) 新規独立化

**内容**: GitHub Actions + pandoc + wkhtmltopdf + fonts-noto-cjk で .md から PDF/HTML/MD 3形式を自動生成するパターン。

**新規判断根拠**:
- 再利用シーン: (1)pdfmerged OSS docs (2)legal-ivr-flow 成果物配布 (3)社内ツールマニュアル → **3シーン**
- 既存重複: github-actions-release-artifact は binary/asset 配布で異スコープ (< 10%)
- 密度: GHA workflow template + pandoc config + CJK対応 + fallback = 150L以上

**推奨skill名**: `pandoc-gha-multiformat-docs` (現名維持)

**SKILL.md節構成案**:
1. Trigger / When to use
2. GHA Workflow Template (build → [smoke, docs_build] → release DAG)
3. pandoc Configuration (--pdf-engine, --css, metadata)
4. CJK Support (fonts-noto-cjk, lang header)
5. PDF Fallback (HTML fallback on PDF generation failure)
6. Testing & Debugging

### C7: n8n-code-yaml-regex-parse → (b) 既存統合

**内容**: n8n Code ノード(typeVersion 2)でjs-yaml不可時の正規表現ベースYAMLパース。ブロック抽出+フィールド取得+三重null判定。

**統合判断根拠**: n8n-code-javascript (347L)のスコープ内。Code nodeでのデータ処理技法の一種。

**統合先**: `n8n-code-javascript`
**追加節**: `## YAML Regex Parsing (js-yaml不可時)` (~30行)
**統合後行数見込**: 347 + 30 = 377L (400L以内)

### C8: shogun-n8n-gcal-synctoken-date-guard → (b) 既存統合

**内容**: Google Calendar syncTokenベース差分同期がtimeMin/timeMaxを無視する問題。jsCodeで手動日付範囲フィルタを追加。

**統合判断根拠**: n8n-gcal-api-pagination-guard (277L)のスコープ内。GCal APIデータ完全性の同系統課題。

**統合先**: `n8n-gcal-api-pagination-guard`
**追加節**: `## syncToken Date Guard (差分同期の日付範囲制限)` (~40行)
**統合後行数見込**: 277 + 40 = 317L (400L以内)

### C9: shogun-systemd-user-cron-healthcheck-pattern → (a) 新規独立化

**内容**: ユーザーsystemd service + cron healthcheck + ntfy通知の定番構成。loginctl enable-linger、repo管理、XDG_RUNTIME_DIR export、cooldown state file、StartLimitInterval/Burst。

**新規判断根拠**:
- 再利用シーン: (1)inbox_watcher systemd化 (2)n8n watcher (3)stall_detector定期実行 → **3シーン**
- 既存重複: 0% (systemd/cron関連skillなし)
- 密度: systemd unit + healthcheck.sh + cron設定 + 通知連携 = 150L以上

**推奨skill名**: `shogun-systemd-user-cron-healthcheck-pattern` (現名維持)

**SKILL.md節構成案**:
1. systemd User Service Configuration
2. loginctl enable-linger Setup
3. healthcheck.sh Template (XDG_RUNTIME_DIR/DBUS/PATH export)
4. Cooldown State File (重複通知抑制)
5. StartLimitInterval/Burst (無限再起動防止)
6. ntfy/Notification Integration
7. Cron Scheduling Examples

### C10: pdfmerged-release-version-consistency-pattern → (b) 既存統合

**内容**: __version__とtag/Releaseの整合性をCIで強制するパターン。build-exe.yml validation step追加。

**統合判断根拠**: pdfmerged-feature-release-workflow (384L)のスコープ内。リリースワークフローの品質ゲートとして自然な位置付け。

**統合先**: `pdfmerged-feature-release-workflow` (project skill)
**追加節**: `## §X Version Consistency Check` (~15行)
**統合後行数見込**: 384 + 15 = 399L (400L以内)

### C11: legal-ivr-flow-design-pattern → (a) 新規独立化

**内容**: 法律事務所IVR電話自動受付フロー設計。3カテゴリ分岐、DTMF+STT使い分け、Webhook構造化通知、弁護士法準拠、PoC Go/No-Go判定。

**新規判断根拠**:
- 再利用シーン: (1)税理士事務所IVR (2)���労士事務所IVR (3)行政書士事務所IVR → **3シーン** (水平展開)
- 既存重複: legal-document-namer (文書命名)、shogun-obsidian-legal-templater-design (文書テンプレート) → いずれも異スコープ (< 10%)
- 密度: フロー設計+分岐ロジック+コンプライアンス+PoC計画 = 200L以上

**推奨skill名**: `legal-ivr-flow-design-pattern` (現名維持)

**SKILL.md節構成案**:
1. Flow Design Template (6-phase構造)
2. DTMF vs STT Decision Matrix
3. Webhook Notification Design
4. Legal Compliance (弁護士法72条/23条/27条)
5. PoC Plan Template (Go/No-Go 4段階)
6. Horizontal Expansion Guide (他士業)

### C12: artifact-registration-pattern → (d) 却下

**内容**: cmd完了時の成果物自動登録パターン。task YAML output_path必須化、artifact_register.sh呼び出し。

**却下理由**: cmd_519振り返りレビュー(subtask_519a, commit 4e12bd4)で「skill化不要」と判断済み。根拠: (1)CLAUDE.md §Artifact Registration Protocol(L370-407)に運用手順が十分に記載 (2)artifact_register.sh自体が246行の実装で、skill化しても新規知見が少ない (3)3cmd運用で安定動作しており追加ガイダンス不要。dashboard🛠️欄の「承認待ち(設計段階)」注記を削除推奨。

## 3. Dashboard更新提案

### 🛠️欄から削除推奨 (却下2件)

1. **csm軍師ペイン高さ確保パターン** (C1) — shutsujin_departure.sh修正で対処��。再利用シーン不足。
2. **artifact-registration-pattern** (C12) — cmd_519振り返りでskill化不要判断済。

### 🛠️欄に残留 (承認待ち10件)

残り10件は殿の判断で順次GO/NO-GOを決定。

**優先実装推奨** (medium):
- C2: shogun-decision-notify-pattern — 通知スクリプト量産の基盤
- C9: shogun-systemd-user-cron-healthcheck-pattern — インフラ安定運用の基盤

**統合実行推奨** (既存skill更新で完了):
- C5 → shogun-n8n-notion-property-sync
- C7 → n8n-code-javascript
- C8 → n8n-gcal-api-pagination-guard
- C10 → pdfmerged-feature-release-workflow

**新規作成** (low priority, 殿の判断で後回し可):
- C4: shogun-snapshot-schema-multi-source-fallback
- C6: pandoc-gha-multiformat-docs
- C11: legal-ivr-flow-design-pattern

**CLAUDE.md追記** (家老作業で即完了可):
- C3: shogun-precompact-snapshot-e2e-pattern → Test Rules節に15行

## 4. North Star Alignment

**status**: aligned
**reason**: 12候補全件を4区分に分類し、各候補にGO/NO-GO判断材料(根拠・推奨・優先度)を添付。殿は一覧表で候補単位に判断可能。
**risks_to_north_star**:
- 統合先skill (C5: 459→474L) が400L上限を超過。内容的に分離不適切のため許容判断としたが、殿の判断で別skillに分離する選択肢もあり。
