# cmd_631 Scope B — shogun 会話ログ → Obsidian → Notion 統合 仕様書

- **task_id**: subtask_631_scope_b_specification
- **担当**: 軍師 (Opus)
- **作成日時**: 2026-05-02 04:31 JST
- **基盤**: `output/cmd_631_requirements.md` (Scope A, 319 行)
- **殿裁可反映**: Q1 (DIARY_DB 流用) / Q2 (Gemini 3.1 Flash-Lite Preview) / Q3 (最低限 REDACT) 全件
- **目的**: Scope C 4 並列担当者 (ash3 / ash5 / ash6 / ash7) が**仕様書のみで実装着手可能**な詳細度を提供

---

## §1 ファイル構成 + Scope C 担当割当

| Scope | 担当 ash | ファイル | 種別 | LoC 見込 |
|-------|----------|---------|------|---------|
| **C1** | ash6 (Codex) | `scripts/session_to_obsidian.sh` | 新規 | 200-280 |
| **C2** | ash5 (Opus+T) | `scripts/generate_notion_summary.sh` | 新規 | 150-200 |
| **C3** | ash3 (Sonnet) | `saneaki/obsidian/.github/workflows/daily-notion-sync.yml` | 新規 (別 repo) | 80-120 |
| **C4** | ash7 (Codex) | `scripts/notion_session_log.sh` 廃止 + アーカイブ | 廃止処理 | -33,438 bytes archive 移動 |

**並列実行可否**: C1/C2/C3/C4 は別ファイルで RACE-001 なし。並列 dispatch 可。
**依存関係**: C1→C2→C3 は実行時依存だが、実装は独立。C2 は C1 出力の md ファイル parse のため C1 出力フォーマットを本仕様書 §3.5 で固定する。

---

## §2 データフロー

```
[S1] ~/.claude/sessions/*.tmp ─┐
[S2] queue/reports/*.yaml ────┤
[S3] queue/inbox/shogun.yaml ─┼──> [C1] session_to_obsidian.sh
[S5] dashboard.md ────────────┘         │
                                         ▼
                          saneaki/obsidian/YYYY/MM/DD/YYYYMMDD_shogun_session.md
                                         │
                                         ▼ (cron 23:00 JST = 14:00 UTC)
                          [C3] daily-notion-sync.yml (GitHub Actions)
                                         │
                                         ├──> [C2] generate_notion_summary.sh
                                         │     (LLM: gemini-3.1-flash-lite-preview)
                                         │
                                         ▼
                          Notion DIARY_DB (1a4e8d62-...) upsert
                                         │
                                         ▼ (Phase 4 廃止確認後)
                          [C4] notion_session_log.sh → scripts/archived/
```

---

## §3 C1 仕様: `scripts/session_to_obsidian.sh` (ash6 担当)

### 3.1 役割

S1+S2+S3+S5 から **当日分 (前日 23:00 〜 当日 23:00 JST)** の会話ログを抽出 → cmd 境界判定 → Obsidian 用 markdown ファイルを生成。

### 3.2 引数

```bash
scripts/session_to_obsidian.sh [--date YYYY-MM-DD] [--dry-run] [--output-dir PATH]
```

- `--date`: 対象日付 (default: 当日 JST)
- `--dry-run`: stdout 出力のみ、ファイル書込なし
- `--output-dir`: Obsidian リポジトリのルート (default: 環境変数 `OBSIDIAN_REPO_PATH` or `/home/ubuntu/obsidian`)

### 3.3 出力ファイル

```
{OBSIDIAN_REPO_PATH}/daily/2026/05/02/20260502_shogun_session.md
```

- ディレクトリは `mkdir -p` で自動作成
- ファイル名: `YYYYMMDD_shogun_session.md` 固定

### 3.4 cmd 境界判定アルゴリズム

```bash
# Step 1: shogun.yaml を timestamp 範囲でフィルタ
yq '.messages[] | select(.timestamp >= "2026-05-02T00:00:00+09:00" and .timestamp < "2026-05-02T23:00:00+09:00")' \
  queue/inbox/shogun.yaml

# Step 2: cmd 発令検出 (3 パターン OR)
# - lord_command type
# - content に "cmd_NNN 発令" / "新 cmd 発令" を含む task_completed
# - dashboard.yaml in_progress に新規 cmd_id 追加
NEW_CMD_REGEX='cmd_[0-9]+\s*発令|新\s*cmd\s*発令'

# Step 3: タイムスタンプ順に message を並べ、新 cmd 検出時に H2 セクション開始
```

