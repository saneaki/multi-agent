# 機構成功ログ (Mechanism Success Log)

## 背景
本ファイルは shogun 多 agent システムにおける **機構の成功事例** を記録する。
`memory/Violation.md` (失敗事例集約) と対をなし、Positive Feedback として
将来の運用で「機構が想定通り機能した瞬間」を組織知化することを目的とする。

## 記録方針
- **記録対象**: 自動検知機構 / 検証機構 / 監視機構 の **真陽性 first hit** または **構造的成功事例**
- **非対象**: 通常の cmd 完遂 (これは dashboard.md の戦果テーブルで管理)
- **対比**: Violation.md の失敗事例と相互参照し、「失敗 → 機構実装 → 成功検出」のストーリー化

## 索引

| ID | タイトル | 機構 | 日時 | 関連 Violation |
|----|---------|------|------|----------------|
| [No.1](#no1--cmd_638-進行中乖離自動検出-初回成功) | cmd_638 進行中乖離自動検出 初回成功 | shogun_in_progress_monitor.sh | 2026-05-02 22:00 JST | No.23 (cmd_633 shelf-ware) と対 |
| No.2 候補 | P8 interactive prompt 検出 | shogun_in_progress_monitor.sh | 2026-05-03 JST | No.24 (cmd_641 Claude Code interactive prompt 凍結) と対 |

---

### No.1 | cmd_638 進行中乖離自動検出 初回成功

| 項目 | 内容 |
|---|---|
| 日時 | 2026-05-02 22:00 JST (cmd_638 cron 初回実行) |
| 機構 | `scripts/shogun_in_progress_monitor.sh` (cmd_638 Scope A: ash5, 370 行) |
| 検出 | **P2 dashboard 鮮度乖離** — ash1 task YAML status=`assigned` のまま (実作業 commit 完了済み) |
| 真陽性根拠 | task YAML 台帳と git 実状態の不整合を 1h 以内に機械的に検出。「お見合い停滞構造」を構造的に検知できた最初の事例 |
| 意義 | 1. 台帳更新漏れ (cmd_625 Scope E ash6 同型 silent failure) を自動検出する設計の有効性を実証<br>2. ash1 が実作業を commit したのに task YAML status を `done` に更新し忘れた、人間/エージェントの認知負担を機構が肩代わり<br>3. cmd_638 が cmd_628 implementation-verifier (受動検証) と相補的に機能することを実証 |
| 設計の証明 | cmd_638 の 5 パターン (P1 家老 dispatch 漏れ / P2 dashboard 鮮度 / P3 ash 滞留 / P4 進行中 stale / P5 殿手作業滞留) のうち P2 が **初回 cron 実行で実検出** に成功 |
| 後処理 | karo が ash1 task YAML を `status=done` + `completed_at` に修正 (人間判断の介在) |
| 関連 Violation | **No.23 (cmd_633 4新列 shelf-ware) と対** — 失敗 (cmd_633 shelf-ware) → 解消 (cmd_637) → 同型再発の自動検出 (cmd_638) という三段サイクル |
| Earned by | cmd_638 Scope A (ash5) + Scope B (ash7) + Scope C (gunshi QC, Go 判定) の協働実装 |
| Future reference | 列・field・property 添加系の State Visibility Gap が再発した場合、本機構が自動検出することで silent failure 化を防止 |

---

### No.2 候補 | P8 interactive prompt 検出

| 項目 | 内容 |
|---|---|
| 状態 | 候補。AC7 gunshi 実動作確認後に正式 No.2 化 |
| 発端 | 2026-05-03 04:00 JST、karo pane が Claude Code feedback prompt で 1h+ 凍結 |
| 機構 | `scripts/shogun_in_progress_monitor.sh` P8 interactive prompt 検出 |
| 検出対象 | 全 agent pane (`multiagent:0.0`〜`multiagent:0.8`) の末尾3行に出る `"How is Claude doing"` / `Choose option` / `[Y/n]` / `?` 終端 / 数字選択肢 |
| 成功条件 | gunshi QC で意図的な interactive prompt を発生させ、5分以内に shogun ntfy alert が発火すること |
| 関連 Violation | No.24 (cmd_641 Claude Code interactive prompt による agent 凍結) |
| 意義 | 既存 P1-P7 では拾えない UI 入力待ちを pane 実状態から検出し、tmux multi-agent 運用の停止を早期 alert に変換する |

---

## 注記
- 本稿は cmd_638 followup (将軍直命) で gunshi が起案。
- 機構成功ログは過剰記録を避け、「真陽性 first hit」または「設計の構造的成功事例」のみに限定する。
- 通常の cmd 完遂は dashboard.md / queue/reports/ で管理し、本 file には含めない。

## 関連
- `memory/Violation.md` — 失敗事例集約 (本 file と対)
- `output/cmd_638_scope_c_qc_report.md` — cmd_638 Scope C QC レポート
- `scripts/shogun_in_progress_monitor.sh` — 機構実装本体
