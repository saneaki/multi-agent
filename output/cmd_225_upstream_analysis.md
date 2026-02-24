# cmd_225: upstream 最新16コミット マージ判断レポート

**作成者**: 軍師 (gunshi)
**作成日**: 2026-02-24
**対象**: upstream/main `300eafc..adf5410`（16コミット、53ファイル、+7,737/-256行）

---

## 1. 全16コミット一覧 — メリット・デメリット表

| # | Hash | 概要 | メリット | デメリット・リスク | 推奨 |
|---|------|------|----------|-------------------|------|
| 1 | `73e5623` | Codex /clear→/new 変換（全instructionファイル） | Codex CLIでの正常動作。/clearはCodexで未対応 | 我々はClaude Code主体のため影響小。AGENTS.mdでコンフリクト | 取込 |
| 2 | `cf4bd27` | Codex /clear→/new 回帰テスト11件追加 | テスト品質向上 | なし | 取込 |
| 3 | `cbad684` | Codex CLI test --search flag対応 | テスト正確性向上 | なし | 取込 |
| 4 | `b01d56b` | Batch Processing Protocol + Critical Thinking rules | 大規模バッチ処理の品質ゲート導入。過去の全量NG事故を防止 | CLAUDE.md/AGENTS.mdでコンフリクト（追加のみ） | **取込** |
| 5 | `fc94077` | SEO大掃除Phase 1レポート | upstream固有データ。参考情報 | 大量のYAMLレポートファイル（5,500+行）がリポジトリに追加 | 見送り |
| 6 | `73c4113` | Stop Hook last_assistant_message解析 | タスク完了/エラーを自動検知→家老に通知。手動inbox_write不要に | grep誤検知リスク（「完了」を含む中間報告等）。要チューニング | **取込** |
| 7 | `cfe7470` | **PR#75: Stop Hook主要配信手段化** | inbox_watcher.shの大幅改善。shogunへのnudge改善。/clear待機時間1.0s化 | **我々の独自関数3件を含まない**（auto-reload, karo-watchdog, shogun-autostart）。最大コンフリクトリスク | **条件付取込** |
| 8 | `4468992` | /readme-sync見出しリネーム | 軽微な整合性修正 | なし | 取込 |
| 9 | `ee742b4` | README_ja.md同期 | ドキュメント最新化 | なし | 取込 |
| 10 | `71d7b0d` | README更新（model-switch, 6 skills） | ドキュメント最新化 | なし | 取込 |
| 11 | `ec88b88` | model-switch skill + switch_cli.sh | ライブCLI切替機能。364行の新スクリプト | 新機能追加のためテスト後にactive化推奨 | **取込** |
| 12 | `2a05856` | shogun ntfy受信ブロック3箇所解除 | shogunへのntfy配信改善。busy時もshogun例外で配信 | shogun paneへのsend-keys安全性（殿の入力への干渉）が低下 | **取込（注意）** |
| 13 | `d1c6049` | bash 3.2互換: agent_status.sh mapfile→while loop | macOS対応。agent_is_busy_check改善（T-BUSY-008修正） | なし | **取込** |
| 14 | `a2c9706` | bash 3.2互換: inbox_watcher fswatch fallback | macOS対応。gtimeout警告追加 | なし | 取込 |
| 15 | `cd28b6f` | bash 3.2互換: first_setup.sh バージョンチェック | macOS対応 | なし | 取込 |
| 16 | `adf5410` | PR#77: PR#75対応テスト修正 | PR#75のテスト整合性 | PR#75に依存 | PR#75と同時取込 |

---

## 2. 安定性リスク評価

### 2.1 コア機能への影響

| コア機能 | 影響するコミット | リスク | 根拠 |
|----------|----------------|--------|------|
| **inbox配信** | cfe7470, 2a05856 | **中** | send_wakeup()のshogun例外追加、display-message廃止→send-keys統一。殿のpaneへのkey injection増加 |
| **agent起動** | cfe7470 | **低** | shutsujin_departure.shの変更は表示名統一のみ |
| **busy判定** | d1c6049 | **低（改善）** | agent_is_busy_checkのstatus bar優先チェック。T-BUSY-008修正で偽busy減少 |
| **Stop Hook** | 73c4113, cfe7470 | **中** | last_assistant_message解析による自動通知は新機能。grep誤検知の可能性あり |
| **ntfy** | 2a05856 | **中** | auto-reply削除、shogunブロック3箇所解除。ntfy配信は改善されるが殿のpane安全性は低下 |
| **エスカレーション** | cfe7470 | **低** | busy時のshogun例外追加のみ。基本ロジック変更なし |