### 3.5 出力フォーマット (C2 が parse する固定形式)

```markdown
---
date: 2026-05-02
shogun_session: true
cmds: [cmd_631, cmd_628, cmd_629]
generated_at: 2026-05-02T23:00:00+09:00
---

# 2026-05-02 shogun 会話ログ

## cmd_631: shogun 会話ログ Obsidian 統合
- **発令時刻**: 2026-05-02 04:22:00 JST
- **担当**: 軍師 (Scope A 要件定義)
- **agents**: 殿, 将軍, 家老, 軍師

### 殿令 / 発令内容
{S3 lord_command の content}

### 将軍検討
{S3 task_completed (from: shogun) の content}

### 足軽/軍師提案
{S2 reports[*].suggestions[].content}

### 完遂報告サマリ
{S2 reports[*].result.summary}

---

## cmd_628: implementation-verifier agent 導入
...
```

**重要**: `cmds:` frontmatter は cmd_id の配列で C2 が読み取る。`## cmd_NNN:` H2 を区切りとして cmd 単位 chunk 化する。

### 3.6 REDACT (Q3: 最低限)

```bash
# token / secret / password / API key パターンを [REDACTED] に置換
sed -E '
  s/(NOTION_INTEGRATION_TOKEN|GEMINI_API_KEY2|GEMINI_API_KEY)=[^[:space:]]+/\1=[REDACTED]/g
  s/(secret|password|token)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_-]{20,}/\1=[REDACTED]/Ig
  s/(Bearer\s+)[A-Za-z0-9_.-]{20,}/\1[REDACTED]/g
  s/(refresh_token|access_token)["[:space:]]*[:=][[:space:]]*"[A-Za-z0-9_.-]{20,}"/\1=[REDACTED]/Ig
'
```

通常の設計議論・コード内容は REDACT 不要 (private repo 前提、殿確定 Q3)。

### 3.7 lockfile (多重起動防止)

```bash
LOCK_FILE="/tmp/session_to_obsidian.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "[session_to_obsidian] lock held → skip" >&2; exit 0; }
```

### 3.8 exit code

- 0: 正常完了 / dry-run 完了
- 1: source 不在 / parse error
- 2: Obsidian 書込失敗

---

## §4 C2 仕様: `scripts/generate_notion_summary.sh` (ash5 担当)

### 4.1 役割

C1 出力の Obsidian markdown を読み込み、**cmd ごと** に Gemini API (gemini-3.1-flash-lite-preview) で 500 字 narrative を生成。Notion DIARY_DB に upsert する JSON ペイロードを出力。

### 4.2 引数

```bash
scripts/generate_notion_summary.sh \
  --input <obsidian.md> \
  [--date YYYY-MM-DD] \
  [--dry-run] \
  [--output <json_path>]
```

- `--input`: C1 出力の md ファイルパス (必須)
- `--date`: 対象日付 (default: md frontmatter から抽出)
- `--dry-run`: API 呼出なし、prompt のみ出力
- `--output`: JSON 出力先 (default: stdout)

### 4.3 LLM 仕様 (Q2: Gemini 3.1 Flash-Lite Preview)

**API**: Gemini API
**Model**: `gemini-3.1-flash-lite-preview`
**API URL**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent`
**Auth**: `x-goog-api-key: $GEMINI_API_KEY2`
**Endpoint**: `https://api.anthropic.com/v1/messages`
**Max tokens**: 800 (500 字 ≒ 700-800 tokens 余裕)
**System prompt**:

```
あなたは shogun マルチエージェントシステムの会話ログを要約する narrative writer です。
入力された 1 つの cmd の会話ログから、以下の構成で日本語 500 字以内の narrative を生成してください。

【構成 (必須)】
1. どういう考えで (背景・動機・北極星)
2. 何を作って (実装・成果物・担当 agent)
3. 結果どうだったか (AC PASS/FAIL・所見・次アクション)

【制約】
- 500 字以内 (450-550 字推奨)
- 機械的羅列禁止 (例: "AC1 PASS / AC2 PASS" は不可)
- ストーリー形式で、1 段落の文章として読める形に
- 殿/将軍/家老/軍師/足軽 の役割語彙を維持
- 提案者と意思決定者を明示する
```

