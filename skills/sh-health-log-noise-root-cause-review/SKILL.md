---
name: sh-health-log-noise-root-cause-review
description: >
  [English] Use when shogun sh-health check shows persistently high fail7d counts.
  Classifies root causes into 5 categories (actual failure / log false positive /
  old continuation line / filename false positive / duplicate log) and sets repair priority.
  [日本語] shogun sh-health の fail7d 高止まりを調査する時に使用。
  原因を5分類して修復優先順位を付ける手順。
tags: [shogun, sh-health, health-check, log-analysis, monitoring, fail7d]
---

# sh-health Log Noise Root Cause Review

shogun の sh-health チェックで `fail7d` カウントが高止まりする場合の根因分類と修復優先順位付け。

## Problem Statement

`sh` health チェック (`scripts/sh_health.sh` 等) で `fail7d` が下がらない。
実際の障害だけでなく、ログ誤検出が多く含まれる可能性がある。

## 5分類による根因分析

### 分類マトリクス

| 分類 | 説明 | 優先度 | 対処 |
|------|------|--------|------|
| **A: 現在障害** | 実際のスクリプト失敗・エラー | P1: 即時修復 | スクリプト/設定修正 |
| **B: ログ誤検出** | エラーパターンに誤マッチする正常ログ | P2: 検出ロジック修正 | grep パターン見直し |
| **C: 古いcontinuation line** | 7日以上前の古いログが集計に残存 | P3: ログローテーション | logrotate or TTL設定 |
| **D: filename false positive** | ファイル名・パス文字列がエラーとして検出 | P2: パターン精緻化 | `--` 区切り or exact match |
| **E: 重複ログ** | 同一エラーが複数エントリとしてカウント | P3: dedup追加 | `sort -u` or `uniq` |

### 手順

**Step 1: 生ログ確認**

```bash
# 直近7日分のfailログを収集
grep -rn "ERROR\|FAIL\|exit [1-9]" logs/ --include="*.log" \
  | grep "$(date -d '-7 days' '+%Y-%m-%d')\|$(date '+%Y-%m-%d')" \
  > /tmp/fail7d_raw.txt
wc -l /tmp/fail7d_raw.txt
```

**Step 2: 分類スクリプト**

```bash
# A: 現在障害 (直近24h)
grep "$(date '+%Y-%m-%d')" /tmp/fail7d_raw.txt | wc -l

# B: ログ誤検出 (ERROR文字列を含むが正常完了ログ)
grep -E "ERROR.*OK|ERROR.*success|FAIL.*skipped" /tmp/fail7d_raw.txt

# C: 古いcontinuation line (7日以上前のタイムスタンプ)
awk -F: '{print $1}' /tmp/fail7d_raw.txt | sort -u | head -20

# D: filename false positive (パス文字列がエラー判定)
grep -E "/.*ERROR|/.*FAIL" /tmp/fail7d_raw.txt | grep -v "^.*\]: "

# E: 重複ログ (同内容の複数エントリ)
sort /tmp/fail7d_raw.txt | uniq -d | wc -l
```

**Step 3: 分類カウントと優先順位**

```bash
cat > /tmp/fail7d_classification.md << EOF
# fail7d 分類結果 $(date '+%Y-%m-%d')
- A (現在障害): X件 → 即時修復
- B (ログ誤検出): X件 → パターン見直し
- C (古いcont.line): X件 → logrotate確認
- D (filename fp): X件 → grep精緻化
- E (重複ログ): X件 → dedup追加
EOF
```

## 修復アクション例

### B: ログ誤検出パターン修正

```bash
# 現在の検出パターン (問題あり)
grep "ERROR" logs/health.log

# 修正: 完了マーカー付きを除外
grep "ERROR" logs/health.log | grep -v "OK$\|success\|completed"
```

### C: ログローテーション設定

```bash
# /etc/logrotate.d/sh-health
/home/ubuntu/shogun/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

### E: 重複ログ dedup

```bash
# health check 集計時に dedup
grep "FAIL" logs/health.log | sort -u | wc -l  # uniq count
```

## sh-health 健全性チェックリスト

- [ ] A (現在障害) = 0件確認
- [ ] B (誤検出) パターン修正済み
- [ ] fail7d ≤ 実 fail 件数の1.2倍 (20%以内の誤検出)
- [ ] ログローテーション動作確認 (7日以上古いエントリなし)
- [ ] 重複エントリ dedup 適用済み

## Battle-Tested Examples

| cmd | Situation | Result |
|-----|-----------|--------|
| cmd_694 | sh health fail7d 高止まり調査 | 5分類で根因特定、B/C/E がノイズの大半と判明 |

## Related Skills

- `shogun-bash-daemon-restart-subcommand-pattern` — shogun bash デーモン操作パターン
- `shogun-agent-status` — エージェント状態監視

## Source

- cmd_694: ash1 Codex review。fail7d 高止まりの根因を5分類して修復優先順位付けを実証
