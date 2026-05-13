# Pattern B OCR Runbook (cmd_721)

殿向け運用手順書。Google Drive Desktop 経由でアップロードした PDF を
NDL OCR Lite + PyMuPDF で検索可能 PDF (`*_ocr.pdf`) に自動変換する
オフライン基盤の使い方をまとめる。

> **対象環境**: Windows 10 / 11 + Python 3.10–3.13
> **依存**: NDL OCR Lite v1.2.1, PyMuPDF, watchdog, Pillow
> **配置**: shogun リポジトリの `scripts/ocr_watch.py` と `scripts/ocr_pdf.py`
> **コスト**: ¥0 (完全オフライン、商用 API 呼出なし)

---

## 1. 初回セットアップ (Phase 0)

### 1.1 Google Drive Desktop の導入

1. <https://www.google.com/drive/download/> から Drive Desktop をインストール。
2. 殿の Google アカウントでサインイン。
3. **マイドライブ** をストリーミングではなく **ミラーリング** で同期する設定にする
   (歯車 → 環境設定 → Google ドライブ → マイドライブ → "ファイルをミラーリングする")。
4. 同期完了後、`%USERPROFILE%\Google Drive\My Drive\` がローカルパスとして使えることを確認。
   (例: `C:\Users\sane\Google Drive\My Drive\`)

### 1.2 監視フォルダの準備

Drive 側に以下を作成する。

```
My Drive/
└── OCR/
    └── input/        ← ここに PDF を投げ込む
```

ローカルでは `%USERPROFILE%\Google Drive\My Drive\OCR\input\` として現れる。

### 1.3 リポジトリの clone と依存導入

```powershell
cd $env:USERPROFILE\source
git clone https://github.com/saneaki/multi-agent.git shogun
cd shogun

# α (subtask_721a) で提供されるセットアップスクリプト
.\scripts\setup_pattern_b.ps1
```

`setup_pattern_b.ps1` の責務 (cmd_721 AC-1/2):

- Python 3.10–3.13 venv を `.\venv\` に作成
- `requirements.txt` から PyMuPDF / watchdog / Pillow / 他依存を導入
- NDL OCR Lite v1.2.1 を `tools\ndlocr-lite\` などに展開し、CLI が動作することを確認

> **β (本書) はこれらに依存する。α が未完の場合、ocr_watch.py は新規 PDF を検出するたびに**
> **`errors.log` に "ocr_pdf script missing" を残して停止する。**

### 1.4 動作確認 (smoke test)

α 完了後、依存導入が済んだ状態で:

```powershell
# Python と watchdog が見えること
.\venv\Scripts\python.exe -c "import watchdog; print(watchdog.__version__)"

# ocr_watch.py の help が出ること
.\venv\Scripts\python.exe .\scripts\ocr_watch.py --help

# 監視フォルダにダミー PDF を 1 件置いて scan-once + dry-run
.\venv\Scripts\python.exe .\scripts\ocr_watch.py `
  --watch-dir "$env:USERPROFILE\Google Drive\My Drive\OCR\input" `
  --scan-once --dry-run
```

`would invoke ... ocr_pdf.py ...` のログが出れば配線 OK。

---

## 2. 日常運用 (Phase 1)

### 2.1 デーモンの起動

```powershell
# 標準起動 (横書き想定)
.\scripts\ocr_watch_start.ps1

# 縦書きを含む PDF 中心なら --enable-tcy を付ける
.\scripts\ocr_watch_start.ps1 -EnableTcy
```

出力例:

```
Python   : C:\Users\sane\source\shogun\venv\Scripts\python.exe
Script   : C:\...\scripts\ocr_watch.py
WatchDir : C:\Users\sane\Google Drive\My Drive\OCR\input
LogDir   : C:\Users\sane\AppData\Local\ocr_watch
EnableTcy: True
Started ocr_watch (PID 12345)
PID file : C:\Users\sane\AppData\Local\ocr_watch\ocr_watch.pid
stdout   : ...\ocr_watch_<timestamp>.out.log
stderr   : ...\ocr_watch_<timestamp>.err.log
```

### 2.2 PDF のアップロード

PC・スマホ・タブレットいずれからでも、Drive の `OCR/input/` に PDF を置けば
Drive Desktop が PC のローカルへ同期 → watchdog が検知 → ocr_pdf.py で OCR
→ 同じフォルダに `元のファイル名_ocr.pdf` を生成する。

> **原本 PDF は上書きしない** 設計のため、Drive 上には原本と `_ocr.pdf` の
> 両方が残る。検索したいときは `_ocr.pdf` 側を開く。

### 2.3 デーモンの停止

```powershell
.\scripts\ocr_watch_stop.ps1
```

`-Force` で強制停止、`-RemoveStartup` で自動起動登録の削除も可能。

### 2.4 PC 起動時の自動起動

ログオン時に自動で常駐させたい場合:

```powershell
.\scripts\ocr_watch_start.ps1 -EnableTcy -InstallStartup
```

`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ocr_watch.lnk`
にショートカットが置かれ、次回ログオン時から有効になる。

> Drive Desktop の自動起動も合わせて確認すること
> (Drive Desktop の環境設定 → 起動時に Google ドライブを開く)。

### 2.5 動作状況の確認

```powershell
# プロセスが居るか
Get-Process python | Where-Object { $_.Path -like "*\venv\Scripts\python.exe" }

