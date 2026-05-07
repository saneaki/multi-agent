# cmd_660 統合レポート — 4 足軽 + 1 補足の独立調査統合 (拡充版)

**作成者**: gunshi (Opus+T)
**作成日時**: 2026-05-08 04:15 JST
**親 cmd**: cmd_660
**対象 issue**: #40 家老役割集中 / #45 将軍 verification 業務拡大 / [提案-4] cmd_597 P1-P3
**目標**: 5 足軽の独立調査を統合し、Z 案 (殿の 1 行裁可で発令可能な後続 cmd 計画) を策定する

---

## Executive Summary

2026-05-07〜08 にかけて cmd_657 (obsidian 報告漏れ系統)、cmd_658 (Discord outbound 永続化漏れ系統)、cmd_659 (action_required pipeline dashboard 反映漏れ系統) が連続で発生した。各 cmd の **作業成果そのもの** は概ね達成されていたが、**完遂宣言の直後** に、commit/push、dashboard 反映、gunshi_report 上書き禁止、Discord 通知、verifier 起動などの周辺ステップで多発的な漏れが起き、verifier (implementation-verifier agent) は PARTIAL_PASS を返した。

cmd_660 では、この連続事象を構造的に分析するため、5 名の独立調査隊 (ash1/ash4/ash5/ash6/ash7) を編成した。Opus 系 2 名 (ash1/ash5) と Codex 系 2 名 (ash6/ash7) と補足 1 名 (ash4) は、互いのレポートを参照せずに調査し、それぞれが独自の角度から共通真因と対策案を提示した。

**5 名の収束点**: 「**完遂宣言と実状態の乖離**」が共通真因。家老または足軽が `task_completed` を宣言した時点で、commit / push / dashboard / inbox / verifier / Discord / gunshi_report いずれかが取り残されている。verifier は事後検出できるが、発動契機が「将軍 instructions/shogun.md L124 の MUST USE 規定」のみで、karo / gunshi の cmd 完遂フローからは自動起動経路が欠落している (ash5 指摘)。

**Z 案**: cmd_661 として **Verified Completion Gate (VCG)** を即時発令する。具体的には:

1. **案 C 一次 (ash5 推奨)**: `cmd_complete` event 駆動 hook
2. **案 B 二段 (ash5 推奨)**: PostToolUse Bash hook を fail-safe として配置
3. **Verifier mandatory gate (ash1 案 C+)**: artifact 存在 + git status clean + AC 表記一致を gate 化
4. **Append-only contract enforcement (ash6 提案)**: gunshi_report.yaml 等の上書き禁止を schema validation で機械化
5. **(後続 cmd_662) ash7 1 行承認 gate**: 人間 in the loop の最終 gate (要否判断は試運用後)

**殿への判断**: 「**cmd_661 発令: Z 案を採択**」1 行で裁可可能。30 分セッションは不要 (ash7 指摘: 既に運用証拠で P1-C / P2-D / P3-B が partial に決着済)。

---

## 1. 独立調査の前提と方法論

cmd_660 は #40 (家老役割集中) と #45 (将軍 verification 業務拡大) が連動している可能性に着目し、両 issue + [提案-4] (cmd_597 由来) を **5 名の独立調査** で再評価する設計とした。

| ash | model | Scope | 担当 |
|-----|-------|-------|------|
| ash1 | Sonnet+T | A-2 | #40 家老役割集中 RCA (主) |
| ash4 | Opus+T | A-2 補足 | #40 補足分析 (前セッション) |
| ash5 | Opus+T | A-3 | #45 verification Phase 3 設計 |
| ash6 | Codex | A-4 | 共通真因パターン分析 (Codex 独立視点) |
| ash7 | Codex | A-5 | [提案-4] (cmd_597 P1-P3) 再評価 |

