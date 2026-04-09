# 📊 戦況報告
最終更新: 2026-04-10 08:17 JST

## 🐸 Frog / ストリーク

| 項目 | 値 |
|------|-----|
| 今日のFrog | 未設定 |
| Frog状態 | 🐸 未撃破 |
| ストリーク | 🔥 29日目継続中 (最長: 29日) |
| 今日の完了 | 2 |
| VFタスク残り | 0件（うち今日期限: 0件） |

## 🚨 要対応 - 殿のご判断をお待ちしております

| タグ | 項目 | 詳細 |
|------|------|------|
| [info] | Claude Code .claude/skills パーミッションバグ | v2.1.78以降 .claude/skills がprotected directory exemptionから漏れている(anthropics/claude-code#37157, #38806)。セッション起動時に足軽がskills/操作でprompt停止する。暫定: 選択肢2で手動承認。公式修正待ち。将軍がセッション開始時に修正状況を確認する。 |
| [action] | gas-mail-manager processAllCustomers 実行+OAuth承認(cmd_486) | clasp push成功(7ファイル)。GASエディタで: (1)関数選択→processAllCustomers (2)実行→OAuth権限再承認ダイアログを承認 (3)処理結果確認。動作確認後、git commit済かどうか確認。 |
| [action] | gas-mail-manager appsscript.json OAuth scope拡大承認(OBS-486-001) | spreadsheets.currentonly→spreadsheets への変更が必要。殿の承認後、appsscript.json更新→clasp push→OAuth再承認が必要。 |
| [proposal] | pdfmerged GHA release workflowにnotes-file固定化(sug_cmd_481_001) | v0.9.3リリースノートがGHA再実行でFull Changelogに上書きされた事象。次回リリース時に.github/workflows/のrelease jobでgh release editステップ追加を検討。|
| [proposal] | 足軽報告書schema違反9連続の構造対策(sug統合) | SO-01/SO-03/SO-12 違反が累積。ashigaru.md報告テンプレートに必須フィールド明記 or qc_auto_check.sh必須化 or Step5 schema validation追加を検討。cmd化推奨。|
| [action] | pdfmerged v0.9.4 Windows実機確認(cmd_487) | subtask_487a(geometry検出化)はWSL2では実機確認不可。Windows環境でpdfmergedを起動し: (1)ノートPC(1366x768)相当の解像度でボタンが見切れないこと (2)テキストファイルのPDF変換で改行位置が正確なこと を確認。v0.9.4 release: https://github.com/saneaki/pdfmerged/releases/tag/v0.9.4 |

## 🔄 進行中 - 只今、戦闘中でござる

| cmd | 内容 | 担当 | 状態 |
|-----|------|------|------|
| — | 待機中 | — | — |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet+T) | ✅完了(QC PASS) | subtask_472a2: python-utf8-errors-replace SKILL.md AC4/4 qc2/5(schema soft fail) |
| 足軽2号(Sonnet+T) | ✅完了(QC PASS) | subtask_487c: v0.9.4 CHANGELOG+commit(12cf69c)+push+release AC3/3 qc4/5 |
| 足軽3号(Sonnet+T) | ✅完了(QC PASS) | subtask_472a3: notion-session-log-section-pattern SKILL.md AC4/4 qc2/5 |
| 足軽4号(Opus+T) | ✅完了(QC PASS) | subtask_472a4: n8n-daily-guard-pattern SKILL.md 560行拡充 AC4/4 qc4/5 |
| 足軽5号(Opus+T) | ✅完了(QC PASS) | subtask_472a5: shogun-compaction-log-analysis SKILL.md AC4/4 qc4/5 |
| 足軽6号(Codex5.3) | ✅完了(QC PASS) | subtask_487a: geometry画面検出+button_frame fill AC5/5 qc5/5 |
| 足軽7号(Codex5.3) | ✅完了(QC PASS) | subtask_487b: pdfmetrics.stringWidth改行修正 AC3/3 qc5/5 |
| 軍師(Opus+T) | ✅完了 | cmd_487全3subtask+cmd_472全5subtask QC PASS(4件バッチ+487c) |
| 家老(Sonnet) | 🔄処理中 | cmd_472/cmd_487完了処理(スキルアーカイブ+dashboard更新) |

## ✅ 本日の戦果（4/10 JST）

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 08:16 | cmd_487 | 🏆 pdfmerged v0.9.4完了 ノートPC表示バグ(geometry検出化+fill)+テキスト改行バグ(stringWidth刷新)+リリース AC全件QC PASS commit 12cf69c | ✅ |
| 08:16 | cmd_472 | 🏆 スキル5件新設完了 codex-cli-poc/python-utf8/notion-session-log/n8n-daily-guard/shogun-compaction-log 全5subtask QC PASS | ✅ |
| 08:14 | cmd_487 | subtask_487c: v0.9.4 CHANGELOG+commit(12cf69c)+push+release+Issue#7#8close AC3/3 qc4/5 | ✅ |
| 08:11 | cmd_487 | subtask_487b: テキスト改行pdfmetrics.stringWidth方式刷新+Issue#7 AC3/3 qc5/5 | ✅ |
| 08:11 | cmd_487 | subtask_487a: ノートPC表示バグ修正(geometry検出化+button_frame fill)+Issue#8 AC5/5 qc5/5 | ✅ |
| 08:10 | cmd_472 | subtask_472a5: shogun-compaction-log-analysis SKILL.md 情報密度最適化セクション追記 AC4/4 qc4/5 | ✅ |
| 08:10 | cmd_472 | subtask_472a4: n8n-daily-guard-pattern SKILL.md 560行拡充(8ノード雛形+3軸代替案+防御的設計) AC4/4 qc4/5 | ✅ |
| 08:05 | cmd_472 | subtask_472a3: notion-session-log-section-pattern SKILL.md新設 AC4/4 qc2/5(schema soft fail) | ✅ |
| 08:03 | cmd_472 | subtask_472a2: python-utf8-errors-replace SKILL.md確認+横展開対象調査 AC4/4 qc2/5(schema soft fail) | ✅ |
| 07:57 | cmd_481 | 🏆 pdfmerged v0.9.3完了 TEST_GUIDE整備+墨消し右カラム+1440x900+GHAリリース+Keep a Changelog AC11/11 | ✅ |
| 07:47 | cmd_481(再) | subtask_481e: GitHub Release v0.9.3 リリースノート再反映(Full Changelog→Keep a Changelog復元) AC3/3 qc5/5 | ✅ |
| 07:47 | cmd_472 | subtask_472a1: codex-cli-poc-verification SKILL.md新設 AC3/3 qc5/5 | ✅ |

