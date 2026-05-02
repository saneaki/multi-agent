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
| F006a / F006b | instructions/common/forbidden_actions.md, instructions/common/shogun_mandatory.md, CLAUDE.md | F006a=generated file 直編集禁止 / F006b=Stall Response などの運用禁止 | passive | high |
| F007 | instructions/common/forbidden_actions.md, instructions/shogun.md | 未検証報告/無承認 push 等の品質・運用違反防止 | passive | critical |
| SO-16 | instructions/common/shogun_mandatory.md | 将軍の成果物直作成禁止（委譲必須） | passive | high |
| SO-17 | instructions/common/shogun_mandatory.md | north_star 3点検証 | passive | high |
| SO-18 | instructions/common/shogun_mandatory.md | bug fix は GitHub Issue 追跡必須 | passive | high |
| SO-19 | instructions/common/shogun_mandatory.md | 完了時 Action Required 清掃必須 | active | medium |
| SO-24 | instructions/common/shogun_mandatory.md | 報告前の inbox/artifact/content 三点検証 (Verification Before Report) | passive | critical |
| SO-01 | instructions/ashigaru.md, queue/shogun_to_karo.yaml | report YAML 必須フィールド厳守 | passive | high |
| SO-03 | queue/shogun_to_karo.yaml | report timestamp 形式厳守 (JST) | passive | high |
| SO-23 | queue/shogun_to_karo.yaml, instructions/gunshi.md | 業務成果 cross-check | active | high |
| L012 | instructions/karo.md | モデル多様化・Codex活用の自己監査 | passive | medium |
| RACE-001 | AGENTS.md, instructions/codex-ashigaru.md | 同一ファイル同時編集禁止 | active | high |
| D001-D008 | instructions/common/destructive_safety.md, AGENTS.md | 破壊的操作の絶対禁止群 | active | critical |

確認済みルール群合計: 18カテゴリ（F001-F007, SO群主要, L012, RACE-001, D001-D008）

### Rule Inventory 詳細版 (ash3 補足)
subtask_566a (ash3) 調査により、完全 Rule Inventory は **54 Rule IDs / 62 definitions** と判明。
内訳: F001-F007 (7) / SO-01〜SO-23 (23) / L001-L015 (15) / RACE-001 (1) / D001-D008 (8)。
詳細は `queue/reports/ashigaru3_report.yaml` を参照。本稿の 18カテゴリは運用上主要なサブセット。

### Rule-source 不整合 (ash3 発見)
単一 source of truth 不在に起因する重複/齟齬 2件が確認された。**Knowledge Distribution Gap (事例15) の具体例**である。

| 不整合 ID | 対象 Rule | 内容 | 影響 | 是正方針 |
|---|---|---|---|---|
| 不整合-1 | **F006 重複意義** | 旧 F006 は「generated file 直編集禁止」と「Stall Response」を同一IDで併用していた | 違反検知時に判定軸が不定、QC で誤認定リスク | **cmd_571で解消済**: F006a (generated file) / F006b (stall response) に分割 |
| 不整合-2 | **SO-20 重複定義** (cmd_572 解消済) | 1箇所は「editable_files 完全性 check」、別箇所は「Verification Before Report (inbox/artifact/content 三点照合)」 | SO-20 違反と言われても何が違反か決定不能、qc_auto_check も両対応必要 | **Option 2 採用**: SO-20 = editable_files 完全性 (維持) / SO-24 (新設) = Verification Before Report (三点照合) |

これら不整合自体が「明文化されているが統治が弱い」構造を示し、**根本解決策 案C (四半期 rule-source 棚卸し)** の必要性を補強する。