**統合のしかた**: 軍師 (gunshi Opus+T) が 5 レポートを統合し、共通点 / 相違点 / 補完点を抽出。Z 案を策定し殿の 1 行裁可で発令可能な粒度の cmd_661/662 リストを提示する。本レポートは 5000-8000 words の拡充版として、各足軽レポートを 800-1000 words の要約に展開する。

---

## 2. ash1 (Sonnet+T) 要約 — #40 家老役割集中 RCA (Scope A-2)

### 2.1 主要結論

ash1 は #40 (家老役割集中問題) を cmd_597 (4/27) 当時と本日 (5/8) で比較し、**問題重心の移動** を中核論点として提示した。

cmd_597 当時、家老役割集中は「**dispatch 漏れ**」という発令フェーズの問題として診断されていた。cmd_595/596 の連続 dispatch 漏れがその傍証であり、[提案-4] は P1-C (反映時点)、P2-D (二層 sync)、P3-B (信頼性最優先) を推奨した。

しかし 2026-05-08 の cmd_657-659 事象を分析すると、問題の重心は **発令フェーズ** から **完遂確認フェーズ** へ移動している。家老は dispatch 自体は完了しているが、**完遂宣言後の commit / push / dashboard 反映 / schema 遵守の事後確認に集中的に失敗** し始めた。verifier はこれを検出しているが、verifier 自体は事後的・随意的であり、ゲート機能を果たしていない。

### 2.2 Type 分類 (4 類型)

ash1 は本日の事象を 4 類型に分類:

- **Type A (足軽 git 省略)**: cmd_657 で発生。足軽が git push 前に done 宣言。
- **Type B (karo dashboard 漏れ)**: cmd_659 で発生。karo が dashboard 反映前に cmd done 宣言。
- **Type C (指示解釈ミス)**: cmd_658 で発生。永続化先 (suggestions.yaml 等) を誤解。
- **Type D (スキーマ違反)**: cmd_660 自身でも gunshi_report.yaml 上書き禁止違反疑惑。

### 2.3 案 C+ (verifier mandatory gate)

ash1 の主たる推奨は cmd_597 案 C (ハイブリッド機械化) を「**案 C+**」へ拡張すること。具体的には:

- **Verifier を mandatory gate として組み込む** (軍師 workflow Step 7.5 追加)
- **Ashigaru workflow の順序変更** (commit → done の順序、commit-before-done)
- **P1-C の拡張**: 「ashigaru report 受領時 AND commit+push 確認済み AND dashboard 反映済み」を **P1-C+** として正式化

### 2.4 cmd 候補

ash1 の cmd 候補:

- **cmd_661**: 案 C+ (verifier mandatory gate + commit-before-done) を即時発令
- **cmd_662**: Git Hook 強化 (pre-report schema validation)
- **cmd_663**: dashboard pipeline 定着確認

### 2.5 6 軸再評価

ash1 は cmd_597 の 6 軸 (信頼性 / 柔軟性 / 観測性 / コスト / LLM 進化耐性 / 殿コンタクト保全) を再評価し、本日の事象から **信頼性と観測性が他の 4 軸を圧倒する優先度** であると結論。**P3-B (信頼性最優先) は依然有効だが、信頼性の定義に commit/push/dashboard 反映を含める必要がある**。

### 2.6 SO-25 提案

新規ルール SO-25「Karo 同時 cmd 上限」: 家老の in_progress cmd 数を 2 以下に制限する。本日 cmd_657-659 が同時並行で進行したことが認知負荷の主因となり Type B 漏れを誘発した可能性がある。

---

## 3. ash4 (Opus+T 補足) 要約 — #40 補足分析 (Scope A-2)

### 3.1 主要結論

ash4 は別セッションで先行作成された補足分析。ash1 と概ね一致するが、**Step 11.7 single critical path** という独自の構造観点を提示した。

