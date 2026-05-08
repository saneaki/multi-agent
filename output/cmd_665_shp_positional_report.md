# cmd_665 — shp positional args + --yes 実装レポート

**Task ID:** subtask_665_shp_positional_args
**Parent cmd:** cmd_665
**Worker:** ashigaru4
**Status:** done
**Completed:** 2026-05-08 09:48 JST

---

## 1. 概要

Discord 殿御要望 (2026-05-08 04:14 JST) に基づき、`scripts/shp.sh` に以下を追加:

1. **positional args モード** — 1/2/3 の数字を引数に取って即出陣
   - 1 引数: 全員 = N1
   - 2 引数: 将軍 = N1, 他全員 = N2
   - 4 引数: 将軍 = N1, 家老 = N2, 軍師 = N3, 足軽全員 = N4
   - 10 引数: MEMBER_IDS 順 (将軍/家老/足軽1-7/軍師) で個別指定
2. **`--yes` / `-y` フラグ** — y/N 確認 prompt をスキップして自動 Yes
3. **既存モード保持** — interactive / `--preset` / `--kill` (`--retreat`) はそのまま動作
4. **排他制御** — positional と `--preset` / `--kill` の併用はエラー

---

## 2. 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `scripts/shp.sh` | usage 更新 + `apply_positional()` 関数追加 + 引数パース拡張 (`[123]` / `--yes` / `-y`) + 排他検証追加 + y/N prompt の YES_FLAG 対応 |
| `docs/shogun_shell_commands.md` | shp 章に positional args 体系表 + 使用例 + 使い分けガイド更新 |
| `output/cmd_665_shp_positional_report.md` | 本レポート (新規) |
| `queue/reports/ashigaru4_report.yaml` | history append + status=done |

---

## 3. 実装詳細

### 3.1 `apply_positional()` 関数

`POSITIONAL_NUMS` 配列の長さで分岐し `SELECTIONS` 連想配列に番号を展開:

```bash
apply_positional() {
    local count="${#POSITIONAL_NUMS[@]}"
    case "$count" in
        1)  # 全員 = N1
        2)  # 将軍 = N1, 他全員 = N2
        4)  # 将軍/家老/軍師/足軽全員
        10) # MEMBER_IDS 順 個別
        *)  # error
    esac
}
```

### 3.2 引数パース拡張

```bash
case "$1" in
    --yes|-y)   YES_FLAG=true; shift ;;
    [123])      POSITIONAL_NUMS+=("$1"); shift ;;
    ...
esac
```

`[123]` glob で 1/2/3 のみ受理 (4 以上やアルファベットは "不明なオプション" エラー)。

### 3.3 排他検証

```bash
if [[ "${#POSITIONAL_NUMS[@]}" -gt 0 && -n "$PRESET" ]]; then
    error "positional 引数 と --preset は同時に使用できません"
fi
if [[ "${#POSITIONAL_NUMS[@]}" -gt 0 && "$RETREAT_MODE" == "true" ]]; then
    error "positional 引数 と --kill/--retreat は同時に使用できません"
fi
```

### 3.4 YES_FLAG による prompt skip

出陣・撤収両モードで:

```bash
if [[ "$YES_FLAG" == "true" ]]; then
    CONFIRM="y"
    echo "  --yes フラグにより出陣確認スキップ (自動 Yes)"
else
    printf "  出陣しますか? (y/N): "
    read -r CONFIRM
fi
```

---

## 4. 検証結果 (Acceptance Criteria)

| ID | 内容 | 結果 | 検証コマンド |
|----|------|------|-------------|
| A-1 | `shp 1` で全員 Sonnet+T、prompt 経ずに summary→出陣 | **PASS** | `bash scripts/shp.sh 1 --yes --dry-run` → 全員 1(Sonnet+T) |
| A-2 | `shp 2` / `shp 3` で全員 Opus+T / Codex | **PASS** | `bash scripts/shp.sh 2 --yes --dry-run` / `bash scripts/shp.sh 3 --yes --dry-run` |
| A-3 | `shp 2 1` で 将軍=Opus, 他全員=Sonnet | **PASS** | `bash scripts/shp.sh 2 1 --yes --dry-run` → 将軍=2(Opus), 他=1(Sonnet) |
| A-4 | `shp 1 2 1 1` で 将軍=N1, 家老=N2, 軍師=N3, 足軽=N4 | **PASS** | `bash scripts/shp.sh 1 2 1 1 --yes --dry-run` → 将軍=1, 家老=2, 軍師=1, 足軽全員=1 |
| A-5 | `shp 1 2 1 1 1 1 1 1 1 2` で構成員10名個別指定 | **PASS** | 結果: 将軍=1, 家老=2, 足軽1-7=1, 軍師=2 (順序通り) |
| A-6 | `--yes / -y` で y/N 確認 prompt skip | **PASS** | "--yes フラグにより出陣確認スキップ (自動 Yes)" 表示確認 |
| B-1 | 既存 --preset / interactive / --dry-run mode 不変 | **PASS** | `--preset current/all-sonnet/heavy-opus/sonnet-codex-mix` 全 PASS、`--kill --dry-run` PASS、排他検証 (positional+preset / positional+kill) も PASS |
| B-2 | `bash -n scripts/shp.sh` PASS | **PASS** | `bash -n` 出力なし (構文 OK) |
| B-3 | `--help` に positional + --yes 説明表示 | **PASS** | `shp <N> [...]` / `shp --yes / -y` / positional args 体系セクション全表示 |
| C-1 | `docs/shogun_shell_commands.md` 更新 | **PASS** | shp 章: 引数表更新 + positional args 体系表新設 + 使い分けガイド 3 行追加 |
| D-1 | output/cmd_665_shp_positional_report.md に実装ログ・テスト結果記録 | **PASS** | 本ファイル |

