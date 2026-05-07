# cmd_660 Scope A-2 ash4 (Opus+T) — #40 家老役割集中問題 問題状況再分析

- 作成: 2026-05-08 ashigaru4 (Opus+T)
- 親 cmd: cmd_660 / issue #40 (家老役割集中問題)
- 入力資料:
  - `output/shogun/cmd_597_role_split_directions_integrated.md` (gunshi 統合 QC, 2026-04-27)
  - `output/cmd_auto_decision_prep_2fe4475e203ff8fd.md` (P1-P3 殿判断資料, 2026-05-07)
  - cmd_657/658/659 commit history + verifier PARTIAL_PASS 結果
  - `dashboard.yaml` action_required 現状
  - issue #40 / #45 殿コメント (2026-05-08 03:35 JST 追記)
- 制約: 他足軽 (ash5/ash6/ash7) のレポート不参照、調査のみ実施

---

## Executive Summary

cmd_597 (4/27) で抽出した役割集中問題は **dispatch 前段の漏れ** が中心であったが、本日 (cmd_657/658/659) は **完遂後段 (commit/push, dashboard 反映, Discord/inbox 通知, gunshi_report 上書き)** に問題重心が移動した。両者は同一構造 (家老 1 人が「manager + scribe + state-mutator」を順次直列に実行する単一 critical path) を持ち、各ステップに external verify が存在しないため 1 抜けで漏れが定着する。本日の verifier PARTIAL_PASS 検出は **Phase 2 (implementation-verifier agent) が機能している証拠** であり、Phase 3 (自動 hook) を欠いていることが唯一の隘路である。塩漬け中の P1-C / P2-D / P3-B (cmd_597 案 C 着手方向) は依然有効だが、対象範囲を「dispatch 前段」から「完遂後段 7 ステップ全域」に拡張すべき。後続 cmd_661 で implementation-verifier の hook 常設化、cmd_662 で Step 11.7 を atomic transaction 化、cmd_663 で dashboard.yaml 完全 SoT 化、cmd_664 で gunshi_report.yaml の append-only schema 強制を、この順序で発令することを推奨する。

---

## 1. cmd_597 時点 vs 2026-05-08 の問題状況ギャップ分析

### 1.1 問題重心の移動

| 軸 | cmd_597 時点 (4/27) | 本日 cmd_657-659 (5/8) |
|---|---|---|
| 漏れ発生フェーズ | **dispatch 前段** (cmd 起票 → ashigaru 起動) | **完遂後段** (Step 11.7 7 ステップ + 永続化 + 通知) |
| 代表事象 | cmd_595/596 dispatch 漏れ 2 連続 | commit/push 漏れ・dashboard 反映漏れ・gunshi_report 上書き |
| 漏れ件数 | 2 cmd × 1 ステップ | 3 cmd × 平均 3-4 ステップ |
| 検出経路 | 殿の事後発見 | implementation-verifier agent の即時検出 (PARTIAL_PASS) |
| 観測可能性 | 低 (再発まで気づかない) | 中 (verifier 起動した cmd のみ即時検出) |

最重要観察: **cmd_597 → 本日で問題重心が dispatch 前段 → 完遂後段に移動したが、構造原因 (役割集中) は不変**。前段の機械化 (案 C ハイブリッド) を実装中であっても、後段の漏れは独立に定着している。これは「dispatch 漏れさえ解消すれば全体問題が解ける」という cmd_597 当時の暗黙仮定を反証する。

### 1.2 6 軸評価への影響

cmd_597 で gunshi が提示した 6 軸 (信頼性 / 柔軟性 / 観測可能性 / コスト / LLM 進化耐性 / 殿との接点保持) のうち、**観測可能性が現実化した** ことが最大の進展である。Phase 2 (implementation-verifier agent) 導入により、4-Layer 検証 (L1 Existence / L2 Content / L3 Hygiene / L4 Pattern) で家老完遂報告の真偽を独立確認できるようになった。本日 cmd_658/659 で **PARTIAL_PASS** を 2 回検出した実績は、Codex (cmd_597 ash6) が懸念した「shadow process が増える」リスクが、agent 経由なら逆転して可観測性向上に寄与することを示す。