### 2.2 我々の独自機能への影響

**重要**: upstream版inbox_watcher.shには以下の我々の独自機能が存在しない：

| 独自機能 | 実装箇所 | 導入cmd | 影響 |
|----------|---------|---------|------|
| `check_script_reload()` | inbox_watcher.sh L851-895 | cmd_198 | auto-reload機能。スクリプト変更時にexec再起動 |
| `check_karo_uncommitted()` | inbox_watcher.sh L897-941 | 独自開発 | karo busy→idle遷移時のgit status確認 |
| `check_shogun_autostart()` | inbox_watcher.sh L943-978 | 独自開発 | Claude未起動+unread時の自動起動 |

**3-way merge結果**: git merge-treeテストの結果、inbox_watcher.shはコンフリクト**なし**。
これは共通祖先(300eafc)にこれらの関数が存在しなかったため、gitが「我々の追加」と「upstreamの変更」を
両方保持する方向で自動マージできるため。**ただし自動マージ結果の動作確認は必須。**

---

## 3. コンフリクト分析（最重要）

### 3.1 merge-tree テスト結果

`git merge-tree` で6箇所のコンフリクトを検出：

| ファイル | コンフリクト数 | 原因 | 解決難易度 |
|---------|---------------|------|-----------|
| `.gitignore` | 1 | 我々の`update_dashboard_timestamp.sh` vs upstream `switch_cli.sh` のホワイトリスト行 | **易** — 両方追加すればよい |
| `AGENTS.md` | 3 | (1) 我々のPattern B (VSCode)セクション vs upstream /clear→/new変更 (2) /clear Recovery見出し変更 (3) Context Layers（我々のLayer 1 global_context.md vs upstream版） | **中** — 我々の独自セクションを保持しつつupstreamの文言変更を取り込む |
| `CLAUDE.md` | 1 | Batch Processing Protocol追加位置の衝突（追加のみ、内容同一の可能性） | **易** — 追加内容が同一なら片方削除 |
| `.github/copilot-instructions.md` | 1 | CLAUDE.mdと同様のBatch Processing Protocol追加 | **易** |

### 3.2 scripts/inbox_watcher.sh（コンフリクトなし、要注意）

自動マージは成功するが、以下の確認が必要：

1. **send_wakeup()内のshogun例外** — upstream版はshogunを`agent_is_busy`チェックから除外。我々のcheck_shogun_autostart()との干渉なし（別関数）
2. **main loop末尾** — upstream版はcheck_karo_uncommitted()とcheck_script_reload()の呼出がない（共通祖先にもないため、我々の追加が保持される）
3. **cli_restart type追加** — 新機能。我々のコードとは無関係。安全に追加される

### 3.3 scripts/stop_hook_inbox.sh（コンフリクトなし）

upstream版が大幅に拡張（last_assistant_message解析追加）。我々の版との差分は95行。
共通祖先からの変更が重ならないため自動マージ可能と推測。

### 3.4 scripts/ntfy_listener.sh（コンフリクトなし）

変更はauto-reply削除の1行のみ（3行→削除）。軽微。

### 3.5 instructions/ 配下