### 4.1 dry-run 検証コマンド集 (再現用)

```bash
# 基本
bash scripts/shp.sh 1 --yes --dry-run                            # A-1
bash scripts/shp.sh 2 --yes --dry-run                            # A-2a
bash scripts/shp.sh 3 --yes --dry-run                            # A-2b
bash scripts/shp.sh 2 1 --yes --dry-run                          # A-3
bash scripts/shp.sh 1 2 1 1 --yes --dry-run                      # A-4
bash scripts/shp.sh 1 2 1 1 1 1 1 1 1 2 --yes --dry-run          # A-5

# 短縮 -y
bash scripts/shp.sh 1 -y --dry-run

# 既存 mode 回帰
bash scripts/shp.sh --preset current --dry-run --yes
bash scripts/shp.sh --preset all-sonnet --dry-run --yes
bash scripts/shp.sh --preset heavy-opus --dry-run --yes
bash scripts/shp.sh --preset sonnet-codex-mix --dry-run --yes
echo -e "y\nN\nN\nN\nN\nN\nN\nN\nN" | bash scripts/shp.sh --kill --dry-run --yes

# エラーケース
bash scripts/shp.sh 1 1 1                                        # 3 個 (invalid count)
bash scripts/shp.sh 4                                            # 不明オプション (1/2/3 のみ受理)
bash scripts/shp.sh 1 --preset all-sonnet                        # 排他エラー
bash scripts/shp.sh 1 --kill                                     # 排他エラー

# 構文 + help
bash -n scripts/shp.sh
bash scripts/shp.sh --help | grep -E -- '--yes|-y|positional|shp 1'
```

### 4.2 検証結果サマリー

- **AC 全 11 項目 PASS** (A-1 〜 A-6, B-1 〜 B-3, C-1, D-1)
- **既存モード regression なし** (4 preset + interactive + --kill 全 PASS)
- **エラーハンドリング正常** (3個/排他/不明数値 全エラーメッセージ表示)
- **実出陣テストは禁止指示につき未実施** (タスク仕様通り dry-run のみ)

---

## 5. 注意事項・補足

### 5.1 positional 引数 4 と 10 の意味分岐

- 4 個: `<将軍> <家老> <軍師> <足軽全員>` — 将軍/家老/軍師は個別、足軽は 1〜7 全員一括
- 10 個: `<将軍> <家老> <足軽1> <足軽2> ... <足軽7> <軍師>` — MEMBER_IDS 配列順
  - 注意: 4 個版と 10 個版で「軍師の位置」が変わる (4 個版は 3 番目、10 個版は最後)
  - 設計意図: 4 個版は「役職階層的順序」、10 個版は「内部 MEMBER_IDS 配列順」
  - 殿の用例 `1 2 1 1 1 1 1 1 1 2` は 10 個版 (構成員順)

### 5.2 番号 1/2/3 以外の引数

`[123]` glob で受理するため `4` `5` 等は "不明なオプション" としてエラー。これは positional パース漏れではなく仕様 (NUMBER_MAP に 1/2/3 のみ定義のため)。

### 5.3 既存ヘルプとの互換性

`shp --help` は既存項目 (`--dry-run`, `--preset`, `--kill`, `--retreat`) を全て保持。新規項目 (`shp <N> [...]`, `--yes / -y`, positional args 体系セクション) を追加した。例セクションを「interactive/preset」と「positional」に分割。

---

## 6. commit / push 計画

```
feat(cmd_665): shp positional args + --yes 実装

- scripts/shp.sh: 1/2/4/10 引数 positional モード追加 (apply_positional 関数)
- scripts/shp.sh: --yes / -y フラグで y/N 確認 prompt skip (出陣・撤収両モード)
- scripts/shp.sh: usage 更新 (positional args 体系表 + 例)
- scripts/shp.sh: 排他検証 (positional + --preset / + --kill)
- docs/shogun_shell_commands.md: shp 章に positional args 体系表 + 使い分けガイド更新
- output/cmd_665_shp_positional_report.md: 実装レポート

検証: AC 全 11 項目 PASS (dry-run のみ、実出陣テストは禁止指示)。

Refs: cmd_665, Discord 殿御要望 2026-05-08 04:14 JST
```

push 先: `origin/main`

---

## 7. 完了報告 (家老向け)

```
bash /home/ubuntu/shogun/scripts/inbox_write.sh karo \
  "【subtask_665_shp_positional_args 完了】shp positional args (1/2/4/10引数) + --yes/-y 実装完了。AC全11項目PASS、dry-run検証完了、既存mode regression なし。docs更新済。commit <hash> push 済。" \
  task_completed ashigaru4
```
