---
name: shogun-nondestructive-tmux-smoke
description: >
  Use when smoke-testing shu/shk/shx/shp/shc shell scripts without destroying the
  active shogun/multiagent tmux session. Pattern: isolated tmux server
  (tmux -L <smoke> -f /dev/null) + SHOGUN_TMUX env hook + setup-only/dry-run mode.
tags: [shogun, tmux, smoke-test, testing, shell, nondestructive]
---

# shogun-nondestructive-tmux-smoke

## Problem Statement

`shu` / `shk` / `shx` / `shp` などのシェルスクリプトを修正後に smoke test を実行すると、
live `shogun` / `multiagent` tmux session を破壊するリスクがある。
通常の `bash scripts/smoke_xxx.sh` 実行は:

- live セッションの pane を kill する可能性
- `config/settings.yaml` を実際に書き換える可能性
- `switch_cli.sh` が real pane に send-keys する可能性

## Pattern: Isolated tmux Server + Env Hook

### 1. 独立 tmux サーバー

```bash
# 本番 session と完全分離した tmux server を起動
export SHOGUN_TMUX="tmux -L smoke_$$ -f /dev/null"
$SHOGUN_TMUX new-session -d -s test -x 220 -y 50
```

- `-L smoke_$$`: 独立サーバー名 (PID付きで衝突回避)
- `-f /dev/null`: 設定ファイルを読まない
- 本番 `shogun` / `multiagent` session には一切影響しない

### 2. スクリプト側の SHOGUN_TMUX フック

```bash
# shutsujin_departure.sh / switch_cli.sh 内
TMUX_CMD="${SHOGUN_TMUX:-tmux}"

# pane 送信時に本番 tmux ではなく smoke server を使用
$TMUX_CMD send-keys -t "$pane" "$cmd" Enter
```

`SHOGUN_TMUX` が未設定の場合はデフォルト `tmux` を使用 (本番動作に影響なし)。

### 3. setup-only / dry-run モード

```bash
# setup-only: session作成のみ、メインループに入らない
bash shutsujin_departure.sh --setup-only

# dry-run: settings.yaml を実際に書き換えない
bash scripts/shp.sh 1 1 1 --dry-run --yes
```

## Smoke Script テンプレート

```bash
#!/usr/bin/env bash
set -euo pipefail

SMOKE_SERVER="tmux -L smoke_$$ -f /dev/null"
export SHOGUN_TMUX="$SMOKE_SERVER"

cleanup() { $SMOKE_SERVER kill-server 2>/dev/null || true; }
trap cleanup EXIT

$SMOKE_SERVER new-session -d -s test -x 220 -y 50

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }

# syntax check
bash -n target_script.sh || fail "syntax error"
pass "syntax"

# setup-only (session作成のみ)
bash target_script.sh --setup-only 2>&1 | grep -q "setup" && pass "setup-only" || fail "setup-only"

# settings.yaml 不変確認
git diff -- config/settings.yaml | grep -q "" && fail "settings.yaml modified" || pass "formations immutability"

echo "All checks PASS"
```

## Settings.yaml 不変性確認

`formations.*` (preset config) が smoke 中に変更されていないことを必ず確認:

```bash
git diff -- config/settings.yaml
# 空 → PASS
# 差分あり → FAIL (formations immutability 違反)
```

## Battle-Tested Examples

| cmd | スクリプト | 検証内容 | 結果 |
|-----|-----------|---------|------|
| cmd_725a | smoke_shu_shk_shx.sh | shu/shk/shx の --help / --setup-only 起動 | PASS: active session破壊なし |
| cmd_725b | smoke_shp_model_switch.sh | shp 将軍モデル選択 + 足軽7号モデル変更 | PASS: settings.yaml diff空 |

## 適用対象スクリプト

- `shutsujin_departure.sh` (shu/shk/shx)
- `scripts/shp.sh`
- `scripts/shc.sh`
- `scripts/switch_cli.sh`
- 今後追加される shogun 系起動・設定スクリプト全般

## Related Skills

- `shogun-shc-switch-silent-failure` — shc/switch_cli の silent failure 検出・修正
- `shogun-tmux-busy-aware-send-keys` — busy pane への send-keys ガード
- `shogun-bash-daemon-restart-subcommand-pattern` — daemon 系スクリプトの再起動パターン

## Source

- cmd_725a: ash6 による shu/shk/shx 起動修復で isolated tmux server パターンを初実装
- cmd_725c: gunshi による γ QC で SHOGUN_TMUX env hook パターンを一般化・統合
- cmd_725b: ash7 による shp 修復でも同パターン適用・PASS 実証