## ✅ 昨日の戦果（4/9 JST）— 6cmd完了 🔥ストリーク29日目

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 02:51 | cmd_486 | 🏆 gas-mail-manager CRITICAL 5件修正+clasp push成功(7ファイル) AC9/9 殿GAS実行待ち | ✅ |
| 02:30 | cmd_485 | 🏆 ntfy cmd_completeタグ欠落バグ3点防御(auto-detect+inbox_write+karo.md) AC8/8 commit 7741e1e | ✅ |
| 01:50 | cmd_484 | 🏆 足軽自己/clear機構実装完遂 self_clear_check.sh+Step9.7+Self Clear Protocol AC6/7 QC PASS | ✅ |
| 01:48 | cmd_484a | 🏆 self_clear_check.sh(131行) dry-run 2テストPASS(assigned→SKIP/done→CLEAR CANDIDATE) | ✅ |
| 01:41 | cmd_483 | 🏆 tkinter GUI検証強化 2並列完遂(instructions schema追加+xvfb feasibility) AC6+5/5 | ✅ |
| 01:38 | cmd_483b | 🏆 xvfb feasibility: pytest-xvfb+winfo推奨(pyautogui不採用) AC5/5 一次情報4件 | ✅ |

## 🛠️ スキル候補（承認待ち）

承認待ち候補を全件表示。✅実装済みは `memory/skill_history.md` にアーカイブ済み。

| スキル名 | 発見元 | 概要 |
|---------|-------|------|
| **shogun-decision-notify-pattern** | cmd_469 足軽4号(Opus+T): 決裁項目([要判断]/[要行動])検出時に殿のスマホへ即時ntfy push + `queue/decision_requests.yaml` atomic append + 5分cooldown重複抑制 + exit 0フェイルセーフの4要素を組合せた汎用通知テンプレート。Frog Reset Reminder/朝のストリーク通知/未撃破リマインド/定期バックアップ通知等の類似通知スクリプト設計時間を60-70%短縮見込み | 承認待ち |
| **shogun-precompact-snapshot-e2e-pattern** | cmd_468c4 足軽5号(Opus+T): PreCompact hook の E2E 検証パターン。テスト前バックアップ→TMUX_PANE 環境変数で対象エージェント切替→4 シナリオ(能動書込み/hook発動/復旧/ロールバック READ-ONLY)→diff -q で安全復元。Hook 系の安全な E2E 検証テンプレートとして再利用可能(PostToolUse/SessionStart 等の検証にも応用) | 承認待ち |
| **shogun-snapshot-schema-multi-source-fallback** | cmd_475a1 足軽5号(Opus+T): snapshot/report YAML の schema 差異を script 側で吸収する多段フォールバックパターン。優先順位=nested.primary→top.primary→nested.secondary→top.secondary→推論→safety net。`cmd_XXX` 文字列への正規化で出力統一し下流 script の分岐削減。context_snapshot.sh + pre_compact_snapshot.sh + qc_auto_check.sh の parent_cmd/cmd_id 統一 + description multi-line 抽出 + snapshot 鮮度閾値 config 化を一般化。multi-agent で schema 差異を吸収する場面に再利用可能 | 承認待ち |
| **shogun-n8n-notion-trigger-v1-flat-access** | cmd_478 足軽3号(Sonnet+T): n8n Notion Trigger v1 は properties をトップレベルにフラット展開する。`page.properties?.['X']?.select?.name` ではなく `page['X']` で直接アクセス。既存の Notion API アクセスコードパターンと異なるため、Notion Trigger v1 使用時は必ず flat 構造を前提とした実装が必要。Docker volume mount 不足(ENOENT)と task-runner 内 process.pid 未定義(ReferenceError)の対処パターンも合わせて記録 | 承認待ち |
| **pandoc-gha-multiformat-docs** | cmd_480a 足軽4号(Opus+T): GitHub Actions で単一 .md ソースから PDF/HTML/MD の3形式を自動生成し release artifact に同梱するパターン。ubuntu runner + pandoc + wkhtmltopdf + fonts-noto-cjk(日本語対応)で構築。build→[smoke, docs_build]並列→release の DAG 設計。PDF 生成失敗時の HTML fallback 付き。一般層向けドキュメント配布が必要な OSS/社内ツールに再利用可能 | 承認待ち |
| **n8n-code-yaml-regex-parse** | cmd_472a4 足軽4号(Opus+T): n8n Code ノード(typeVersion 2)でjs-yamlが使えない場合の正規表現ベースYAMLパース。ブロック抽出+フィールド取得+三重null判定の防御的実装テンプレート | 承認待ち |
