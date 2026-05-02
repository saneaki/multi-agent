# cmd_631 Scope A — shogun 会話ログ → Obsidian → Notion 統合 要件定義書

- **task_id**: subtask_631_scope_a_requirements
- **担当**: 軍師 (Opus)
- **作成日時**: 2026-05-02 04:21 JST
- **対象システム**: shogun 多 agent 会話ログを Obsidian (中継ハブ) 経由で Notion に統合する自動化基盤
- **殿確定仕様反映**: 9 件全反映 (本書 §1-§8 で網羅)

---

## §1 背景・目的

### 1.1 現状の二重記録問題

shogun システムでは現在、2 つの記録チャネルが並存:

1. **`scripts/notion_session_log.sh`** — Stop hook 呼出で Notion Activity Log DB と日記タスクに記録 (33,438 bytes / cmd_604 期に整備)
2. **`~/.claude/sessions/*.tmp`** — Claude Code が自動生成するセッションファイル (42 件、2026-03-29〜2026-05-02 累積)

両者の問題点:
- 記録の **重複** と **不整合** が散発 (Notion 側 / tmp 側で取り扱い差)
- **詳細会話 (cmd 単位)** が Notion Activity Log では取り出しにくい (集約サマリーのみ)
- **Obsidian は未活用** で、検索性 / バックリンクの恩恵を受けられていない
- 殿が後日「あの cmd で何を考えたか」を辿るには、tmp + reports + inbox を手動横断する必要

### 1.2 Obsidian 中継ハブ化の意図

Obsidian は **PKM (Personal Knowledge Management)** に最適化されたローカル markdown 中心の体系。本統合では:

- **Obsidian** = 詳細会話ログ (cmd ごと、自動分類、検索/バックリンク前提)
- **Notion** = 概要 narrative (500字、「考え→作業→結果」のストーリー) + Obsidian 逆リンク

役割分担により、Notion の「閲覧/共有性」と Obsidian の「検索/関連性」を併用、cmd 単位で「どう考えて何を作って結果どうだったか」を後追い可能にする。

### 1.3 北極星

| ID | 北極星 |
|----|--------|
| N1 | source S1-S3+S5 の完全性 (取りこぼしゼロ) |
| N2 | cmd 発令時の新セクション正確分離 (cmd_NNN 境界の安定検出) |
| N3 | Notion 概要 500字 narrative 品質 (機械的羅列でなく「考え→作業→結果」) |
| N4 | 二重記録解消 (`notion_session_log.sh` 廃止) |

---

## §2 対象スコープ

### 2.1 記録対象会話 (殿確定)

以下 3 種の会話 / 出力を統合記録する:

1. **殿 ↔ 将軍 直接会話** — 将軍 (Claude Code main) が殿から受けた指示・質問・確認応答
2. **足軽 / 軍師の提案事項** — `queue/reports/*_report.yaml` の `suggestions` フィールドに含まれる ash/gunshi 提言
3. **将軍の検討** — 将軍が `queue/inbox/shogun.yaml` 経由で karo に発した cmd / 判断 / 殿令対処内容

### 2.2 除外スコープ

- 自動 shell コマンド出力 (`Bash` tool の素出力) — 文脈依存性高く、機械情報のため記録対象外
- agent 内部の thinking ブロック (本来非可視のため対象外)
- `*.lock` / `*.tmp` 等の中間ファイル (記録の冗長化を避ける)

---

## §3 入力ソース定義 (S1-S3+S5)

### 3.1 S1: `~/.claude/sessions/*.tmp`

- **形式**: markdown / プレーンテキスト混在 (例: `2026-05-02-shogun-session.tmp`)
- **内容**: Claude Code セッション開始日時 / 経過 / 状態スナップショット (冒頭 3 行例: `# Session: 2026-04-01 / **Date:** 2026-04-01 / **Started:** 11:18`)
- **件数**: 42 件累積 (2026-03-29 起点、agent 別 `.claude-session.tmp` / `shogun-session.tmp` の 2 系統)
- **抽出粒度**: 1 ファイル = 1 セッション = 1 日分または 1 復旧サイクル
- **欠損対応**: tmp 不在 / サイズ 0 の場合はそのソースをスキップしログに warn

