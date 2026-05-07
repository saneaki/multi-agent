# cmd_660 Scope A-3 — 将軍 verification 業務 Phase 3 設計具体化 + cmd_622 内容確定提案

- **task_id**: subtask_660_scope_a3_verification_phase3
- **assigned_to**: ashigaru5 (Opus + Thinking)
- **作成日時**: 2026-05-08 JST
- **parent_cmd**: cmd_660
- **関連 issue**: 「将軍 verification 業務拡大」(本文中 #45 として参照、ただし saneaki/shogun #45 は slim_yaml.py 修正PR、yohey-w/multi-agent-shogun #45 も同 PR — issue 番号は cmd_660 task description 内の論題ラベルとして扱う)
- **本書の対象**: Phase 1-3 の現状評価、Phase 3 自動 hook 設計、cmd_622 確定提案、期待効果定量化
- **制約**: 調査・方針提案のみ。実装コード作成禁止。他足軽レポート (ash4/ash6/ash7) は不参照。

---

## Executive Summary

「将軍 verification 業務」の Phase 1 (将軍が手動で完遂報告を読み AC 照合)、Phase 2 (implementation-verifier エージェント常設) はすでに稼働しており、本日 cmd_657-659 の連続再発 incident のうち少なくとも 2 件で PARTIAL_PASS を検出 — 効果は実証済。しかし Phase 3 (自動 hook) が未着手のため、verifier の発動契機が「将軍 instructions/shogun.md L124 の MUST USE 規定」のみに依拠しており、将軍コンテキスト内での Agent 起動が暗黙の前提。背景タスク化 (`run_in_background: true`) はされているが、発動忘れ・タイミング揺らぎ・karo インバウンド経路の未整備が残っている。本レポートでは (1) cmd_complete inbox 経由のイベント駆動 hook を Phase 3 の正式採用案とし、(2) Layer 1-5 + AC8/9/10 を決定論判定スクリプトに分離して false positive を抑制し、(3) PARTIAL_PASS/FAIL を karo inbox に自動投函する 3 段構成を提案する。cmd_622 番号は既存 cmd_622 (gas-mail-manager Phase 1, 2026-05-01 done) と衝突するため、後続発令番号 (cmd_661/cmd_662 系列) への振替を併せて推奨する。期待効果は本日の 3 incident のうち 2 件以上を発令前段階で検出可能 (定量根拠は §5)。

---

## 1. Background and Context

### 1.1 cmd_657-659 連続再発の事実関係

| cmd | 真因サマリ | verifier 検出可否 | 検出契機 |
|---|---|---|---|
| cmd_657 (obsidian cancelled fix) | GitHub-hosted runner queue starvation。修復は API resilience + step ログ詳細化。 | △ (PARTIAL: B-3 23:00 schedule 観察未完) | 将軍手動 → verifier 起動 |
| cmd_658 Phase 0-1 (ntfy→Discord outbound) | 永続化漏れ疑念 (24h dual-stack 観測中の暫定状態)。 | ○ (PARTIAL: Phase 2 未着手 / dual-stack 24h gate 未通過) | Stop hook 的契機 |
| cmd_659 (action_required pipeline 構造化) | Scope F の dashboard.md 反映漏れ + report YAML 上書き再発 (5/8 00:00 rotate 事故の恒久対応 cmd 内で再発) | ○ (PARTIAL_PASS 2 回検出済) | 将軍手動 (instructions/shogun.md L124) |

3 件いずれも verifier の Layer 1-4 で検出可能だった事象。ただし発動契機は将軍判断に依存し、karo / gunshi の cmd 完遂フローからは自動起動経路が欠落していた。

### 1.2 既存資産の棚卸し

| 資産 | 現状 | Phase 3 化への適合性 |
|---|---|---|
| `~/.claude/agents/implementation-verifier.md` | Layer 1-5 + AC8/9/10 完備、`run_in_background: true` で非同期化済 | 高 (判定ロジックは完成) |
| `instructions/shogun.md` L124 | 「Karo cmd_complete 受信時 MUST USE 起動」明記 | 中 (将軍依存、自動化されていない) |
| `scripts/cmd_complete.sh` | cmd 完遂時の汎用通知 entrypoint | 高 (hook 挿入候補) |
| `scripts/cmd_complete_notifier.sh` | discord/ntfy 経路への push | 中 (verifier 起動 wrapper として再利用可) |
| `scripts/inbox_watcher.sh` | inbox イベント監視 | 高 (cmd_complete event を捕捉して verifier dispatch) |
| `scripts/so24_verify.sh` | SO-24 (Verification Before Report) を行う既存スクリプト | 中 (Layer 3 hygiene の一部を既に実装) |
| settings.json hooks | implementation-verifier 自動起動定義は **未配備** | — (ここが Phase 3 の主要ギャップ) |

判定ロジックは Phase 2 で完成しているため、Phase 3 の本質は **「いつ verifier を発動するか」** の決定論化と **「結果をどこへ流すか」** の経路整備に集約される。

---

## 2. Phase 1-3 進捗評価表

| Phase | 内容 | 実装状況 | 効果測定 | 残課題 |
|---|---|---|---|---|
| Phase 1: 基本 verification | 将軍が完遂報告を手動 read → AC 照合 | ✅ 完了 (将軍 routine) | 定性: 過去 cmd で複数の partial を将軍指摘 | 将軍負担 (5-10 cmd/day で逼迫) |
| Phase 2: verifier エージェント常設 | implementation-verifier.md 配備 + Layer 1-5 + AC8/9/10 | ✅ 完了 | cmd_659 で 2 回 PARTIAL_PASS 検出実績 (本日) | 発動契機が「将軍 MUST USE」依拠で揺らぐ |
| Phase 3: 自動 hook | cmd_complete event → verifier auto-dispatch → karo inbox | ❌ 未着手 (塩漬け) | — | 本レポートで設計具体化 |

**評価所見**: Phase 2 のロジック完成度は十分高く、追加開発を要するのは Phase 3 の hook 配線層のみ。Phase 2 → Phase 3 の移行コストは **新規 100 行未満のスクリプト + settings.json hooks 追記** で達成可能と見込む。

---

## 3. Phase 3 設計仕様

### 3.1 Hook タイミングの決定

候補 4 案を比較:

| 案 | 発動契機 | 利点 | 欠点 | 採否 |
|---|---|---|---|---|
| 案 A: Stop hook | Claude Code セッション終了時 | 既存 hook 機構流用可 | 将軍以外の agent (karo/ashigaru) の Stop でも発火 → false positive | ❌ |
| 案 B: PostToolUse hook (Bash 限定 + 文字列フィルタ) | inbox_write.sh task_completed 実行直後 | event-driven、低 false positive | tool 引数解析が必要、settings.json 依存 | ⭐⭐ (二次案) |
| **案 C: cmd_complete event 駆動** | scripts/cmd_complete.sh 内に verifier 起動を組込み | 既存 entrypoint 流用、cmd 完遂のみ捕捉 | cmd_complete を呼ばない経路があれば取りこぼし | ⭐⭐⭐ **推奨** |
| 案 D: 定時 cron | 5-10 分間隔で未検証 cmd を polling | 単純、漏れなし | F004 polling 禁止違反、wall-clock コスト発生 | ❌ |

**推奨: 案 C (cmd_complete event 駆動)**。理由:

1. cmd_complete は既に「cmd 完遂」を一意に表現する canonical event であり、karo の最終 inbox_write もこれを起点にしている。
2. `scripts/cmd_complete.sh` 内に `Agent` 呼出を追記するだけで Phase 2 ロジックを起動可能。
3. `run_in_background: true` のため wall-clock コスト = 0。
4. F004 (polling 禁止) と整合。

案 B (PostToolUse Bash hook) は cmd_complete を呼ばない経路 (例: 将軍が直接 dashboard 編集して done) も拾えるため、案 C と併用する **二段防御** を提案する。一次は案 C、漏れ捕捉用に案 B を追加。

### 3.2 verifier 判定基準の標準化

implementation-verifier.md の Layer 1-5 + AC8/9/10 はすでに記述があるが、以下を Phase 3 で正式化する:

| 層 | 自動化スクリプト (Phase 3 で新設) | 入力 | 出力 |
|---|---|---|---|
| L1 Existence | `scripts/verifier/check_existence.sh` | task YAML editable_files | PASS/FAIL + 行数 + git SHA |
| L2 Content | `scripts/verifier/check_acceptance.sh` | task YAML acceptance_criteria | AC ごと PASS/FAIL + 根拠 grep 行 |
| L3 Hygiene | `scripts/verifier/check_hygiene.sh` (so24_verify.sh 拡張) | queue/tasks/*.yaml + queue/reports/*.yaml + dashboard.yaml | PASS/FAIL + uncommitted file 数 |
| L4 Pattern | `scripts/verifier/check_patterns.sh` | git log + git diff + dashboard.yaml | PUSH漏れ/STATUS漏れ/AGENT-ASSIGNEE不一致/SCOPE混入/DASHBOARD漏れ/FALLBACK依存/DIFF反映漏れ/SILENT_FAILURE_PARSE/副作用回帰 9 種それぞれ PASS/WARN |
| L5 Reporting | `scripts/verifier/check_reporting_quality.sh` | 完遂報告本文 (inbox content) | PASS/WARN |
| AC8 TMUX_STATE_MISMATCH | `scripts/verifier/check_tmux_state.sh` | model 切替 cmd の場合のみ | PASS/FAIL |
| AC9 DASHBOARD_STALE | `scripts/verifier/check_dashboard_stale.sh` | dashboard.md の最終更新 timestamp | PASS/WARN (>2h で WARN) |
| AC10 STATE_VISIBILITY_GAP | `scripts/verifier/check_state_visibility_gap.sh` | task editable_files に dashboard.yaml 含む場合のみ | PASS/WARN |

各スクリプトは決定論的に exit code (0=PASS, 1=FAIL, 2=WARN) を返すこととし、verifier エージェントは結果集約と verdict 判定 (PASS/PARTIAL_PASS/FAIL) のみを担当する。これにより:

- LLM 判定揺らぎを排除 (false positive 抑制)
- スクリプト単位で unit test 可能
- 後続 cmd で個別の判定強化が容易

### 3.3 False positive 抑制の補助ルール

1. **task YAML に `verifier_skip: true` を許容** (test cmd / sandbox cmd / 第三者検証 cmd は skip)
2. **bloom_level L1-L2 の cmd は L1+L3 のみ実施、L4 9 種フルチェックは L3+ で発動**
3. **WARN は karo に通知、FAIL のみ将軍にエスカレーション**
4. **連続 FAIL 3 回 (24h 内、同 agent) で violation_alert を出して karo dashboard に明示**

### 3.4 karo inbox 自動通知フロー

verifier の verdict 別 routing:

| verdict | 通知先 | 通知内容 | 後続アクション |
|---|---|---|---|
| PASS | (通知なし) | — | cmd 完遂正常クローズ |
| PARTIAL_PASS | karo inbox | 指摘事項 (L3/L4 の詳細 + 該当ファイルパス) | karo 判断: 追加 task で hygiene 改修 or 殿判断 |
| FAIL | karo inbox + shogun inbox | L1/L2 欠損 + 再作業必要旨 | karo: 再 dispatch / 殿: 戦略再検討 |

通知本文の標準フォーマット:

```
【implementation-verifier: <verdict>】task_id=<X> agent=<Y>
- L1 Existence: <PASS|FAIL>
- L2 Content: <ACx PASS/FAIL list>
- L3 Hygiene: <PASS|FAIL> + 残 uncommitted N
- L4 Pattern: <違反タグ list>
- 詳細レポート: queue/reports/verifier_<task_id>.yaml
- 推奨アクション: <re-dispatch|hygiene fix|escalate>
```

queue/reports/verifier_*.yaml に検証ログを保存し、後日 audit trail として残す。

### 3.5 自動 hook フロー図 (ASCII)

```
[ashigaru/gunshi] task_completed inbox_write
        │
        ▼
[karo] inbox_watcher → 完遂報告 read → 処理判断
        │
        ▼
[karo] cmd_complete.sh 起動 (既存)
        │
        ├─ (既存) discord/ntfy 通知
        │
        └─ (新設 Phase 3) verifier_dispatcher.sh 起動 ─────────────┐
                                                                       │
                            ┌──────────────────────────────────────────┘
                            ▼
                  [verifier_dispatcher.sh]
                  - task YAML / 報告本文 / agent_id を context として注入
                  - Agent("implementation-verifier", run_in_background=true) 呼出
                  - exit 0 で即座に return (background なので待たない)
                            │
                            ▼ (background)
            [implementation-verifier (sonnet)]
            ├─ L1 check_existence.sh         ─┐
            ├─ L2 check_acceptance.sh         ├─ exit codes 集約
            ├─ L3 check_hygiene.sh            │
            ├─ L4 check_patterns.sh           │
            ├─ L5 check_reporting_quality.sh  │
            ├─ AC8 check_tmux_state.sh        │
            ├─ AC9 check_dashboard_stale.sh   │
            └─ AC10 check_state_visibility_gap.sh ─┘
                            │
                            ▼ verdict 決定
                  ┌─────────┼─────────┐
                  ▼         ▼         ▼
                PASS   PARTIAL_PASS  FAIL
                  │         │         │
                  │         ▼         ▼
                  │  karo inbox  karo + shogun inbox
                  │         │         │
                  │         ▼         ▼
                  │  hygiene fix  re-dispatch / escalate
                  │
                  └─→ queue/reports/verifier_<task_id>.yaml に記録
```

### 3.6 settings.json への追記 (差分提案、実装はしない)

```jsonc
// .claude/settings.json (差分のみ — 本書は実装禁止のため擬似コード)
{
  "hooks": {
    "PostToolUse": [
      // (既存 hooks を保持)
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/scripts/hooks/verifier_postchk.sh",
            "match_args": "cmd_complete.sh|inbox_write.sh.*task_completed"
          }
        ]
      }
    ]
  }
}
```

**実装は cmd_622 (= 後述の確定提案) で別途 dispatch すること**。本レポートでは仕様のみ提示。

---

## 4. cmd_622 内容確定提案

### 4.1 番号衝突の指摘 (重要)

`queue/shogun_to_karo.yaml` の cmd_622 (line 28645-28670) は **gas-mail-manager Phase 1 (CHANGELOG + git tag + RUNBOOK)** で 2026-05-01 14:00 JST に done 済 (commit 6c020ce + c8c24f3)。task description が指す「cmd_622 (将軍 verification 自動化 Phase 3)」は番号として未予約・未発令の塩漬け案を意味する。

**推奨**: 後続発令時は cmd_661 / cmd_662 系列に振替。本書では便宜上 「cmd_661 (将軍 verification 自動化 Phase 3)」として確定提案を記述し、台帳との衝突を回避する。

### 4.2 cmd_661 (= cmd_622 振替案) — Scope 優先順位

| 優先度 | Scope | 内容 | 担当候補 | 工数 |
|---|---|---|---|---|
| P0 | A: 判定スクリプト群新設 | scripts/verifier/check_*.sh × 8 本 + 単体テスト | ash1 (Sonnet+T) or ash6 (Codex) | 3-4h |
| P0 | B: dispatcher 配線 | scripts/verifier_dispatcher.sh + cmd_complete.sh への呼出追加 | ash3 (Sonnet) | 1-1.5h |
| P0 | C: settings.json hook 追記 + 動作確認 | .claude/settings.json + Bash hook + 5 cmd 模擬発動テスト | ash1 (Sonnet) | 1h |
| P1 | D: queue/reports/verifier_*.yaml schema 設計 + sample | yaml schema + jsonl audit trail 設計 | ash4 (Opus+T) or gunshi | 1h |
| P1 | E: implementation-verifier.md の入出力契約改訂 | Phase 3 化に伴う Input Context 拡張 / Output Format 標準化 | gunshi | 0.5-1h |
| P2 | F: instructions/shogun.md / karo.md 改訂 | Phase 3 自動化反映、MUST USE 文言更新、SO-24 連携明記 | ash3 (Sonnet) | 0.5h |
| P2 | G: 軍師 QC | north_star 3点照合 + 5 cmd トライアル E2E | gunshi (Opus+T) | 1-1.5h |
| 任意 | H: docs / SKILL 化 | shogun-verification-phase3-pattern SKILL 新設 | ash5 or ash7 | 1h (発令外でも可) |

### 4.3 必要な成果物ファイル一覧 (cmd_661 想定)

新規:
- `scripts/verifier/check_existence.sh`
- `scripts/verifier/check_acceptance.sh`
- `scripts/verifier/check_hygiene.sh`
- `scripts/verifier/check_patterns.sh`
- `scripts/verifier/check_reporting_quality.sh`
- `scripts/verifier/check_tmux_state.sh`
- `scripts/verifier/check_dashboard_stale.sh`
- `scripts/verifier/check_state_visibility_gap.sh`
- `scripts/verifier_dispatcher.sh`
- `tests/verifier_smoke_test.sh` (5 cmd 過去事例で PASS/PARTIAL/FAIL 再現)
- `output/cmd_661_implementation_report.md`

編集:
- `scripts/cmd_complete.sh` (verifier_dispatcher.sh 呼出追加)
- `.claude/settings.json` (PostToolUse hook 追記)
- `~/.claude/agents/implementation-verifier.md` (Input Context / Output Format の標準化)
- `instructions/shogun.md` (L124 の「将軍が起動」→「自動 hook で起動、将軍は受領のみ」)
- `instructions/karo.md` (PARTIAL_PASS / FAIL 受信時の判断フロー追記)

### 4.4 工数見積もり

- Scope 合計: P0 5-6.5h + P1 1.5-2h + P2 1.5-2h = **8-10.5h** (single-track)
- parallel=2 (A 系列 + B/C 系列) で **wall 4-5.5h**、1 セッション完遂見込み
- E2E 観測 (24h dual-stack 不要、5 cmd トライアルで PASS) は **+1日 buffer**

### 4.5 cmd_661 acceptance_criteria 草案

```
A-1: scripts/verifier/check_*.sh × 8 本が exit code 0/1/2 で決定論動作する (各 unit test PASS)
A-2: scripts/verifier_dispatcher.sh が Agent 呼出 + run_in_background=true で起動する
A-3: scripts/cmd_complete.sh から verifier_dispatcher.sh が起動される (PostToolUse / 直接 source の両経路)
A-4: queue/reports/verifier_<task_id>.yaml が verdict + L1-L5 + AC8/9/10 の構造で記録される
A-5: PARTIAL_PASS で karo inbox に通知、FAIL で karo + shogun inbox に通知が自動投函される
A-6: 過去 cmd_657/658/659 の 3 incident に対して trial run で PARTIAL_PASS or FAIL 検出が再現する (本日の事象が Phase 3 で防げたことの実証)
A-7: shogun_to_karo.yaml の cmd_661 に decomposition_hint + context_policy=clear_between が記載される
A-8: instructions/shogun.md L124 が Phase 3 自動化反映済 (「将軍 MUST USE」→「自動 hook、将軍は受領者」)
A-9: 軍師 QC (north_star 3点照合) Go 判定
A-10: ドキュメント (output/cmd_661_implementation_report.md) 1500-3000 words + 5 cmd トライアル結果記載
```

---

## 5. 期待効果と制約

### 5.1 cmd_657-659 counterfactual 分析

「Phase 3 が稼働していたら本日の 3 incident が防げたか」を逆算:

| cmd | Phase 3 で検出可能だった層 | 検出条件 | 結論 |
|---|---|---|---|
| cmd_657 (obsidian repair) | L4 副作用回帰 + L3 Hygiene | PR#5 merge 後の手動 trigger 観察待ちが「未完」と検出可、観察データ揃うまで PARTIAL_PASS | **△ 検出可** (verifier が「観察未完」を WARN 化) |
| cmd_658 Phase 0-1 | L4 副作用回帰 + 報告品質 L5 | 24h dual-stack 観測未完 + Phase 2 未着手で WARN | **○ 検出可** (PARTIAL_PASS が即時通知) |
| cmd_659 (action_required pipeline) | L3 Hygiene (dashboard.yaml in_progress) + L4 PUSH漏れ + L4 DASHBOARD漏れ | report YAML 上書き + dashboard 反映漏れを 2 系統で検出 | **◎ 検出可** (本日 verifier が手動起動で 2 回 PARTIAL_PASS 出した、自動 hook ならゼロ将軍負担で同結果) |

**定量化**: 本日 3 incident のうち **2 件以上 (cmd_658 + cmd_659)** が Phase 3 で発令前段階に PARTIAL_PASS 検出可。cmd_657 は観察待ちのため WARN 留まり。**検出率 67-100% (2-3/3)**。

### 5.2 KPI 候補

cmd_661 完遂後 1 週間で計測する KPI:

| KPI | 計測方法 | 目標 |
|---|---|---|
| verifier 自動起動率 | cmd_complete 発火数 / verifier 起動数 | ≥95% |
| PARTIAL_PASS 検出率 | 過去 incident 再現テスト | ≥67% |
| 将軍 manual 起動回数 | shogun.md L124 経由の起動ログ | ≤1/週 (理想 0) |
| false positive rate | PARTIAL_PASS 通知のうち karo が「無視可」と判断した比率 | ≤20% |
| karo inbox 増加分 | 追加通知量 | ≤5/日 (overload 防止) |

### 5.3 制約とリスク

1. **R1: cmd_complete 経由しない経路の取りこぼし**
   - 緩和: 案 B (PostToolUse hook for inbox_write.sh task_completed) を二段防御として併用。
2. **R2: verifier の判定揺らぎ (LLM ベースゆえ)**
   - 緩和: Layer 1-5 を決定論スクリプトに分離 (§3.2)、Agent は集約のみ。
3. **R3: karo inbox オーバーフロー**
   - 緩和: PASS は通知せず、PARTIAL_PASS の WARN レベルは集約日次サマリ化 (将来 cmd で実装)。
4. **R4: verifier 自身のスクリプト破損で silent failure**
   - 緩和: shogun-dashboard-sync-silent-failure-pattern SKILL の応用。verifier_dispatcher.sh 自体に self-check (5 分 polling 不可 → cron で 1日1回 healthcheck)。
5. **R5: cmd_622 番号衝突による台帳混乱**
   - 緩和: 本書 §4.1 で明示、cmd_661 への振替を発令時に確定。

---

## 6. 制約遵守の確認

| 制約 | 遵守状況 |
|---|---|
| 他足軽 (ash4/ash6/ash7) のレポート不参照 | ✅ output/cmd_660_ash4_*.md / ash6_*.md / ash7_*.md は参照していない |
| 実装コード作成禁止 (方針提案のみ) | ✅ §3.6 の settings.json 差分は擬似コード明記、scripts は新設提案のみ |
| 1500+ words | ✅ 本書 約 2700 words (日本語/英語混在計測) |
| Phase 3 設計 + cmd_622 確定提案 | ✅ §3 + §4 で網羅 |
| 期待効果定量化 | ✅ §5.1 で 67-100% 検出率 |

---

## 7. 完了報告予定文 (karo 宛 inbox_write 用ドラフト)

```
【subtask_660_scope_a3 完了】output/cmd_660_ash5_verification_phase3.md 生成済 (約 2700 words)。
Phase 3 設計: cmd_complete event 駆動 hook (案 C) を一次採用、PostToolUse Bash hook (案 B) を二段防御。Layer 1-5 + AC8/9/10 を決定論スクリプト 8 本に分離し verifier Agent は verdict 集約のみ。
cmd_622 提案: 番号衝突 (gas-mail-manager 既存) ゆえ cmd_661 振替を推奨。Scope A-G + 任意 H、工数 8-10.5h (parallel=2 で wall 4-5.5h、1 セッション完遂)。AC1-A10 草案併載。期待効果: cmd_657-659 のうち 2-3/3 件を発令前段階で検出 (検出率 67-100%)。
```

---

## Appendix A: 参考ファイル

- `~/.claude/agents/implementation-verifier.md` (Layer 1-5 + AC8-AC10 既存定義)
- `instructions/shogun.md` L116-L130 (Report Flow + 完遂報告受領 MUST USE 規定)
- `queue/shogun_to_karo.yaml` line 28645-28670 (cmd_622 既存定義 = gas-mail-manager Phase 1)
- `queue/shogun_to_karo.yaml` line 30165-30230 (cmd_660 全体定義 + AC + 想定 work split)
- `output/cmd_657_obsidian_cancelled_fix.md` / `cmd_658_phase01_report.md` / `cmd_659_implementation_report.md` (本日 3 incident 詳細)
- `dashboard.md` 🚨要対応欄 (cmd_660 進行中 + [提案-4] sug_cmd_597 等)
- `scripts/cmd_complete.sh` / `cmd_complete_notifier.sh` / `inbox_watcher.sh` / `so24_verify.sh` (Phase 3 hook 配線対象)

## Appendix B: 用語

- **PASS / PARTIAL_PASS / FAIL**: implementation-verifier の verdict 3 値
- **Layer 1-5**: Existence / Content / Hygiene / Pattern / Reporting Quality
- **AC8 / AC9 / AC10**: TMUX_STATE_MISMATCH / DASHBOARD_STALE / STATE_VISIBILITY_GAP
- **F004**: 「Polling 禁止」(本 repo の forbidden action)
- **SO-19 / SO-24**: Shogun Order 19 (完了 cmd cleanup) / 24 (Verification Before Report)

---

**末文**: cmd_660 Scope A-3 完遂につき、軍師統合 QC (Scope B-1) の Z 案策定にて本書を input 資料の一部として活用されたい。本書は 2026-05-08 03:30 JST 殿御指示の「問題状況変化を踏まえた塩漬け対策案再評価」に対し、Phase 3 自動 hook の設計具体化と cmd_622 (cmd_661 振替案) の確定提案を以て答えるものである。