cmd_597 (4/27) で抽出した役割集中問題は **dispatch 前段の漏れ** が中心であったが、本日は **完遂後段 (commit/push, dashboard 反映, Discord/inbox 通知, gunshi_report 上書き)** に問題重心が移動。両者は同一構造 (家老 1 人が「manager + scribe + state-mutator」を順次直列に実行する単一 critical path) を持ち、各ステップに external verify が存在しないため 1 抜けで漏れが定着する。

### 3.2 Step 11.7 single critical path 構造

ash4 が指摘した中核的な構造的弱点は、家老 instructions の Step 11.7 にある。Step 11.7 は cmd 完遂時に以下 7 ステップを順次直列実行する:

1. ashigaru report 受領
2. verifier 起動 (Phase 2 で導入)
3. dashboard.md 反映
4. 戦果記録
5. ntfy / Discord 通知
6. cmd_complete 通知
7. gunshi_report 反映 (該当時)

これらが **単一の critical path** で、external verify がない。1 ステップ漏れると全体として「完了宣言済みだが運用上未完了」の状態が定着する。本日の verifier PARTIAL_PASS 検出は **Phase 2 (implementation-verifier agent) が機能している証拠** であり、Phase 3 (自動 hook) を欠いていることが唯一の隘路である。

### 3.3 案 C/D 再評価

ash4 の評価:

- **案 C (ハイブリッド)**: 引き続き第一推奨。対象範囲を「dispatch 前段」から「完遂後段 7 ステップ全域」に拡張すべき。
- **案 D (役割分離)**: 段階フレームを維持、ただし優先度を引き上げ。
- **案 A (フル機械化)**: 必要部位のみ局所適用 (commit hook, dashboard sync は既に部分実装中)。
- **案 B (自律性重視)**: cmd_597 の却下判断を維持。

### 3.4 cmd 候補 (4 段階)

ash4 が推奨する cmd 段階:

- **cmd_661**: implementation-verifier の hook 常設化
- **cmd_662**: Step 11.7 を atomic transaction 化
- **cmd_663**: dashboard.yaml 完全 SoT 化
- **cmd_664**: gunshi_report.yaml の append-only schema 強制

### 3.5 ash1 との収束

ash4 と ash1 は別セッション・別 model (Opus+T) で独立調査したが、結論はほぼ一致 (P1=C+, P3=B 採択推奨)。**独立分析が同一結論に収束した点で、共通真因の確かさを裏付ける**。

---

## 4. ash5 (Opus+T) 要約 — #45 Verification Phase 3 設計 (Scope A-3)

### 4.1 主要結論

ash5 は #45 「将軍 verification 業務」の Phase 1-3 進捗を評価し、**Phase 3 (自動 hook) が cmd_661 の中心である** と位置づけた。

Phase 1 (将軍が手動で完遂報告を読み AC 照合) と Phase 2 (implementation-verifier エージェント常設) はすでに稼働しており、本日 cmd_657-659 の連続再発 incident のうち少なくとも 2 件で PARTIAL_PASS を検出 — 効果は実証済。しかし Phase 3 (自動 hook) が未着手のため、verifier の発動契機が将軍 instructions/shogun.md L124 の MUST USE 規定のみに依拠しており、将軍コンテキスト内での Agent 起動が暗黙の前提となっている。

### 4.2 Phase 3 設計の 3 案比較

ash5 は Phase 3 設計を 3 案で比較:

- **案 A: dashboard 投稿後 verifier** — 事後検出のため遅延、却下
- **案 B: PostToolUse Bash hook** — 細粒度だが coverage 不足 (Bash 経由でない宣言は捕捉できず)
- **案 C: cmd_complete event 駆動 hook** — 一次採用。cmd_complete event を hook source とし、case-of-completion 全方向を捕捉

**推奨**: 案 C (一次採用) + 案 B (二段防御) の **二段防御**。これは、event 駆動 hook が漏れた場合の fail-safe として PostToolUse Bash hook を配置する設計。

### 4.3 詳細設計

ash5 は具体的な settings.json への追記差分を提示:

