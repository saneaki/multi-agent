# 自律判断支援設計: 自律コンテキスト衛生 (cmd_578)

**作成日**: 2026-04-24  
**担当**: ashigaru3 (subtask_578e)  
**分析元**: Scope A (ash4) + Scope B (ash1) + Scope C (ash6) QC=Go  
**north_star**: 外部介入なし。自律判断支援のみ。家老/軍師が自律的に /clear or /compact を判断できる decision support 機構設計。

---

## 1. 背景と north_star

### 問題

shogun マルチエージェントシステムでは、家老・軍師が tmux 常駐型の連続 context を持つ。
cmd の並列発令が増えるほど context が肥大化し、auto-compact が頻発する事態が生じていた (4/24 home実測: 4回/日)。

これに対する既存対策 (`safe_clear_check.sh` + `context_notify`) は:
1. karo では C2 fail-safe が常時 block (構造欠陥、後述 §2)
2. context_notify logs が 4/22 以降 0 bytes (計測不能)
3. gunshi では cron 未登録のため実行機会が限定的

### north_star (設計制約)

> **外部介入禁止。自律判断支援のみ。**
>
> - 家老/軍師が「/clear すべきか」を自律的に判断できる仕組みの設計
> - 殿・外部スクリプトによる強制発動 (emergency_mode) は採用しない
> - 既存インフラ (inbox_watcher.sh, safe_clear_check.sh) を最大活用

---

## 2. empirical 分析 (Scope A: ash4 成果)

### 2.1 家老 safe window — 4/24 empirical 再構築

| compaction 時刻 | 直前 C1 check | C1 (unread) | C2 verdict | 安全窓の有無 |
|----------------|-------------|------------|-----------|------------|
| 07:49 | 07:47 (-2min) | 0 | SKIP C2 (fail-safe) | ❌ C2 block |
| 08:11 | 08:09 (-2min) | 1 | SKIP C1 | ❌ C1 NG |
| 08:35 | 08:33 (-2min) | 0 | SKIP C2 (fail-safe) | ❌ C2 block |
| 09:23 | 09:21 (-2min) | 2 | SKIP C1 | ❌ C1 NG |

**empirical 発見**: C1=0 は 4 回成立したが、全て C2 fail-safe「task YAML not found」に block された。

### 2.2 家老 C2 fail-safe 構造欠陥 (新規発見)

```
karo の役割: dispatcher (cmd 全体管理)
→ persistent task YAML は存在しない (queue/tasks/karo.yaml は task execution 用ではない)
→ safe_clear_check.sh の C2 判定「task YAML not found → fail-safe SKIP」が karo で常時 block
→ C1=0 が達成されても /clear は発生しない
```

これは cmd_577 Scope B の tertiary 要因 (C3 dispatch_debt) より重大な **primary blocker**。

### 2.3 軍師 safe window — 4/22 empirical 確認

| ts | C1 | C2 | C4 | tool_count | verdict |
|----|----|----|----|-----------:|----|
| 08:23:13 | 0 | done | 7 (cmd_532 preserve) | - | SKIP C4 |
| 13:55:00 | 0 | done | 9 (cmd_532 preserve) | - | SKIP C4 |
| **14:48:37** | **0** | **done** | **6 (no preserve)** | **85** | **APPROVE ★** |

1 件の empirical safe window 確認。cmd_532 (preserve_across_stages) が in_progress から外れた直後 = QC cycle 区切りが safe window。

### 2.4 推奨事項 R1-R4

| 優先 | ID | タイトル | 根拠 |
|-----|----|---------|----|
| P1 | R1 | karo safe_clear_check.sh C2 logic 修正 | karo は dispatcher → C2 を dispatch_debt 判定に置換 |
| P2 | R2 | context_notify logs 復旧 | 4/22 以降 0 bytes、多変量条件の empirical 検証に必須 |
| P3 | R3 | gunshi safe_clear_check cron 登録 | 4/24 gunshi.log 記録なし、QC 区切り safe window を自動捕捉するため |
| P4 | R4 | 多変量条件の観測手段整備 | in_progress/dispatch_debt/直前5min_tool_calls が現行 check で計測不能 |

---

## 3. 多変量判定基準 (Scope B: ash1 成果)

### 3.1 家老 safe window: 5条件 (ALL_OF)

| ID | 条件 | 測定手段 |
|----|-----|---------|
| C1 | context_pct >= 70% | safe_clear_check.sh context_pct 出力 |
| C2 | inbox_actionable_unread == 0 *(P2 緩和)* | type in (task_assigned, blocked, escalate) かつ read=false の件数 = 0 |
| C3 | in_progress == 0 | dashboard.md 🔄進行中 テーブル参照 |
| C4 | dispatch_debt == 0 | karo_self_clear_check.sh dispatch_debt ロジック |
| C5 | karo_idle_for >= 5min | tmux capture-pane で karo pane 活動確認 |