**User prompt** (input としての md chunk):

```
以下は cmd_{cmd_id} の会話ログです:

{markdown chunk from "## cmd_NNN:" to next "## cmd_" or EOF}

500 字以内の narrative を生成してください。
```

### 4.4 cmd ごとの分割処理

```bash
# C1 出力の md から H2 (## cmd_NNN:) で chunk 化
awk '
  /^## cmd_[0-9]+:/ {
    if (current_cmd) {
      print "---SEPARATOR---"
    }
    current_cmd = $0
  }
  current_cmd { print }
' "$INPUT_MD" | csplit -z -f "/tmp/cmd_chunk_" - '/^---SEPARATOR---$/' '{*}'
```

### 4.5 出力 JSON フォーマット

```json
{
  "date": "2026-05-02",
  "obsidian_link": "https://github.com/saneaki/obsidian/blob/main/daily/2026/05/02/20260502_shogun_session.md",
  "cmds": [
    {
      "cmd_id": "cmd_631",
      "title": "shogun 会話ログ Obsidian 統合",
      "narrative": "本 cmd は二重記録問題を解消し、Obsidian を中継ハブ化する設計を起案するものであった。軍師が要件定義 (Scope A) で... (500 字)",
      "agents": ["殿", "将軍", "家老", "軍師"],
      "status": "in_progress"
    },
    {
      "cmd_id": "cmd_628",
      "title": "implementation-verifier agent 導入",
      "narrative": "...",
      "agents": ["殿", "将軍", "家老", "軍師", "足軽1", "足軽5"],
      "status": "completed"
    }
  ]
}
```

### 4.6 環境変数

- `GEMINI_API_KEY2` (必須): Gemini API キー
- 不在時は exit 1 + ntfy 通知

### 4.7 retry / rate limit

- 429 → 30 秒待機後 retry (最大 3 回)
- timeout 30 秒 → 機械サマリ fallback ("cmd_NNN: 完遂 / 主要成果物: ...")

### 4.8 cost 試算

- 1 cmd ≒ 入力 5,000 tokens + 出力 800 tokens
- Gemini 3.1 Flash-Lite Preview: $0.00245/cmd 想定 (月¥110 = daily 1回 × 30日)
- 1 cmd: 約 $0.0072 (≈ 1.1円)
- 月 100 cmd: 約 $0.72 (≈ 約 110 円)

### 4.9 exit code

- 0: 正常完了
- 1: API key 不在 / API timeout
- 2: input md parse 失敗

---

## §5 C3 仕様: `saneaki/obsidian/.github/workflows/daily-notion-sync.yml` (ash3 担当)

### 5.1 役割

毎日 JST 23:00 に GitHub Actions cron 起動 → C2 を呼び出し → Notion DIARY_DB に upsert。

### 5.2 配置先

```
saneaki/obsidian リポジトリ内:
.github/workflows/daily-notion-sync.yml
```

**注意**: 本 cmd で対象とするのは saneaki/obsidian リポジトリ。shogun リポジトリには配置しない。

### 5.3 workflow 全文 (テンプレート)