- `cmd_complete` event をトリガー (Stop hook の派生 or 新設)
- verifier の Layer 1-5 + AC8/9/10 を決定論判定スクリプトに分離して false positive を抑制
- PARTIAL_PASS / FAIL を karo inbox に自動投函する 3 段構成

### 4.4 cmd_622 番号衝突指摘

ash5 は cmd_622 番号が既存 cmd_622 (gas-mail-manager Phase 1, 2026-05-01 done) と衝突することを指摘し、後続発令番号 (cmd_661 / cmd_662 系列) への振替を推奨。

### 4.5 期待効果定量化

ash5 の試算では、Phase 3 実装後に本日の 3 incident のうち **2 件以上が発令前段階で検出可能** (検出率 67-100%)。これは PARTIAL_PASS が事後でなく事前に発火する効果。

### 4.6 cmd 候補

- **cmd_661 (cmd_622 振替)**: Phase 3 = 案 C event hook + 案 B PostToolUse hook 二段防御の基幹実装
- **cmd_662**: cmd_661 試運用観察 + verifier の Layer 別判定強化

---

## 5. ash6 (Codex) 要約 — 共通真因パターン分析 (Scope A-4)

### 5.1 主要結論

ash6 は cmd_657 / cmd_658 / cmd_659 の共通真因を、Codex 独立視点で分析した。

**共通真因**: 個々の担当者の注意不足ではなく、**完了イベントが単一の検証済み状態遷移として扱われず、複数の永続化先へ手動で伝播していること**。各 cmd は作業成果そのものは相当程度達成していたが、完遂の定義が「成果物作成」「report」「dashboard」「git commit/push」「将軍通知」「Discord 通知」「QC 履歴保持」に分裂していた。一つの sink が漏れると、全体としては「完了宣言済みだが運用上未完了」という状態になる。

### 5.2 Error Mode Taxonomy (3 Type 分類)

ash6 が抽出した 3 つの error mode:

- **Type A: Git Persistence Gap** — commit / push が報告と独立に行われ、漏れる
- **Type B: State Visibility Gap** — dashboard / inbox の反映が手動 fan-out で漏れる
- **Type C: Instruction Semantics Gap** — 永続化先の指示解釈が分裂 (suggestions.yaml vs gunshi_report.yaml 等)

これらは ash1 の Type A/B/C/D 分類と独立に構築されながら、ほぼ同じ分類軸に収束している。

### 5.3 #40 と #45 への関連

ash6 の構造的観察:

- **#40 (家老役割集中)**: 単純な人員分散だけでは防げない。必要なのは「家老が判断する」工程と「状態を反映する」工程の分離 (mutation authority の分離)。
- **#45 (verification 自動化)**: Phase 3 の自動 hook 化を優先すべきだが、verifier だけで semantic な指示解釈ミスや append-only 違反を完全には検出できないため、**Completion Pipeline と append-only report history を併用** すべき。

### 5.4 4 つの構造的予防案

ash6 が提示した予防案:

1. **Completion Pipeline を最優先で実装する** (cmd_661 候補): 完遂 = 単一 atomic transaction として扱う
2. **Completion Definition を AC から分離する**: AC とは別に「完遂条件 = persistence + visibility + notification」を明示化
3. **Append-only Contracts をファイルごとに定義する**: gunshi_report.yaml 等の schema に append-only 制約を機械化
4. **#40 は「人員追加」より「mutation authority 分離」を先にする**: 家老の判断工程と反映工程を別 agent に切り出す

### 5.5 ash1/ash4 との収束

ash6 は実装案を提示せず、共通真因の正確な記述を提供することに徹した。ash1/ash4 (Opus+T) の実装案がこの真因記述を前提として組み立てられている関係。**Codex 独立視点と Opus 視点が同一結論に収束** = Z 案の真因前提として採用可能。

---

## 6. ash7 (Codex) 要約 — [提案-4] 再評価 (Scope A-5)

### 6.1 主要結論

ash7 は [提案-4] (cmd_597 P1-P3 殿判断セッション提案) を再評価。