### 3.2 S2: `queue/reports/*.yaml`

- **形式**: yaml (`gunshi_report.yaml` / `ashigaru[1-8]_report.yaml` の 9 ファイル)
- **内容**: 各 agent の完遂報告 + AC verification + suggestions + skill_candidate + north_star_alignment
- **抽出粒度**: 1 yaml = 1 task の完遂レポート (上書き式、最新のみ反映)
- **抽出フィールド優先順** (narrative 生成に必要):
  1. `result.summary` (1-3 段落、cmd の概要)
  2. `suggestions[].content` (提案・補強)
  3. `north_star_alignment.reason` (北極星整合)

### 3.3 S3: `queue/inbox/shogun.yaml`

- **形式**: yaml (`messages: [...]`)
- **内容**: 殿令対処報告 (karo→shogun) / 反省 / cmd 発令通知 / reality_check_alert
- **抽出粒度**: 1 message = 1 イベント (timestamp 単位)
- **重要 type**: `task_completed` / `lord_command` / `reality_check_alert`

### 3.4 S5: `dashboard.md` (補助)

- **形式**: markdown (`dashboard.yaml` から `generate_dashboard_md.py` で生成)
- **内容**: 完遂 cmd 一覧 (✅) / 進行中 (🔄) / 要行動 / 運用指標 / 各 agent 状態
- **役割**: narrative 生成時に「cmd_NNN は何だったか」のタイトル / ステータスを補助参照

---

## §4 出力定義

### 4.1 Obsidian 出力

- **保存先**: `saneaki/obsidian` リポジトリ (殿確定)
- **ファイル命名規則**: `YYYY-MM-DD-shogun-cmd-{cmd_id}.md`
  - 例: `2026-05-02-shogun-cmd-631.md`
  - **自動日付フォルダ分類**: `daily/2026-05-02/` 配下に自動配置
- **見出し階層**:

  ```markdown
  # {YYYY-MM-DD} shogun 会話ログ

  ## cmd_631: shogun 会話ログ Obsidian 統合
  - **発令時刻**: 2026-05-02 04:22 JST
  - **担当**: 軍師 (Scope A 要件定義)

  ### 殿令 / 発令内容
  (殿↔将軍直接会話)

  ### 将軍検討
  (将軍の判断、karo への dispatch)

  ### 足軽/軍師提案
  (suggestions[].content)

  ### 完遂報告サマリ
  (result.summary)

  ## cmd_632: 次の cmd
  ...
  ```

- **cmd セクション分割ロジック**: §5 参照
- **Obsidian frontmatter**: tags `[shogun, cmd, daily-log]` + `cmd_id` メタデータ (Dataview クエリ用)

### 4.2 Notion 出力

- **保存先**: 既存の Notion ワークスペース (殿の Activity Log DB を流用 or 新規 cmd 単位 DB を新設の二択 — Scope B で確定推奨)
- **概要 narrative**: 500 字 (前後 ±50 字許容) で「**どういう考えで何を作って結果どうだったか**」のストーリー形式
  - 機械的羅列禁止 (例: "AC1 PASS / AC2 PASS" ではなく "G1 を解消する設計を立て、ash5 が process substitution bug まで掘り下げて根本解消した")
  - LLM (Claude API or Codex) で生成 (Scope B で生成プロンプト確定)
- **Obsidian リンク**: Notion ページ末尾に
  ```markdown
  📂 詳細: https://github.com/saneaki/obsidian/blob/main/daily/2026-05-02/2026-05-02-shogun-cmd-631.md
  ```
