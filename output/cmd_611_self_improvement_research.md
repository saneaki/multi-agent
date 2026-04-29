# cmd_611 Scope A — shogun multi-agent 全体自己改善ループ調査 (Opus 全体俯瞰 arm)

**作成**: ashigaru5 (Opus 4.7) | **日付**: 2026-04-30 JST | **task**: subtask_611_scope_a_opus
**並列 arm**: ash6 (Codex) — 実装詳細 (`output/cmd_611_self_improvement_research_codex.md`)
**統合**: gunshi (Scope C) で本書 + Codex arm を統合し殿提示

---

## 0. 本書の位置付け (Scope 分担)

| Scope | 担当 | 焦点 |
|-------|------|------|
| **A (本書)** | ash5 Opus | **戦略・全体俯瞰** — 全 agent 視点 vector + 既存資産接続 + 採択候補 cmd 群 |
| B | ash6 Codex | 実装詳細 — jsonl mining script / hook delta generator / 工数見積 |
| C | gunshi | 統合 QC (殿提示) |
| D | (未配備) | 採択 cmd の commit 担当 |

殿のご指摘 (2026-04-29):「拙者案は shogun 自身の改善に偏り、karo/ashigaru/gunshi を含めた**全体の改善視点が足りない**」を本書の北極星 (north_star) とする。

---

## 1. 拙者骨子 4 Phase の継承と全 agent 拡張案 (AC1)

### 1.1 拙者 (shogun) 骨子 4 Phase の再評価

| Phase | 当初定義 | shogun 偏重の課題 | 全 agent 拡張版 |
|-------|----------|------------------|----------------|
| Phase 1: Pattern Extraction | 会話ログ/成果物から反復パターン抽出 | shogun jsonl のみ想定 | **全 agent jsonl + queue/reports + dashboard 履歴** を統合 mining |
| Phase 2: Hook Injection | 抽出パターンを hook/instruction に自動注入 | shogun の reality check 偏重 | **agent 別 instruction/hook delta** (shogun/karo/gunshi/ashigaru 各別) |
| Phase 3: Self-Tuning Loop | hook 効果計測→改善のフィードバック | shogun の reality check 回数のみ計測 | **多元 KPI** (silent failure 率 / cleanup 漏れ率 / blind spot 検出率 / role 別 cycle time) |
| Phase 4: Framework | 全 agent 適用可能な共通 framework 化 | 後付けの一般化 | **役職別 vector の和 + 組織学習層** の 2 段構造で最初から設計 |

### 1.2 全 agent 拡張版 4 Phase

```
Phase 1: 多元 Pattern Extraction
  ├── Source A: jsonl mining (zenn 流) — agent 別 + cross-agent
  ├── Source B: queue/reports + queue/inbox — 失敗の正規化された記録
  ├── Source C: dashboard.md 履歴 (git log) — 殿の reality check 跡
  └── Source D: gunshi blind spot ledger — QC 漏れの自己申告

Phase 2: 役職別 Hook/Instruction Delta
  ├── shogun: 発令前 evidence check / ntfy 信号交差確認
  ├── karo:  silent failure 防御 (parse 整合・format SoT)
  ├── gunshi: blind spot checklist 自動生成
  └── ashigaru: cleanup protocol 自動化 (inbox/task/snapshot 整合)

Phase 3: 組織レベル Self-Tuning (karpathy 流短サイクル)
  ├── 短サイクル: 1 cmd 単位 5-15 分の実験ループ
  ├── 客観 KPI: cmd 別 (success_rate / silent_failure / cycle_time / reality_check_count)
  └── keep/discard: KPI 改善時のみ採用、悪化時は自動 revert

Phase 4: 組織学習層 (Beyond Sum-of-Agents)
  ├── 共通 memory: global_context.md (現存) を agent-keyed に再構造化
  ├── 横断 catalog: 全 agent 共通の failure pattern catalog
  └── 知識伝播: 採択 instruction delta を全 agent broadcast (role 別 filter)
```

---

## 2. 各 agent 別 self-improvement vector (AC2)

殿のご指摘の核心。**役職ごとに固有の改善 vector が異なる** ことを認識せねば、共通 framework は機能しない。

