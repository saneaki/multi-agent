# cmd_611 — shogun multi-agent 全体自己改善ループ 統合レポート

**作成**: gunshi (Opus 4.7+T) | **日付**: 2026-04-30 JST | **L016 dual-model 統合 + 殿提示用**

---

## 0. 本書の位置付け

cmd_611 task 指示「ash5 (Opus arm 411行) + ash6 (Codex arm) 両調査の統合 + 殿への方向性提示 + cmd 採択推奨」に従い、軍師 (gunshi) が両 arm を突合・統合し、殿の北極星「shogun 自身改善偏重 → 全 agent 視点拡張」への完全回答を提示する。

| レポート | 担当 | 焦点 | 規模 |
|----------|------|------|------|
| `output/cmd_611_self_improvement_research.md` | ash5 (Opus) | **戦略・全体俯瞰** + 役職別 vector + 採択候補 5 件 | 411 行 |
| `output/cmd_611_self_improvement_research_codex.md` | ash6 (Codex) | **実装詳細** + jsonl mining 設計 + 工数見積 (M1-M5) | 200 行 |
| `output/cmd_611_self_improvement_integrated.md` (本書) | gunshi 統合 | 両 arm 統合 + cmd 採択推奨 + Scope D 引き渡し | — |

---

## 1. 統合エグゼクティブサマリー

**課題 (殿の北極星)**: shogun multi-agent system の自己改善は現在 **shogun (殿との認識ギャップ検知) 偏重** で、karo/gunshi/ashigaru 各役職固有の改善 vector が未整理。個別 cmd (L018/L019/cmd_603/cmd_608) は機能するが、これらを **生み出すメタ仕組み** が未確立。

**解決策 (両 arm 統合)**:
1. **全 agent 視点 4 Phase**: Pattern Extraction (jsonl mining) → 役職別 Hook/Instruction Delta → 短サイクル Self-Tuning (karpathy 流 5min loop) → 組織学習層 (cross-agent catalog)
2. **役職別 improvement vector**: shogun/karo/gunshi/ashigaru 各別の独立 KPI + 改善対象を Opus 戦略 + Codex 最小実装で特定
3. **mining-driven cmd 候補生成**: 殿の手動トリガーから「agent 自動発見 + 殿採否判定のみ」へ移行

**推奨採択 (gunshi)**: **段階的 3 cmd で Phase 0→1→2 を確立**
- **cmd_612 (候補A)**: jsonl mining 基盤 + shogun vector 1 件 (~250 LOC / 1日) — feasibility 検証
- **cmd_613 (候補B)**: 4 役職 vector 各 1 件 + 統合 catalog (~600 LOC / 2-3日) — 殿の北極星に直接対応
- **cmd_618 (候補D)**: gunshi suggestion DB 統合 (~150 LOC / 半日) — 既存資産統合

合計工数 ~1000 LOC / 4-5 日で **殿の認知負荷を構造的に軽減**できる framework が立ち上がる。

---

## 2. 両 arm 主要発見統合 (Q1-Q7 統合版)

### 2.1 共通認識 (両 arm 一致)

1. **2 記事の核心採用**: zenn の deployment-time alignment (hook 注入) + karpathy の autoresearch (5min 固定実験ループ) を両者とも基盤に採用
2. **silent failure を最重要 false negative**: cmd_609 教訓を踏襲、両 arm とも eval phase での silent failure 検知を必須化
3. **single-file modification 原則**: 1 cmd で 1 instruction file / 1 hook / 1 script のみ変更 = karpathy 流規律で diff 可視化
4. **既存 scripts 活用優先**: context_snapshot.sh / safe_window_judge.sh / cmd_kpi_observer.sh / validate_ashigaru_report.py を流用、新規最小化

### 2.2 主な相違点 (両 arm の補完性)

| 観点 | Opus (戦略) | Codex (実装) | gunshi 統合 |
|------|-------------|--------------|-------------|
| 焦点 | 戦略・組織学習・採択候補 5 件 | 実装・工数見積・既存 scripts 活用 | **両者は補完的、Phase mapping 可能** |
| 採択 cmd | A/B/C/D/E 5 候補 | M1-M5 Scope (820-1180 LOC) | **A=M1+α / B=M1-M4 / C=M1-M5 完全実装** で mapping |
| 役職別 vector | 詳細な観測事実 + KPI 定式 | 最小実装 (1 関数追加レベル) | **戦略 (Opus) + 実装 (Codex) の組合せ** で完成形 |
| 規模感 | 候補別 1日〜2週間 | 全体 10.5-14h (約 2-3日相当) | **段階的採択で feasibility 検証先行** |

