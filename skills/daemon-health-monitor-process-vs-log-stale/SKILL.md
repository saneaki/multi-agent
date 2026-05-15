---
name: daemon-health-monitor-process-vs-log-stale
description: |
  [English] Use when health-checking idle / event-driven daemons whose own log mtime
  is unreliable. Separate `process_alive` from `log_stale`, then use a watcher_supervisor
  roll-call as a secondary heartbeat (`health_evidence`). GREEN = process alive AND
  roll-call ALIVE; never mark RED on log mtime alone.
  [日本語] idle / イベント駆動 daemon の log mtime が信頼できない時に使用。
  `process_alive` と `log_stale` を分離し、`watcher_supervisor` の roll-call を
  secondary heartbeat (`health_evidence`) として扱う。process生存 + supervisor
  roll-call ALIVE で GREEN 判定し、log mtime stale だけで RED にしない。
tags: [monitoring, daemon, health-check, watchdog, false-positive-prevention, shogun-system]
---

# Daemon Health Monitor (Process vs Log Stale)

idle / イベント駆動 daemon を「log mtime が古い = 死んでいる」と誤判定しないため、
**process 生存** と **secondary heartbeat (roll-call)** を組み合わせて GREEN 判定する pattern。

## When to Use

- 監視対象が「メッセージ来た時だけログを吐く」型 (`inbox_watcher` / `cmd_complete_notifier`
  / `shogun_inbox_notifier` / 各種 event watcher)。
- log mtime ベースの単純 RED 判定で **false positive (誤死亡判定)** が頻発する時。
- daemon 群を束ねる **supervisor** が roll-call ping を流せる時 (`watcher_supervisor.sh` 型)。

## Do NOT Use For

- **継続的にログを吐く** daemon (定期 cron / 常時ポーリング型) — log mtime だけで十分。
- supervisor を立てる余裕が無い単独 daemon — process 生存 + heartbeat ファイル touch で代替。
- 1 shot script の死活監視 — `cron --last-run` で足りる。

## Core Idea: 2軸 + 補助線

| 軸 | 判定 | 信頼性 | 何を見るか |
|----|------|--------|----------|
| **process_alive** | pgrep / Win32 Process 検索 | ◎ 高 | プロセス存在 = 仕事を受ける能力ある |
| **log_stale** | log mtime - now > threshold | △ 中 | idle daemon では false stale に化ける |
| **supervisor_roll_call** | watcher_supervisor が定期 ping → daemon が ALIVE 応答 | ○ 高 | idle でも生存確認できる secondary heartbeat |

### 判定マトリクス

| process_alive | log_stale | supervisor roll-call | 判定 | 意味 |
|:-:|:-:|:-:|:-:|:-:|
| ✅ | ❌ fresh | — | GREEN | 通常稼働 |
| ✅ | ✅ stale | ALIVE / REVIVED (recent) | GREEN | idle だが死んでいない |
| ✅ | ✅ stale | missing / old | YELLOW | idle 疑い、要 secondary 確認 |
| ❌ | — | — | RED | 確実に死んでいる |

`log_stale` だけでは **絶対に RED にしない**。process 死亡 OR roll-call 失敗のみが RED 条件。

## Implementation Reference

shogun 環境では `scripts/sh_health_check.sh` (L299-475) に実装済み。

### daemon_health.yaml schema (抜粋)

```yaml
- name: inbox_watcher
  proc_pattern: "scripts/inbox_watcher.sh"
  log_path: logs/inbox_watcher.log
  red_after: 600           # log_stale RED 閾値 (秒)
  yellow_after: 300        # log_stale YELLOW 閾値 (秒)
  supervisor_roll_call: true
  supervisor_roll_call_log: roll_call.log
  supervisor_roll_call_green_after: 600
  alive_log_stale_status: green_with_roll_call
```

### 判定アルゴリズム (sh_health_check.sh L439-465 要約)