- **DB schema 草案** (Scope B で精緻化):
  - `Title` (title): cmd_NNN: <タイトル>
  - `cmd_id` (rich_text): cmd_631
  - `date` (date): 2026-05-02
  - `narrative` (rich_text 500 字)
  - `obsidian_link` (url)
  - `agents_involved` (multi_select): 殿 / 将軍 / 家老 / 軍師 / 足軽1〜7
  - `status` (select): in_progress / completed
  - `dashboard_section` (select): cmd完遂 / 殿の決定事項 / 改善提案

---

## §5 cmd 境界判定ロジック

### 5.1 cmd 発令検出パターン (OR 条件のいずれか)

1. **shogun.yaml に `lord_command` type メッセージ** が出現 (殿令)
   - Pattern: `messages[].type == "lord_command"`
2. **shogun.yaml に `cmd_NNN 発令` または `新 cmd 発令`** を含む `task_completed` メッセージ (karo の完遂報告)
   - Regex: `/cmd_\d+\s*発令/` or `/新\s*cmd\s*発令/`
3. **dashboard.yaml の `in_progress` に新 `cmd_id` エントリが追加** (家老の dispatch)
   - cmd_id が前日 dashboard に存在しなければ「新 cmd」とみなす

### 5.2 cmd 跨ぎ会話の扱い

- 1 つの会話ターンが複数 cmd に跨る場合 (例: cmd_628 完遂報告 + cmd_629 開始判断が連続) は、**timestamp 順** で前後を分割
- 分割境界の判定: 上記 §5.1 の発令検出パターンが立った時点で次 cmd セクション開始

### 5.3 auto-compact 時の継続処理

- auto-compact 実行 (S1 tmp の途中切断 or 復旧) があっても、cmd_id をキーに **同 cmd への追記** を行う
- compaction 復旧後の最初のメッセージは「[cmd_NNN 続き]」見出しで補足記載

### 5.4 複数 cmd 並行の扱い (RACE-001 関連)

- cmd_628 と cmd_629 が同時並行で進む場合、Obsidian では **2 つの ## cmd_NNN セクションが同日ファイル内に共存**
- timestamp 順で交互に出現してもよい (Obsidian の見出し折りたたみで個別閲覧可能)

---

## §6 Acceptance Criteria (AC1-AC10)