> **P2 緩和**: 従来の "全未読=0" から "actionable 未読=0" へ。task_completed/report_completed 型は除外 → 並列 cmd 中でも達成可能な窓が大幅拡大。

### 3.2 家老 /clear vs /compact 選択指針

```
(最優先) context_pct >= 85%         → /compact 強制 (auto-compact 92% 回避)
          in_progress >= 1             → /compact 推奨 (進行中 cmd の文脈を保持)
          in_progress == 0 AND debt==0 → /clear 推奨 (全タスク完了後、最クリーン)
[70,85) AND C2-C5 全成立              → /clear 可 (safe window 内かつ余裕あり)
```

### 3.3 軍師 safe window: 4条件 (ALL_OF)

| ID | 条件 |
|----|-----|
| G1 | context_pct >= 60% |
| G2 | qc_cycle_boundary == true (gunshi task YAML が done 直後) |
| G3 | next_qc_not_started == true (inbox に task_assigned qc_request = 0件) |
| G4 | inbox_actionable_unread == 0 (P2 と同様) |

### 3.4 軍師 /clear vs /compact 選択指針

```
G1-G4 全成立 (QC cycle 区切り) → /clear 推奨 (次 QC は新 context で独立性確保)
QC 途中 (G2/G3 未成立)          → /compact のみ可 (QC 文脈を保持)
context_pct >= 85%               → /compact 強制
```

### 3.5 emergency_mode 正式却下 (P5)

**却下決定者**: 殿 (2026-04-24 明示指示)

| ID | 却下理由 |
|----|---------|
| R1 | north_star 違反: 外部スクリプトによる強制 /clear = 外部介入 |
| R2 | 殿明示指示: 「emergency_mode (強制 clear) は却下」 |
| R3 | 家老判断権尊重: 連続 cmd 処理中の状態情報は家老が最も把握 |
| R4 | 技術的問題: 92% LIMIT 到達時に dispatch_debt <= 2 の保証なし |

**代替**: P1 (karo C2 修正) + P2 (C1 緩和) + P3 (早め WARN 70%) の 3点セットで 92% 到達自体を構造的に防止。

### 3.6 情報提示: 推奨案 (c) self-notify

| 案 | 仕組み | 判定 |
|----|-------|-----|
| (a) role_context_notify 拡張 | dashboard に hint 追記 | passive、単独では効果薄 |
| (b) ntfy 通知 | 殿経由プッシュ通知 | **north_star 違反、採用不可** |
| **(c) self-notify** | karo inbox に context_advisory を自己投入 | **推奨: 自律的、north_star 完全準拠** |

**案 (c) の流れ**:
```
karo_self_clear_check.sh
  → safe window 条件検出
  → inbox_write.sh karo "safe window detected" context_advisory
  → inbox_watcher.sh が context_advisory を受信
  → /clear or /compact を実行
```
*context_advisory は P2 C2 判定の対象外 (actionable カウント外) → C2 条件に影響しない*

---

## 4. 分野知見 (Scope C: ash6 L012 成果)

### 4.1 K1-K5 要約

| ID | 知見 | 関連フレームワーク |
|----|-----|----------------|
| K1 | 自律 compact 一般パターン: token 閾値 trim / task 完了で履歴 drain / GroupChat 終了条件 | LangChain, CrewAI, AutoGen |
| K2 | orchestrator vs worker の役割差: orchestrator は履歴全体を保持、worker は task 局所文脈 | AutoGen manager/participant 分離 |
| K3 | safe window 検出標準: 「未読/未処理なし」「直近アクティビティ低下」「直後に再開可能」 | CrewAI task境界, LangGraph checkpointer |
| K4 | shogun 適用提言: 家老=LangGraph 型 running summary, 軍師=QC cycle 単位 summary→clear, 足軽=task done 直後 clear 維持 | — |
| K5 | shogun 固有課題: tmux 常駐で肥大化しやすい、YAML queue は safe window 判定に有利、未読 inbox と dispatch debt の同時監視が必要 | — |

### 4.2 shogun 固有マッピング

```
家老 (continuous orchestrator)
  → role_context_notify に「inbox_unread=0 AND in_progress<=1 AND dispatch_debt=0 AND recent_tool_calls=0」
    判定を追加し、safe window 時のみ /compact 推奨表示 (K4 LangGraph 型)

軍師 (QC cycle)
  → QC 完了イベントをトリガに「次 QC 未着手かつ未読なし」なら /clear 推奨。
    QC 途中は /compact のみ (K3 safe window 標準)

足軽 (task 完結)
  → 現行 self_clear_check 運用を維持 (non-regression)
```

### 4.3 実装時注意事項