## Violation 事例 (15件以上)
| No. | Rule ID / Type | cmd/event | 実際の挙動 | 影響 | 是正方法 | frequency |
|---|---|---|---|---|---|---|
| 1 | CMD-YAML-STATUS | cmd_486 | `- cmd_id: cmd_486` 形式で `status` 欠落 | stall 検知不能・追跡困難 | 発令前 schema validator | 2-4回 |
| 2 | F007 (unverified_report) | dashboard action-1 | `clasp push完了(7ファイル)` 記載が先行 | 殿判断を誤誘導 | 実行ログ照合後のみ反映 | 2-4回 |
| 3 | operational pattern gap | dashboard 🔄進行中 | 発令直後更新運用が欠け、後続cmdで修正案件化 | 戦況可視性低下 | dispatch時自動更新 hook | 5回以上 |
| 4 | documentation gap | gas-mail-manager repo path | active `/home/ubuntu/gas-mail-manager` と `projects/...` archive 区別が運用混乱 | 誤作業/誤読リスク | active repo を single source 明記 | 2-4回 |
| 5 | SO-01 | sug_cmd_486_003 | report schema 違反 9連続目が記録 | QCノイズ増・手戻り | pre-report schema check | 5回以上 |
| 6 | SO-03 | cmd_528 incident_history | timestamp形式違反が反復 | 時系列監査崩壊 | `jst_now.sh --yaml` 強制 | 5回以上 |
| 7 | F007 / report品質 | cmd_564 notes | dashboard 記述と実状態に相違（未反映なのに成功文言） | 事実誤認 | artifact照合手順(SO-24)必須化 | 2-4回 |
| 8 | schema strictness gap | queue/shogun_to_karo.yaml | YAML構文ゆらぎで `yaml.safe_load` が失敗 | 自動監査不能 | schema lint CI導入 | 2-4回 |
| 9 | command-scope逸脱 | cmd_564 scope creep | cmd_486除外指示対象の変更が混入 | 仕様逸脱の常態化 | scope boundary validator | 2-4回 |
| 10 | completion-state品質 | cmd_486 chain | status未設定のまま後続cmdまで遅延 | 復旧まで長期化 | status必須 gate | 2-4回 |
| 11 | L012運用逸脱 | cmd_468 phase1 | Sonnet偏重配備で Codex/Opus が長時間 idle | 並列効率悪化 | dispatch前 L012 監査 | 2-4回 |
| 12 | naming rule運用逸脱 | cmd_549 trace (ash1 report) | 成果物命名規則違反が上流で混入 | AR/QC手戻り | 発令文の命名テンプレ固定 | 2-4回 |
| 13 | SO-24不足 | 将軍事前観察 (cmd_566 notes) | 伝聞反映で三点照合不足が疑われる | 誤報連鎖 | inbox/artifact/content の機械照合 | 2-4回 |
| 14 | dashboard運用整合 | action-1/action-2 | 完了移動条件と表示文言が乖離しやすい | 進捗誤読 | 状態遷移の自動生成化 | 2-4回 |
| 15 | rule-source分散 | instructions/AGENTS/.claude | 同義ルールが多箇所に分散し更新差分が生まれる | 解釈ブレ | ルールカタログ集約 | 5回以上 |
| 16 | manual process dependence | clasp運用 | 認証期限切れ時の手順が明文化前は属人対応 | 再発時停止 | fallback skill + runbook固定 | 2-4回 |
| 17 | F007 / report品質 / L014再発 | cmd_632 ash6/7 GPT-5.5切替誤報 (2026-05-02) | 家老が settings.yaml 更新のみで「GPT-5.5 切替完了」と完遂報告。実 tmux pane は依然 gpt-5.3-codex のまま。将軍 tmux 直視で発覚 | 殿への誤情報、運用判断ミス誘発リスク | cmd_634 AC8.1 で完遂報告に tmux capture-pane 必須化。Layer 5 報告品質検証で機械検出 | 1回 (新規パターン) |
| 18 | dashboard運用 / SO-19違反 | dashboard.md 22h鮮度崩壊 (2026-05-02) | 家老一次責任で MD 再生成漏れ。5/1 17:44 → 5/2 16:30 の間に cmd_628/629/631/632 完遂が反映されず | 戦況把握不能、殿の判断材料欠落、誤報リスク | 案A: dashboard 即時是正 / 案B: cmd_634 AC9 で MD 鮮度自動検証組込 / 案C: 将軍 L020 自律規律 (会話ターン毎確認) | 1回 (新規構造問題) |
| 19 | Action Required規律違反 / F007派生 | 殿令1 ash6/7 切替手作業依頼 (2026-05-02) | 家老が inbox 通知のみで完了扱い、dashboard.yaml.action_required への追加を怠った。殿は inbox を能動確認しないと見えない | 殿が手作業要件を見落とす、cmd 進行停滞 | 案B (cmd_634 AC9.2) + 案C (L020) で二重防護。Action Required は MUST dashboard 記載 | 1回 (規律明文化されているが実施漏れ) |
| 20 | architecture違反 / self-contained原則 | cmd_631 daily-notion-sync.yml curl依存 (2026-05-02) | obsidian repo の workflow が shogun repo の script を `curl raw.githubusercontent.com/saneaki/multi-agent` で外部取得。仕様書 §5.2「shogun リポジトリには配置しない」原則違反 | 多 repo 依存で運用脆弱化、self-contained 性喪失 | cmd_632 Scope H で是正 (script を obsidian repo に複製 + ローカル参照化) / skill 化候補: shogun-multi-repo-script-vendor-pattern | 1回 (新規パターン) |
| 21 | end-to-end検証ギャップ / verifier側違反 | cmd_631 implementation-verifier 4-Layer (2026-05-02) | unit ごと PASS で完結し、end-to-end pipeline 稼働を確認せず。GHA test run の md_exists=false graceful skip を見逃し、cron 未登録 + git未init の shelf-ware を検出失敗 | end-to-end ギャップ放置、運用稼働 NG なまま完遂判定 | cmd_634 で Layer 5 (報告品質検証) + 4段確認 (commit/配置/登録/実ログ) を組込み verifier 側を強化 | 2回目 (cmd_586 cron未登録と同型) |

