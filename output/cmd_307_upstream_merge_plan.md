# upstream/main マージ計画書 (cmd_307)

作成日: 2026-03-10 JST
対象: upstream/main (2ef81f9) → origin/original

## 概要

| 項目 | 値 |
|------|-----|
| upstream新コミット | 1件 (2ef81f9: compaction後ペルソナ復元の強制) |
| 前回マージ | b253999 (2026-03-05) |
| diff規模 | 45ファイル、+1,424 / -4,613行 |
| diffが大きい理由 | upstreamの大幅リファクタリング + fork独自ファイルとの乖離 |

## 1. upstream新機能（採用すべき変更）

### 1.1 Post-Compaction Recovery (CLAUDE.md)

compaction後にペルソナ・口調が脱落する問題の対策。compaction後にinstructions/*.mdの再読込を強制する。

**判定: 採用**。我々も同じ問題に遭遇しており、有益な改善。

### 1.2 bloom_routing_rule (CLAUDE.md)

`config/settings.yaml` の bloom_routing 設定を確認し、auto なら家老が Step 6.5 を必ず実行する旨を明記。

**判定: 採用**。Bloom Taxonomy ルーティングの確実な実行を保証する。

### 1.3 instructions/karo.md 大規模リライト (1,807行変更)

upstream がkaro.mdを大幅に書き直している。

**判定: 慎重にマージ**。cmd_302（Step 3 進行中更新漏れ修正）およびcmd_303（IMP-001〜004）の fork独自修正との衝突が確実。手動マージが必要。

### 1.4 Report Flow の表現簡素化 (CLAUDE.md)

軍師自律QCプロトコルに関する表現が簡素化されている。

**判定: fork版を優先**。我々の記述の方が具体的で運用に即している。

## 2. fork独自で保持すべきセクション

upstreamが削除したが、我々の運用に必要なもの:

| セクション | ファイル | 理由 |
|-----------|---------|------|
| Pattern B: VSCode環境分岐 | CLAUDE.md | fork独自機能。VSCode拡張での利用に必要 |
| memory/global_context.md のContext Layer | CLAUDE.md | 殿の決定で学習メモ保存先として運用中 |
| テスト自走原則 | CLAUDE.md | n8n Gmail WF等のテスト自動化に必要 |
| Web検索義務（Critical Thinking Rule #6） | CLAUDE.md | 殿承認済みルール。エラー修正品質の担保 |
| ペルソナテーブル（/clear Recovery内） | CLAUDE.md | fork独自の口調定義。全エージェントが参照 |
| 軍師自律QCプロトコル詳細 | CLAUDE.md | cmd_244/245の9時間停滞事故の再発防止策 |

## 3. 削除対象ファイル分析

### 3.1 fork独自ファイル（upstreamに一度も存在しない）

マージ時に衝突しないが、整理の機会として判断する。

| ファイル | 行数 | 経緯 | 判定 | 理由 |
|---------|------|------|------|------|
| scripts/notion_session_log.sh | 808 | cmd_232〜282で7回改修 | **保持** | 花の園Notion日記に活動ログを反映。殿の業務で使用中 |
| scripts/cmd_complete_notifier.sh | 97 | cmd_241で作成 | **削除検討** | dashboard変更→ntfy自動通知。karo.md Step 11.7の正規ntfy経路と重複。セーフティネットとしての価値はあるが二重通知リスク |
| scripts/update_dashboard_timestamp.sh | 37 | cmd_199で作成 | **削除検討** | PostToolUse Hookから呼ばれるが、全Edit/Writeで発火するため非効率。upstreamも同Hookを削除 |
| scripts/worktree_cleanup.sh | 117 | cmd_126 PoCで作成 | **削除** | worktreeは運用に入っていない |
| scripts/worktree_create.sh | 106 | cmd_126 PoCで作成 | **削除** | 同上 |
| instructions/common/worktree.md | 115 | cmd_244でkaro.mdから外部抽出 | **削除** | worktree未使用 |
| instructions/skill_policy.md | 276 | 初期作成 | **削除** | 参照箇所ゼロ。スキル管理はdashboard + suggestions.yaml に移行済み |
| instructions/skill_candidates.yaml | 171 | 初期作成 | **削除** | 同上 |
| instructions/generated/* | 各138 | karo.md派生(Copilot/Codex/Kimi用) | **削除** | 未使用。4ファイル計552行 |

### 3.2 upstreamにも存在し、fork側で拡張したファイル

| ファイル | upstream | fork | 差分 | 判定 | 理由 |
|---------|----------|------|------|------|------|
| scripts/watcher_supervisor.sh | 55行 | 132行 | +77行 | **保持（fork版）** | 多重起動防止ロック + cmd_complete_notifier起動 + 定期点呼(roll call)機能。Issue #3で導入した自動復旧機構 |
| lib/agent_status.sh | 11行 | 11行 | なし | upstream版に合わせる | 変更なし |

### 3.3 画像ファイル

| ファイル | 判定 | 理由 |
|---------|------|------|
| images/screenshots/*.jpg (ルート直下6枚) | **削除** | READMEは `masked/` サブディレクトリを参照。ルート直下はforkでコピーした重複 |
| images/screenshots/ntfy_tasklist_final.jpg | **削除** | README未参照 |
| images/screenshots/tdd_ndd_rdd.png | **削除** | README未参照 |

## 4. 削除検討2件の詳細分析

### 4.1 cmd_complete_notifier.sh

**現状の通知経路（2系統が並存）:**

| # | 経路 | 仕組み | トリガー |
|---|------|--------|---------|
| 1 | cmd_complete_notifier.sh | inotifywaitでdashboard.md監視 → 「✅」検出 → ntfy送信 | ファイル変更 |
| 2 | karo.md Step 11.7 | cmdコンプリート時にkaro自身が `bash scripts/ntfy.sh` を実行 | karo判断 |

**分析:**

- 経路2（Step 11.7）が正式経路として2026-02以降安定稼働
- 経路1は経路2導入前の暫定措置（cmd_241, 2026-02中旬）
- 経路1が残ることで、karoがコンパクション等で通知を落とした場合のセーフティネットになりうる
- 一方、二重通知（同じcmd完了が2回ntfyに届く）が発生するリスクあり

**削除した場合の影響:** watcher_supervisor.shの `start_cmd_notifier_if_missing()` 関数も除去が必要。

### 4.2 update_dashboard_timestamp.sh

**現状:**

- `.claude/settings.json` の PostToolUse Hook として登録済み
- matcher: `Edit|Write` → **全ファイルの編集で発火**（dashboard以外でも）
- upstreamは同Hookを削除済み

**分析:**

- dashboard.mdの最終更新時刻をJSTで自動更新する役割
- しかし全Edit/Writeで発火するため、足軽のコード編集時にも無駄に実行される
- dashboard更新は家老/軍師が `jst_now.sh` で手動記載する運用が確立しており、自動更新の必要性が低下

**削除した場合の影響:** `.claude/settings.json` のPostToolUse Hookも除去が必要。

## 5. マージ実装計画

### Phase 1: 事前準備

1. 進行中タスク（cmd_305/306）の完了を待つ
2. 全変更をcommit
3. fork独自削除対象ファイルを先に削除・commit（衝突を減らす）

### Phase 2: マージ実行

1. `git merge upstream/main` でコンフリクト一覧を確認
2. コンフリクト解決（優先度順）:

| ファイル | 戦略 |
|---------|------|
| CLAUDE.md | upstream変更を採用 + fork独自セクション(§2)を復元 |
| instructions/karo.md | **最重要**。upstreamリライト + cmd_302/303修正の手動マージ |
| instructions/ashigaru.md | IMP-001/003の変更を保持 + upstream変更を取り込み |
| instructions/gunshi.md | IMP-002/004の変更を保持 + upstream変更を取り込み |
| instructions/shogun.md | upstreamの削減を受け入れつつ、fork独自セクションを保持 |
| .claude/settings.json | upstreamのHook削除を受け入れ（§4.2の判断次第） |

### Phase 3: テスト

1. unit test: `bats tests/unit/` 全件PASS（SKIP=0必須）
2. E2E test: `bats tests/e2e/` SKIP以外全件PASS
3. 手動確認: 各agent起動→instructions読込→ペルソナ維持→正常動作

### Phase 4: push

1. `git push origin original`

## 6. リスク

| リスク | 影響度 | 対策 |
|--------|--------|------|
| karo.md衝突が複雑 | HIGH | 手動マージ + 軍師レビュー |
| cmd_305修正がマージと衝突 | MEDIUM | cmd_305完了後にマージ着手 |
| テスト変更で既存テストが壊れる | MEDIUM | マージ後に全テスト実行で検証 |
| fork独自セクション復元漏れ | LOW | §2のチェックリストで確認 |

## 7. 殿のご判断が必要な事項

1. **cmd_complete_notifier.sh**: 削除するか、セーフティネットとして残すか
2. **update_dashboard_timestamp.sh + PostToolUse Hook**: 削除するか
3. **マージのタイミング**: cmd_305/306完了後でよいか
