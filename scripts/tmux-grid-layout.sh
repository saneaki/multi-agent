#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# tmux-grid-layout.sh - 動的グリッドレイアウト適用スクリプト
# ═══════════════════════════════════════════════════════════════════════════════
#
# multiagent セッションのペインを動的なグリッドに配置する。
# ペイン数に応じて列数を自動計算し、端数時は最初のペイン（家老）を優遇する。
#
# 列数の決定ルール:
#   1ペイン: そのまま
#   2ペイン: 2列×1行
#   3〜8ペイン: 2列×N行
#   9ペイン以上: 3列×N行
#
# 端数時の家老優遇:
#   グリッドに端数が出る場合、最初のペイン（家老）が他より大きくなる。
#   例: 2列で5ペイン → 家老が左列上部を2行分占有、残り4ペインが均等グリッド
#
# tmux の after-split-window フックから呼び出される。
#
# 使い方:
#   tmux-grid-layout.sh <target_window>
#
# 例:
#   tmux-grid-layout.sh "multiagent-aidemy:agents"
#
# ═══════════════════════════════════════════════════════════════════════════════

TARGET="$1"

if [ -z "$TARGET" ]; then
    exit 1
fi

# ペイン数を取得
PANE_COUNT=$(tmux list-panes -t "$TARGET" 2>/dev/null | wc -l | tr -d ' ')

# 1ペイン以下なら何もしない
if [ "$PANE_COUNT" -le 1 ]; then
    exit 0
fi

# ウィンドウサイズを取得
WIN_W=$(tmux display-message -t "$TARGET" -p '#{window_width}')
WIN_H=$(tmux display-message -t "$TARGET" -p '#{window_height}')

# ペインIDを順番に取得
PANE_IDS=($(tmux list-panes -t "$TARGET" -F '#{pane_id}'))

