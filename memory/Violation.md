# .md ルール遵守違反の体系調査

## 背景
cmd_486/cmd_564/cmd_565 の運用連鎖で、ルール明文化と実運用の乖離が継続観測された。
本稿は cmd_566 の draft として、Rule Inventory と Violation 事例を先行整理する。

## Rule Inventory

### 対象
- `instructions/*.md`
- `instructions/common/*.md`
- `/home/ubuntu/.claude/rules/common/*.md`
- `AGENTS.md`

### 棚卸 (主要ルール群)
| Rule ID | 出典 .md | 内容要旨 | 型 | severity |
|---|---|---|---|---|
| F001 | instructions/shogun.md, instructions/karo.md, instructions/ashigaru.md | 役割逸脱禁止（将軍直実行/家老の実装作業など） | passive | critical |
| F002 | 同上 | 指揮系統 bypass 禁止（人間直連絡/将軍直報告など） | passive | critical |
| F003 | 同上 | 権限外実行禁止（割当外作業/管理越権） | passive | high |
| F004 | AGENTS.md, instructions/common/forbidden_actions.md | polling/wait loop 禁止 | passive | high |
| F005 | AGENTS.md, instructions/common/forbidden_actions.md | context 読込 skip 禁止 | passive | critical |
| F006 | instructions/karo.md, instructions/common/forbidden_actions.md | generated file 直編集などの禁止 | passive | high |
| F007 | instructions/common/forbidden_actions.md, instructions/shogun.md | 未検証報告/無承認 push 等の品質・運用違反防止 | passive | critical |
| SO-16 | instructions/common/shogun_mandatory.md | 将軍の成果物直作成禁止（委譲必須） | passive | high |
| SO-17 | instructions/common/shogun_mandatory.md | north_star 3点検証 | passive | high |
| SO-18 | instructions/common/shogun_mandatory.md | bug fix は GitHub Issue 追跡必須 | passive | high |
| SO-19 | instructions/common/shogun_mandatory.md | 完了時 Action Required 清掃必須 | active | medium |
| SO-20 | instructions/common/shogun_mandatory.md | 報告前の inbox/artifact/content 三点検証 | passive | critical |
| SO-01 | instructions/ashigaru.md, queue/shogun_to_karo.yaml | report YAML 必須フィールド厳守 | passive | high |
| SO-03 | queue/shogun_to_karo.yaml | report timestamp 形式厳守 (JST) | passive | high |
| SO-23 | queue/shogun_to_karo.yaml, instructions/gunshi.md | 業務成果 cross-check | active | high |
| L012 | instructions/karo.md | モデル多様化・Codex活用の自己監査 | passive | medium |
| RACE-001 | AGENTS.md, instructions/codex-ashigaru.md | 同一ファイル同時編集禁止 | active | high |
| D001-D008 | instructions/common/destructive_safety.md, AGENTS.md | 破壊的操作の絶対禁止群 | active | critical |

確認済みルール群合計: 18カテゴリ（F001-F007, SO群主要, L012, RACE-001, D001-D008）

