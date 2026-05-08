# cmd_666 実装レポート: shp 撤収モード (--kill / --retreat)

**作成日時**: 2026-05-08 09:39 JST  
**作業者**: ashigaru2  
**タスクID**: subtask_666_shp_retreat

---

## 実装内容

### 変更ファイル

| ファイル | 変更種別 | 概要 |
|---------|---------|------|
| `scripts/shp.sh` | 変更 | `--kill` / `--retreat` オプション追加、撤収モード関数群追加 |
| `docs/shogun_shell_commands.md` | 変更 | shp 撤収対応・役割分担表・使い分けガイド更新 |

---

## 実装詳細

### scripts/shp.sh

**追加した定数:**
```bash
RETREAT_MEMBER_IDS=(karo ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7 gunshi)
```
将軍を除く9名を撤収対象として定義。

**追加した関数:**

| 関数名 | 役割 |
|--------|------|
| `resolve_pane_retreat()` | agent_id から tmux pane を解決 (switch_cli.sh と同ロジック) |
| `interactive_select_retreat()` | 9名それぞれに y/N を問い RETREAT_TARGETS に格納 |
| `show_retreat_summary()` | 撤収対象一覧と人数を表示 |
| `execute_retreat()` | dry_run フラグに従い /exit 送信または表示のみ |

**引数パース追加:**
```bash
--kill|--retreat)
    RETREAT_MODE=true
    shift
    ;;
```

**組み合わせ検証:**
```bash
if [[ "$RETREAT_MODE" == "true" && -n "$PRESET" ]]; then
    echo "ERROR: --kill/--retreat と --preset は同時に使用できません"
    exit 1
fi
```

**撤収時の CLI 終了処理:**
- Codex: `Escape → Ctrl-C → /exit Enter`
- その他 (claude 等): `/exit Enter`

---

## テスト結果

### AC C-1: bash -n PASS
```
bash -n scripts/shp.sh
→ SYNTAX OK
```

### AC C-2: --help に --kill / --retreat が表示される
```
bash scripts/shp.sh --help | grep -E -- '--kill|--retreat'
→ shp --kill                   撤収モード interactive (対象を選択して /exit 送信)
→ shp --retreat                --kill の同義語
→ shp --kill --dry-run         撤収確認のみ (pane/process 変更なし)
```

### AC C-3: --kill --dry-run PASS・実撤収未実行確認
```
printf "y\nN\nN\ny\nN\nN\nN\nN\nN\ny\n" | bash scripts/shp.sh --kill --dry-run

出力:
  [DRY-RUN] 実行シミュレーション (tmux pane/process に変更なし)
  [DRY-RUN] 家老 (karo) → /exit 送信予定
  [DRY-RUN] 足軽3 (ashigaru3) → /exit 送信予定
  [DRY-RUN] 上記が実際の撤収対象になります。
```
tmux send-keys は一切呼ばれておらず、実撤収ゼロを確認。

### AC A-4: 既存出陣モード破壊なし
```
printf "N\n" | bash scripts/shp.sh --preset current --dry-run
→ 出陣設定サマリーが正常表示。settings.yaml 変更なし。
```

### 0人選択時の中止
```
全員 N → "撤収対象が選択されていません。中止します。"
```

---

## 実撤収未実行理由

destructive_safety ルール (Tier 1/2) に基づき、本タスクでは tmux pane への `/exit` 送信を含む実撤収は実施しない。

理由:
1. 稼働中エージェントを停止する行為は destructive operation に該当する
2. タスクの受け入れ条件は dry-run 検証のみを要求している (AC C-3)
3. 実撤収は殿の明示操作時のみ許可される

実際の撤収操作は以下のコマンドで実施可能:
```bash
shp --kill          # 対話選択
shp --retreat       # 同義
```

---

## AC 達成状況

| AC | 内容 | 結果 |
|----|------|------|
| A-1 | --kill と --retreat が実装され --help に表示 | ✅ PASS |
| A-2 | 9構成員 y/N UI・summary・y/N確認 | ✅ PASS |
| A-3 | --dry-run で変更なし・表示のみ | ✅ PASS |
| A-4 | 既存出陣モード破壊なし | ✅ PASS |
| B-1 | docs 更新 (役割分担・例・注意事項) | ✅ PASS |
| C-1 | bash -n PASS | ✅ PASS |
| C-2 | --help に --kill/--retreat 表示 | ✅ PASS |
| C-3 | --kill --dry-run PASS・実撤収なし | ✅ PASS |
| D-1 | 本レポート | ✅ 本ファイル |