```yaml
name: Daily Notion Sync

on:
  schedule:
    - cron: '0 14 * * *'  # JST 23:00 = UTC 14:00
  workflow_dispatch:        # 手動実行可

permissions:
  contents: read

jobs:
  sync:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout obsidian
        uses: actions/checkout@v4

      - name: Resolve target date
        id: date
        run: |
          DATE=$(TZ=Asia/Tokyo date +%Y-%m-%d)
          YEAR=$(echo $DATE | cut -d- -f1)
          MONTH=$(echo $DATE | cut -d- -f2)
          DAY=$(echo $DATE | cut -d- -f3)
          MD_PATH="daily/${YEAR}/${MONTH}/${DAY}/${YEAR}${MONTH}${DAY}_shogun_session.md"
          echo "date=$DATE" >> $GITHUB_OUTPUT
          echo "md_path=$MD_PATH" >> $GITHUB_OUTPUT

      - name: Verify md exists
        id: verify
        run: |
          if [[ ! -f "${{ steps.date.outputs.md_path }}" ]]; then
            echo "[WARN] md not found: ${{ steps.date.outputs.md_path }}" >&2
            exit 0  # graceful — md がない日 (cmd 0件) は skip
          fi
          echo "md_exists=true" >> $GITHUB_OUTPUT

      - name: Generate Notion summary
        if: steps.verify.outputs.md_exists == 'true'
        env:
          GEMINI_API_KEY2: ${{ secrets.GEMINI_API_KEY2 }}
        run: |
          # generate_notion_summary.sh を shogun リポから取得 or vendor in
          curl -fsSL https://raw.githubusercontent.com/saneaki/shogun/main/scripts/generate_notion_summary.sh \
            -o /tmp/generate_notion_summary.sh
          chmod +x /tmp/generate_notion_summary.sh

          /tmp/generate_notion_summary.sh \
            --input "${{ steps.date.outputs.md_path }}" \
            --date "${{ steps.date.outputs.date }}" \
            --output /tmp/notion_payload.json

      - name: Upsert to Notion DIARY_DB
        if: steps.verify.outputs.md_exists == 'true'
        env:
          NOTION_TOKEN: ${{ secrets.NOTION_INTEGRATION_TOKEN }}
          DIARY_DB_ID: 1a4e8d62-e4aa-81f1-8ede-c239ea53299b
        run: |
          python3 .github/scripts/notion_upsert.py \
            --payload /tmp/notion_payload.json \
            --db-id "$DIARY_DB_ID"
```

### 5.4 secrets (saneaki/obsidian repo に設定)

- `GEMINI_API_KEY2` (新規追加)
- `NOTION_INTEGRATION_TOKEN` (既存 or 新規追加)

### 5.5 補助スクリプト: `.github/scripts/notion_upsert.py`

C3 担当者は以下も同時実装:

```python
#!/usr/bin/env python3
"""Notion DIARY_DB に cmd 単位で upsert する。"""
import json, sys, os, requests
from argparse import ArgumentParser

NOTION_API = "https://api.notion.com/v1"
NOTION_VERSION = "2022-06-28"

def main():
    ap = ArgumentParser()
    ap.add_argument("--payload", required=True)
    ap.add_argument("--db-id", required=True)
    args = ap.parse_args()

    with open(args.payload) as f:
        data = json.load(f)

    token = os.environ["NOTION_TOKEN"]
    headers = {
        "Authorization": f"Bearer {token}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }

    for cmd in data["cmds"]:
        # query で既存 page 検索
        existing = query_existing(args.db_id, cmd["cmd_id"], data["date"], headers)
        if existing:
            patch_page(existing, cmd, data, headers)
        else:
            create_page(args.db_id, cmd, data, headers)
```

(完全実装は ash3 が記述、本仕様書は骨格を示す)

---

## §6 DIARY_DB properties 追加仕様 (Q1: 既存 DB 流用)

### 6.1 既存 DIARY_DB

- **DB ID**: `1a4e8d62-e4aa-81f1-8ede-c239ea53299b`
- **既存 properties** (notion_session_log.sh L221-L300 から推定):
  - 既存 title property (流用候補)
  - 「活動ログ」relation (notion_session_log.sh で使用)
  - 「プロジェクト」select
  - 「Driveリンク」url

### 6.2 追加 properties (cmd_631 用)

以下 4 propertyを追加 (Notion UI または API 経由で事前手動作成):

| property 名 | type | 用途 | 例 |
|-------------|------|------|-----|
| `cmd_id` | rich_text | shogun cmd ID | `cmd_631` |
| `summary` | rich_text | LLM 生成 narrative (500字) | "本 cmd は二重記録問題を解消し..." |
| `obsidian_link` | url | Obsidian md への GitHub URL | `https://github.com/saneaki/obsidian/blob/...` |
| `session_date` | date | shogun セッション日 | 2026-05-02 |

**重要**: 追加 properties が存在しない状態で C3 を実行すると `properties.<name> does not exist` エラーになる。**Scope C3 着手前に殿または家老が手動で 4 property を Notion UI で追加する必要あり**。

### 6.3 既存 properties への影響

- 既存「活動ログ」relation は C3 では使用しない (notion_session_log.sh の機能)
- 既存「プロジェクト」select は流用可能 (Phase 移行期)
- title property は新規 cmd ページの title として `cmd_NNN: <title>` 形式で書込み