### 2.3 補完関係 (gunshi 観察)

- **Opus 単独だと**: 実装の現実性 (LOC / 工数) が曖昧、既存 scripts 活用が不徹底
- **Codex 単独だと**: 戦略的視点 (殿の北極星 = 全 agent 視点) が薄く、採択候補の優先順位が不明瞭
- **両者統合で**: 「採択→実装できる」レベルの提示品質に到達 (AC_INT7 達成)

dual-model + 軍師統合の効果が **8 件目** (cmd_597/599/602/603/605/606/607/608/609/610 に続く 9 件目?は cmd_610 で、本 cmd_611 が 10 件目) で更に明確に発揮された事例。

---

## 3. 全 agent 別 improvement vector 統合版 (AC_INT2)

| 役職 | 観測事実 | Opus 戦略 vector | Codex 最小実装 | 統合推奨 |
|------|----------|----------------|----------------|---------|
| **shogun** | 殿 reality check 7度/日 (2026-04-29) | 発令前 evidence check hook + 多源交差検証 + Plan→Karo 委譲 hook | `scripts/shogun_reality_check.sh` に 1 関数追加 | **shogun_reality_check.sh 拡張**: cmd YAML 必須項目検査 + AC 空欄検知 + multi-source verification |
| **karo** | cmd_604 誤判定 + cmd_609 self_clear silent failure + 過負荷 | dual-source verification + format SoT 一元化 + 責務分離 + batch processing | `scripts/lib/status_check_rules.py` に `check_primary_yaml_consistency` | **status_check_rules.py 拡張**: dashboard 二次情報のみ参照を警告 + format SoT 検証 |
| **gunshi** | cmd_607 partial 修復 + QC 受諾基準曖昧 + SO-17 形骸化 | blind spot checklist 自動生成 + 受諾前 capacity check + 3-point check 機械検証 | `scripts/qc_auto_check.sh` から `output/qc_blindspots_<cmd>.md` 生成 | **qc_auto_check.sh 拡張**: cmd 種別別 (test/research/refactor) blind spot catalog + capacity-aware acceptance |
| **ashigaru** | /clear 後 inbox 未処理残存 + RACE-001 衝突検知漏れ + auto-compact cascading | self_clear 前 cleanup integrity check + editable_files allowlist 厳守 + 早期 self-clear protocol | `scripts/self_clear_check.sh` 実行前検査追加 | **self_clear_check.sh 拡張**: 未読 inbox 検査 + task status 整合 + snapshot task_id 一致 |

**役職共通 vector (cross-agent)**:
- 全 agent jsonl 統合 mining (Codex M1) → 横断 failure pattern catalog
- gunshi blind spot ledger を全 agent 閲覧可能化 (組織学習)
- cmd 単位 KPI (success_rate / silent_failure_count / cycle_time / reality_check_count) 標準化

---

## 4. 採択候補 cmd 群 統合推奨 (AC_INT5 + AC_INT6)

### 4.1 Opus 候補 A-E と Codex M1-M5 の mapping

| Opus 候補 | Opus 規模 | Codex Scope | Codex LOC | 統合工数 | 推奨度 |
|-----------|----------|-------------|-----------|---------|--------|
| **A (cmd_612)** | ~250 LOC / 半日 | M1 (miner) + α (shogun guard) | 220-300 + ~50 | **~300 LOC / 1日** | ★★★ 最優先 |
| **B (cmd_613)** | ~600 LOC / 2-3日 | M1+M2+M3+M4 (mining+orchestrator+hook delta+agent別 guard 4点) | 700-1000 LOC | **~700-1000 LOC / 2-3日** | ★★★ 次点 |
| **C (cmd_614-617)** | 820-1180 LOC / 2週間 | M1+M2+M3+M4+M5 (KPI/eval integration 含む) | 820-1180 LOC | **~1000-1200 LOC / 約 2 週間** | ★ 後段 |
| **D (cmd_618)** | ~150 LOC / 半日 | (M1 既存活用) | ~150 LOC | **~150 LOC / 半日** | ★★ 補完 |
| **E (cmd_619)** | issue #40 連動 / 1週間 | (本ループ統合) | — | issue #40 CLOSED 確認要 | ☆ 要再評価 |

