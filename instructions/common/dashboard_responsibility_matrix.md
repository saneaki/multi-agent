# Dashboard Responsibility Matrix

**canonical責務マトリクス** — cmd_659 Scope D 制定 (2026-05-08)

各役割の dashboard 責務・禁止事項はこのファイルを正とする。
他ファイル (karo.md / gunshi.md / shogun_mandatory.md) はここへの参照のみとし、記述を複製しない。

---

## 責務マトリクス

| 役割 | 責務 | 禁止事項 |
|------|------|----------|
| **gunshi** | `gunshi_report.yaml` の `result.action_required_candidates` に候補を出力 | dashboard.md 直接編集 |
| **action_required_sync.sh** | `gunshi_report.yaml` を読み `dashboard.yaml` の `action_required` に idempotent upsert。完了後 `generate_dashboard_md.py` を呼出す | dashboard.md への direct write |
| **generate_dashboard_md.py** | `dashboard.yaml` → `dashboard.md` render (境界コメント内のみ全置換。境界外セクションは input md からそのままコピー) | yaml 直接編集 |
| **karo** | resolved 判断・escalation・cmd 戦果記載・🚨要対応 [要行動]/[要判断] タグ管理 | dashboard.md 直接編集 (緊急例外のみ将軍/家老の明示判断) |
| **dashboard.md** | render artifact (読み取り専用 — renderer が生成) | 直接編集禁止 (緊急例外のみ将軍/家老の明示判断) |

---

## セクション別更新担当

| セクション | 更新方法 | 担当 |
|----------|---------|------|
| 🔄 進行中 / 🏯 待機中 | `scripts/update_dashboard.sh` 自動更新 (queue/tasks/*.yaml から partial-replace) | 自動 |
| 最終更新 (header) | `scripts/update_dashboard.sh` 自動更新 (`jst_now.sh` 由来) | 自動 |
| 📊 運用指標 | `scripts/update_dashboard.sh` 自動更新 (logs/cmd_squash_pub_hook.daily.yaml 由来) | 自動 |
| 🚨 要対応 | `action_required_sync.sh` → `generate_dashboard_md.py` render (cmd_659 Pipeline 稼働後) | 自動 (暫定: 家老 + 軍師 直接編集) |
| ✅ 本日/昨日/一昨日の戦果 | dashboard.md 直接編集 (Edit/Write) | 家老 (+軍師の本日戦果直接記載) |
| 🐸 Frog / ストリーク | dashboard.md 直接編集 (Edit/Write) | 家老 |
| ⚠️ 違反検出 | `scripts/update_dashboard.sh` には触らせない (専用スクリプト or 直接編集) | 家老 |
| 🛠️ スキル候補 | dashboard.md 直接編集 (Edit/Write) | 家老 + 軍師 |
| 📋 記載ルール | dashboard.md 直接編集 (Edit/Write) | 家老 |

---

## 🚨要対応 タグ分類

| タグ | 判定基準 | 使用権限 |
|------|---------|---------|
| [要行動] | 殿しかできない作業（認証情報取得・外部操作等） | 家老のみ |
| [要判断] | 殿の GO/NO-GO 判断待ち（本番切替・方針決定等） | 家老のみ |
| [提案] | チームからの改善提案（採否は殿が決定） | 家老・軍師 |
| [情報] | ブロッカーではないが認識いただきたい事項 | 家老・軍師 |

Priority: [要行動] > [要判断] > [提案] > [情報]

---

## 変更履歴

| 日時 | 変更内容 | cmd |
|------|---------|-----|
| 2026-05-08 | 初版作成 (各 instruction からの canonical 参照集約) | cmd_659 Scope D |