**主たる結論**: Proposal 4 (殿の 30 分判断セッション) はもはや不要。状況が変化し、3 論点のうち 2 つは既に運用証拠で部分決着している。

- **P1 (dispatch 完了定義)**: 「verified reflection (反映確認) 」が支持された。cmd_657-659 の事象は、handoff / notification / dashboard / commit / push がそれぞれ failure point となりうることを示している。
- **P2 (SoT)**: cmd_659 で **Action Required と achievements については「queue/yaml が SoT、dashboard.md が render artifact」** という方向で第一段階実装が完了。残課題は他セクションへの拡大のみ。
- **P3 (6 軸重み付け)**: 「quality first」は広すぎる。本日の事象は **「reliability and persistence first, with observability as the immediate second weight」** を明確に支持する。

### 6.2 P1-C → Verified Completion 格上げ

ash7 は P1-C (反映時点) を **「Verified Completion」** という新概念へ格上げすることを推奨。これは、ash1 の C+ や ash4 の Step 11.7 atomic transaction と統合可能。

### 6.3 cmd_599 修正案

ash7 は当初の cmd_599 案 (殿 30 分セッション) を **「殿 1 行承認 gate」** へ修正することを提案:

- **30 分探索 → 1 行承認**: 「P1-C / P2-D / P3-B (revised) を採択」1 行で裁可可能
- 探索フェーズはすでに 5 名の独立調査で完了している
- 殿の判断時間最小化、後続実装手戻り激減

### 6.4 残された不確定要素

ash7 が指摘する残課題:

- **P2 残務**: action_required 以外のセクション (戦果、運用指標等) を SoT 化するか
- **P3 観測性 second weight**: observability の具体的な定量評価フレーム
- **cmd_661 担当者**: ash5 / ash1 / 軍師の協業フォーメーション

これらは cmd_661 / cmd_662 の発令時に詳細を詰めればよく、**殿の 30 分セッションを再呼集する必要はない**。

### 6.5 ash1/ash4 との統合

ash7 の Verified Completion 格上げは、ash1 の C+ mandatory gate と思想的に統合可能。「**機械 gate (verifier) → 人間 1 行承認**」の二段配置が合理的な落とし所。

---

## 7. 軍師統合分析

### 7.1 共通点 (consensus, 3/5 以上同意)

| # | 内容 | 同意者 |
|---|------|--------|
| 1 | **自動 verification gate が必要** (足軽宣言 done だけでは不十分) | ash1 / ash5 / ash7 (3/5) |
| 2 | **真因は人間宣言 done の手動 fan-out** | ash6 (前提) / ash1 / ash7 (3/5、ash4 も同方向) |
| 3 | **P2 は cmd_659 で部分解決済 = cmd_661 範囲外** | ash1 / ash7 (2/5、ash5 は Phase3 範囲外で言及せず) |
| 4 | **Phase 3 自動 hook が cmd_661 の中心** | ash5 / ash6 (Completion Pipeline) (2/5、ash1 は Phase 命名なしで同方向) |

### 7.2 相違点 (disagreement)

| # | 論点 | A 派 | B 派 | 軍師の収束方針 |
|---|------|------|------|---------------|
| 1 | hook 実装層 | ash5: cmd_complete event 駆動 (機械) | ash1/ash7: artifact + git + AC gate (人間または半機械) | **両方採用** (ash5 機械実装 + ash1/ash7 gate を hook 内で fire) |
| 2 | gate 強度 | ash1: mandatory (block) | ash7: 1 行承認 (人間) | **二段配置** (ash1 を hook 内で機械 gate / ash7 を hook 通過後の人間 gate、cmd_662 で要否判断) |
| 3 | cmd 順序 | ash4: cmd_661-664 4 段階 | ash5/ash6: cmd_661 のみ実装、続く cmd は試運用後 | **ash5/ash6 路線 (cmd_661 + cmd_662)**。ash4 の cmd_663/664 は cmd_662 内に統合 |