### 6.4 upsert ロジック (新規 vs update)

```python
# 新規/既存判定: cmd_id + session_date の AND クエリ
filter = {
    "and": [
        {"property": "cmd_id", "rich_text": {"equals": "cmd_631"}},
        {"property": "session_date", "date": {"equals": "2026-05-02"}},
    ]
}
existing = post(f"/databases/{db_id}/query", {"filter": filter})
if existing["results"]:
    page_id = existing["results"][0]["id"]
    patch(f"/pages/{page_id}", {"properties": new_props})  # update
else:
    post(f"/pages", {"parent": {"database_id": db_id}, "properties": new_props})  # create
```

---

## §7 C4 仕様: `notion_session_log.sh` 廃止処理 (ash7 担当)

### 7.1 Phase 移行 (Scope A §8.3 より)

| Phase | 作業 | 担当 |
|-------|------|------|
| Phase 1 | cron エントリ削除 (`crontab -e` で `0 * * * * bash ... notion_session_log.sh ...` を削除) | ash7 |
| Phase 2 | `scripts/notion_session_log.sh` を `scripts/archived/notion_session_log.sh` へ移動 | ash7 |
| Phase 3 | `skill_history.md` に廃止記録追加 (`cmd_631 で廃止: 二重記録解消`) | ash7 |
| Phase 4 | 関連 cron / Stop hook / watcher が notion_session_log.sh を参照していないか grep 確認 | ash7 |

### 7.2 cron 削除手順

**現行 cron** (確認済):
```
0 * * * * bash /home/ubuntu/shogun/scripts/notion_session_log.sh >> /tmp/notion_session_log.log 2>&1
```

**削除手順**:
```bash
# 1. 現行 crontab をバックアップ
crontab -l > /tmp/crontab_backup_$(date +%Y%m%d).txt

# 2. notion_session_log.sh の行を除外して再登録
crontab -l | grep -v "notion_session_log.sh" | crontab -

# 3. 確認
crontab -l | grep -c "notion_session_log" # → 0 期待
```

### 7.3 archive 移動

```bash
mkdir -p /home/ubuntu/shogun/scripts/archived
git mv /home/ubuntu/shogun/scripts/notion_session_log.sh \
       /home/ubuntu/shogun/scripts/archived/notion_session_log.sh
```

### 7.4 影響範囲確認 (Phase 4)

```bash
# scripts/ 配下で参照確認
grep -rn "notion_session_log" /home/ubuntu/shogun/scripts/ --exclude-dir=archived

# Stop hook / settings 確認
grep -n "notion_session_log" ~/.claude/settings.json /home/ubuntu/.claude/settings.json 2>/dev/null

# crontab 確認 (再確認)
crontab -l | grep -c "notion_session_log"  # → 0 期待

# inbox watcher 等の参照確認
grep -rn "notion_session_log" /home/ubuntu/shogun/instructions/ /home/ubuntu/shogun/skills/ 2>/dev/null
```

すべて 0 件であれば Phase 4 完了。1 件でもヒットすれば、当該箇所を Scope D で修正する。

### 7.5 skill_history.md 追記内容

```markdown
## 2026-05-02 cmd_631 で廃止: notion_session_log.sh

二重記録問題解消のため廃止。新システム (session_to_obsidian.sh + generate_notion_summary.sh
+ daily-notion-sync.yml on saneaki/obsidian) に置換。詳細は output/cmd_631_requirements.md
+ output/cmd_631_specification.md 参照。アーカイブ: scripts/archived/notion_session_log.sh
```

---

## §8 テスト仕様 (Scope D 向け)

### D1: dry-run 条件

```bash
# C1 dry-run
bash scripts/session_to_obsidian.sh --date 2026-05-02 --dry-run

# 期待: stdout に md 形式で出力、ファイル書込なし
# 検証: cmds: [...] frontmatter が当日 cmd_id を全件含む
```

### D2: LLM 品質基準

