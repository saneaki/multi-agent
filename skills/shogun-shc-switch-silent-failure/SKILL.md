---
name: shogun-shc-switch-silent-failure
description: >
  Use when shc deploy or switch_cli.sh silently fails on busy tmux panes without
  raising an error. Covers detection (is_pane_busy), halt behavior, || true removal,
  and post-deploy verification patterns for shogun shell scripts.
tags: [shogun, tmux, silent-failure, shc, switch-cli, shell]
---

# shogun-shc-switch-silent-failure

## Problem Statement

`shc.sh deploy` および `switch_cli.sh` は busy な tmux pane に対してコマンドを送信する際、
エラーを発生させずに処理をスキップする **silent failure** が発生する。
症状: デプロイ・モデル切替が成功したように見えるが設定が反映されない。

## Root Causes

| RCA | 根因 | 影響 |
|-----|------|------|
| RCA-1 | `switch_cli.sh` が busy pane チェックなしで `tmux send-keys` を実行 | コマンド未送信で返却 |
| RCA-2 | `shc.sh` の deploy ループ内で `|| true` が失敗を隠蔽 | エラー伝播なし |
| RCA-3 | post-deploy verify がなく、成功可否を確認しない | サイレント不整合 |

## Detection Pattern

```bash
# pane が busy か判定
is_pane_busy() {
    local pane="$1"
    tmux display-message -t "$pane" -p '#{pane_current_command}' 2>/dev/null \
        | grep -qvE '^(bash|zsh|sh)$'
}

# タイムアウト付き待機
wait_for_idle() {
    local pane="$1" timeout="${2:-30}"
    local elapsed=0
    while is_pane_busy "$pane"; do
        sleep 1
        ((elapsed++))
        [ "$elapsed" -ge "$timeout" ] && return 1
    done
    return 0
}
```

## Fix Pattern

### 1. || true 除去 + halt 化

```bash
# BEFORE (silent failure):
shc.sh deploy --settings-only || true

# AFTER (halt on error):
shc.sh deploy --settings-only || {
    log_error "shc deploy failed"
    halt "shc deploy failed"
}
```

### 2. Post-deploy Verification

```bash
# デプロイ後に設定反映を確認
verify_deploy() {
    local expected_model="$1"
    local actual
    actual=$(python3 -c "
import yaml, sys
with open('config/settings.yaml') as f:
    s = yaml.safe_load(f)
print(s.get('cli', {}).get('agents', {}).get('karo', ''))
")
    [ "$actual" = "$expected_model" ] || {
        log_error "post-deploy verify failed: expected=$expected_model actual=$actual"
        return 1
    }
}
```

### 3. switch_cli.sh busy pane guard

```bash
send_to_pane() {
    local pane="$1" cmd="$2"
    wait_for_idle "$pane" 30 || {
        log_warn "pane $pane still busy after timeout, skipping"
        return 1
    }
    tmux send-keys -t "$pane" "$cmd" Enter
}
```

## Audit Script Pattern

```bash
# silent failure 有無を静的チェック
bash scripts/audit_silent_failure.sh
# 出力例: "SILENT_FAILURE: switch_cli.sh:42: || true hides error"
```

## Battle-Tested Examples

| cmd | 状況 | 結果 |
|-----|------|------|
| cmd_705 | shc deploy が busy pane で silent failure、設定未反映 | is_pane_busy + wait timeout 実装で解消 |
| cmd_717 | shx の親スクリプト (shutsujin_departure.sh) で `|| true` 隠蔽を発見 | audit_silent_failure.sh 導入 + halt 化で恒久修正 |

## Related Skills

- `shogun-tmux-busy-aware-send-keys` — tmux send-keys の busy pane 全般ガード
- `shogun-nondestructive-tmux-smoke` — active session を破壊しない smoke test 実行パターン
- `shogun-bash-daemon-restart-subcommand-pattern` — daemon 系スクリプトの再起動パターン

## Source

- cmd_705: ash4 による shc/switch_cli.sh silent failure RCA と初回修正
- cmd_717: ash 系による shx 親スクリプト是正 + audit_silent_failure.sh 導入