# 直近のログ (out)
Get-ChildItem $env:LOCALAPPDATA\ocr_watch\*.out.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50

# エラー履歴 (errors.log は監視フォルダ直下)
Get-Content "$env:USERPROFILE\Google Drive\My Drive\OCR\input\errors.log" -Tail 50

# 処理済 PDF の記録
Get-Content "$env:USERPROFILE\Google Drive\My Drive\OCR\input\.processed.json"
```

---

## 3. トラブルシュート (Phase 2)

### 3.1 OCR されない

| 症状 | 確認 | 対処 |
|------|------|------|
| `_ocr.pdf` が出来ない | デーモンが動いているか (2.5 参照) | 停止していれば `ocr_watch_start.ps1` を再実行 |
| ファイル名末尾が `_ocr.pdf` | 仕様 (再 OCR 防止) | `_ocr.pdf` は監視対象外。別名で置き直す |
| 隠しファイル名 (先頭 `.`) | 仕様 (システムファイル除外) | ファイル名を変更 |
| `.tmp` / `.crdownload` 等 | Drive 同期中ファイルとして除外 | 同期完了を待つ (自動で再検出) |
| 拡張子が `.PDF` (大文字) | 仕様 (小文字限定) | リネームで `.pdf` に統一 |
| サブフォルダ配下に置いた | recursive watch=有効 (検出される) | `errors.log` を確認 |

### 3.2 errors.log の見方

```
[2026-05-13T14:02:11+09:00] C:\...\input\foo.pdf :: ocr_pdf returncode=1 :: NDL CLI: ...
```

| メッセージ | 意味 | 対処 |
|------------|------|------|
| `ocr_pdf script missing` | `scripts/ocr_pdf.py` が無い | α (subtask_721a) の導入を確認 |
| `python executable missing` | `-PythonExe` が間違い / venv 未作成 | setup_pattern_b.ps1 を再実行 |
| `ocr_pdf returncode=N` | OCR 本体が失敗 | detail を確認。多くは NDL OCR Lite or PyMuPDF の例外 |
| `ocr timed out` | 30 分以内に完了せず | PDF サイズを確認。大型は分割を検討 |
| `file did not stabilize before OCR` | Drive 同期が長引いた | 同期完了後に手動で再投入 |
| `ocr_pdf reported success but output missing` | exit 0 だが `_ocr.pdf` 無し | α の I/F 不一致。報告 (本書 §5 参照) |
| `unhandled exception` | 想定外例外 | detail と stderr ログを軍師に共有 |

> **本デーモンはリトライしない**。誤投入は `errors.log` のエントリを削除した上で
> 同じファイルを置き直すか、`.processed.json` を編集して再処理させる。

### 3.3 PC 起動忘れ / スリープ

- PC スリープ中・電源 OFF 中はパイプラインが止まる。
- 復帰時に **起動時スキャン** が走り、`_ocr.pdf` が未生成のファイルだけ処理される。
- スリープ復帰時に同期と OCR が重なるため、初回数十秒は CPU 使用率が上がる。

### 3.4 Drive 同期遅延

- Drive Desktop はファイル更新を即座にローカル反映するが、巨大 PDF やネット
  状況により数十秒〜数分かかる。
- ocr_watch は `wait_until_stable` でファイルサイズが安定するまで待つため、
  途中の壊れた状態で OCR してしまうことはない。

### 3.5 `.processed.json` の手動操作

| 操作 | 手順 |
|------|------|
| 1 件を再 OCR したい | `.processed.json` を開き、当該キー (フルパス) を削除して保存 |
| 全件を再 OCR したい | `.processed.json` を削除 (次回起動時に再生成) |
| 既存 `_ocr.pdf` を破棄 | エクスプローラから `_ocr.pdf` を削除し、上を実行 |

> JSON は人手編集可能。`schema=1`, `items` の dict、各エントリは `size` / `mtime_ns` / `output` / `processed_at`。

---

## 4. 縦書き / 横書き / 既存 PDF の扱い

### 4.1 縦書きと横書きの混在

NDL OCR Lite は両方扱える。`--enable-tcy` を渡すと縦中横 (数字・英字が縦書きに
回り込む組版) の認識が改善する。基本は `ocr_watch_start.ps1 -EnableTcy` で常時
有効にしておくのが安全。横書き中心の文書でも副作用は小さい。

> NDL OCR Lite 自体の縦書き精度は cmd_720a の調査結果を参照
> (`output/cmd_720a_ndl_ocr_lite_research.md`)。
> 殿の手元 PDF での実機検証は γ (subtask_721c, 未配備) の責務。

### 4.2 既存 PDF の一括変換

本デーモンは **新規 / 未処理 PDF のみ** 対象。`OCR/input/` の中に既に `_ocr.pdf`
を持たない PDF が大量にあると、起動時スキャンですべて処理対象になる。

| ケース | 推奨手順 |
|--------|---------|
| 数件 (10 件未満) | そのまま `OCR/input/` に置く。起動時スキャンで自動処理 |
| 多数 (10–100 件) | `OCR/input/` のサブフォルダ (例: `batch_20260513/`) に投入。1 回の起動で連続処理 |
| 大量 (100+) | 別 cmd で計画 (cmd_721 積み残し参照)。並列化や進捗可視化が必要 |

`.processed.json` を空にして再起動すれば全件再 OCR できる。ただし
NDL OCR Lite の処理時間は 1 ページ 2–5 秒程度を想定するため、所要時間に注意。

---

## 5. β からの引継ぎ / 既知の制約 (γ 向け)

### 5.1 前提 I/F (α 確定前の暫定設計)

β は α 未完の状態で実装したため、以下の I/F を前提にしている。
α 確定値と差分がある場合は γ で吸収する。

```text
python scripts/ocr_pdf.py <INPUT_PDF> --output <OUTPUT_PDF> [--enable-tcy]
  - INPUT_PDF: 既存 PDF パス (上書き禁止)
  - OUTPUT_PDF: 別名 (推奨: <stem>_ocr.pdf)
  - returncode 0 = 成功、非 0 = 失敗 (stdout/stderr に診断)
  - --enable-tcy: 縦中横改善 (NDL OCR Lite に転送)