### 2.1 shogun (orchestrator): 殿との認識ギャップ検知

| 観測事実 | 改善 vector | 既存資産との接続 |
|----------|-------------|----------------|
| 殿 reality check 7 度 / 日 (2026-04-29) | **発令前 evidence check hook** — cmd YAML AC 空欄 / north_star 欠落 / dispatch hint 欠落を機械検知 | L018 (context% primary source) / L019 (s-check) の延長 |
| 単一シグナル盲信 (dashboard.md / 通知 / 体感) | **多源交差検証義務化** — shogun 応答に `checked_sources` + `last_verified` 必須記載 | L019 既制定 (本件は遵守強化) |
| 計画→実装の hand-off 漏れ | **Plan→Karo 委譲 hook** — plan 完了時に「自己実装抑止」reminder inject | feedback_plan_then_delegate.md (auto-memory) |

**Self-improvement vector 定式**:
```
shogun_correction_rate(t+1) = f(evidence_check_pass_rate, source_diversity, plan_to_delegate_rate)
```

### 2.2 karo (manager): silent failure 反復構造の解消

| 観測事実 | 改善 vector | 既存資産との接続 |
|----------|-------------|----------------|
| cmd_604 誤判定 (HTTP 403 真因見落とし) | **dual-source verification** — dashboard 二次情報のみ参照を hook 警告 | cmd_603 (status_check_rules.py) 拡張済 |
| cmd_609 self_clear A4 parse bug + C5 silent fail | **format SoT 一元化** — karo_self_clear_check.sh と safe_window_judge.sh の出力 schema 統一 | issue #40 (karo 過負荷) と接続 |
| 過負荷 (タスク分解 + ルーティング + dashboard + 報告) | **責務分離** (issue #40 提案: 奉行 bugyo 新設) | issue #40 (CLOSED 提案) |
| dispatch_debt 累積 | **batch processing 強制** (cmd 単位 + cmd 横断の dispatch backlog 監視) | safe_window_judge.sh 拡張 |

**Self-improvement vector 定式**:
```
karo_silent_failure_rate(t+1) = f(format_SoT_unified, dispatch_debt, evidence_first_judgment)
```

### 2.3 gunshi (QC): partial 修復のみ blind spot

| 観測事実 | 改善 vector | 既存資産との接続 |
|----------|-------------|----------------|
| cmd_607 safe_window 列見落とし (partial 修復) | **blind spot checklist 自動生成** — cmd 種別 (test / research / refactor) 別 QC 観点 catalog | L017 dual-model rule の延長 |
| QC 受諾基準曖昧 (調査タスク受諾→キュー停滞) | **受諾前 capacity check** | L012 (足軽配分ルール) の gunshi 版 |
| north_star 3-point check の SO-17 形骸化 | **3-point check 機械検証** (task YAML field 直読) | SO-17 既制定 (本件は遵守強化) |

**Self-improvement vector 定式**:
```
gunshi_blind_spot_rate(t+1) = f(checklist_coverage, capacity_aware_acceptance, north_star_alignment_rate)
```

### 2.4 ashigaru (worker): subtask 完遂後の cleanup 漏れ

| 観測事実 | 改善 vector | 既存資産との接続 |
|----------|-------------|----------------|
| /clear 後の inbox 未処理エントリ残存 | **self_clear 前 cleanup integrity check** — inbox 既読化 + task status 整合 + snapshot task_id 一致を機械検証 | self_clear_check.sh 拡張 |
| RACE-001 衝突検知漏れ | **editable_files allowlist 厳守 hook** | RACE-001 既制定 |
| auto-compact cascading (tool count 1486 等) | **早期 self-clear protocol** (cmd_609 で扱った構造問題) | cmd_609 統合レポート参照 |

**Self-improvement vector 定式**:
```
ashigaru_cleanup_miss_rate(t+1) = f(self_clear_integrity_check, race001_compliance, early_clear_trigger)
```

### 2.5 役職共通の vector (cross-agent)

- **共通 jsonl mining**: 全 agent jsonl を統合 mining し、agent 横断の failure pattern を catalog 化
- **失敗事例の公開原則**: gunshi blind spot ledger を全 agent に閲覧可能化 (組織学習)
- **cmd 単位 KPI の標準化**: success_rate / silent_failure_count / cycle_time / reality_check_count を全 cmd 計測

---

## 3. 2 記事 (zenn / karpathy) 知見統合と適用案 (AC3)

### 3.1 記事 1 (zenn/hrmtz) の核心と shogun 適用

**核心**:
> "deployment-time における N=1 personalized alignment" — 会話ログを training signal と見なし、UserPromptSubmit hook で active reflex を形成する閉ループ

**shogun への適用**:

| zenn 概念 | shogun 移植 |
|----------|-------------|
| User correction phrase mining | **殿の reality check 発話 mining** — 「またか」「確認したか」「dashboard だけ見るな」等を pattern 化 |
| UserPromptSubmit hook で context inject | shogun では **inbox_write のメッセージ受信時 hook** で同等機能。karo/gunshi/ashigaru には **task YAML 受諾時 hook** を新設 |
| 月次 mining + REMINDERS 辞書 | shogun では **週次 mining + agent 別 instruction delta 提案** (日次は cost 過大) |
| False positive 許容 / False negative 不許容 | shogun では **silent failure を最重要 false negative として扱う** (cmd_609 教訓) |
| 100+ entries で modularize | shogun では **agent 別 catalog file** 分割で最初から modular |

**適用上の制約**:
- shogun jsonl は agent 別に分散 (ash1-7 + karo + gunshi + shogun) → **agent_id keying が必須**
- 殿の発話は希少 signal (1 日 7 度の reality check も小サンプル) → **multi-day window の集約** が必要
- inject 経路は zenn の hook より複雑 (inbox_write 経由 + task YAML 経由 + instruction file 経由) → **inject point catalog** を最初に整備

### 3.2 記事 2 (karpathy/autoresearch) の核心と shogun 適用

**核心**:
> 3 ファイル分離 (`prepare.py` / `train.py` / `program.md`) + **5 分固定実験ループ** + **単一客観指標 (val_bpb)**。Single file modification で diff 可視化 + 短サイクルで原因不明回避。

**shogun への適用**:

| karpathy 概念 | shogun 移植 |
|---------------|-------------|
| `prepare.py` (固定 utility) | **`scripts/improvement_runner/` 配下の固定 utility 群** — mine / propose / apply / evaluate |
| `train.py` (agent 編集対象) | **agent 別 instruction delta file** (`output/improvement/{agent}_delta_{N}.md`) — 1 cmd で 1 file のみ編集 |
| `program.md` (人間指示) | **本書 (cmd_611) + 殿の方針指示** — 制約・指向の明示 |
| 5 分固定 wall-clock | shogun では **1 cmd = 1 実験単位** (実時間 15-60 分相当) — agent 並列性により wall-clock 短縮可 |
| val_bpb 単一指標 | shogun では **複合指標** (silent_failure_rate + reality_check_count + cycle_time の重み付け和) — 単一指標には agent 多様性が収まらない |
| keep/discard 自動判定 | shogun では **gunshi QC + 殿承認** の 2 段ゲート (LLM agent 改変は影響範囲広く自動 revert は危険) |

**適用上の核心**:
- **single-file modification 原則**: 1 cmd で 1 instruction file / 1 hook / 1 script のみ変更 → diff 可視化 + 原因切り分け容易
- **固定短サイクル**: 大改修禁止、最小 delta + 検証 + 採否判定の規律
- **客観指標必須**: 主観評価のみの cmd は採択しない (要 KPI 定義)

### 3.3 2 記事の統合視点

| 軸 | zenn | karpathy | 統合 |
|---|------|----------|------|
| 改善 source | 会話 log (受動) | 仮説 (能動) | **両用** — log mining で問題発見、仮説で解決提案 |
| 適用 timing | runtime hook | 1 実験単位 | **2 段** — 即時 hook (緊急停止) + 周期 cmd (構造改善) |
| 評価方法 | hook 発火 log の trend | val_bpb 比較 | **多元 KPI + 短期/長期分離** |
| 失敗対応 | false positive 許容 | discard で自然淘汰 | **silent failure は両者を超えた最重要対策対象** (cmd_609 教訓) |

---

## 4. 既存資産との接続 (AC4)

### 4.1 既存ルール体系との位置付け

| 既存資産 | 自己改善ループとの接続 |
|---------|----------------------|
| **L013** (Opus+Codex dual-review) | Pattern Extraction の精度向上に dual-model 適用可 |
| **L016** (調査系 dual-model) | 自己改善 cmd の Pattern Extraction phase で適用 |
| **L017** (Test 系 dual-model) | hook delta apply 後の eval phase で適用 |
| **L018** (context% primary source) | shogun vector の 1 つ (本ループの output 例) |
| **L019** (s-check / cross-source) | shogun vector の 1 つ (本ループの output 例) |
| **cmd_603** (status_check_rules.py 共通モジュール) | karo vector の Phase 2 hook delta 起点 |
| **cmd_608** (s-check skill) | shogun vector の Phase 2 hook delta 完成形 |
| **issue #40** (karo 過負荷 / bugyo 新設) | karo vector の構造改善案 — 自己改善ループで監視 KPI 化 |

### 4.2 自己改善ループ自身の位置付け

L018 / L019 / cmd_603 / cmd_608 は **個別の改善 cmd** だった。本ループは **これらを生み出すメタ仕組み**。

```
個別改善 cmd (現状): 殿の reality check → cmd 発令 → 個別 instruction 改修
                       ↑ 殿の手動トリガー依存

メタ仕組み (本ループ): jsonl mining → pattern catalog → cmd 候補生成 → 殿承認 → cmd 自動発令
                       ↑ 殿は採否判定のみ。発見と提案は agent 自動化
```

### 4.3 gunshi suggestions との接続

現状の `queue/suggestions/` (もしくは config/suggestions.yaml) は **gunshi が個別に提案** する形。本ループはこれを **mining-driven** に強化:
- gunshi 個別 suggestion → 残置 (高 abstraction の改善案)
- jsonl mining → cmd 候補 (低 abstraction の reflex 系改善案)
- 両者を suggestion DB に統合し、殿の採否判定 UI を統一

---

## 5. 失敗モードと防御設計 (Q6 回答)

### 5.1 Silent Improvement (改善が検知困難)

**リスク**: hook 注入で問題が「見えなく」なるだけ (実害が水面下に潜伏)
**対策**:
- hook 発火と同時に `logs/improvement/hook_fires.jsonl` に full context 記録
- 週次 review で hook 抑制された pattern が真に解消されたか目視確認 (gunshi 担当)

### 5.2 Regression (既存 hook の劣化)

**リスク**: 新 hook が既存 hook と衝突し、過去の防御を無効化
**対策**:
- karpathy 流 single-file modification 厳守
- hook delta apply 前に **既存 hook regression test** 必須 (eval phase の一部)
- 衝突検知時は自動 revert + 殿に escalation

### 5.3 Over-improvement (複雑化→メンテ不能)

**リスク**: hook / instruction が肥大化し、agent 自身が rule を遵守できなくなる
**対策**:
- agent 別 instruction file 行数を **monitoring** (hard cap: 1000 行)
- 半年に 1 度 instruction 整理 cmd を発令 (gunshi 主導)
- pattern catalog の **TTL 設定** — 90 日発火なし pattern は archive

### 5.4 Silent Failure (本件最大の敵)

**リスク**: cmd_609 の C5 常時失敗のような **AND 条件 silent failure** が hook delta に紛れ込む
**対策**:
- hook delta は必ず **fire/no-fire 両側の test case** を eval phase に含める
- gunshi は blind spot checklist で「条件が一度も真になっていない」項目を機械検出

---

## 6. Issue #40 接続性 (Q7 回答)

### 6.1 同方向の問題: 単一 agent 集中

issue #40 (karo 過負荷) と本自己改善ループは **「単一 agent への集中リスク」** で同方向。

```
issue #40: karo 機能集中 → bugyo 新設で水平分散
本ループ:   shogun reality check 集中 → 自己改善 hook で防御層分散
```

### 6.2 自己改善ループの貢献

issue #40 単独では「分散後の各役職の品質」が保証されない。本ループは:
- bugyo 新設後に **bugyo 自身の self-improvement vector** を計測可能化
- karo vector の silent failure rate を継続監視 → 分散後の改善効果を客観評価
- 4 役職構造 (shogun/karo/bugyo/gunshi) における各 vector の独立計測

### 6.3 接続度の評価

- **強接続**: issue #40 実装後の効果検証 = 本ループの KPI で測定
- **独立性**: issue #40 は構造改革、本ループは reflex 形成 — 並列推進可能
- **推奨**: 本ループを **issue #40 実装前** に小さく開始し、bugyo 新設後の baseline 比較に活用

---

## 7. 殿への方向性提示: 採択候補 cmd 群 (AC5)

殿の選択肢として **3 段階の規模** で 5 候補を提示する。

### 候補 A (最小): cmd_612 — jsonl mining 基盤 + shogun vector 1 件

**規模**: 1 ash + 1 gunshi / ~250 LOC / 半日
**内容**:
- `scripts/improvement_runner/mine_jsonl.py` 新設 (Codex arm の M1 採用)
- shogun jsonl のみで `output/improvement/shogun_problem.md` 生成
- shogun 用 hook delta 1 件試作 (発令前 evidence check)
- KPI 計測: shogun_correction_rate のみ
**Why**: zenn 流の最小実装で feasibility 検証。失敗しても影響軽微
**期間**: 1 日 (実装半日 + 検証半日)
**Stop criteria**: 1 週間運用で reality check 件数の baseline 確立失敗 → 中止

### 候補 B (中規模): cmd_613 — 4 役職 vector 各 1 件 + 統合 catalog

**規模**: 4 ash 並列 + 1 gunshi / ~600 LOC / 2-3 日
**内容**:
- 全 agent jsonl + queue/reports 統合 mining
- 各 agent 別 problem.md / solution.md / eval.md (3 file 分離 — karpathy 流)
- 4 役職それぞれに **1 つだけ** instruction delta apply (single-file modification 厳守)
- 横断 KPI dashboard (`dashboard.md` の新セクション)
**Why**: 全 agent 視点の最小実装。殿の北極星に直接対応
**期間**: 3 日 (各 agent 1 日)
**Stop criteria**: 4 vector のうち 2 件以上が KPI 改善失敗 → frame 再設計

### 候補 C (フル規模): cmd_614〜617 連続 — Phase 1〜4 全実装

**規模**: 4 cmd 連続 / Codex arm 見積 820-1180 LOC / 約 2 週間
**内容**: Codex arm の M1-M5 + 本書の Phase 1-4 完全実装
**Why**: 自己改善ループを正規 framework として確立
**期間**: 2 週間
**Stop criteria**: cmd_614 (Phase 1) で KPI 改善 0% → 中止

### 候補 D (補完): cmd_618 — gunshi suggestion DB 統合

**規模**: 1 ash + 1 gunshi / ~150 LOC / 半日
**内容**:
- 既存 gunshi suggestions と mining-driven suggestions の DB 統合
- 殿の採否判定 UI 統一 (dashboard.md の 🛠️ section 拡張)
**Why**: 既存資産の活用 + 殿の認知負荷軽減
**期間**: 半日
**前提**: 候補 A or B のいずれかが完了している

### 候補 E (issue #40 連動): cmd_619 — bugyo 新設 + 本ループ baseline 計測

**規模**: 大規模 / issue #40 の実装 + KPI 計測機構
**内容**:
- bugyo agent 新設 (issue #40 提案実装)
- 本ループの KPI で bugyo 効果を baseline 計測
**Why**: 構造改革と reflex 形成の相乗効果検証
**期間**: 1 週間 (issue #40 単独より計測機構分長い)
**前提**: 候補 A or B が完了し、baseline KPI が確立している

### 7.1 推奨採択順 (Opus arm 所見)

```
Phase 0 (推奨開始): 候補 A (cmd_612) — feasibility 検証
  ↓ 成功
Phase 1: 候補 B (cmd_613) — 全 agent 視点で水平展開
  ↓ 効果確認
Phase 2: 候補 D (cmd_618) — 既存資産統合
  ↓ 並行
Phase 3: 候補 C (cmd_614〜617) または 候補 E (cmd_619)
```

**理由**:
1. 候補 A で「mining 自体が機能するか」を低リスクで検証
2. 候補 B で「全 agent 視点」(殿の北極星) を満たす
3. 候補 C のフル実装は前 2 段の baseline がないと評価不能
4. 候補 E (issue #40 連動) は本ループの **応用** として位置付け、先行ではない

---

## 8. 完了基準 (AC1-AC5) チェック

| AC | 内容 | 本書での対応 |
|----|------|-------------|
| AC1 | 拙者骨子 4 Phase 継承 + 全 agent 視点拡張案 | §1 (4 Phase 拡張表 + 統合 architecture) |
| AC2 | 各 agent 別 vector 特定 (4 役職別) | §2 (shogun/karo/gunshi/ashigaru 各別 + cross-agent) |
| AC3 | 2 記事知見統合と適用案 | §3 (zenn / karpathy 個別 + 統合視点) |
| AC4 | 既存資産との接続 (L017/L018/L019 + cmd_603/608 + suggestions) | §4 (rule 体系 / メタ仕組みの位置付け / suggestions 統合) |
| AC5 | 殿への方向性提示: 採択候補 cmd 群 | §7 (5 候補 + 推奨採択順) |

**追加成果**:
- §5 失敗モード防御設計 (Q6)
- §6 issue #40 接続性 (Q7)

---

## 9. ash6 (Codex arm) との分担確認

| 領域 | Opus (本書) | Codex (`*_codex.md`) |
|------|-------------|---------------------|
| 戦略・全体俯瞰 | ◎ | △ |
| 役職別 vector | ◎ | ○ |
| 既存資産接続 | ◎ | ○ |
| 採択候補 cmd 群 | ◎ (5 候補 + 順序) | ○ (Scope M1-M5 工数) |
| jsonl mining 実装詳細 | △ | ◎ (Python script + bash) |
| 工数見積 | △ | ◎ (820-1180 LOC / 10.5-14h) |
| hook delta 自動生成 | △ (概念のみ) | ◎ (具体 rule) |

**統合視点**: gunshi (Scope C) は両 arm を以下のように統合すると推奨:
1. **戦略層** = 本書 (Opus) の §1-§7
2. **実装層** = Codex arm の §1-§7
3. **採択 cmd 案** = 本書の候補 A-E + Codex の M1-M5 を mapping し、殿提示

---

## 10. 結語

殿のご指摘「拙者案は shogun 自身の改善に偏り、全体の改善視点が足りない」に対し、本書は:

1. **役職別 vector の独立性** を明示 (§2) — shogun/karo/gunshi/ashigaru で改善対象が異なる
2. **組織学習層** の必要性を提示 (§1.2 Phase 4) — agent 個別改善の和を超える framework
3. **段階的採択 cmd 群** を 5 候補で提示 (§7) — 殿が規模・優先順位を選択可能
4. **既存資産 (L013-L019 + cmd_603/608 + issue #40) との接続** を網羅 (§4)

採択候補のうち、殿の「全体視点」要請に最も直接対応するのは **候補 B (cmd_613 — 4 役職 vector 各 1 件)** である。最小規模の **候補 A (cmd_612)** から段階的に開始し、効果確認後に候補 B へ展開することを推奨する。

---

**参照 URL (WebFetch 完了)**:
- 記事 1: https://zenn.dev/hrmtz/articles/8fb837b9cfac57
- 記事 2: https://github.com/karpathy/autoresearch

**関連 Issue**:
- Issue #40 (karo 過負荷 / bugyo 新設提案、CLOSED 済)

**関連既存資産**:
- L013-L019 (memory/global_context.md)
- cmd_603 (status_check_rules.py 共通モジュール)
- cmd_608 (s-check skill 三段構成)
- cmd_609 (karo self_clear 統合レポート — silent failure 構造解析)