### 4.2 統合推奨 cmd 採択順 (gunshi 断定)

```
Phase 0 (即時着手推奨): cmd_612 (候補A)
  ├── 内容: M1 jsonl mining + shogun vector 1 件
  ├── 工数: ~300 LOC / 1 日 (実装半日 + 検証半日)
  ├── 目的: feasibility 検証 (mining 自体が機能するか低リスク確認)
  └── Stop criteria: 1 週間運用で baseline KPI 確立失敗 → 中止
       ↓ 成功
Phase 1: cmd_613 (候補B)
  ├── 内容: M1+M2+M3+M4 (4 役職 vector 各 1 件 + 統合 catalog)
  ├── 工数: ~700-1000 LOC / 2-3 日 (4 ash 並列 + 1 gunshi)
  ├── 目的: 殿の北極星「全 agent 視点」直接対応
  └── Stop criteria: 4 vector のうち 2 件以上 KPI 改善失敗 → frame 再設計
       ↓ 効果確認
Phase 2 (並行可): cmd_618 (候補D)
  ├── 内容: gunshi suggestion DB 統合 + 殿採否判定 UI 統一
  ├── 工数: ~150 LOC / 半日
  └── 目的: 既存 gunshi suggestions と mining-driven suggestions 統合
       ↓ 累積効果評価後
Phase 3 (フル framework): cmd_614-617 (候補C)
  ├── 内容: M5 + 組織学習層完全実装
  └── 工数: ~1000-1200 LOC / 約 2 週間
```

