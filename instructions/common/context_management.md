# Context Management (3-Layer Standard)

> cmd_535 Phase 3 で制定。設計書: output/cmd_535_context_management_design.md

## 1. 優先順

```
/clear  >  self /compact  >  auto-compact
```

- **/clear** が最優先。コスト最小・context 完全リセット
- **self /compact** は /clear 不可時の次善策(Role 別 Instruction で重要情報を保持)
- **auto-compact** は真の最後の砦。すべての能動的手段が尽きた時のみ

---

## 2. 段階閾値マトリクス

| Role \ 閾値 | 50% | 70% WARN | 80% RE_CHECK | 85% FORCE | 92% LIMIT |
|------------|-----|----------|--------------|-----------|-----------|
| **shogun** | 通常 | compact_suggestion inbox 投入 | safe_clear_check 再実行(提案のみ) | 殿自身の判断で /compact (Instruction 提示) | compact_exception_check 3 条件判定 |
| **karo** | 通常 | dashboard に警告 | safe_clear_check(dispatch debt 優先チェック) | /compact (Instruction = dispatch debt + cmd 状態 preserve) | compact_exception 発動 or 受容 |
| **gunshi** | 通常 | dashboard に警告 | safe_clear_check(preserve_across_stages なら SKIP) | /compact (Instruction = AC 評価メモ preserve) | compact_exception 発動 or 受容 |
| **ashigaru** | 通常 | 注意喚起 log | safe_clear_check(task 完了後なら即 /clear) | /compact (Instruction = progress preserve, ただし稀) | auto-compact 受容 |

### 遷移ルール

- 閾値超過ごとに該当アクションを 1 回だけ実行(hysteresis 防止)
- compact 実行後は counter reset
- 50% 以下は意識せず通常運用

---

## 3. /clear 安全条件

### 3.1 共通 4 条件 (AND、全 Role 必須)

| # | 条件 | 判定ロジック | 判定不能時の fallback |
|---|------|-----------|------|
| C1 | `inbox=0` | `queue/inbox/{agent_id}.yaml` の `read:false` エントリ数 = 0 | YAML parse 失敗時は SKIP (fail-safe) |
| C2 | `in_progress=0` | `queue/tasks/{agent_id}.yaml` の `status` が `idle` または `done` | status 未定義 → SKIP |
| C3 | `dispatch_debt=0` | Karo 限定: `queue/tasks/*.yaml` に `status:blocked` かつ `blocked_by` が全 `done` の obligation なし | scan 失敗 → SKIP |
| C4 | `context_policy=clear_between` | 進行中 cmd の `shogun_to_karo.yaml` を regex 抽出、`preserve_across_stages` cmd が 1 件もない | 検出不能 → SKIP |

### 3.2 Role 別追加条件

| Role | 追加条件 | 根拠 |
|------|---------|------|
| shogun | 自動 /clear 禁止(提案型のみ) | F001 + cmd_531 設計 |
| karo | tool_count > 50 | ashigaru 閾値 30 より高め(多工程管理) |
| gunshi | tool_count > 30 + preserve_across_stages 継続なら SKIP | QC 複数段の文脈保持 |
| ashigaru | tool_count > 30 | 既存 self_clear_check.sh 踏襲 |

### 3.3 判定スクリプト

```bash
bash scripts/safe_clear_check.sh --agent-id <id> --tool-count <n>
```

- exit 0: APPROVE (clear 可)
- exit 1: SKIP (clear 不可)
- ログ: `/tmp/safe_clear_check_{agent_id}.log`

---

## 4. Self /compact 発動手順

85% FORCE 到達時:

```bash
# 1. compact 許可確認
bash scripts/compact_exception_check.sh

# 2. context snapshot 保存
bash scripts/context_snapshot.sh write $AGENT_ID \
  "<approach>" "<progress>" "<decisions>" "<blockers>"

# 3. /compact 発動 (Role 別 Instruction を指定)
/compact <Role別Instruction>
```

詳細: [instructions/common/compact_exception.md](compact_exception.md)

---

## 5. Role 別 /compact Instruction (preserve 項目)

### 5.1 共通 preserve 項目 (全 Role)

1. agent_id / role / speech_style
2. 現在の task_id + parent_cmd + status
3. 禁止事項リスト (F001-F006 / D001-D008)
4. snapshot 参照先: `queue/snapshots/{agent_id}_snapshot.yaml`

### 5.2 Role 別追加 preserve 項目

| Role | 追加項目 | 根拠 |
|------|---------|------|
| shogun | 人格/口調(沈着威厳) + 直近 decision log | F002 遵守文脈 |
| karo | dispatch debt list(blocked tasks) + cmd 進行状況 | Issue #32 対策 |
| gunshi | 進行中 QC の AC 評価メモ + sug 抽出途中データ | 多段 QC の継続性 |
| ashigaru | 実装アプローチ + progress + blockers | snapshot で既に担保 |

### 5.3 Instruction テンプレート例 (gunshi)

```
あなたは gunshi (軍師) です。
現在のタスク: {task_id} (parent: {parent_cmd})
禁止事項: F001(将軍直報), F002(人間直接連絡), F003(足軽管理), F004(ポーリング), F005(コンテキスト読飛ばし)
snapshot: queue/snapshots/gunshi_snapshot.yaml を参照して作業を再開せよ。
QC途中の場合、snapshot の ac_evaluation_notes フィールドから継続せよ。
```

---

## 6. Auto-compact 閾値 (92%)

```bash
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=92
```

- デフォルト 83% → 92% に引上げ
- 9% の追加猶予で 85% self /compact が確実に発動可能
- 反映先: `~/.bashrc` + `scripts/setup-vps.sh`
- 実装状況: 別 subtask (535e) で対応予定

### 引上げ根拠

| リスク | 影響 | 緩和策 |
|--------|------|--------|
| summary 生成失敗 | 中 | 85% self /compact で事前 summary 済なら影響小 |
| token コスト増 | 低〜中 | /clear 頻度増で総コスト減の見込み |
| snapshot race | 低 | pre_compact hook で snapshot 強制完了後に発動 |

---

## 7. 参照

- 設計書全文: `output/cmd_535_context_management_design.md`
- /clear 実装: `scripts/self_clear_check.sh`, `scripts/gunshi_self_clear_check.sh`
- compact 例外: `instructions/common/compact_exception.md`
- Issue #32: お見合い恒久対策 (pre/post compact hook — 別 subtask 535c で実装予定)
