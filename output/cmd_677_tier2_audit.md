# cmd_677 Tier 2 調査報告 (output/cmd_677_tier2_audit.md)

作成: 2026-05-08 JST / 担当: ashigaru5

---

## 概要

Tier 2 対象 4 件の真因仮説・修正コスト見積を記録する。修正実装は別 cmd 候補。

---

## D-1. cmd_kpi_observer: 7d failure 12件

### 状況
- sh_health_check: 7d success=6, 7d failure=12
- last_error: `[cmd_kpi_observer] KPI: git_commit_success=9 cron_fail=0`

### 真因仮説
**FALSE POSITIVE**: `sh_health_check` の `failure_pattern` が `FAIL` (大文字) を含み、
grep -i (大文字小文字無視) で `fail=0` の metric ログ行にマッチしている。

証拠:
- `grep -i "ERROR|FAIL" logs/kpi_observer.log` → 0件
- `kpi_observer.log` に実際のエラーなし (START → KPI lines → END の全件 SUCCESS)
- 旧フォーマット行 `KPI: pub_us_invoke=0 success=0 fail=0` が `fail=0` を含む → FAIL 誤検出

### 修正案
`config/sh_health_targets.yaml` の cmd_kpi_observer エントリに ignore_patterns 追加:
```yaml
- name: cmd_kpi_observer
  ignore_patterns:
    - 'fail=\d+'   # metric field, not an error
    - 'ALERT'
    - 'RESULT=false'
```

### コスト見積
- 実装: 5分 (YAML 1行追加)
- テスト: sh_health_check 再実行で failure=0 確認
- **合計: 15分、低リスク**

---

## D-2. inbox_watcher[shogun]: 7d failure 31件

### 状況
- sh_health_check: failure 31件
- last_error: なし (failure カウントは古い log から)

### 真因仮説
**混合原因**: 3種類の failure が蓄積している:

1. **2026-02 の `shogun_report_hook.sh` 失敗** (February): 旧フック機構からの古い WARNING
2. **2026-04-17 send-keys 失敗**: shogun pane がビジー時のタイムアウト (3回リトライ失敗)
3. **現在 (5/1-5/8)**: 送信成功 (All messages read → escalation reset の繰り返し確認)

証拠:
- `inbox_watcher_shogun.log` 5/1 以降の failure: send-keys retry 散発のみ
- 現在の動作は正常 (nudge 送信後にすぐ既読)

### 修正案
- 短期: ログローテーション (古い February logs がカウントを汚染)
- 中期: sh_health_check の 7d window 計算をタイムスタンプ based に改善
  (現状: ログ行数ベース vs. 期待: 7日分のタイムスタンプ filter)

### コスト見積
- ログローテーション: 10分
- sh_health_check タイムスタンプ filter 改善: 2-3h
- **合計: Medium コスト、別 cmd 推奨**

---

## D-3. inbox_watcher[karo]: send-keys retry 失敗

### 状況
- last_error: `WARNING: send-keys failed after 2 retries for karo`
- 関連: `[WARN] CLI drift detected for karo: arg=claude, pane=codex`

### 真因仮説
**CLI drift issue**: karo pane で Codex CLI が動作中の時、inbox_watcher が
`arg=claude` を期待するが実際の pane プロセスが `codex` に変わっている。
inbox_watcher はドリフトを検出して pane value (codex) を使うが、
Codex の入力機構は Claude Code と異なるため send-keys nudge が機能しない。

証拠:
- `[WARN] CLI drift detected for karo: arg=claude, pane=codex` が複数回発生
- send-keys 3回リトライ全て失敗
- Codex 実行終了後は通常動作に戻る (既読になれば escalation reset)

### 修正案
inbox_watcher.sh に Codex pane 対応を追加:
- `pane=codex` 検出時: `codex` コマンドへの適切な入力方式 (例: Enter キーのみ、または別チャネル)
- または: Codex 起動時は inbox_watcher nudge をスキップし、
  Codex 終了後のポーリングで対応

### コスト見積
- 調査 (Codex 入力機構の確認): 1h
- 実装: 2h
- テスト: 1h
- **合計: 4h、Medium リスク、別 cmd 推奨**

---

## D-4. shogun_inbox_notifier: 7d failure 4件

### 状況
- sh_health_check: 7d success=34, failure=4
- last_error: `[2026-04-30 07:58:41] Sending shogun inbox for cmd_610: 🏆🏆cmd_610 COMPLETE...`

### 真因仮説
**FALSE POSITIVE**: 通知内容に "FAIL" が含まれる場合に誤検出。

証拠:
- last_error 行は実際は SUCCESS (notifier が cmd 完了通知を送信)
- 通知内容に "YAML parse error修復" → "error" マッチ, "cmd_579完了(ash5): ash3/ash4 YAML parse error修復" → "error" マッチ
- grep -i "FAIL|ERROR" で通知本文がヒット

### 修正案
`sh_health_targets.yaml` の shogun_inbox_notifier エントリに ignore_patterns 追加:
```yaml
- name: shogun_inbox_notifier
  ignore_patterns:
    - 'Sending shogun inbox'   # 通知送信行は SUCCESS
    - 'shogun inbox sent'      # 送信完了行は SUCCESS
    - 'ALERT'
    - 'RESULT=false'
```

### コスト見積
- 実装: 5分 (YAML 2行追加)
- **合計: 15分、低リスク**

---

## 後続 cmd 候補サマリー

| 優先度 | 対象 | 修正内容 | コスト |
|--------|------|---------|--------|
| 低 | cmd_kpi_observer + shogun_inbox_notifier | ignore_patterns 追加 (false positive 解消) | 15分 |
| 中 | inbox_watcher[shogun] | ログローテーション + sh_health 7d filter 改善 | 3h |
| 中 | inbox_watcher[karo] | Codex pane 対応 (send-keys スキップ or 代替) | 4h |