| AC | 内容 | 検証方法 |
|----|------|---------|
| **AC1** (N1) | S1 (~/.claude/sessions/*.tmp) を当日分全件読込し、欠損ゼロで取り込む | `find ~/.claude/sessions -name "*.tmp" -newermt "today" \| wc -l` と Obsidian ファイル内 reference 数が一致 |
| **AC2** (N1) | S2 (queue/reports/*.yaml) を 9 件全件読込し、各 agent の `result.summary` を抽出 | `grep -c "summary:" queue/reports/*.yaml` と narrative 内 agent 言及数が一致 |
| **AC3** (N1) | S3 (queue/inbox/shogun.yaml) を timestamp 範囲で抽出 (前日 23:00 〜 当日 23:00) | shogun.yaml の対象範囲 message 数と Obsidian 出力で参照される件数一致 |
| **AC4** (N1) | S5 (dashboard.md) から cmd タイトル / ステータスを補助参照 | dashboard.md の cmd_NNN タイトルと Obsidian の `## cmd_NNN: <タイトル>` が一致 |
| **AC5** (N2) | cmd 発令検出パターン (§5.1) が 100% で当日新 cmd を検知 | 当日の dashboard.yaml in_progress 新規追加 cmd_id 数 = Obsidian 新セクション数 |
| **AC6** (N2) | cmd 跨ぎ会話が timestamp 順で正確に分割される | テスト: 連続 2 cmd の会話を投入し、分割境界が §5.2 ルール通りであること |
| **AC7** (N3) | Notion 概要が 450-550 字範囲で「考え→作業→結果」narrative になる | 文字数カウント + LLM 評価 (narrative 形式チェック) |
| **AC8** (N3) | Notion 概要に Obsidian リンクが GitHub URL 形式で含まれる | regex `^📂 詳細: https://github.com/saneaki/obsidian/blob/main/daily/` |
| **AC9** (N4) | `notion_session_log.sh` を廃止し、cron / Stop hook から呼出停止 | `crontab -l` + `~/.claude/settings.json` の hooks に notion_session_log への参照ゼロ |
| **AC10** (trigger) | 毎日 JST 23:00 自動 batch が cron で実行され、Obsidian + Notion 出力完成 | cron `0 23 * * *` 設定確認 + 翌日 0:00 時点で Obsidian + Notion 反映確認 |

---

## §7 Edge Cases

### E1: cmd 跨ぎ会話 (cmd_628 完遂と cmd_629 開始が同日)

- 検知: §5.1 pattern で cmd_629 発令を検出 → 以降を cmd_629 セクションへ振り分け
- リスク: timestamp 解像度が分単位の場合、近接 (1分以内) cmd 切替で順序逆転
- 対策: timestamp + message id (UUID) でハイブリッドソート

### E2: auto-compact 発生時

- 検知: S1 tmp の途中切断検知 (ファイルサイズ急減 / EOF 直前不正) または `~/.claude/sessions/compaction-log.txt` 参照
- 対策: 切断前後で同一 cmd_id の場合は「[cmd_NNN 続き]」見出しで連結

### E3: 複数 ash 並行 cmd (cmd_628 + cmd_629 同時進行)

- 検知: dashboard.yaml in_progress に複数 cmd_id 共存
- 対策: Obsidian ファイル内で cmd_id 別 H2 を共存させ、timestamp 順で交互配置

### E4: session file が空 / 欠損

- 検知: `wc -l` 0 行 / ファイル不在
- 対策: 当該 source をスキップ + 当日 batch ログに `[WARN] S1 tmp missing for {date}` 記録 + ntfy 通知

### E5: Obsidian / Notion API エラー

- Obsidian (GitHub API) エラー: 429 rate limit → 指数バックオフ retry (最大 3 回) / 401 認証失敗 → ntfy 通知 + batch 中断
- Notion API エラー: `Notion-Version: 2022-06-28` 固定使用 / 429 → 30 秒待機 retry / 認証失敗 → ntfy 通知

### E6: Notion 概要 LLM 生成失敗 (length 異常 / API timeout)

- 検知: LLM 出力が 200 字未満 or 1000 字超 / API timeout 30 秒
- 対策: フォールバックで機械的サマリ ("cmd_NNN 完遂: AC1-N PASS / 主要成果物: ...") を出力 + ntfy 通知

### E7: cron 実行漏れ (システム停止 / cron 設定変更)

- 検知: 翌日朝 (JST 06:00) 時点で前日分 Obsidian/Notion 出力なし
- 対策: 朝の `shogun_reality_check.sh` に「前日 batch 完遂確認」項目を追加 + 不在時 ntfy 通知

### E8: シークレット漏洩リスク

- 検知: 会話本文に API token / password 等を疑うキーワード (regex: `[A-Za-z0-9]{32,}` 等)
- 対策: 検出時は当該行を `[REDACTED:secret]` に置換した上で Obsidian/Notion へ送信、ntfy で殿に通知

---

## §8 廃止対象: `notion_session_log.sh`

### 8.1 現行機能整理

| 機能 | 行 | 役割 | 新システムでの代替 |
|------|-----|------|---------------------|
| flock 排他制御 | L11-L13 | 多重起動防止 | 新 batch script でも flock 採用 (継承) |
| Notion API 直叩き | (33,438 bytes 全体) | Notion Activity Log DB / 日記 DB 更新 | 新 batch が同じ Notion API 経路を使用 (Notion-Version: 2022-06-28 維持) |
| 冪等性 (同日再実行) | L4 コメント | 重複追記防止 | 新 batch も Notion 側で `cmd_id + date` 主キーで冪等性確保 |
| Voice review block | L31 (動的検索) | 機能C: 音声 review block 連携 | **廃止** (用途消滅、Obsidian で代替検討) |
| Streak 数集計 | L52 (dashboard.md ストリーク抽出) | 日記タスクに Streak 追記 | **廃止** (新 batch では narrative 内に組込) |
| Stop hook 連動 | shebang 経由 | 各 session 終了時に逐次実行 | **廃止** (新 batch は cron 23:00 集約実行) |

### 8.2 廃止後の影響範囲

- `~/.claude/settings.json` の hooks 内 `notion_session_log.sh` への参照を削除
- `crontab -l` で同 script を呼ぶエントリがあれば削除 (殿確認推奨)
- スクリプト本体は **削除せず** に `scripts/_archived/notion_session_log.sh` へ退避 (履歴保持 / 復活用)
- 既存 Notion Activity Log DB のデータは保持 (新 batch が継続書込か、新 DB へ移行かは Scope B 確定)

### 8.3 移行スケジュール (Scope B 推奨)

1. **Phase 0** (Scope A 完了時点): 要件定義 + 殿承認 — **本書で達成**
2. **Phase 1** (Scope B): 仕様書 + DB schema + LLM プロンプト確定
3. **Phase 2** (Scope C 実装): 新 batch script 開発 + cron 設定 + ドライラン (実書込なし)
4. **Phase 3**: 並行運用 (旧 + 新両稼働) で 1 週間検証
5. **Phase 4**: `notion_session_log.sh` を `scripts/_archived/` へ退避 + Stop hook / cron 参照削除

---

## §9 完了基準確認

| AC | 内容 | 本書での達成 |
|----|------|-----------|
| AC1 | 殿確定仕様 9 件全反映 | ✅ §2 (対象会話) / §3 (S1-S3+S5) / §4 (Obsidian + Notion 出力) / §5 (cmd 境界) / §6 AC10 (trigger 23:00) / §8 (廃止) |
| AC2 | AC + edge case が実装者がテスト可能な形式で記述 | ✅ §6 で AC1-AC10 各々に検証コマンド明示、§7 で edge case 8 件 (E1-E8) を検知方法+対策付で記述 |

---

## §10 Scope B (仕様書) への申し送り

Scope A は要件定義のみで、以下は Scope B (仕様書 / 設計書) で確定:

1. **Notion DB**: 既存 Activity Log DB 流用 vs 新規 cmd 単位 DB 新設 — 殿確認推奨
2. **LLM 選択**: Claude API (Sonnet/Haiku) vs Codex GPT-5 — narrative 生成のコスト/品質トレードオフ
3. **Obsidian リポジトリ初期構造**: `daily/` フォルダのみ vs `cmd/`/`agent/`/`skill/` 多軸タグ — Dataview クエリ要件で確定
4. **シークレット REDACT 規則**: regex pattern + 除外語 (false positive 抑制) の精緻化
5. **既存 Notion Activity Log DB データ移行**: 新システムで継続書込か、新 DB に移行か

---

## §11 north_star アライメント

```yaml
north_star_alignment:
  status: aligned
  reason: |
    cmd_631 Scope A 北極星 N1-N4 を全て要件定義レベルで満たした。
    S1-S3+S5 の入力源を網羅 (N1) / cmd 発令検出パターン 3 種で境界判定 (N2) /
    Notion 概要 narrative 500字 + LLM 生成 (N3) / notion_session_log.sh の
    Phase 移行廃止計画 (N4) を全件記述。
  risks_to_north_star:
    - "S1 tmp ファイルの形式が Claude Code バージョンアップで変わると要件定義の前提が崩れる"
    - "Notion 概要 LLM 生成のコストが高い場合 (毎日 23:00 + 複数 cmd) は Haiku 採用検討"
    - "Obsidian リポジトリ public 公開時のシークレット漏洩リスクは E8 対策のみで不十分の可能性、
      Scope B で REDACT 規則の精緻化 + private repo 維持が望ましい"
```

---

**生成統計**: 約 270 行 / セクション 11 / AC 10 件 / Edge Case 8 件 / 廃止計画 4 Phase / Scope B 申し送り 5 件

— 軍師 (Opus)