### 1.3 [提案-4] (P1-P3 殿判断資料) の現時点有効性

`output/cmd_auto_decision_prep_2fe4475e203ff8fd.md` (P9c 7 日 SLA 自動生成) は本日も有効である。ただし範囲拡張が必要:

- **P1 (dispatch 完了 = 反映時点)**: 本日事象を踏まえ、「反映時点」の定義を **Step 11.7 の 7 ステップ全完了 + verifier PASS** まで広げるべき。提案当時は dispatch SLA を意識した文言だったが、今や Step 11.7 全域が対象。
- **P2 (queue + dashboard 二層 sync)**: cmd_659 で dashboard.yaml の action_required / achievements 部分のみ SoT 化済 (構造化完了)。残部 (進行中ボード / 🐸 Frog / streaks) は未構造化のため、二層 sync の片端 (queue → dashboard.md generator) も部分稼働状態。完全 SoT 化が次の段階。
- **P3 (信頼性最優先)**: 立証フェーズ完了。本日の verifier PARTIAL_PASS が、信頼性 > 柔軟性の重み付けが正しいことを実証している。

---

## 2. 本日事象から見た「家老役割集中」の本質的原因 (RCA)

### 2.1 漏れの類型化

本日 3 cmd で観測された漏れを 4 類型に分類する。

| 類型 | 事象例 | 直接原因 | 構造原因 |
|---|---|---|---|
| (i) 永続化漏れ | cmd_658 12 ファイル未 commit / cmd_659 5 ファイル untracked | `git add`/`git commit`/`git push` の手動運用 | Step 11.7 に commit/push が atomic に組込まれていない |
| (ii) 通知漏れ | cmd_658/659 Discord 未発火 / 将軍 inbox 報告 0 | `cmd_complete_notifier.sh` 起動条件 (🏆 marker on dashboard.md change) が満たされない | dashboard.md 書込が前提 → 書込抜けると通知も連鎖抜け |
| (iii) 反映漏れ | cmd_658/659 dashboard 🏆 未書込 / SO-19 進行中欄残存 | Step 11.7 sub-step 3,4,6 の実行抜け | 7 step が直列実行で家老 1 人完結、external verify なし |
| (iv) 上書き事故 | cmd_659 で gunshi_report.yaml の cmd_651 entry 消失 (fd5c286 で復元) | YAML 単一 document 書込 (multi-document append でない) | schema 制約なし、家老が「最新だけ残す」と自己解釈する余地 |

### 2.2 共通真因: Step 11.7 の "single critical path" 構造

家老 instructions Step 11.7 (`instructions/karo.md` line 618-633) は 7 ステップを atomic に実行することを要求する:

1. shogun_to_karo.yaml status → done
2. saytask/streaks.yaml 更新
3. dashboard.md 進行中→戦果移動
4. cmd_complete.sh による SO-19 cleanup
5. inbox_write shogun
6. update_dashboard.sh (進行中→🏯)
7. suggestions hard check

この 7 ステップは **家老 1 人が直列に実行** する単一フローであり、各ステップに **external verify が存在しない**。1 ステップ抜けると、その後の連鎖 (例: ステップ 3 抜け → cmd_complete_notifier 不発火 → 通知 0 → 殿気付かず) で問題が定着する。本日 cmd_658/659 はまさにこのパターンを 2 回連続で再現した。