### AC3 必須5事例の明示
- (a) `cmd_486 status field 欠落`: `queue/shogun_to_karo.yaml` の `cmd_486` ブロック（`cmd_id` 形式、status 欠落）
- (b) dashboard 誤記: `dashboard.md` action-1 の `clasp push完了(7ファイル)`
- (c) dashboard 進行中運用不在: `cmd_514` 等で「進行中更新漏れ修正」がcmd化されている履歴
- (d) repo documentation gap: `cmd_564 notes` に active/archive の二重管理明記
- (e) SO-01/SO-03 9連続違反: `cmd_528 incident_history` に `sug_cmd_486_003` 記録

## 分類 (violation type × severity × frequency)

### type 別件数 (No.1-21 集計)
| violation type | 件数 |
|---|---:|
| schema field / schema strictness | 5 |
| operational pattern gap | 4 |
| documentation gap | 2 |
| unverified / reporting quality | 5 (No.17/19 追加) |
| rule-source governance | 2 |
| architecture / self-contained 原則違反 | 1 (No.20 追加) |
| end-to-end verification gap | 1 (No.21 追加) |
| dashboard 運用規律違反 | 1 (No.18 追加) |

### severity 別件数 (No.1-21 集計)
| severity | 件数 |
|---|---:|
| critical | 6 (No.18 追加) |
| high | 9 (No.17/19/20/21 追加) |
| medium | 4 |
| low | 2 |

### frequency 別件数 (No.1-21 集計)
| frequency | 件数 |
|---|---:|
| 1回 (新規) | 4 (No.17/18/19/20) |
| 2回目以上 (反復) | 1 (No.21 = cmd_586 同型) |
| 2-4回 | 11 |
| 5回以上 | 5 |

## 分類 (深化版) — gunshi Opus深考 (subtask_566e)

### 軸定義
| 軸 | 値域 | 目的 |
|---|---|---|
| violation_type | schema_omission / unverified_report / process_bypass / doc_drift / systemic_recurrence / scope_creep / single_point_of_failure | 違反の形態を分類 |
| severity | critical / high / medium / low | 影響の重さ |
| frequency | isolated (1回) / recurring (2-4回) / systemic (5回以上) | 再発性 |
| root_cause_category | Enforcement Gap / State Visibility Gap / Verification Protocol Gap / Scope Definition Gap / Knowledge Distribution Gap / Single Point of Failure / Regression Feedback Gap | 深層原因 |

### 16事例マッピング