我々のinstructionsは独自構造（`instructions/shogun.md`等）のため、
upstream版generated/ファイルとの直接コンフリクトは発生しない。
ただしroles/の変更（Critical Thinking Protocol等）は手動でinstructions/*.mdに反映が必要。

---

## 4. マージ戦略の推奨

### 推奨: **D. 段階的マージ（2Phase）**

**根拠**: 全マージ(A)はコンフリクト解決が一度に必要で検証負荷が高い。cherry-pick(B)は16コミットの依存関係追跡が煩雑。見送り(C)は有用な改善を逃す。段階的マージが最もリスクが低い。

#### Phase 1: 安全な改善（即時マージ可能）— 10コミット

対象:
- `d1c6049` — bash 3.2互換 agent_status.sh（busy判定改善）
- `a2c9706` — bash 3.2互換 inbox_watcher fswatch
- `cd28b6f` — bash 3.2互換 first_setup.sh
- `ec88b88` — model-switch skill + switch_cli.sh
- `b01d56b` — Batch Processing Protocol + Critical Thinking
- `73e5623` — Codex /clear→/new変換
- `cf4bd27` — Codex回帰テスト
- `cbad684` — Codex CLI test更新
- `4468992` + `71d7b0d` + `ee742b4` — README/ドキュメント更新

**手順**: cherry-pick → batsテスト全件実行 → コンフリクト解決(AGENTS.md/CLAUDE.md) → push

#### Phase 2: コア変更（テスト環境での検証後マージ）— 4コミット

対象:
- `73c4113` — Stop Hook last_assistant_message解析
- `cfe7470` — **PR#75 Stop Hook主要配信**
- `adf5410` — PR#77 テスト修正
- `2a05856` — shogun ntfy受信ブロック解除

**手順**:
1. 別ブランチ `feature/upstream-phase2` で全マージ実行
2. 自動マージ結果のinbox_watcher.shを手動レビュー（独自関数3件の保持確認）
3. stop_hook_inbox.shの自動マージ結果確認
4. batsテスト全件実行（特に test_send_wakeup.bats — 354行の差分あり）
5. inbox_watcher.sh再起動 → 実環境テスト（inbox配信、エスカレーション）
6. 問題なければoriginalにマージ

#### 見送り: 1コミット

- `fc94077` — SEO大掃除Phase 1レポート（5,500+行のデータファイル。リポジトリ肥大化リスク。upstream固有データ）

---

## 5. マージした場合のテスト計画

### Phase 1テスト

| テスト | コマンド | 確認項目 |
|--------|---------|---------|
| bats全件 | `bats tests/` | 全件PASS（既存5 FAIL以外の退行なし） |
| busy判定 | 手動: pane末尾確認 | agent_is_busy_checkの偽busy/偽idle解消 |
| model-switch | `bash scripts/switch_cli.sh ashigaru1 sonnet` | CLI切替動作 |
| AGENTS.md/CLAUDE.md | 目視 | コンフリクト解決の整合性 |

### Phase 2テスト

| テスト | コマンド | 確認項目 |
|--------|---------|---------|
| bats全件 | `bats tests/` | test_send_wakeup.bats, test_stop_hook.bats含む |
| inbox配信 | `bash scripts/inbox_write.sh ashigaru1 "test" test_msg karo` → inbox到着確認 | inbox_watcher正常動作 |
| Stop Hook | 足軽タスク完了 → karoへの自動通知到着 | last_assistant_message解析の誤検知チェック |
| shogun nudge | ntfy送信 → shogun pane到着 | busy時のshogun例外動作 |
| 独自関数 | inbox_watcher.shログ確認 | auto-reload, karo-watchdog, shogun-autostartが動作 |
| エスカレーション | 4分放置テスト | Phase2/3が正常動作 |

---

## 6. 殿の判断を仰ぐべきポイント

1. **Phase 2のshogun nudge変更**: upstream版はshogun paneへのsend-keys制限を撤廃。殿がClaude使用中にntfy nudgeが割り込む可能性が増加。これを許容するか？
2. **SEO大掃除レポート（fc94077）**: 5,500+行のデータファイル。リポジトリに含めるか見送るか？
3. **Stop Hook自動通知のチューニング**: 「任務完了」「完了でござる」等のgrepパターンは我々の戦国口調に最適化済みだが、誤検知（中間報告に「完了」を含む文脈）のリスクをどう扱うか？
4. **Phase 1→Phase 2の実施タイミング**: Phase 1を即時実施してよいか？Phase 2はどの程度の検証期間を設けるか？

---

## 付録: 新規ファイル一覧

| ファイル | 行数 | 内容 |
|---------|------|------|
| `scripts/switch_cli.sh` | 364 | ライブCLI切替スクリプト |
| `skills/shogun-model-switch/SKILL.md` | 152 | model-switchスキル |
| `skills/shogun-readme-sync/SKILL.md` | 104 | README同期スキル |
| `tests/unit/test_build_system.bats` | 69 | ビルドシステムテスト |
| `tests/unit/test_stop_hook.bats` | 149 | Stop Hookテスト |
| `tests/unit/test_switch_cli.bats` | 287 | switch_cliテスト |
| `queue/reports/ashigaru*_cleanup_report.yaml` | ~5,500 | SEO大掃除レポート（6ファイル） |