```python
process_alive = proc_alive(proc_pat) if proc_pat else True
if not process_alive:
    status = "red"  # 死亡確定
elif log_age > red_after:
    if supervisor_roll_call and roll_call_state in ("ALIVE", "REVIVED") \
       and roll_call_age <= roll_call_green_after:
        status = "green"  # idle だが ALIVE
    else:
        status = "yellow"  # 要確認
elif log_age > yellow_after:
    status = "yellow"
else:
    status = "green"

# health_evidence にすべての軸を残す (audit 可能性)
health_evidence = f"process_alive={process_alive}; pid_alive={pid_alive}; " \
                  f"log_age={fmt_age(age)}; " \
                  f"supervisor_roll_call={roll_call_state} age={fmt_age(roll_call_age)}"
```

### Supervisor 側 (`scripts/watcher_supervisor.sh` 抜粋)

```bash
roll_call_check() {
    for agent in "${WATCHED_DAEMONS[@]}"; do
        # daemon に ping → 応答待ち → ALIVE/REVIVED/DEAD を判定
        echo "[ROLL-CALL] [$timestamp] ${agent}: ${state}"
    done
}

# main loop
while true; do
    roll_call_check 2>&1 | tee -a "$SCRIPT_DIR/logs/roll_call.log" || true
    sleep "$INTERVAL"
done
```

## Battle-Tested Examples

| cmd | 状況 | 結果 |
|-----|------|------|
| cmd_695 | `inbox_watcher` を log mtime のみで監視 → idle で頻繁に false RED 化 | 2軸 + roll-call の health_evidence pattern を導入、誤死亡判定ゼロに |
| cmd_complete_notifier | 同型 idle daemon | 同 pattern で false RED 抑止 |
| shogun_inbox_notifier | 将軍 inbox 専用 nudge daemon | health_evidence で `process_alive=True; roll_call=ALIVE` を可視化 |

## Anti-Patterns

- **❌ log mtime だけで RED 判定**: idle daemon が常に RED になり監視疲労 + 真の death に
  気付けなくなる。
- **❌ process_alive だけで GREEN**: ハングしてプロセスは残っているが ping にも応答しない
  ゾンビ daemon を見逃す。
- **❌ roll-call ログを daemon 自身のログに書き込む**: 自分の log mtime を自分で
  更新するため log_stale 軸が機能不全になる。**別ファイル** (`roll_call.log`) に分離する。
- **❌ supervisor を監視しない**: supervisor 自身が死ぬと全体が静かに腐る。supervisor は
  cron + heartbeat ファイル touch などの **継続書込型** で別軸監視する。

## Tuning Notes

| パラメータ | 目安 | 注意 |
|------------|------|------|
| `red_after` | 既知 idle 上限の 2-3 倍 | 短すぎると false RED |
| `yellow_after` | `red_after` の半分 | 早期警戒用 |
| `roll_call_green_after` | roll-call interval の 2-3 倍 | supervisor 1 cycle 飛ばしを許容 |
| roll-call interval | 60-300 秒 | 短すぎると supervisor CPU 浪費、長すぎると false YELLOW |

## Related Skills

- `shogun-bash-daemon-restart-subcommand-pattern` — daemon 起動・再起動の共通骨格
- `shogun-systemd-user-cron-healthcheck-pattern` — systemd 側 watchdog 連携
- `shogun-silent-failure-audit-pattern` — silent failure 全般の防止文化

## Source

- ash3 cmd_695: idle daemon false RED 問題の構造解消提案
- `scripts/sh_health_check.sh` L299-475: production 実装 (`supervisor_roll_call_latest` /
  判定マトリクス / health_evidence)
- `scripts/watcher_supervisor.sh` L140-216: roll_call_check + main loop
- skill_history.md L15/L18/L19: 「ash3 cmd_695 抽出」承認待ち登録 (silent duplicate あり、
  cmd_726d で整理対象)