- LangChain 旧 Memory API は deprecated → LangGraph/LangMem 寄りで統一
- AutoGen: 0.2 系と stable (0.4+) で API 差分あり。stable docs を正として版固定必須
- CrewAI: task 境界で memory drain 完了を待ってから reset

---

## 5. cmd_586 実装 AC draft

### 5.1 safe_window_judge.sh 仕様

```bash
# scripts/safe_window_judge.sh
# Usage: bash safe_window_judge.sh --agent-id <karo|gunshi|ashigaru{N}>
# Output: APPROVE / SKIP:<reason>
# Exit code: 0=APPROVE, 1=SKIP

AGENT_ID=$1  # --agent-id の値
CONTEXT_PCT=$(get_context_pct)  # role_context_notify.sh 参照

case $AGENT_ID in
  karo)
    # C1: context_pct >= 70
    # C2: actionable_unread == 0 (type filter: task_assigned/blocked/escalate)
    # C3: in_progress == 0 (dashboard.md 参照)
    # C4: dispatch_debt == 0 (karo_self_clear_check.sh ロジック)
    # C5: karo_idle_for >= 5min (tmux capture-pane)
    ;;
  gunshi)
    # G1: context_pct >= 60
    # G2: qc_cycle_boundary (task YAML status=done)
    # G3: next_qc_not_started (inbox qc_request=0)
    # G4: actionable_unread == 0
    ;;
  ashigaru*)
    # 既存 self_clear_check.sh を呼び出す (non-regression)
    bash scripts/safe_clear_check.sh --agent-id "$AGENT_ID"
    ;;
esac
```

### 5.2 karo C2 logic 修正方針

```
現行: task YAML not found → fail-safe SKIP
修正後: karo は dispatcher → C2 = dispatch_debt 判定 (unassigned subtask == 0)
実装: karo_self_clear_check.sh の C2 branch に karo 専用 logic を追加
      queue/tasks/karo.yaml 不在を SKIP ではなく OK として扱い、
      代わりに dispatch_debt カウントを C2 として評価
```

### 5.3 inbox_watcher.sh context_advisory ハンドラ

```bash
# inbox_watcher.sh への追加
case $TYPE in
  context_advisory)
    CONTEXT_PCT=$(extract_context_pct "$MSG_CONTENT")
    if [ "$CONTEXT_PCT" -ge 85 ]; then
      send_clear_or_compact "compact"  # 強制 compact
    else
      send_clear_or_compact "clear"    # safe window → /clear 推奨
    fi
    ;;
esac
```

### 5.4 実装優先度

| 優先 | 作業 | 推定コスト | 前提 |
|-----|-----|-----------|-----|
| P1 (最優先) | karo_self_clear_check.sh C2 logic 修正 (R1) | 0.3d | — |
| P2 | C1 判定を actionable_unread に限定 | 0.2d | — |
| P3 | inbox_watcher.sh context_advisory ハンドラ追加 | 0.3d | P1+P2 完了後 |
| P4 | context_notify logs 復旧 (R2) | 0.2d | — |
| P5 | gunshi safe_clear_check cron 登録 (R3) | 0.1d | — |
| P6 | safe_window_judge.sh 実装 | 0.5d | P1-P5 完了後 |

---

## 6. 今後の工程

### 6.1 cmd_586 依存関係

```
cmd_586: safe_window_judge.sh 実装 + karo_self_clear_check.sh 修正
  ├── 依存: cmd_578 (本設計 doc) ← 今回完了
  ├── 依存: 殿承認 (karo C2 修正方針の確認)
  ├── 依存: R2 context_notify logs 復旧 (empirical 検証のため)
  └── 並列: R3 gunshi cron 登録 (独立実施可)
```

### 6.2 優先度マトリクス

| cmd | 内容 | 優先度 | 前提 |
|-----|-----|-------|-----|
| cmd_586-P1 | karo C2 logic 修正 | critical | 殿承認 |
| cmd_586-P2 | actionable_unread C1 緩和 | high | — |
| cmd_586-P3 | inbox_watcher context_advisory | high | P1+P2 |
| cmd_R2 | context_notify logs 復旧 | medium | — |
| cmd_R3 | gunshi cron 登録 | medium | — |
| cmd_586 full | safe_window_judge.sh 実装 | low (後続) | P1-R3 完了後 |

### 6.3 成功指標

- 家老 auto-compact 頻度 ≤ 1回/日 (現行 4回/日 → 75% 削減)
- 軍師 safe window APPROVE rate ≥ 50% (現行 12.5%)
- 外部介入ゼロ: 全ての /clear, /compact が agent 自律発動

---

*作成: ashigaru3 / subtask_578e / 2026-04-24*  
*source: ashigaru4_report.yaml (Scope A) + ashigaru1_report.yaml (Scope B) + ashigaru6_report.yaml (Scope C)*