# ─────────────────────────────────────────────────────────────────────────────
# tmux チェックサム計算（16ビット回転チェックサム）
# ─────────────────────────────────────────────────────────────────────────────
calculate_checksum() {
    local layout="$1"
    local csum=0
    local i char ascii

    for ((i = 0; i < ${#layout}; i++)); do
        char="${layout:$i:1}"
        ascii=$(printf '%d' "'$char")
        csum=$(( (csum >> 1) + ((csum & 1) << 15) ))
        csum=$(( (csum + ascii) & 0xFFFF ))
    done

    printf '%04x' "$csum"
}

# ─────────────────────────────────────────────────────────────────────────────
# ペイン数から最適な列数を決定
# ─────────────────────────────────────────────────────────────────────────────
determine_columns() {
    local pane_count=$1
    if [ "$pane_count" -le 2 ]; then
        echo 2
    elif [ "$pane_count" -le 8 ]; then
        echo 2
    else
        echo 3
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 動的グリッドレイアウト文字列を生成
# ─────────────────────────────────────────────────────────────────────────────
#
# 端数処理（家老優遇）:
#   cols列 × rows行 のグリッドで、total = cols * rows に対してペイン数が
#   足りない場合（端数あり）、最初のペイン（家老）に余った行の高さを加算する。
#
#   具体例（2列、5ペイン）:
#     rows = ceil(5/2) = 3行。slots = 2*3 = 6。端数 = 6-5 = 1。
#     家老（ペイン0、左列先頭）は通常1行分だが、端数1行分を加算して2行分の高さになる。
#     左列: [家老(2行分)] [ペイン2(1行分)]  = 3行分
#     右列: [ペイン1(1行分)] [ペイン3(1行分)] [ペイン4(1行分)] = 3行分
#
generate_grid_layout() {
    local win_w=$1
    local win_h=$2
    local pane_count=$3
    local num_cols=$4
    shift 4
    local pane_ids=("$@")

    # ペインIDの数字部分を抽出
    local pids=()
    for pid in "${pane_ids[@]}"; do
        pids+=("${pid#%}")
    done

    local col_sep=1
    local row_sep=1

    # 行数を計算（切り上げ）
    local num_rows=$(( (pane_count + num_cols - 1) / num_cols ))
    # グリッドの総スロット数
    local total_slots=$(( num_cols * num_rows ))
    # 端数（空きスロット数） = 家老が余分に使える行数
    local empty_slots=$(( total_slots - pane_count ))

    # 列幅を計算
    local usable_w=$(( win_w - (num_cols - 1) * col_sep ))
    local base_col_w=$(( usable_w / num_cols ))
    local col_w_remainder=$(( usable_w % num_cols ))

    # 各列の幅を配列で保持
    local col_widths=()
    local col_xs=()
    local x_offset=0
    for ((c = 0; c < num_cols; c++)); do
        local cw=$base_col_w
        # 余りは左の列から1pxずつ配分
        if [ $c -lt $col_w_remainder ]; then
            cw=$(( base_col_w + 1 ))
        fi
        col_widths+=("$cw")
        col_xs+=("$x_offset")
        x_offset=$(( x_offset + cw + col_sep ))
    done

    # 各列にペインを配分
    # 列0（左端）に家老ペインを配置。端数がある場合、列0の家老は複数行分を占有。
    # ペインの配分: 列順に上から下へ埋めていく
    #
    # 端数なしの場合: 各列 num_rows 個ずつ
    # 端数ありの場合:
    #   列0: 家老が (1 + empty_slots) 行分の高さ、残り (num_rows - 1 - empty_slots) 個のペイン
    #   列0の合計ペイン数 = 1 + (num_rows - 1 - empty_slots) = num_rows - empty_slots
    #   他の列: 各 num_rows 個ずつ

    # 行の高さを計算
    local usable_h=$(( win_h - (num_rows - 1) * row_sep ))
    local base_row_h=$(( usable_h / num_rows ))
    local row_h_remainder=$(( usable_h % num_rows ))

    # 各行の高さを配列で保持（余りは上の行から1pxずつ配分）
    local row_heights=()
    for ((r = 0; r < num_rows; r++)); do
        local rh=$base_row_h
        if [ $r -lt $row_h_remainder ]; then
            rh=$(( base_row_h + 1 ))
        fi
        row_heights+=("$rh")
    done

    local layout_body=""
    local pid_idx=0

    for ((c = 0; c < num_cols; c++)); do
        local cw=${col_widths[$c]}
        local cx=${col_xs[$c]}

        if [ -n "$layout_body" ]; then
            layout_body="${layout_body},"
        fi

        if [ $c -eq 0 ] && [ $empty_slots -gt 0 ]; then
            # 列0: 家老優遇レイアウト
            # 家老ペインの高さ = (1 + empty_slots) 行分 + セパレータ分
            local karo_rows=$(( 1 + empty_slots ))
            local karo_h=0
            for ((r = 0; r < karo_rows; r++)); do
                karo_h=$(( karo_h + ${row_heights[$r]} ))
                if [ $r -lt $(( karo_rows - 1 )) ]; then
                    karo_h=$(( karo_h + row_sep ))
                fi
            done

            local col0_pane_count=$(( num_rows - empty_slots ))

            if [ $col0_pane_count -eq 1 ]; then
                # 家老ペインのみ（列全体を占有）
                layout_body="${layout_body}${cw}x${win_h},${cx},0,${pids[$pid_idx]}"
                pid_idx=$(( pid_idx + 1 ))
            else
                # 家老ペイン + 残りのペイン
                local col_rows="${cw}x${karo_h},${cx},0,${pids[$pid_idx]}"
                pid_idx=$(( pid_idx + 1 ))

                local y_offset=$(( karo_h + row_sep ))
                local used_h=$karo_h

                for ((r = karo_rows; r < num_rows; r++)); do
                    local rh=${row_heights[$r]}
                    if [ $r -eq $(( num_rows - 1 )) ]; then
                        # 最後の行は残りの高さ
                        rh=$(( win_h - y_offset ))
                    fi
                    col_rows="${col_rows},${cw}x${rh},${cx},${y_offset},${pids[$pid_idx]}"
                    pid_idx=$(( pid_idx + 1 ))
                    used_h=$(( used_h + rh ))
                    y_offset=$(( y_offset + rh + row_sep ))
                done

                layout_body="${layout_body}${cw}x${win_h},${cx},0[${col_rows}]"
            fi
        else
            # 通常の列: num_rows 個のペインを均等配置
            local col_pane_count=$num_rows
            # 最後の列でペインが足りない場合の調整
            local remaining=$(( pane_count - pid_idx ))
            if [ $remaining -lt $num_rows ]; then
                col_pane_count=$remaining
            fi

            if [ $col_pane_count -eq 1 ]; then
                layout_body="${layout_body}${cw}x${win_h},${cx},0,${pids[$pid_idx]}"
                pid_idx=$(( pid_idx + 1 ))
            else
                local col_rows=""
                local y_offset=0
                local used_h=0

                for ((r = 0; r < col_pane_count; r++)); do
                    local rh=${row_heights[$r]}
                    if [ $r -eq $(( col_pane_count - 1 )) ]; then
                        # 最後の行は残りの高さ
                        rh=$(( win_h - y_offset ))
                    fi

                    if [ -n "$col_rows" ]; then
                        col_rows="${col_rows},"
                    fi
                    col_rows="${col_rows}${cw}x${rh},${cx},${y_offset},${pids[$pid_idx]}"
                    pid_idx=$(( pid_idx + 1 ))
                    used_h=$(( used_h + rh ))
                    y_offset=$(( y_offset + rh + row_sep ))
                done

                layout_body="${layout_body}${cw}x${win_h},${cx},0[${col_rows}]"
            fi
        fi
    done

    # 全体を波括弧で囲む
    local layout_str="${win_w}x${win_h},0,0{${layout_body}}"

    # チェックサムを計算
    local checksum
    checksum=$(calculate_checksum "$layout_str")

    echo "${checksum},${layout_str}"
}

# ─────────────────────────────────────────────────────────────────────────────
# レイアウト適用
# ─────────────────────────────────────────────────────────────────────────────

NUM_COLS=$(determine_columns "$PANE_COUNT")
LAYOUT=$(generate_grid_layout "$WIN_W" "$WIN_H" "$PANE_COUNT" "$NUM_COLS" "${PANE_IDS[@]}")

tmux select-layout -t "$TARGET" "$LAYOUT" 2>/dev/null || \
    tmux select-layout -t "$TARGET" tiled 2>/dev/null
