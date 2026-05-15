---
name: windows-watchdog-folder-daemon
description: |
  [English] Use when building a Windows-resident daemon that watches a local sync folder
  (Google Drive Desktop / OneDrive / Dropbox) and invokes a processor on new files.
  Covers watchdog Observer + initial scan, stable-wait, idempotent state JSON,
  retryless errors.log, PowerShell start/stop scripts, and Startup folder registration.
  [日本語] Windows ローカルの同期フォルダを監視し、新規ファイルに処理を走らせる常駐 daemon
  を構築する時に使用。watchdog Observer + 起動時 scan + 安定化待ち + 冪等 state JSON +
  retry無し errors.log + PowerShell start/stop + Startup 登録 + Runbook 一式を体系化。
tags: [windows, watchdog, daemon, drive-desktop, automation, powershell]
---

# Windows Watchdog Folder Daemon

Windows 上のローカル同期フォルダ (Google Drive Desktop など) を監視して、
新規ファイルを外部処理に流す常駐 daemon の再利用テンプレート。

## When to Use

- 殿手元 Windows PC で **Drive Desktop / OneDrive / Dropbox** が同期するフォルダに
  新規ファイル (PDF / 画像 / docx 等) が落ちる度に外部処理 (OCR / 画像変換 / アーカイブ)
  を走らせたい時。
- **起動時 + 監視中** の両局面で取りこぼし無く処理したい時 (PC スリープ復帰 / 同期遅延 / 誤投入)。
- 常駐運用に **start/stop/Startup 自動起動 + Runbook** が必要な時。

## Do NOT Use For

- 単発バッチ処理 (cron / Task Scheduler 1回起動で十分)。
- Linux/macOS 常駐 (systemd / launchd を使う、`shogun-bash-daemon-restart-subcommand-pattern` 参照)。
- PC を跨いだクラウド側監視 (Google Drive Push notifications / n8n Drive Trigger を使う)。

## Architecture

```
Drive Desktop sync (G:\My Drive\<folder>\)
   │
   ├─ initial_scan() で起動時未処理ファイルを順次処理 ──┐
   │                                                     │
   └─ watchdog.Observer (recursive=True)                 │
       │ on_created / on_moved                           │
       └──▶ is_candidate() ──▶ Invoker ◀─────────────────┘
                                  │
                                  ├─ wait_until_stable() で同期完了待ち
                                  ├─ subprocess: 外部処理 [--option]
                                  ├─ 成功時: ProcessedStore.mark_done (state.json 追記)
                                  └─ 失敗時: ErrorLog.record (errors.log 追記、リトライしない)
```

## Implementation Pattern

### Python daemon (`<name>_watch.py`)

| 観点 | 採用 | 理由 |
|------|------|------|
| 言語 | Python 3.10+ (stdlib + `watchdog`) | 依存が軽く同一スタックで処理側と統合しやすい |
| state schema | `{schema:1, items:{path:{size,mtime_ns,output,processed_at}}}` | path 一致 + size + mtime_ns で「同名差し替え」も再処理 |
| 除外 suffix / fragment | 自処理出力 (`_ocr.pdf` 等) + `.tmp/.part/.crdownload/.filepart/.download/~$` + 先頭 `.` | Drive Desktop / Word / DL の途中ファイルを誤検出させない |
| 安定化待ち | `size` を 0.5s × 10 polls (10連続一致で確定) / timeout 120s | 同期中起動を防ぐ |
| 外部処理 timeout | 30 分 (subprocess.run の timeout) | 大型データ許容しつつ無限ハング防止 |
| リトライ | **なし** (`mark_done` を呼ばないので再起動で再試行) | 殿判断待ち / state idempotency でカバー |
| 並列 | 逐次 (Observer のシングルスレッド処理) | 1 PC + Drive 同期で並列利得が小さく競合リスク回避 |
| stop シグナル | SIGINT / SIGTERM | Windows でも `Stop-Process` / `CloseMainWindow` で停止可 |

