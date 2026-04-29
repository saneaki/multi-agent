---
name: s-check
description: |
  将軍が「状況」「進捗」「動作確認」「完了報告」「動いてるか」「s-check」「確認してくれ」などの指示を受けた際、dashboard.yamlを起点に一次情報を三点突合し、誤報・盲信・silent successを防ぐための確認手順。報告前にtasks/reports/inbox/tmux/git logを段階的に照合し、整合/軽微ズレ/阻害不一致を判定して殿向け4-blockで返す。実装・設計・文章生成そのものが主目的の依頼には使わず、状態監査と根拠提示が必要な場面でのみ使用する。
---

## 1. When to use
- トリガー語: 「状況」「進捗」「動作確認」「完了報告」「動いてるか」「s-check」「確認してくれ」
- 状況一覧:
  - 将軍が現況の真偽確認を求めるとき
  - dashboard.yaml の値を報告前に裏取りするとき
  - 「終わったはず」の silent success 疑いがあるとき
  - report と task の不整合が疑われるとき

## 2. When NOT to use
- ネガティブトリガー:
  - 新機能実装・リファクタ・設計書作成が主目的
  - 単純なファイル整形や文体修正のみ
  - 根拠照合なしで速報を優先する即時応答
  - 監査ではなく意思決定のみを求める相談

## 3. Required Sources
- Primary (必ず読む):
  - `queue/tasks/*.yaml`
  - `queue/reports/*_report.yaml`
  - `queue/inbox/*.yaml`
  - `dashboard.yaml`
  - tmux pane (9本)
  - `git log`
- Secondary (必要時):
  - `dashboard.md`
- Supplemental (補助のみ):
  - `compact_suggestion`
  - `shogun_context_notify`

## 4. Verification Order (2-stage)
- Stage1 (summary):
  - `dashboard.yaml` を起点に、対象cmdの tasks YAML と reports YAML を三点突合
  - ステータス、時刻、完了条件の一致を確認
- Stage2 (evidence):
  - Stage1で不整合候補が出た箇所のみ深掘り
  - `inbox`、tmux pane、`git log` を追加照合して原因特定

## 5. Decision Rubric (3-tier)
- `consistent`: 全sourceで主要事実が一致し、阻害要因なし
- `minor drift`: 軽微ズレあり（表示遅延・時刻差分・記載漏れ）だが進行可能
- `blocking mismatch`: 進行不能級の不一致（完了偽装、依存未解決、根拠欠落）

## 6. Output Template (4-block 殿向け)
- Block1: 結論
  - `consistent` / `minor drift` / `blocking mismatch`
- Block2: 根拠
  - checked sources: `[...]` を必ず列挙
  - last verified timestamp: `YYYY-MM-DD HH:MM JST` を必須記載
- Block3: 不確実性
  - 未確認source、推定箇所、inconclusive要素を明示
- Block4: 次アクション
  - 追加確認、修正指示、保留判断を具体化

## 7. Failure Handling
- silent success 防止:
  - 出力に checked sources を必ず含める
  - 「確認済み」の根拠source未記載は無効報告として扱う
- inconclusive 容認:
  - 全sourceを読めない場合でも partial 結果を返す
  - 誤答するくらいなら未確定として明示する

## 8. Common Module Integration
- スクリプトチェック補助:
  - `scripts/lib/status_check_rules.py` (Scope B 実装) を参照
- on-demand 用途:
  - shogun が `/s-check` 発動時に必要箇所のみ呼び出し
  - ルール更新時は SKILL と module の整合を同時確認
