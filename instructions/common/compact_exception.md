# /compact 例外運用 (all agents)

## 前提

本システムは **`/clear` 主軸運用**。`/compact` は文脈要約で品質劣化リスクを伴うため、原則使わない。ただし `context_policy: preserve_across_stages` な多段 cmd 進行中に context が逼迫した場合、**文脈継続の最終手段** として例外的に許可する。

## 使用基準 (全 AND)

| cond | 内容 |
|------|------|
| cond_1 | `shogun_to_karo.yaml` に `status: in_progress` + `context_policy: preserve_across_stages` な cmd が1件以上 |
| cond_2 | 現在の context 使用率 > 80% |
| cond_3 | `/clear` 実施不能 (preserve 要件で文脈喪失不可。cond_1=TRUE なら TRUE) |

判定は `scripts/compact_exception_check.sh <agent_id> <context_pct>` を呼び、**exit 0** を確認してから `/compact` を実施する。exit 1 の場合は **`/clear` 可能性を検討せよ**。

## 実施手順

```bash
# Step 1: 事前チェック (snapshot 書込 + ログ append も自動実施)
bash scripts/compact_exception_check.sh ashigaru4 85
# exit 0 ならば →

# Step 2: /compact 実施
/compact

# Step 3: 復帰後に snapshot を確認して作業再開
bash scripts/context_snapshot.sh read ashigaru4
```

`compact_exception_check.sh` は PASS 時に自動で `context_snapshot.sh write` を呼ぶ。`/compact` 発動前の手動 snapshot は不要。

## ログ

発動時(exit 0 時)は `logs/compact_exceptions.log` に1行 append:

```
{timestamp}|{agent_id}|{cmd_id}|{context_pct}|{reason}
```

## 事後レビュー (必須)

`/compact` を発動した場合、当該 cmd 完了時に軍師(gunshi)が以下を QC する:

1. 発動理由が妥当だったか (3条件を満たしていたか)
2. `/clear` ですんだのに `/compact` を選択していないか
3. 発動後の復帰が snapshot で機能したか
4. 次回以降の設計改善案 (例: cmd 分割で `/clear` 可能化)

レビュー結果は dashboard.md の 🛠️スキル候補 もしくは 🚨[提案] に記載する。

## 禁忌

- **事前チェックなしの `/compact` 禁止**: `compact_exception_check.sh` の exit 0 確認なしで `/compact` を打たない
- **cond_2 (80%) 未満での発動禁止**: 閾値未満なら `/clear` を先に検討
- **preserve_across_stages 不在時の発動禁止**: preserve 要件なき cmd は `/clear` で安全にリセット可