## Violation 事例 (15件以上)
| No. | Rule ID / Type | cmd/event | 実際の挙動 | 影響 | 是正方法 | frequency |
|---|---|---|---|---|---|---|
| 1 | CMD-YAML-STATUS | cmd_486 | `- cmd_id: cmd_486` 形式で `status` 欠落 | stall 検知不能・追跡困難 | 発令前 schema validator | 2-4回 |
| 2 | F007 (unverified_report) | dashboard action-1 | `clasp push完了(7ファイル)` 記載が先行 | 殿判断を誤誘導 | 実行ログ照合後のみ反映 | 2-4回 |
| 3 | operational pattern gap | dashboard 🔄進行中 | 発令直後更新運用が欠け、後続cmdで修正案件化 | 戦況可視性低下 | dispatch時自動更新 hook | 5回以上 |
| 4 | documentation gap | gas-mail-manager repo path | active `/home/ubuntu/gas-mail-manager` と `projects/...` archive 区別が運用混乱 | 誤作業/誤読リスク | active repo を single source 明記 | 2-4回 |
| 5 | SO-01 | sug_cmd_486_003 | report schema 違反 9連続目が記録 | QCノイズ増・手戻り | pre-report schema check | 5回以上 |
| 6 | SO-03 | cmd_528 incident_history | timestamp形式違反が反復 | 時系列監査崩壊 | `jst_now.sh --yaml` 強制 | 5回以上 |
| 7 | F007 / report品質 | cmd_564 notes | dashboard 記述と実状態に相違（未反映なのに成功文言） | 事実誤認 | artifact照合手順(SO-20)必須化 | 2-4回 |
| 8 | schema strictness gap | queue/shogun_to_karo.yaml | YAML構文ゆらぎで `yaml.safe_load` が失敗 | 自動監査不能 | schema lint CI導入 | 2-4回 |
| 9 | command-scope逸脱 | cmd_564 scope creep | cmd_486除外指示対象の変更が混入 | 仕様逸脱の常態化 | scope boundary validator | 2-4回 |
| 10 | completion-state品質 | cmd_486 chain | status未設定のまま後続cmdまで遅延 | 復旧まで長期化 | status必須 gate | 2-4回 |
| 11 | L012運用逸脱 | cmd_468 phase1 | Sonnet偏重配備で Codex/Opus が長時間 idle | 並列効率悪化 | dispatch前 L012 監査 | 2-4回 |
| 12 | naming rule運用逸脱 | cmd_549 trace (ash1 report) | 成果物命名規則違反が上流で混入 | AR/QC手戻り | 発令文の命名テンプレ固定 | 2-4回 |
| 13 | SO-20不足 | 将軍事前観察 (cmd_566 notes) | 伝聞反映で三点照合不足が疑われる | 誤報連鎖 | inbox/artifact/content の機械照合 | 2-4回 |
| 14 | dashboard運用整合 | action-1/action-2 | 完了移動条件と表示文言が乖離しやすい | 進捗誤読 | 状態遷移の自動生成化 | 2-4回 |
| 15 | rule-source分散 | instructions/AGENTS/.claude | 同義ルールが多箇所に分散し更新差分が生まれる | 解釈ブレ | ルールカタログ集約 | 5回以上 |
| 16 | manual process dependence | clasp運用 | 認証期限切れ時の手順が明文化前は属人対応 | 再発時停止 | fallback skill + runbook固定 | 2-4回 |

### AC3 必須5事例の明示
- (a) `cmd_486 status field 欠落`: `queue/shogun_to_karo.yaml` の `cmd_486` ブロック（`cmd_id` 形式、status 欠落）
- (b) dashboard 誤記: `dashboard.md` action-1 の `clasp push完了(7ファイル)`
- (c) dashboard 進行中運用不在: `cmd_514` 等で「進行中更新漏れ修正」がcmd化されている履歴
- (d) repo documentation gap: `cmd_564 notes` に active/archive の二重管理明記
- (e) SO-01/SO-03 9連続違反: `cmd_528 incident_history` に `sug_cmd_486_003` 記録

## 分類 (violation type × severity × frequency)

### type 別件数
| violation type | 件数 |
|---|---:|
| schema field / schema strictness | 5 |
| operational pattern gap | 4 |
| documentation gap | 2 |
| unverified / reporting quality | 3 |
| rule-source governance | 2 |

### severity 別件数
| severity | 件数 |
|---|---:|
| critical | 5 |
| high | 7 |
| medium | 4 |

### frequency 別件数
| frequency | 件数 |
|---|---:|
| 1回 | 0 |
| 2-4回 | 11 |
| 5回以上 | 5 |

## 注記
本稿は draft。根本解決策・最終 recommendation・QC 統合は gunshi (subtask_566e) 追記対象。

## 調査データソース
- `queue/shogun_to_karo.yaml`
- `queue/reports/*.yaml`
- `memory/global_context.md`
- `dashboard.md`