```

α が異なる I/F を採用した場合は `scripts/ocr_watch.py` の `OcrInvoker.process()`
を最小限の変更で合わせ込む (引数並び順 / オプション名のみ)。

### 5.2 β で未検証の項目

| 項目 | 理由 | γ / 殿対応 |
|------|------|------------|
| 実機 Windows での `Start-Process` 動作 | VPS = Linux のため pwsh 不在 | 殿が手元 PC で `.\scripts\ocr_watch_start.ps1` を一度実行し、PID file と log が生成されることを確認 |
| 自動起動 (Startup フォルダ ショートカット) | 同上 | `-InstallStartup` でログオン再起動して常駐するか確認 |
| Drive Desktop の同期挙動 | 同上 | 巨大 PDF (50MB+) で `wait_until_stable` のタイムアウト (現状 120s) が足りるか確認 |
| OCR 本体との結合 | α 未完 | α 完成後に scan-once 実機 (10 件程度) で結合確認 |
| 縦書き PDF の `--enable-tcy` 効果 | NDL Lite 動作確認は γ PoC | γ で 5–10 件 PoC |

### 5.3 拡張余地

- 並列処理: 現状逐次。CPU コア数を活かす並列実装は γ 以降で検討。
- メトリクス: 処理件数 / 平均処理時間を `.processed.json` から集計するスクリプト未提供。
- 通知: 失敗時の Slack / GChat 通知未実装 (errors.log を殿が見る前提)。

---

## 6. ファイル一覧

| パス | 役割 |
|------|------|
| `scripts/ocr_watch.py` | watchdog デーモン本体 (β, 本書対象) |
| `scripts/ocr_watch_start.ps1` | Windows 起動スクリプト (β) |
| `scripts/ocr_watch_stop.ps1` | Windows 停止スクリプト (β) |
| `scripts/ocr_pdf.py` | OCR 本体 (α, subtask_721a) |
| `scripts/setup_pattern_b.ps1` | 依存導入 (α) |
| `requirements.txt` | Python 依存リスト (α が watchdog/PyMuPDF を追加) |
| `<watch-dir>/.processed.json` | 処理済記録 |
| `<watch-dir>/errors.log` | 失敗ログ |
| `%LOCALAPPDATA%\ocr_watch\*.out.log` | デーモン stdout |
| `%LOCALAPPDATA%\ocr_watch\*.err.log` | デーモン stderr |
| `%LOCALAPPDATA%\ocr_watch\ocr_watch.pid` | 実行中 PID |

---

## 7. 参考: cmd_721 設計との対応

| AC | 対応 |
|----|------|
| AC-4 監視デーモン | scripts/ocr_watch.py (本書 §2/§3) |
| AC-5 Windows 自動起動 | scripts/ocr_watch_start.ps1 + `-InstallStartup` (§2.4) |
| AC-7 殿向け使用手順 | 本書全文 |

### β 内部 AC (subtask_721b)

| 内部 AC | 対応 |
|---------|------|
| B-1 watchdog 実装 | `OcrInvoker` + `make_handler` + `run_watch` |
| B-2 起動時未処理検出 | `initial_scan` + `_ocr.pdf` / hidden / tmp 除外 |
| B-3 `.processed.json` | `ProcessedStore` (size + mtime_ns で再処理判定) |
| B-4 errors.log + リトライなし | `ErrorLog` + 失敗時 `mark_done` 呼ばない設計 |
| B-5 start/stop + Startup | ocr_watch_start.ps1 / stop.ps1 + `-InstallStartup` |
| B-6 Runbook | 本書 |
| B-7 単独 β 検証 | `--help` / `--scan-once --dry-run` / `py_compile` |
| B-8 引継ぎ記録 | `output/cmd_721b_watchdog_runbook.md` |
| B-9 git status | β report YAML 記録 |