| No. | violation_type | severity | frequency | root_cause_category | Rule源 |
|---:|---|---|---|---|---|
| 1 | schema_omission | high | recurring | Enforcement Gap | SO-01 / cmd_YAML形式 |
| 2 | unverified_report | critical | recurring | Verification Protocol Gap | F007 / SO-24 |
| 3 | process_bypass | high | systemic | State Visibility Gap | dashboard運用 |
| 4 | doc_drift | medium | recurring | Single Point of Failure | active/archive 2重管理 |
| 5 | schema_omission | high | systemic | Regression Feedback Gap | SO-01 |
| 6 | schema_omission | high | systemic | Enforcement Gap | SO-03 |
| 7 | unverified_report | high | recurring | Verification Protocol Gap | F007 / SO-24 |
| 8 | schema_omission | high | recurring | Enforcement Gap | YAML lint不在 |
| 9 | scope_creep | medium | recurring | Scope Definition Gap | cmd boundary不明確 |
| 10 | schema_omission | critical | recurring | State Visibility Gap | status gate不在 |
| 11 | process_bypass | medium | recurring | Regression Feedback Gap | L012 |
| 12 | process_bypass | medium | recurring | Enforcement Gap | 命名規則 |
| 13 | unverified_report | critical | recurring | Verification Protocol Gap | SO-24 |
| 14 | doc_drift | medium | recurring | State Visibility Gap | dashboard状態遷移 |
| 15 | systemic_recurrence | high | systemic | Knowledge Distribution Gap | rule-source分散 |
| 16 | single_point_of_failure | high | recurring | Single Point of Failure | clasp手順属人化 |

### root_cause_category 別集計 (本調査の構造ギャップ核心)

| root_cause_category | 件数 | 説明 | 対応軸 |
|---|---:|---|---|
| **Enforcement Gap** | 5 | ルールは.md明文だが自動施行機構不在、人間注意力依存 | 案A (validator/hook) |
| **Verification Protocol Gap** | 3 | SO-24三点照合の実行漏れ、pre-report self-check未体系化 | 案B (dispatch/QC gate) |
| **State Visibility Gap** | 3 | 違反/進捗の観測・記録機構が弱い、手動運用依存 | 案A (state machine) |
| **Regression Feedback Gap** | 2 | 同違反9連続等、反復学習構造未整備 | 案C (retrospective) |
| **Scope Definition Gap** | 1 | cmd発令時 scope境界曖昧、scope creep常態化 | 案B (scope lint) |
| **Knowledge Distribution Gap** | 1 | 同義ルール分散、単一 source of truth 不在 | 案C (rule集約) |
| **Single Point of Failure** | 2 | 属人手順、fallback skill整備後追い | 案C (skill整備) |

### 殿の問題提起への直接回答: 「md明文化 ≠ 遵守」の構造的本質

**命題**: 遵守は「明文化 (documentation)」のみでは成立しない。以下 3 mechanism の同時成立が必要。

| 機構 | 役割 | 現状 | Violation 16事例での欠如割合 |
|---|---|---|---:|
| **Enforcement** (施行) | 違反を事前/自動で阻止する強制機構 | 人間注意力依存 (validator 0件) | 8/16 (50%) |
| **Observation** (観測) | 違反発生を即座に検知・記録する機構 | 手動運用中心 (state machine 不在) | 3/16 (19%) |
| **Learning** (学習) | 反復パターンを特定し構造対策する機構 | ad-hoc cmd対応 (trend分析不在) | 5/16 (31%) |