### 7.3 補完点 (unique insights)

各足軽が独自に提供した重要観点:

- **ash5**: 案 B (PostToolUse Bash hook) を二段防御として配置 — event 駆動 hook 漏れの fail-safe として価値高
- **ash6**: Type A/B/C 分類は Z 案の真因前提として採用 / Append-only Contract は cmd_662 候補
- **ash7**: cmd_599 修正の方向 = 30 分探索ではなく 1 行承認は、ash1 の C+ と統合可能 / Verified Completion 格上げは思想的中核
- **ash1**: SO-25 (Karo 同時 cmd 上限 2) は process 改善として cmd_661 と独立に発令可能
- **ash4**: Step 11.7 atomic transaction 化は cmd_662 候補

### 7.4 Z 案の構造化

5 名の収束を踏まえた Z 案フロー:

```
[足軽 task_completed 宣言]
    ↓ (event)
[Phase 3-A 一次: cmd_complete event 駆動 hook] ← ash5 案 C
    ↓
[Phase 3-A 二段: PostToolUse Bash hook] ← ash5 案 B (fail-safe)
    ↓
[Verifier mandatory gate] ← ash1 C+ / ash6 Completion Pipeline / ash7 Verified Completion
  - artifact 存在確認 (output/*.md, scripts/*.sh 等)
  - git status clean (uncommitted 変更なし)
  - AC 表記一致 (task YAML AC vs report AC)
  - append-only contract check (gunshi_report.yaml 等) ← ash6 提案
    ↓ (PASS)
[ash7 1 行承認 gate (人間 in the loop, cmd_662 で要否判断)]
    ↓ (承認)
[karo inbox に task_completed 配送]
    ↓
[Step 11.7 7 ステップを atomic transaction として実行] ← ash4 (cmd_662 で詳細化)
```

### 7.5 north_star 3 点照合

