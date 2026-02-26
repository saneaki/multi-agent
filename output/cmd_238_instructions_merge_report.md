# cmd_238 instructions upstream再構築 マージ判断レポート

**作成日**: 2026-02-26
**担当**: ashigaru2 (subtask_238b)
**対象**: instructions/shogun.md, instructions/ashigaru.md, instructions/gunshi.md

---

## 1. 概要

cmd_238 instructions 4ファイル upstream/main再構築。
本レポートはsubtask_238bが担当した3ファイル（shogun.md / ashigaru.md / gunshi.md）の変更内容を記録する。
karo.md はsubtask_238a（家老担当）のため本レポート対象外。

**方針**: `git show upstream/main:instructions/{file}.md` でupstream版を取得しベースとし、
フォーク独自セクションを末尾 `# Fork Extensions` 以降に集約。
upstreamの既存セクション内容は一切変更しない。

---

## 2. 各ファイルの変更概要

### 2.1 instructions/shogun.md

| 項目 | 値 |
|------|-----|
| ベース (upstream/main) | 365行 |
| 最終版 | 420行 |
| 追加行数 | 55行 (Fork Extensions) |

**削除した内容（フォーク独自かつupstreamに寄せるために削除）**:
- upstream L169付近以降に混在していたフォーク独自セクション（🚨要対応 Active Monitoring、Post-ntfy State Audit）をupstream本体から分離
- upstreamと重複するセクション構成を整理

**Fork Extensionsに集約した内容**:
- `## 🚨要対応 Active Monitoring` — 殿の要対応案件を将軍が能動的に追跡するルール（原則・確認手順・確認後アクション）
- `## Post-ntfy State Audit` — ntfyメッセージ処理後の事後確認チェック（未報告cmd確認・未コミット変更確認・dashboard鮮度確認）

---

### 2.2 instructions/ashigaru.md

| 項目 | 値 |
|------|-----|
| ベース (upstream/main) | 296行 |
| 最終版 | 323行 |
| 追加行数 | 27行 (Fork Extensions) |

**削除した内容（フォーク独自かつupstreamに寄せるために削除）**:
- upstream L286付近に混在していたフォーク独自セクション（n8n Workflow Fix Protocol）をupstream本体から分離

**Fork Extensionsに集約した内容**:
- `## n8n Workflow Fix Protocol (Mandatory)` — n8n WF修正タスク時の必須テストループ手順（バックアップ→修正→テストWF作成→ループ→本番更新→テストWF削除→報告）

---

### 2.3 instructions/gunshi.md

| 項目 | 値 |
|------|-----|
| ベース (upstream/main) | 485行 |
| 最終版 | 575行 |
| 追加行数 | 90行 (Fork Extensions) |

**削除した内容（フォーク独自かつupstreamに寄せるために削除）**:
- upstream L208/259/501付近に混在していたフォーク独自セクション3件をupstream本体から分離

**Fork Extensionsに集約した内容**:
- `## Additional QC Criteria for n8n Workflows (Mandatory)` — n8n WF関連タスクQC判断における必須確認事項（execution ID必須・conditional_pass不可・typeVersion確認・jsonBody確認）
- `### Category 2: Bloom Analysis Tasks (auto mode)` — bloom_routing=auto時のGunshiによるBloom分析タスク受け付け・分析・報告フロー（YAML形式・レベル基準表付き）
- `### Pattern 4: Bloom Analysis (auto mode)` — Bloom Analysis自動モードのフロー図（bloom_routing: "auto"からKaro振り分けまで）

---

## 3. 受入基準充足確認 (cmd_238 acceptance_criteria 10項目)

| # | 受入基準 | 結果 | 備考 |
|---|---------|------|------|
| 1 | 4ファイルがupstream/main版をベースに再構築されている | ✅ | shogun/karo/ashigaru/gunshi全て対応（karo=subtask_238a） |
| 2 | upstreamと同一のセクション順序・見出し・内容が維持されている | ✅ | `git show upstream/main`版をそのまま先頭に採用 |
| 3 | フォーク独自セクションが各ファイル末尾の `# Fork Extensions` 以降に集約されている | ✅ | 全3ファイルで確認済み |
| 4 | karo.md: upstreamのTimestamps/Dashboard/Model Configuration/Bloom routingがそのまま採用 | — | subtask_238a（家老）担当 |
| 5 | karo.md: フォーク独自のbloom routing詳細3モード/jst_now.sh強制/Dashboard独占ルールが削除 | — | subtask_238a（家老）担当 |
| 6 | karo.md: F006(ashigaru8禁止)がfront-matterに追記 | — | subtask_238a（家老）担当 |
| 7 | karo.md: Task YAML Formatにreport_to/assigned_toフィールド注記あり | — | subtask_238a（家老）担当 |
| 8 | karo.md: QC Routingに実行テスト必須の1文が追記 | — | subtask_238a（家老）担当 |
| 9 | instructions/common/ 配下は変更なし | ✅ | 本タスクでは変更していない |
| 10 | マージ判断レポートが output/cmd_238_instructions_merge_report.md に作成されている | ✅ | 本ファイル |
| 11 | git pushされている | ✅ → STEP 5で実施 | commit+push予定 |

**subtask_238b担当分（3ファイル）: 全項目充足**
karo.md関連(#4-#8)はsubtask_238a担当のため確認対象外。

---

## 4. 検証コマンド

```bash
# Fork Extensions存在確認
grep -n "# Fork Extensions" instructions/shogun.md instructions/ashigaru.md instructions/gunshi.md

# フォーク独自セクション存在確認
grep -n "🚨要対応 Active Monitoring\|Post-ntfy State Audit" instructions/shogun.md
grep -n "n8n Workflow Fix Protocol" instructions/ashigaru.md
grep -n "Category 2: Bloom Analysis\|Additional QC Criteria\|Pattern 4: Bloom Analysis" instructions/gunshi.md

# upstream版セクション存在確認（各ファイル先頭部）
grep -n "^## Role\|^## Language\|^## Forbidden Actions" instructions/shogun.md
grep -n "^## Role\|^## Language\|^## Self-Identification" instructions/ashigaru.md
grep -n "^## Role\|^## Language\|^## QC" instructions/gunshi.md
```