→ 明文化 (instructions/*.md) は「必要条件」。施行+観測+学習の 3 機構が「十分条件」。
  16事例は 3 機構の同時成立欠如で発生しており、どれか 1 機構でも整備されれば予防可能。

## 根本解決策 — 3案提示

### 案A: 自動 Enforcement (CI / hook / validator)

**内容**:
- `shogun_to_karo.yaml` / `report_*.yaml` に jsonschema 定義、pre-commit hook で機械検証
- PostToolUse hook で report YAML 必須フィールド (worker_id/task_id/status/timestamp/result) を自動 check
- `qc_auto_check.sh` 拡張: naming / scope / SO-24 三点照合 を自動化
- Dashboard state machine: 🔄進行中 / 🚨action / ✅戦果 の状態遷移を auto-generate (karo手動更新削減)

**評価**:
| 項目 | 評価 |
|---|---|
| feasibility | **high** (既存 `qc_auto_check.sh` / hook 基盤を拡張) |
| cost | medium (初期 1-2w、維持は自動) |
| effectiveness | **high** (schema系 / state系違反の 80% 削減予測) |
| timeline | 2w (Phase 1) + 3-4w (Phase 2) |
| 適用 root_cause | Enforcement Gap (5) + State Visibility Gap (3) = 8/16 (50%) |

**カバー事例**: No. 1, 3, 5, 6, 8, 10, 12, 14

**リスク**:
- validator が厳しすぎると karo/ash の dispatch 速度低下
- schema 変更時の migration 負荷
- false positive で運用停滞の可能性 (緩和: dry-run 期間を設ける)

### 案B: Dispatch Gate (karo mandatory QC / pre-report checklist)

**内容**:
- `instructions/karo.md` に cmd 分解時 mandatory checklist 追補:
  cmd_id / status / scope / out-of-scope / editable_files / deadline / reporters 必須
- `instructions/gunshi.md` の QC autonomous protocol に:
  SO-24 三点照合 (inbox/artifact/content) を step 8 前の gate に昇格
- cmd 発令文に `scope` / `out_of_scope` セクション必須化 (scope creep 予防)
- ashigaru report schema に pre-report self-check (worker自ら 5項目確認) を義務化

**評価**:
| 項目 | 評価 |
|---|---|
| feasibility | **high** (.md 追補のみ、既存基盤活用) |
| cost | **low** (0.5-1w) |
| effectiveness | medium-high (Verification Protocol Gap 完封) |
| timeline | 1w (Phase 1 完結) |
| 適用 root_cause | Verification Protocol Gap (3) + Scope Definition Gap (1) = 4/16 (25%) |

**カバー事例**: No. 2, 7, 9, 13

**リスク**:
- checklist の形骸化 (対策: 月次 retrospective で運用実態を gunshi が観察)
- instructions 肥大化で読込 token 増大 (対策: 共通ルールは common/*.md に集約)

### 案C: Retrospective 文化化 (violation log + learning loop)

**内容**:
- `memory/Violation.md` を生きた台帳として維持: gunshi が cmd 完了毎に違反事例を追記 (QC step 9.5 拡張)
- 類似違反 3回で自動 alarm → karo が構造対策案を検討・提案
- 月次 retrospective (violation trend分析 → 構造対策案) を仕組み化
- 四半期 rule-source 棚卸し (instructions/AGENTS/.claude 分散統合)
- skill 候補は `memory/skill_history.md` で battle-tested 回数追跡 → 3回で本登録昇格

**評価**:
| 項目 | 評価 |
|---|---|
| feasibility | medium-high (現存の gunshi QC + `queue/suggestions.yaml` 基盤上) |
| cost | low-medium (運用継続コスト、月次 0.5d / 四半期 1d) |
| effectiveness | medium (短期 impact 小、長期 learning effect 大) |
| timeline | 即時開始可、半年で顕在化 |
| 適用 root_cause | Regression Feedback Gap (2) + Knowledge Distribution Gap (1) + Single Point of Failure (2) = 5/16 (31%) |

**カバー事例**: No. 4, 11, 15, 16 (+ 構造観測として他事例の予防寄与)

**リスク**:
- Violation.md 肥大化で参照コスト増 (対策: 四半期で archive)
- retrospective 疎遠化 (対策: 月次 cron で karo に reminder)

### 案比較マトリクス

| 指標 | 案A (Enforcement) | 案B (Dispatch Gate) | 案C (Retrospective) |
|---|---|---|---|
| カバー事例 | 8/16 (50%) | 4/16 (25%) | 5/16 (31%) |
| 初期工数 | 2w | 1w | 即時 |
| 運用工数 | 自動 | 低 | 月次 0.5d |
| 予防型/事後型 | 予防型 | 予防型 | 事後型 |
| 対応 mechanism | Enforcement + Observation | Enforcement + Observation | Learning |
| 単独採用時 残余 | Verification/Learning gap | Schema/State gap | Schema/State/Verification gap |

→ **単独では不十分**。案A+B の前後二段施行 + 案C の学習ループが相互補完。

## Recommendation

### 最優先: 案A + 案B の ハイブリッド (案C 並行)

**採用根拠**:
- 案A 単独では Verification Protocol Gap (3件) が残る
- 案B 単独では schema_omission の反復 (5件) を断てない
- 案A+B で 12/16 (75%) を 4w 以内に機械的予防可能
- 案C は低コストで即時並行、Regression Feedback Gap を補完
- 3案ハイブリッドで 14-15/16 (88-94%) カバー予測

### 実装ロードマップ

#### Phase 1 — Quick Wins (1-2w)
| ID | 案 | 内容 | 工数 | 対象違反 |
|---|---|---|---|---|
| P1.1 | 案B | karo.md に cmd 発令時 mandatory checklist 追補 (cmd_id/status/scope/editable_files/reporters) | 0.3w | No. 9, 10 |
| P1.2 | 案A | `shogun_to_karo.yaml` jsonschema 定義 + pre-commit validator | 0.5w | No. 1, 10 |
| P1.3 | 案A | report YAML schema validator (PostToolUse hook) | 0.5w | No. 5, 6, 8 |
| P1.4 | 案B | gunshi QC に SO-24 三点照合 (inbox/artifact/content) 自動化 | 0.3w | No. 2, 7, 13 |

**Phase 1 完了時**: 7-8件 / 16件 (44-50%) を機械的予防

#### Phase 2 — Structural Fixes (3-4w)
| ID | 案 | 内容 | 工数 | 対象違反 |
|---|---|---|---|---|
| P2.1 | 案A | dashboard 状態機械化 (🔄進行中 / 🚨 / ✅ の auto-transition) | 1w | No. 3, 14 |
| P2.2 | 案A | `qc_auto_check.sh` 拡張: naming / scope / SO-21 強化 | 1w | No. 12 |
| P2.3 | 案B | cmd 発令文 scope boundary validator (pre-commit lint) | 0.5w | No. 9 |
| P2.4 | 案C | `memory/Violation.md` 維持機構 (gunshi QC step 9.5 拡張) | 0.3w | No. 4, 16 |

**Phase 2 完了時**: 12-13件 / 16件 (75-81%) を予防

#### Phase 3 — Long-term Learning (2-3 month)
| ID | 案 | 内容 | 工数 | 対象違反 |
|---|---|---|---|---|
| P3.1 | 案C | 月次 retrospective (violation trend 分析) 仕組み化 | 0.5d/月 | No. 11 |
| P3.2 | 案C | 四半期 rule-source 棚卸し (instructions/AGENTS/.claude 集約) | 1d/Q | No. 15 |
| P3.3 | 案A | AI-assisted violation detection (違反予兆で gunshi auto-trigger) | 2w | 全般予防寄与 |

**Phase 3 完了時**: 14-15件 / 16件 (88-94%) を予防

### Quick Wins vs Structural Fixes 区分

| 区分 | 該当項目 | 特徴 |
|---|---|---|
| **Quick Wins** | P1.1 / P1.2 / P1.3 / P1.4 | 既存基盤上で 1-2w で成果。ROI 高 |
| **Structural Fixes** | P2.1 / P2.2 / P2.3 | 状態機械化・schema 統治で基盤強化 |
| **Cultural / Long-term** | P2.4 / P3.1 / P3.2 / P3.3 | Learning loop 構築で根本治癒 |

### Expected Impact (定量予測)

| Phase | 時期 | 予防率 | 残余リスク |
|---|---|---:|---|
| 現状 | — | 0% | 16事例全件 |
| Phase 1 完了 | 1-2w 後 | 44-50% | Verification 一部 / 属人手順 |
| Phase 2 完了 | 4-6w 後 | 75-81% | Regression / Knowledge 分散 |
| Phase 3 完了 | 2-3ヶ月後 | 88-94% | doc_drift (No.4) / 新規パターン |

### 残余リスク (予防困難枠)

- **No. 4 (repo path confusion)**: 文化的合意必須、自動化で完封不能 → README / CLAUDE.md 明示 + 月次確認
- **No. 16 (clasp 属人 fallback)**: skill 整備で緩和済 (cmd_565 で SKILL.md 作成)、但し他属人手順の継続発生は残る → skill_history.md で battle-tested 回数追跡

### 運用責任 RACI (提案)

| 活動 | R (実行) | A (承認) | C (相談) | I (通知) |
|---|---|---|---|---|
| validator 実装 (Phase 1/2) | ashigaru | karo | gunshi | shogun |
| schema 更新 | karo | shogun | gunshi | ashigaru |
| Violation.md 維持 | gunshi | karo | — | shogun |
| 月次 retrospective | gunshi | karo | shogun | ashigaru |
| 四半期 rule棚卸し | gunshi + karo | shogun | ashigaru | — |

## 2026-05-02 追記: cmd_631/cmd_632 incident cluster

### 経緯
2026-05-02 (cmd_631 完遂後 / cmd_632 進行中) に 5 件の violation (No.17-21) が連続発生・発覚した。
将軍 (拙者) の reality check と implementation-verifier 強化版 (Layer 5) で検出。

### 構造的位置づけ
| violation | root_cause_category | 既存対策案カバー | 新規対策 |
|---|---|---|---|
| No.17 (ash6/7切替誤報) | Verification Protocol Gap | 案B 部分対応 | cmd_634 AC8.1 (Layer 5: tmux capture-pane 必須) |
| No.18 (dashboard 22h鮮度) | State Visibility Gap | 案A 部分対応 | cmd_634 AC9 (鮮度自動検証) + L020 将軍規律 |
| No.19 (Action Required漏れ) | Enforcement Gap | 案B 部分対応 | cmd_634 AC9.2 (action_required 記載確認) |
| No.20 (curl 外部依存) | Single Point of Failure | 案C 部分対応 | shogun-multi-repo-script-vendor-pattern skill |
| No.21 (verifier ギャップ) | Verification Protocol Gap | 案A 部分対応 | cmd_634 4段確認 (commit/配置/登録/実ログ) |

### 教訓: L014 教訓の構造化
L014 (家老申告を鵜呑み禁止) は 2026-04-17 に明文化されたが、cmd_632 で再発。
**規律明文化単独では予防不能** という命題 (本稿 §「殿の問題提起への直接回答」) が再証明された。
構造的予防は cmd_634 verifier 強化 (Layer 5 報告品質検証) に集約される。

### 新規 root_cause_category 候補 (検討中)
- **Verifier Coverage Gap**: 検証側 (verifier 自身) が end-to-end pipeline を確認しない構造的欠陥
  → No.21 (cmd_631) で初観測。cmd_634 で予防対策実装中。

### No.22 | 「0cmd完了」誤報連鎖 (cmd_635 incident)

| 項目 | 内容 |
|---|---|
| 発生 | 2026-04-27 〜 2026-05-02 (6日間) |
| 影響 | Notion Activity Log DB に `0cmd完了` 誤報が 6件生成された |
| 根因 | `scripts/archived/notion_session_log.sh` の `COMPLETED=$(grep -oP '今日の完了 \| \K[0-9]+' dashboard.md)` が dashboard.md の stale/不整合な統計値 `0` を採用し、同時に本日の戦果テーブルからは実完了行を抽出していたため、title/完了cmd数だけが `0cmd完了` になった |
| 連鎖 | dashboard.md 22h 鮮度崩壊 (No.18) → `今日の完了` 0件 → Notion Activity Log DB へ `0cmd完了` 誤報 → 6日間継続 |
| 発覚 | cmd_635 Scope C retrospective で Notion Activity Log DB 過去7日を実照合 |
| 対策 | cmd_631/632/635 で session→Obsidian→Notion パイプライン刷新。旧 `notion_session_log.sh` は cmd_631 で archive 済み。今後の再発防止は L020 Dashboard Freshness Check (`instructions/shogun.md`) と cmd_634 verifier 強化で担保 |
| Violated | SO-17 North Star alignment (Reality Check 失敗) |
| Cleanup 提案 | 2026-04-27〜2026-05-02 の該当 6ページは削除ではなく修正推奨。詳細・要約には実完了行が残っているため、title と `完了cmd数` を dashboard/Obsidian 由来の正値へ補正する。2026-05-02 の空 detail ページのみ削除候補 |

## 注記
本稿は gunshi (subtask_566e) による分類深化 + 根本解決策3案 + Recommendation 完成版。
2026-05-02 追記分は 将軍 (shogun) が Lord 直命により実施。RACI 上は gunshi 維持責任ゆえ、次回 gunshi QC で本追記の構造整合性を検証されたし。
566a(ash3) / 566b(ash4) の調査継続中の追加知見があれば追補する。

## 調査データソース
- `queue/shogun_to_karo.yaml`
- `queue/reports/*.yaml`
- `memory/global_context.md`
- `dashboard.md`
- `instructions/**/*.md`, `AGENTS.md`, `/home/ubuntu/.claude/rules/common/*.md`