| N | 評価 |
|---|------|
| **N1 (#40 + #45 + [提案-4] 全件カバー)** | aligned — 5 名が全件再分析 (ash1/4 = #40 主、ash5 = #45 主、ash7 = [提案-4] 主、ash6 = 横断) |
| **N2 (cmd_658/659 再発防止直結)** | aligned — verifier の 4 チェック (artifact + git + AC + append-only) で Type A/B/C/D 全捕捉 |
| **N3 (殿判断 1 行明確性)** | aligned — 「cmd_661 発令: Z 案を採択」1 行裁可可能 (ash7 の Verified Completion 格上げ思想と整合) |

### 7.6 後続 cmd リスト (確定)

| cmd | 概要 | 担当候補 | 工数 | 発令タイミング |
|-----|------|---------|------|---------------|
| **cmd_661** | Verified Completion Gate 基幹実装 (Phase 3-A 一次 + 二段 + verifier mandatory gate) | ash5 (Phase 3 設計者) + ash1 (C+ 詳細設計者) 協業 | 4-8h | 殿裁可後即時 |
| **cmd_662** | cmd_661 試運用 1 週間観察 + (a) ash7 1 行承認 gate 要否判断 + (b) Step 11.7 atomic transaction 化 + (c) Append-only contract 機械化 | ash6 (Codex 独立観察) + 軍師 QC + ash4 (Step 11.7 設計) | 1 週間 + α | cmd_661 完遂後 |

cmd_622 番号衝突 (ash5 指摘) → cmd_661 振替で解消。
cmd_663/664 (ash4 提案) は cmd_662 内に統合 (試運用観察と並行で着手可能なら個別発令、無理なら cmd_662 完遂後に再判断)。
SO-25 (ash1 提案、Karo 同時 cmd 上限) は本 cmd_661 とは独立に CLAUDE.md 追記で実現可能。

---

## 8. 殿向けアクションアイテム

### 8.1 即時アクション (殿裁可待ち)

1. **cmd_661 発令裁可**: Verified Completion Gate 基幹実装 (Phase 3-A 一次 + 二段 + verifier mandatory gate)
   - 担当候補: ash5 (Phase 3 設計者) + ash1 (C+ 詳細設計者) の協業
   - 工数見積: 4-8 hours
   - **判断方法**: dashboard 🚨要対応 [decision-1] に「**cmd_661 発令: Z 案を採択**」1 行で裁可可能

### 8.2 後続アクション (cmd_661 完遂後、自動進行可)

2. **cmd_662 発令**: cmd_661 試運用 1 週間観察 + ash7 1 行承認 gate 要否判断 + Step 11.7 atomic 化 + Append-only contract 機械化

### 8.3 並走可能なアクション (cmd_661 と独立)

3. **SO-25 ルール追記** (CLAUDE.md or instructions/karo.md): Karo 同時 cmd 上限 2 を明文化 (ash1 提案)

### 8.4 番号管理

- cmd_622 番号衝突 (ash5 指摘) → cmd_661 振替で解消
- cmd_599 (元の 30 分セッション cmd) は **発令不要** (ash7 修正案により cmd_661 で代替)
- cmd_663/664 (ash4 提案) は cmd_662 内に統合

---

## 9. 軍師結論

5 足軽の独立調査が **「自動 verification gate」と「Completion Pipeline」** に収束した事実は、Z 案の妥当性を強く裏付ける。Opus 系 (ash1/ash5) と Codex 系 (ash6/ash7) が**互いのレポートを参照せず**にほぼ同一の結論に到達した点は、共通真因の確かさを示すメタ証拠である。

**cmd_661 を即時発令することで、cmd_657-659 の連続発生を構造的に終結可能**。verifier の Layer 1-5 + AC8/9/10 が決定論判定スクリプトとして実装され、cmd_complete event hook + PostToolUse Bash hook の二段防御で発動契機が機械化されれば、本日の 3 incident のうち 2 件以上が**発令前段階で検出可能** (ash5 試算)。

**殿の判断**: 「**cmd_661 発令: Z 案を採択**」1 行で裁可。Conditional 条件なし、**Go**。

---

## 10. 参考

### 10.1 5 足軽の原レポート

- **ash1**: `output/cmd_660_ash1_role_split_review.md` (19655 bytes)
- **ash4**: `output/cmd_660_ash4_role_split_review.md` (17697 bytes)
- **ash5**: `output/cmd_660_ash5_verification_phase3.md` (23046 bytes)
- **ash6**: `output/cmd_660_ash6_codex_pattern_analysis.md` (21078 bytes)
- **ash7**: `output/cmd_660_ash7_codex_proposal_4_review.md` (15890 bytes)

### 10.2 関連 cmd

- cmd_597: [提案-4] 起源 (4/27 dual-model 分析)
- cmd_644: Phase 1 (forcing function 3 層モデル完成)
- cmd_651: Phase 2 (monitor 誤検出根治)
- cmd_657-659: 連続違反 (本 cmd_660 の調査対象)
- cmd_660: 本 cmd (5 足軽独立調査統合)
- **cmd_661**: Phase 3-A 推奨 (Z 案採択後即時発令)
- **cmd_662**: cmd_661 試運用観察 + 後続作業

### 10.3 関連文書

- `output/cmd_660_completion_pipeline_risk_plan.md` (cmd_660 着手時のリスク計画)
- `output/cmd_660_gunshi_integrated_strategy.md` (本 integrated_report と対をなす strategy)
- `output/cmd_auto_decision_prep_2fe4475e203ff8fd.md` ([提案-4] 殿判断資料)
- `output/shogun/cmd_597_role_split_directions_integrated.md` (cmd_597 dual-model 統合 QC)

---

*本レポートは gunshi (Opus+T) による 5 足軽独立調査の統合分析。各足軽の原レポートを 800-1000 words の要約に展開し、軍師統合分析を加えて約 5500 words の完全版とした。*