```bash
# C2 dry-run + 検証
bash scripts/generate_notion_summary.sh \
  --input /tmp/sample_obsidian.md \
  --dry-run

# 期待:
# - 各 cmd の narrative が 450-550 字
# - 「考え」「作成物」「結果」の3要素を含む (regex で確認)
echo "$NARRATIVE" | python3 -c "
import sys
text = sys.stdin.read()
chars = len(text.replace(' ', '').replace('\n', ''))
assert 450 <= chars <= 550, f'length out of range: {chars}'
assert any(k in text for k in ['考え', '思考', '北極星']), '考え 欠落'
assert any(k in text for k in ['作', '実装', '成果物']), '作成物 欠落'
assert any(k in text for k in ['結果', 'PASS', '判定']), '結果 欠落'
"
```

### D3: Notion upsert (test row)

```bash
# 1. test cmd_id = "cmd_test_999" で create
# 2. Notion UI で確認 (cmd_id=cmd_test_999 の row が存在)
# 3. 同 cmd_id で再実行 → update (page_id 不変、updated_time 更新)
# 4. test row 削除 (Notion UI 手動)
```

### D4: 廃止確認

```bash
# 4 件全件 0 期待:
crontab -l | grep -c "notion_session_log.sh"  # → 0
grep -rn "notion_session_log" /home/ubuntu/shogun/scripts/ --exclude-dir=archived | wc -l  # → 0
grep -c "notion_session_log" ~/.claude/settings.json /home/ubuntu/.claude/settings.json 2>/dev/null  # → 0
ls /home/ubuntu/shogun/scripts/archived/notion_session_log.sh  # → 存在
```

---

## §9 REDACT ルール (Q3: 最低限)

### 9.1 適用箇所

C1 (`session_to_obsidian.sh`) の出力前。md ファイル書込み直前にフィルタ実行。

### 9.2 検出 + 置換 pattern

```bash
# トークン系 (環境変数形式)
sed -E 's/(NOTION_INTEGRATION_TOKEN|GEMINI_API_KEY2|GEMINI_API_KEY|OPENAI_API_KEY|GITHUB_TOKEN)=[^[:space:]]+/\1=[REDACTED]/g'

# Bearer トークン
sed -E 's/(Bearer\s+)[A-Za-z0-9_.-]{20,}/\1[REDACTED]/g'

# OAuth tokens
sed -E 's/(refresh_token|access_token|client_secret)["[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9_.-]{20,}"?/\1=[REDACTED]/Ig'

# secret/password キーワード周辺
sed -E 's/(secret|password)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_-]{16,}/\1=[REDACTED]/Ig'
```

### 9.3 適用しない箇所

- 通常の設計議論・コード内容
- shogun 内部の cmd_id / agent ID
- Notion DB ID (`1a4e8d62-...` は public, REDACT 不要)

### 9.4 false positive 対策

- 16-20 文字以上のランダム文字列のみ検出 (短い変数名は除外)
- 大文字始まりの環境変数名 + `=` の組合せに限定 (誤検知最小化)

---

## §10 Acceptance Criteria (Scope B)

| AC | 内容 | 検証 |
|----|------|------|
| AC1 | 殿裁可 Q1-Q3 全反映 (DIARY_DB 流用 / Gemini 3.1 Flash-Lite Preview / 最低限 REDACT) | §6 Q1 / §4.3 Q2 / §9 Q3 |
| AC2 | Scope C 4 担当者が仕様書のみで実装着手できる詳細度 | §3-§7 で各 ash 担当の引数 / 入出力 / API / pattern を完全記述 |

---

## §11 Scope C dispatch 推奨 task YAML 内容 (家老向け)

### C1 (ash6) task YAML 抜粋

```yaml
title: '[cmd_631 Scope C1] session_to_obsidian.sh 実装'
working_dir: /home/ubuntu/shogun
editable_files:
  - scripts/session_to_obsidian.sh
acceptance_criteria:
  - id: AC1
    check: '当日分 S1+S2+S3 を取込 + cmd 境界判定 + Obsidian md 出力 (dry-run で確認)'
  - id: AC2
    check: 'frontmatter cmds: [...] が当日 cmd_id 全件を含む'
  - id: AC3
    check: '§9 REDACT ルール適用'
```

### C2 (ash5) task YAML 抜粋

