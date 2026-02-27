# cmd_249: Googleカレンダー同期WF v4.1 429エラー修正報告

**実施日**: 2026-02-28
**担当**: ashigaru7 (subtask_249a)
**対象WF**: Googleカレンダー同期フロー v4.1 (id: `calendar-sync-v32`)

---

## 問題概要

syncToken取得ノードで3日連続 22:00 JST頃に429エラーが発生。

| exec ID | 発生時刻 (UTC) | ステータス |
|---------|--------------|-----------|
| 4096 | 22:00 JST相当 | error |
| 5859 | 22:00 JST相当 | error |
| 5964 | 2026-02-27T22:00:52Z | error |

**エラー**: "The service is receiving too many requests from you" (Google API 429)

---

## 根本原因

WFが毎時 `:52` に発火しており、Google Sheets/Calendar API の呼び出しが他WFと重なりレート制限に到達。

---

## 修正内容

### 1. cron式変更（時間分散）

```
修正前: {"field": "hours"}          # 毎時 :52 発火
修正後: {"field": "cronExpression", "expression": "3 * * * *"}  # 毎時 :03 発火
```

→ 22:52 → 22:03（次回から）で他WFとの競合を回避

### 2. syncToken取得ノード waitBetweenTries 短縮

```
修正前: waitBetweenTries: 60000  (60秒待機)
修正後: waitBetweenTries: 5000   (5秒待機)
retryOnFail: true, maxTries: 3 は変更なし
```

→ 一時的な429エラー発生時の回復速度を改善

---

## 実施結果

- n8n API PUT: 200 OK
- WF active状態: True（継続稼働中）
- GitHub Issue: https://github.com/saneaki/n8n/issues/25 (作成・クローズ済み)

---

## 参照スキル

- `~/.claude/skills/shogun-n8n-cron-stagger.md` (cron分散パターン)
- `~/.claude/skills/shogun-n8n-api-field-constraints.md` (PUT許可フィールド)