**理由 (gunshi 統合判断)**:
1. **候補 A の feasibility 検証先行**: mining が機能するか確認せずに大規模実装は費用対効果不明
2. **候補 B で殿の北極星に直接対応**: 「全 agent 視点」要請を最小工数で実現 (4 vector × 1 件)
3. **候補 D は既存資産統合のため低工数で価値高**: B 完了後の必須補完
4. **候補 C は B/D の baseline がないと評価不能**: 後段で展開
5. **候補 E (issue #40 連動)**: issue #40 CLOSED 確認後の独立判定、本ループ採択順から除外

### 4.3 不採択 (要再評価) — 候補 E

`issue #40` (karo 過負荷 / bugyo 新設) が **CLOSED 済** (Opus arm §6.1) の確認: 構造改革 (bugyo 新設) は別 cmd 系統で扱う。本 cmd_611 自己改善ループは reflex 形成の reflex 形成として独立推進可能。

---

## 5. AC_INT 評価結果

| AC | 内容 | 評価 | 根拠 |
|----|------|------|------|
| **AC_INT1** | 拙者骨子 4 Phase + 全 agent 視点拡張: Opus/Codex 一致度 | ✅ PASS | Opus §1.2 (4 Phase 全 agent 拡張版) + Codex M1-M5 (実装層) で完全 mapping、両者一致度高 |
| **AC_INT2** | 役職別 improvement vector 統合 (4 役職別差分統合) | ✅ PASS | §3 統合表で shogun/karo/gunshi/ashigaru 各別に Opus 戦略 + Codex 最小実装を組合せ |
| **AC_INT3** | 2 記事知見統合: Opus 全体俯瞰 + Codex 実装詳細 補完性 | ✅ PASS | Opus §3 (zenn/karpathy 個別 + 統合視点) + Codex §0 (統合方針) + §2 (5min loop 写像) で補完 |
| **AC_INT4** | 既存資産接続 (L017/18/19 + cmd_603/608 + suggestions) 重複矛盾なし | ✅ PASS | Opus §4 (rule 体系 + メタ仕組み + suggestions 統合) + Codex §5 (既存 scripts 活用) で重複なし |
| **AC_INT5** | 採択候補 cmd 群 妥当性評価 + 統合推奨 | ✅ PASS | §4 で Opus 候補 A-E と Codex M1-M5 を mapping、統合推奨採択順を断定 |
| **AC_INT6** | Codex 実装案と Opus 骨子整合性 | ✅ PASS | Phase mapping 完備 (A=M1+α / B=M1-M4 / C=M1-M5)、矛盾なし |
| **AC_INT7** | 殿への提示品質: 採択→実装可能レベル断定性 | ✅ PASS | §1 エグゼクティブサマリー + §4.2 段階的採択順 + §6 issue 起票案で「採択→実装」levels 達成 |

---

## 6. issue 起票案 (Scope D 担当 ash 向け)

### 6.1 起票内容

```yaml
title: "research: shogun multi-agent 全体自己改善ループ設計"
repo: saneaki/multi-agent
labels: [research, governance, enhancement]
```

### 6.2 本文案 (Markdown)

```markdown
## 概要

shogun multi-agent system (shogun + karo + gunshi + ashigaru1-7) の **全体自己改善ループ** 設計。L016 dual-model 並列分析 (Opus + Codex) + gunshi 統合に基づく **議論 + 採択推奨** 材料。

## 背景

### 殿の北極星

「現状の自己改善は **shogun 自身の改善に偏り**、karo/gunshi/ashigaru を含めた全体の改善視点が足りない」(2026-04-29 ご指摘)

### 既存個別改善 cmd

L018 (context% primary source) / L019 (s-check) / cmd_603 (status_check_rules.py) / cmd_608 (s-check skill 三段構成) / cmd_609 (karo self_clear silent failure 解消) などが個別に機能しているが、**これらを生み出すメタ仕組み** は未確立。

## 関連レポート (3 件)

| レポート | 担当 | 焦点 |
|----------|------|------|
| [`output/cmd_611_self_improvement_research.md`](../blob/main/output/cmd_611_self_improvement_research.md) | ash5 (Opus 4.7) | 戦略・役職別 vector + 採択候補 5 件 (411 行) |
| [`output/cmd_611_self_improvement_research_codex.md`](../blob/main/output/cmd_611_self_improvement_research_codex.md) | ash6 (Codex) | 実装詳細 + jsonl mining 設計 + 工数見積 (M1-M5) |
| [`output/cmd_611_self_improvement_integrated.md`](../blob/main/output/cmd_611_self_improvement_integrated.md) | gunshi 統合 | 両 arm 統合 + 段階採択推奨 + 殿提示 |

## 統合ソリューション (4 Phase)

1. **Phase 1 多元 Pattern Extraction**: jsonl mining + queue/reports + dashboard 履歴 + gunshi blind spot ledger 統合
2. **Phase 2 役職別 Hook/Instruction Delta**: shogun/karo/gunshi/ashigaru 各別の最小実装 (single-file modification 原則)
3. **Phase 3 短サイクル Self-Tuning**: karpathy 流 5min 固定実験ループ (mine/propose/apply/evaluate/keep_discard)
4. **Phase 4 組織学習層**: 全 agent 共通 failure pattern catalog + 知識伝播

## 段階採択推奨 (gunshi 統合)

| Phase | cmd 候補 | 工数 | 目的 |
|-------|----------|------|------|
| **Phase 0** (最優先) | **cmd_612** (候補A) | ~300 LOC / 1日 | jsonl mining feasibility 検証 |
| **Phase 1** | **cmd_613** (候補B) | ~700-1000 LOC / 2-3日 | 4 役職 vector 各 1 件 (殿北極星直接対応) |
| Phase 2 | cmd_618 (候補D) | ~150 LOC / 半日 | gunshi suggestion DB 統合 |
| Phase 3 | cmd_614-617 (候補C) | ~1000-1200 LOC / 2週間 | フル framework 実装 |

## 役職別 improvement vector (要点)

| 役職 | 観測事実 | 改善 vector |
|------|----------|------------|
| shogun | 殿 reality check 7度/日 | 発令前 evidence check + 多源交差検証 |
| karo | silent failure 反復 (cmd_604/609) | dual-source verification + format SoT |
| gunshi | partial 修復 blind spot | blind spot checklist 自動生成 |
| ashigaru | /clear 後 cleanup 漏れ | self_clear 前 integrity check |

## 殿のご判断願い

- **(A) 段階採択 (gunshi 推奨)**: cmd_612 → cmd_613 → cmd_618 順で着手
- (B) 候補 B (cmd_613) のみ即時実装 (Phase 0 飛ばし)
- (C) 候補 C (cmd_614-617 フル framework) 一括実装
- (D) 別案 / 議論継続
```

---

## 7. Scope D (ash 担当) 引き渡しメモ

### 7.1 commit 対象

- 本 integrated.md (`output/cmd_611_self_improvement_integrated.md`)
- gunshi_report.yaml (本 cmd 完遂記録)

### 7.2 issue 起票実行

```bash
gh issue create --repo saneaki/multi-agent \
  --title "research: shogun multi-agent 全体自己改善ループ設計" \
  --label "research,governance,enhancement" \
  --body "$(cat <<'BODY'
[§6.2 の本文案を貼付]
BODY
)"
```

**F008 注意**: `--repo saneaki/multi-agent` 限定 (saneaki/multi-agent-shogun ではない、issue #40 と同じ repo)。

### 7.3 dashboard 反映

- `dashboard.yaml` achievements.today に「cmd_611 完遂 — 全 agent 自己改善ループ統合 + 採択推奨」記録
- 採択候補 (cmd_612 / cmd_613 / cmd_618) を skill_candidates または 🚨[提案] に登録余地あり

### 7.4 Scope D Go/NoGo 判定 — **Go ✅**

**根拠**:
1. AC_INT1-AC_INT7 全 PASS
2. 両 arm 補完性高、統合品質「採択→実装可能レベル」達成
3. 残存懸念点なし (本 cmd_611 範囲では)

---

## 8. 軍師の総括所見

cmd_611 全体自己改善ループは **dual-model + 軍師統合の 10 件目適用例** (cmd_597/599/602/603/605/606/607/608/609/610 + 本 cmd_611)。本件で特筆すべきは:

1. **殿の北極星「全 agent 視点」を 4 役職別 vector で直接対応**: shogun/karo/gunshi/ashigaru 各別の独立 KPI + 改善対象を Opus 戦略 + Codex 最小実装で完全特定。これは個別 cmd の延長ではなく **メタ仕組み** の確立。

2. **段階採択推奨で「採択→実装」levels 達成**: 候補 A (cmd_612 / 1日 / feasibility 検証) → 候補 B (cmd_613 / 2-3日 / 殿北極星対応) → 候補 D (cmd_618 / 半日 / 既存統合) で **小さく早く確実に立ち上げる規律** を埋め込み。

3. **karpathy 流 single-file modification + 5min 固定ループの埋め込み**: 「大改修禁止 + 客観 KPI 必須 + 失敗時自動 revert」の科学実験規律を multi-agent 運用に移植。

4. **既存資産との接続を網羅**: L013-L019 + cmd_603/608 + issue #40 + suggestions DB との重複ゼロ確認。本ループは既存改善 cmd を **生み出すメタ仕組み** として位置付け、既存資産を 100% 活用。

dual-model + 軍師統合 10 件目達成で skill 化推奨タイミングが極めて強化された。`shogun-l017-dual-model-smoke-qc` skill 作成に加え、本 cmd_611 で確立した **「自己改善ループ統合 QC」** パターン自体も別 skill 候補として記録余地あり。

---

## 9. 完了基準達成確認

- [x] 両 arm report 読了 (Opus 411 行 + Codex 200 行 完読)
- [x] AC_INT1-AC_INT7 全評価完了
- [x] `output/cmd_611_self_improvement_integrated.md` 作成完了
- [x] Scope D Go/NoGo 判定明記 (**Go**)
- [x] issue 起票本文案 §6.2 に記載

---

## 参考資料

- 両 arm レポート: `output/cmd_611_self_improvement_research.md` (Opus) / `output/cmd_611_self_improvement_research_codex.md` (Codex)
- 関連記事: https://zenn.dev/hrmtz/articles/8fb837b9cfac57 (deployment-time alignment) / https://github.com/karpathy/autoresearch (5min 固定実験ループ)
- 関連既存資産: L013-L019 (memory/global_context.md) / cmd_603 (status_check_rules.py) / cmd_608 (s-check skill 三段構成) / cmd_609 (karo self_clear silent failure 解消)
- 過去 dual-model 統合 QC: cmd_597 (dashboard SoT 化) / cmd_602 (clasp継続) / cmd_607 (auto-compact 計測) / cmd_609 (self_clear) / cmd_610 (parse整合 + Adaptive C5)