### PowerShell `start.ps1`

- `.\venv\Scripts\python.exe` を自動検出 (なければ PATH の `python`)
- `Start-Process -WindowStyle Hidden -PassThru` で非表示常駐
- stdout / stderr / pid を `%LOCALAPPDATA%\<name>\` に保存
- `-InstallStartup` で Startup フォルダにショートカット作成 (`WScript.Shell`)
- `-Foreground` でデバッグ用フォアグラウンド実行

### PowerShell `stop.ps1`

- pid file → `CloseMainWindow` → 5 秒待機 → `Stop-Process -Force` のフォールバック
- pid file 不在時は `Get-CimInstance Win32_Process` で `<name>_watch.py` を含む `python.exe` を捜索
- `-RemoveStartup` で Startup ショートカット削除

## Battle-Tested Examples

| cmd | 用途 | 結果 |
|-----|------|------|
| cmd_721b | Drive Desktop `G:\My Drive\OCR\input\` の新規 PDF → NDL OCR Lite 経由 `_ocr.pdf` 出力 | 462L watchdog + 156L start.ps1 + 107L stop.ps1 + 312L Runbook 完成 (β scope PASS)。`scan-once --dry-run` で 4 fixture (sample / `_ocr` 除外 / `.hidden` / `.tmp`) を期待通り処理 |
| cmd_721 final | 殿日本語 Win 実機で `ocr_pdf.py` 単発モード + Acrobat 日本語検索ヒット | SO-17 outcome evidence 充足、Pattern B runtime は `saneaki/legal-pdf-ocr` に分離 |

## Reuse Checklist

1. 処理対象拡張子と除外 suffix を `is_candidate()` に列挙
2. 安定化待ち poll 数 / timeout は同期サイズに合わせて調整
3. state.json の path は **絶対 path** + size + mtime_ns で同名差し替え検出
4. errors.log 行頭は ISO8601+JST タイムスタンプ
5. `.gitignore` whitelist 環境では `!scripts/<name>_watch.py` / `!scripts/<name>_start.ps1` /
   `!scripts/<name>_stop.ps1` / `!docs/<name>_runbook.md` 追加忘れ注意
6. Runbook には 初回 / 日常 / トラブル / エラー復旧 / Startup 解除 を網羅
7. VPS Linux に `pwsh` が無い場合、PowerShell syntax 検証は殿手元実機で
   `Get-Help .\scripts\<name>_start.ps1 -Full` 実施

## Anti-Patterns

- **❌ リトライ自動実行**: 失敗ファイルを `mark_done` せず errors.log 記録のみ。
  リトライは「殿判断後の再起動」のみが安全 (無限ループ防止)
- **❌ size 安定化待ち省略**: Drive 同期中の処理起動 → 0 byte ファイル / 中途半端な内容で破綻
- **❌ `_processed.json` を監視対象に含める**: 自分の state ファイルで on_created が再帰発火
- **❌ syslog/Application Event Log だけに記録**: 殿が状況確認しにくい。
  errors.log を **同期フォルダ内** に置いて Drive 経由でスマホ確認可能にする運用も検討

## Related Skills

- `pyinstaller-pymupdf-dll-bundling` — Pattern B のような PyMuPDF 系 EXE 化時の補完
- `pyinstaller-exe-smoke-test-pattern` — start.ps1 起動後の EXE 動作確認
- `shogun-bash-daemon-restart-subcommand-pattern` — Linux 側の同型 daemon (相補)
- `shogun-screenshot` — Runbook 用 PC 画面キャプチャ

## Source

- ash7 cmd_721b: Pattern B watchdog 実装レポート (`output/cmd_721b_watchdog_runbook.md`)
- cmd_721 final: 殿実機 SO-17 outcome 確認 + Pattern B runtime の `saneaki/legal-pdf-ocr` 分離
- skill_history.md L12: 「ash7 cmd_721b 抽出」承認待ち登録 (2026-05-13)
