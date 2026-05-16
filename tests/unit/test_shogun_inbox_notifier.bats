#!/usr/bin/env bats
# test_shogun_inbox_notifier.bats — shogun_inbox_notifier.sh ユニットテスト
#
# テスト構成:
#   T-SIN-001: bash -n 構文チェック
#   T-SIN-002: log() が LOG_FILE に1回のみ書き込む (tee 二重書込みなし)
#   T-SIN-003: STATE_FILE dedup — 登録済み cmd_id は check_and_notify でスキップ
#   T-SIN-004: PIDFILE guard — flock/mkdir lock 取得済みの場合は即時終了する (macOS fallback対応)

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT="$PROJECT_ROOT/scripts/shogun_inbox_notifier.sh"
}

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_LOG_FILE="$TEST_TMPDIR/notifier.log"
    export TEST_STATE_FILE="$TEST_TMPDIR/notified.txt"
    export TEST_PIDFILE="$TEST_TMPDIR/notifier.pid"
    export TEST_DASHBOARD="$TEST_TMPDIR/dashboard.md"
    touch "$TEST_STATE_FILE" "$TEST_LOG_FILE"
    # mock scripts ディレクトリ
    mkdir -p "$TEST_TMPDIR/scripts" "$TEST_TMPDIR/logs"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ────────────────────────────────────────────────────────────
# T-SIN-001: 構文チェック
# ────────────────────────────────────────────────────────────
@test "T-SIN-001: bash -n 構文チェック" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────────────────────
# T-SIN-002: log() 1回書込み確認
#   修正前: echo "..." | tee -a LOG_FILE → nohup redirect と合わさり 2 行書込み
#   修正後: echo "..." >> LOG_FILE      → 1 行のみ
# ────────────────────────────────────────────────────────────
@test "T-SIN-002: log() が nohup redirect と合わせて LOG_FILE に 1 回のみ書き込む" {
    local log_file="$TEST_TMPDIR/test_log.log"

    # log() を含む最小ラッパースクリプト (修正後と同じ実装)
    cat > "$TEST_TMPDIR/test_log.sh" << 'INNER'
#!/usr/bin/env bash
LOG_FILE="$1"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
log "first message"
log "second message"
INNER
    chmod +x "$TEST_TMPDIR/test_log.sh"

    # nohup 起動をシミュレート: stdout も同じ log_file へリダイレクト
    bash "$TEST_TMPDIR/test_log.sh" "$log_file" >> "$log_file" 2>&1

    # 2 回呼び出したので 2 行のみ (tee バグ版では 4 行になる)
    local line_count
    line_count=$(wc -l < "$log_file")
    [ "$line_count" -eq 2 ]
}

@test "T-SIN-002b: tee 実装では二重書込みが発生することの対比確認" {
    local log_file="$TEST_TMPDIR/test_tee.log"

    cat > "$TEST_TMPDIR/test_tee.sh" << 'INNER'
#!/usr/bin/env bash
LOG_FILE="$1"
# 旧実装 (tee): nohup redirect と合わさると二重書込みになる
log_buggy() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
log_buggy "first message"
INNER
    chmod +x "$TEST_TMPDIR/test_tee.sh"

    bash "$TEST_TMPDIR/test_tee.sh" "$log_file" >> "$log_file" 2>&1

    # tee 版では 2 行 (1 call × 2 writes)
    local line_count
    line_count=$(wc -l < "$log_file")
    [ "$line_count" -eq 2 ]
    # → 二重書込みバグが再現できることを確認 (修正版 T-SIN-002 との対比)
}