```yaml
title: '[cmd_631 Scope C2] generate_notion_summary.sh 実装'
acceptance_criteria:
  - id: AC1
    check: 'Gemini API (gemini-3.1-flash-lite-preview) 呼出'
  - id: AC2
    check: 'narrative 450-550 字 + 3要素 (考え/作成物/結果)'
  - id: AC3
    check: 'JSON 出力 ({date, obsidian_link, cmds: [{cmd_id, title, narrative, agents, status}]})'
```

### C3 (ash3) task YAML 抜粋

```yaml
title: '[cmd_631 Scope C3] daily-notion-sync.yml + notion_upsert.py 実装'
working_dir: /home/ubuntu/obsidian (saneaki/obsidian repo)
editable_files:
  - .github/workflows/daily-notion-sync.yml
  - .github/scripts/notion_upsert.py
acceptance_criteria:
  - id: AC1
    check: 'cron 0 14 * * * (UTC) で起動'
  - id: AC2
    check: 'Notion DIARY_DB upsert (cmd_id + session_date キー)'
  - id: AC3
    check: 'secrets GEMINI_API_KEY2 + NOTION_INTEGRATION_TOKEN 参照'
```

### C4 (ash7) task YAML 抜粋

```yaml
title: '[cmd_631 Scope C4] notion_session_log.sh 廃止 + アーカイブ'
acceptance_criteria:
  - id: AC1
    check: 'cron 削除 (crontab -l | grep -c notion_session_log → 0)'
  - id: AC2
    check: 'scripts/archived/ に git mv 完了'
  - id: AC3
    check: 'skill_history.md 追記'
  - id: AC4
    check: '影響範囲 grep 全件 0 確認 (settings.json / hooks / instructions)'
```

---

## §12 注意事項 (家老/Scope C 担当者向け)

### 12.1 Scope C3 着手の前提条件

**Notion DIARY_DB に cmd_id / summary / obsidian_link / session_date の 4 property が事前追加されていること**。これは Scope C3 担当者 (ash3) ではなく、**殿または家老が Notion UI から手動追加** する必要がある (API 経由でも可)。

### 12.2 C2 の API key 管理

`GEMINI_API_KEY2` は shogun 環境変数として既存 (`/home/ubuntu/.n8n-mcp/n8n/.env` 等) に存在する場合は流用、不在なら殿が新規発行。

### 12.3 C4 完了タイミング

C4 (廃止) は C1+C2+C3 が完成し動作確認 (Phase 3 並行運用 1 週間) を経た**後** に実施。task spec の「即 Scope C 4 並列 dispatch」は実装着手の並列化を意味し、C4 の実 archive 移動は他 3 つの完成検証を待つ。

### 12.4 implementation-verifier 連携

cmd_628 で導入した implementation-verifier agent は本 cmd_631 の C1-C4 完遂報告に対しても適用される。L4 Pattern Check 9 件のうち特に **DIFF反映漏れ** (本仕様書の差分要求が C1-C4 実装に反映されているか grep 確認) と **PUSH漏れ** (commit 後の push 状態) が重要。

---

## §13 north_star アライメント

```yaml
north_star_alignment:
  status: aligned
  reason: |
    cmd_631 Scope B 北極星は Scope A 要件定義の N1-N4 を仕様レベルに具体化すること。
    殿裁可 Q1 (DIARY_DB 流用) を §6 で具現化、Q2 (Gemini 3.1 Flash-Lite Preview) を §4.3 で確定、
    Q3 (最低限 REDACT) を §9 で実装パターン化。Scope C 4 並列担当者が
    本仕様書のみで実装着手できる詳細度 (引数・入出力・API・pattern) を全件記述。
  risks_to_north_star:
    - "Notion DIARY_DB の properties 追加 (§6.2) は殿/家老の手動作業。
      C3 着手前に未完だと C3 が API エラーで停止"
    - "GEMINI_API_KEY2 が saneaki/obsidian repo secrets に未設定だと C3 が停止。
      C3 着手前に殿が secrets 追加要"
    - "C1 出力 frontmatter の `cmds: [...]` 形式が C2 の入力前提。
      C1 担当者がこの形式を遵守しないと C2 が parse 失敗 (依存仕様の脆弱性)"
```

---

**生成統計**: 約 460 行 / セクション 13 / Scope C 4 担当 (ash3/5/6/7) / API 仕様 2 (Anthropic + Notion) / REDACT pattern 4 / DIARY_DB property 追加 4

— 軍師 (Opus)