加えて、**commit/push は Step 11.7 7 ステップに含まれていない**。これが cmd_604 (origin/main 未到達) → cmd_620 (push 漏れ実例 #001) → 本日 cmd_658/659 で永続化漏れが 5 月だけで 3 cmd 同型再発する真因である。

### 2.3 役割集中の現代的姿

cmd_597 当時の構造分析 (manager / scribe / state-mutator の 3 役同居) は依然正しいが、本日事象を踏まえ **6 役同居** に拡張すべきである:

1. manager (タスク分解・dispatch)
2. scribe (dashboard.md / 各 YAML 書込)
3. state-mutator (cmd 状態遷移)
4. **persister (git commit/push) ← 本日新規類型**
5. **notifier (Discord / inbox / ntfy) ← 本日新規類型**
6. **integrity guarantor (gunshi_report 等の append-only 維持) ← 本日新規類型**

家老 1 体が 6 役を直列に演じる構造ゆえ、1 役の手順抜けが必ず連鎖漏れを生む。

---

## 3. 案 A-D 再評価 — P1=C案 / P2=D案 / P3=B案 の現時点有効性

### 3.1 案 C (ハイブリッド・クリティカル遷移機械化) — 引き続き第一推奨

cmd_597 gunshi 統合所見の通り、案 C は引き続き第一推奨である。ただし **対象クリティカル遷移の定義を拡大** する必要がある:

| cmd_597 当時の対象 | 拡張後の対象 (本日改訂) |
|---|---|
| dispatch (cmd 起票 → ashigaru 起動) のみ | + Step 11.7 7 ステップ全域 + commit/push 永続化 + 通知発火 |

Codex (ash6) が cmd_597 で要求した 2 条件 (SLA 10 分以内 / 単一ログ収集点) は、Phase 2 verifier の登場で `queue/reports/*.yaml` + `agent task notification` が単一ログ収集点として既に整備された。SLA は verifier 起動時間 (典型 30 秒) で 10 分以内を大幅にクリアしている。**前提条件は既に整っており、案 C 着手の障害は除去済**。

### 3.2 案 D (役割分離・新 agent 増設) — 段階フレーム維持、ただし優先度を引き上げ

cmd_597 では「案 C → 観測 → 案 D」の段階フレームが推奨されたが、本日事象は **案 D の優先度引き上げ** を示唆する。具体的には:

- **persister 専任化**: post-commit hook + push gate を独立 agent / hook 化 (家老から分離)
- **integrity guarantor 専任化**: gunshi_report 等の YAML 上書き禁止 schema validator (家老から分離)

これらは新 agent 増設ではなく、**hook + script 単位の責務分離** で実現可能なため、案 D の重い形 (新 pane / 新 agent) を取らずに段階的に着手できる。cmd_597 で懸念された inter-agent race condition / 完了判定主体不統一は、hook 単位なら「家老が触れたら verifier が即検証」の単純フローで回避できる。

### 3.3 案 A (フル機械化) — 必要部位のみ局所適用

case 案 A の主リスク (escape hatch なし、shadow process 増殖) は変わらず妥当。ただし **Step 11.7 sub-step 1,2,4,6 (機械的書換のみで判断不要)** は state machine 化しても escape hatch 不要であり、局所適用が安全。手順抜けを「技術的不可能」化する点で、本日類型 (iii) 反映漏れに直接効く。

### 3.4 案 B (自律性重視) — cmd_597 の却下判断を維持

cmd_597 で「単独採用不可」と判定された案 B (LLM プロンプト + .md 強化) の判断は本日も妥当。本日事象 cmd_658/659 は karo 用 instruction.md がしっかり整備された後にも関わらず再発した点で、自律性のみの限界を再立証している。**ただし案 C/D の prompt 補強として併用** は引き続き有効 (例: Step 11.7 直前に verifier 起動を強制する文言)。

---

## 4. 新たな対策案 (Q1-Q4) — 本日事象に基づく追加提案

cmd_597 の 4 案 (A/B/C/D) に加え、本日事象から導かれる新規対策を 4 つ提案する。これらは案 C/D の具体実装パスとして整合する。

### Q1: implementation-verifier の hook 常設化 (= Phase 3)

issue #45 で塩漬け中の Phase 3 (自動 hook) を即時実装する。本日 verifier PARTIAL_PASS 2 件の検出効果は **agent 起動を将軍が手動で行った場合のみ機能** している。これを Stop hook / cmd_complete_notifier hook の派生で **家老の Step 11.7 完了時点で自動起動** するよう常設化すれば、本日類型 (i)(ii)(iii)(iv) すべてが完遂直後に検出可能になる。

実装規模: hook 定義追加 + verifier 起動 wrapper script。0.3-0.5 週。

### Q2: Step 11.7 を atomic transaction 化 (post-commit + push hook)

現状 Step 11.7 7 ステップは家老 instruction で命名されているのみで、技術的 atomicity が無い。これを以下のように補強:

- **pre-step**: `git stash` 退避 + lock 取得
- **step 1-7**: 各ステップ完了で checkpoint 書込 (`/tmp/karo_step_{n}.done`)
- **post-step**: 7 checkpoint 全揃い時のみ commit/push を 1 transaction で実行
- **rollback**: いずれかのステップ失敗で `git stash pop` + lock 解放

加えて、commit/push を Step 11.7 の **8th step** として明示組込みする。本日類型 (i) 永続化漏れの構造的不能化。実装規模: 0.5-1 週。

### Q3: gunshi_report.yaml 上書き禁止 schema 制約

cmd_659 で `git add fd5c286` 緊急復元した cmd_651 entry 消失事故は、gunshi_report.yaml が **single document YAML** として書き換えられた結果である。これを **multi-document YAML (`---` separator append-only)** schema に固定し、書込操作を `yq -i e '. += [{...}]'` のような append 専用にラップする。書込前に既存 entry 数の sanity check (前回 ≦ 今回) を validator で強制すれば、上書き事故は技術的に不能化できる。実装規模: 0.2-0.3 週。

### Q4: 完遂直後の強制 verify gate

`cmd_complete_notifier.sh` (dashboard.md 🏆 marker 検出で発火) の派生として、**verifier hook** を追加する。家老完遂時に dashboard.md 🏆 が書込まれた瞬間に implementation-verifier を `Agent(run_in_background=true)` で起動し、PARTIAL_PASS / FAIL 時は `notify_decision.sh` で殿に即通知。Q1 と組み合わせれば、家老が完遂を宣言してから 30 秒以内に verifier 結果が殿に届く。本日類型全てに対応。実装規模: 0.2-0.3 週 (Q1 と統合して 0.5 週)。

### Q1-Q4 の段階導入順序

1. **Q1 (Phase 3 hook 常設化)** ← 既に Phase 2 で動作実証済、最低工数で最大効果
2. **Q3 (gunshi_report append-only)** ← 上書き事故再発防止、Q1 と独立並列可能
3. **Q2 (Step 11.7 atomic transaction)** ← 上記 2 つで観測した漏れパターンを技術的不能化
4. **Q4 (verify gate hook 統合)** ← Q1 + Q2 完了後の最終ゲート

---

## 5. 後続 cmd 推奨事項 (cmd_661 以降)

cmd_597 当時は cmd_599 候補 (sug_cmd_596_dispatch_automation_001) を起点とする計画だったが、本日事象を踏まえ **後続 cmd を再編** する:

| cmd 番号予約 | 内容 | 担当 | 工数 | 依存 | 優先度 |
|---|---|---|---|---|---|
| **cmd_661** | implementation-verifier hook 常設化 (Q1, issue #45 Phase 3 解凍) | 家老 + ash | 0.3-0.5w | なし | **最高** |
| **cmd_662** | Step 11.7 atomic transaction 化 (Q2, commit/push 組込み) | 家老 + ash | 0.5-1w | cmd_661 | 高 |
| **cmd_663** | dashboard.yaml 完全 SoT 化 (P2-D 範囲拡大: 戦果/進行中/Frog/streaks) | 家老 + ash + gunshi | 0.5-1w | cmd_661 | 高 |
| **cmd_664** | gunshi_report.yaml append-only schema 強制 (Q3) | 家老 + gunshi | 0.2-0.3w | なし (並列可) | 中 |
| ~~cmd_599~~ | ~~dispatch 機械化単独~~ | — | — | **cmd_661 に吸収** | 廃止 |

**重要**: cmd_597 当時の cmd_599 候補 (dispatch 機械化単独) は、本日の問題重心移動を受けて **単独発令する意義が薄れた**。cmd_661 (verifier hook 常設化) で完遂後段全域をカバーすれば、dispatch 前段の verify は副次的に達成されるため、cmd_661 に吸収統合することを推奨する。

### 5.1 殿の判断 1 行で発令可能なメニュー

**メニュー A (推奨)**: 「cmd_661 即時発令」 → Q1 のみ着手、効果 1-2 日以内測定
**メニュー B**: 「cmd_661 + cmd_664 並列発令」 → Q1+Q3 同時、上書き事故も即座に防止
**メニュー C**: 「cmd_661-664 全件発令、優先度通り段階実装」 → 完全パス、3-4 週

殿の現時点判断資料 (P1-C / P2-D / P3-B) はすべてメニュー A-C で整合する。

---

## 6. 結論・推奨アクション

cmd_597 で抽出した「家老役割集中」は **構造問題として依然有効** だが、本日事象は問題重心が **dispatch 前段 → 完遂後段 (Step 11.7 + 永続化 + 通知 + integrity)** に移動したことを示す。役割は manager / scribe / state-mutator から **6 役 (manager / scribe / state-mutator / persister / notifier / integrity guarantor)** に拡張すべきであり、対策範囲も同様に拡張要。

`output/cmd_auto_decision_prep_2fe4475e203ff8fd.md` の P1-C / P2-D / P3-B 推奨は **依然として正しい判断軸** だが、適用対象を Step 11.7 全域に広げる必要がある。Phase 2 (implementation-verifier agent) は本日 PARTIAL_PASS 2 件の実績で機能を立証しており、唯一の隘路は Phase 3 (自動 hook) の塩漬けである。

**1 行推奨**: 殿は **cmd_661 (Q1: implementation-verifier hook 常設化、issue #45 Phase 3 解凍)** を即時発令されたし。これにより本日類型 4 種すべてが完遂直後 30 秒以内に検出可能となり、続く cmd_662-664 の効果測定基盤も同時に整う。塩漬け解凍の最初の一歩として工数最小・効果最大の選択である。

---

## 参考

- `output/shogun/cmd_597_role_split_directions_integrated.md` (gunshi 統合 QC, 2026-04-27)
- `output/shogun/cmd_597_role_split_directions_report.md` (Opus 単独, ash5)
- `output/shogun/cmd_597_role_split_directions_report_codex.md` (Codex 単独, ash6)
- `output/cmd_auto_decision_prep_2fe4475e203ff8fd.md` (P1-P3 判断資料, 2026-05-07)
- `instructions/karo.md` Step 11.7 (line 618-633), Dashboard 編集権限 (line 694-717)
- `instructions/common/dashboard_responsibility_matrix.md` (cmd_659 新設)
- `output/cmd_659_implementation_report.md` (本日完遂時 cmd 報告)
- `dashboard.yaml` action_required entries (cmd_657/658 由来 5 件)
- issue #40 (saneaki/multi-agent) — 殿コメント 2026-05-08 03:35 JST 追記分
- issue #45 (saneaki/multi-agent) — Phase 2 移行完了 (cmd_628) + Phase 3 塩漬け
- 本日 commit: 0f2e830 / 64fcca6 (cmd_658) / a7e3920 / fd5c286 (cmd_659)
- 関連 verifier 結果: agent task `a8cb753f1096a6184` (cmd_658) / `a07451b3151b24672` (cmd_659)