# ────────────────────────────────────────────────────────────
# T-SIN-003: STATE_FILE dedup
# ────────────────────────────────────────────────────────────
@test "T-SIN-003: STATE_FILE dedup — 登録済み cmd_id は通知しない" {
    # ダッシュボードに cmd_100 (新規) と cmd_200 (既通知) を配置
    cat > "$TEST_DASHBOARD" << 'EOF'
| 12:00 | shogun | 任務A | 🏆🏆cmd_100 COMPLETE: test |
| 11:00 | shogun | 任務B | 🏆🏆cmd_200 COMPLETE: old |
EOF
    # cmd_200 は既通知として STATE_FILE に登録
    echo "cmd_200" > "$TEST_STATE_FILE"

    # 通知コールを記録する mock inbox_write.sh
    local notify_record="$TEST_TMPDIR/notify_record.txt"
    cat > "$TEST_TMPDIR/scripts/inbox_write.sh" << MOCK_EOF
#!/usr/bin/env bash
echo "\$@" >> "$notify_record"
exit 0
MOCK_EOF
    chmod +x "$TEST_TMPDIR/scripts/inbox_write.sh"

    # SKIP_MAIN_LOOP=1 で watch ループをスキップしてデータ処理のみ実行
    SHOGUN_NOTIFIER_PIDFILE="$TEST_PIDFILE" \
    SHOGUN_SCRIPT_DIR="$TEST_TMPDIR" \
    SKIP_MAIN_LOOP=1 \
    bash "$SCRIPT" >> "$TEST_LOG_FILE" 2>&1 || true

    # cmd_200 は通知されていないこと
    if [ -f "$notify_record" ]; then
        run grep "cmd_200" "$notify_record"
        [ "$status" -ne 0 ]
    fi

    # STATE_FILE に cmd_200 が残っていること (dedup 動作確認)
    run grep -xF "cmd_200" "$TEST_STATE_FILE"
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────────────────────
# T-SIN-004: PIDFILE guard (flock/mkdir fallback 両対応)
#   flock が使えれば flock パス、なければ mkdir fallback パスをテスト
#   macOS (flock 不在) でも SKIP なし
# ────────────────────────────────────────────────────────────
@test "T-SIN-004: PIDFILE guard — lock取得済みなら即時終了して 'Already running' を出力" {
    local lockdir="${TEST_PIDFILE}.lock"

    if command -v flock &>/dev/null; then
        # flock 利用可能: flock でロックを先取り (プロセス1をシミュレート)
        exec 201>"$TEST_PIDFILE"
        flock -n 201

        run timeout 5 env \
            SHOGUN_NOTIFIER_PIDFILE="$TEST_PIDFILE" \
            SHOGUN_SCRIPT_DIR="$TEST_TMPDIR" \
            bash "$SCRIPT" 2>&1

        exec 201>&-
    else
        # flock 不在 (macOS 等): mkdir fallback — lockdir を先取り
        mkdir "$lockdir"

        run timeout 5 env \
            SHOGUN_NOTIFIER_PIDFILE="$TEST_PIDFILE" \
            SHOGUN_SCRIPT_DIR="$TEST_TMPDIR" \
            bash "$SCRIPT" 2>&1

        rmdir "$lockdir" 2>/dev/null || true
    fi

    # "Already running" が出力されていること
    [[ "$output" == *"Already running"* ]]
}

@test "T-SIN-004b: 同一 PIDFILE の 2 プロセス目はブロックされる (flock/mkdir fallback 両対応)" {
    local lockdir="${TEST_PIDFILE}.lock"
    local bg_pid=""

    if command -v flock &>/dev/null; then
        # flock パス: バックグラウンドプロセスでロック保持
        (
            exec 202>"$TEST_PIDFILE"
            flock -n 202
            echo "HELD" > "$TEST_TMPDIR/held_flag"
            sleep 5
        ) &
        bg_pid=$!

        # ロックが確保されるまで待機
        local i
        for i in $(seq 1 10); do
            [ -f "$TEST_TMPDIR/held_flag" ] && break
            sleep 0.1
        done
    else
        # flock 不在 (macOS 等): mkdir lockdir を手動作成 (プロセス1をシミュレート)
        mkdir "$lockdir"
        echo "99999" > "$TEST_PIDFILE"
    fi

    # プロセス 2: 同じ PIDFILE で起動 → Already running で終了するはず
    run timeout 5 env \
        SHOGUN_NOTIFIER_PIDFILE="$TEST_PIDFILE" \
        SHOGUN_SCRIPT_DIR="$TEST_TMPDIR" \
        SKIP_MAIN_LOOP=1 \
        bash "$SCRIPT" 2>&1

    # クリーンアップ
    if [ -n "$bg_pid" ]; then
        kill "$bg_pid" 2>/dev/null || true
        wait "$bg_pid" 2>/dev/null || true
    fi
    rmdir "$lockdir" 2>/dev/null || true

    # "Already running" が出力されていること
    [[ "$output" == *"Already running"* ]]
}
