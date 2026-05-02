# cmd_640 Scope E — 統合 QC レポート (gunshi/Opus)

- **task_id**: subtask_640_scope_e_qc
- **担当**: gunshi (Opus)
- **作成日時**: 2026-05-03 04:14 JST
- **対象**: cmd_640 全 Scope (A+A2+B+C+D) 統合 QC + 3点照合 + AC1-AC10 全確認
- **判定**: **NoGo (構造的依存問題)** — 詳細は §5 参照

---

## 1. 全 Scope 完了状態

| Scope | 担当 | task YAML status | 実装確認 | 評価 |
|---|---|:---:|:---:|:---:|
| A: Bug1 cwd修正 + Bug2 isinstance guard | ash6 | done | ✅ session_to_obsidian.sh:3 cd + line 267-298 isinstance 5箇所 | PASS |
| A2: Stop hook 削除 + Issue#46 第3真因 | ash6 | done | ✅ settings.json から notion_session_log 0 件 + Issue#46 body に第3真因記載 | PASS |
| B: check_pattern_7 GHA upsert 0件 alert | ash5 | **assigned** ⚠️ | ✅ shogun_in_progress_monitor.sh:378 check_pattern_7 + 447行 (404→447) | PASS (実装) / **REGISTRY lag** |
| C: cmd_633/635/636/637/638 backfill | ash3 | done | ✅ scripts/notion_backfill_20260502.sh + 全 cmd 含有 | PASS |
| D: cron simulation /tmp 起動 | ash7 | done | ✅ /tmp 起動 dry-run exit 0 | PASS |

**所見**: 5 scope 中 4 が task YAML done。ash5 (scope_b) のみ task YAML status=assigned のまま、実装は commit 8db7853 に含まれて push 済み。これは **REGISTRY_UPDATE_LAG** の典型例 (cmd_634 AC11 auto-done が ash5 から `task_completed` 投函を受けていないため発火せず)。家老は ash5 task YAML を retroactive に done 化、または scope_b 完了報告経路を追跡されたし。

---

## 2. 3点照合結果 (AC7 — cmd_635 QC 失敗の反省で必須化)

### 照合 1: `session_to_obsidian.sh --dry-run` exit 0 + cmd_634/639/640 含有 — **PASS**

```
cd /home/ubuntu/shogun
bash scripts/session_to_obsidian.sh --dry-run
```

実行結果:
- exit code: **0**
- 出力 frontmatter: `cmds: [cmd_634, cmd_639, cmd_640]` — 5/3 進行中の 3 cmd を全件含有
- セッション形式: `# 2026-05-03 shogun セッション` + 各 cmd の発令時刻 (cmd_634=00:19 / cmd_639=00:54 / cmd_640=01:02) + 殿令本文抽出 OK

### 照合 2: obsidian repo に 5/3 ファイル存在 — **FAIL (時刻依存)**

| 確認方法 | 結果 |
|---|---|
| GitHub repo `01_data/2026/05/` ディレクトリ列挙 | `02` のみ存在、**`03` ディレクトリなし** |
| `gh search code "2026-05-03" --repo saneaki/obsidian` | 結果 `[]` (空) |
| local clone `/home/ubuntu/obsidian/01_data/2026/05/` | `02` のみ |
| local find `*2026-05-03*` `*20260503*` | 0 件 |
| local unpushed commits (`git log origin/main..HEAD`) | 0 件 |

**根本原因**: session_to_obsidian.sh の cron schedule は **`30 13 * * *`** (毎日 13:30 JST 実行)。現在時刻は **2026-05-03 04:14 JST**、本日の cron 実行は **9 時間後 (13:30 JST)**。5/3 push 自体が物理的に未実行 (= 期待動作通り、ただし照合不能タイミング)。

5/2 までは正常稼働実績あり (commit `2026-05-02 17:30:21 feat(cmd_635): shogun session log 2026-05-02`)。

### 照合 3: Notion DIARY_DB に 5/3 entry 存在 — **FAIL (時刻依存)**

```
DIARY_DB_ID=1a4e8d62-e4aa-81f1-8ede-c239ea53299b
filter: {Date: {on_or_after: "2026-05-03"}}
```

実行結果: **0 件**

**根本原因**: Notion DIARY 同期は GHA daily-notion-sync 経由。直近 success 実行は `2026-05-02T14:40:45Z = 2026-05-02 23:40 JST`。本日 (5/3) の sync は obsidian repo に 5/3 file が反映された後 (= cron 13:30 後) に走る設計。現時点で 5/3 entry が無いのは **upstream (obsidian) 未反映の連鎖** ゆえ正常。

### 3点照合 まとめ

| 照合 | 判定 | 根拠 |
|---|:---:|---|
| 照合 1 dry-run | **PASS** | exit 0 + cmd 全件含有 |
| 照合 2 obsidian 5/3 | **FAIL (時刻依存)** | cron 13:30 待ち、現在 04:14 |
| 照合 3 Notion 5/3 | **FAIL (時刻依存)** | obsidian 未反映の下流連鎖 |

---

## 3. AC1-AC10 個別判定

| AC | 内容 | 判定 | 根拠 |
|---|---|:---:|---|
| AC1 | scripts/session_to_obsidian.sh:3 cwd 修正 | ✅ PASS | line 3 `cd "$(dirname "$0")/.." || exit 1` 実体存在 |
| AC2 | get_cmd_meta() 周辺 isinstance guard | ✅ PASS | line 267, 269, 271, 296, 298 で isinstance 5箇所配置 |
| AC3 | dry-run exit 0 + 5/3 cmd 含有 | ✅ PASS | exit 0、cmds に cmd_634/639/640 |
| AC4 | cron simulation /tmp 起動 exit 0 | ✅ PASS | `cd /tmp && bash scripts/session_to_obsidian.sh --dry-run` exit 0 |
| AC5 | 5/2 backfill (cmd_633/635/636/637/638) | ✅ PASS | scripts/notion_backfill_20260502.sh 存在 + 全 cmd 含有 |
| AC6 | check_pattern_7 GHA upsert 0件 alert | ✅ PASS | shogun_in_progress_monitor.sh:378 + 447 行に拡張 (P7 keyword hit 6) |
| AC7 | 3点照合 (dry-run + obsidian + Notion) 全 PASS | **❌ FAIL** | 照合 1 PASS / 照合 2/3 時刻依存 FAIL — 詳細 §2 |
| AC8 | implementation-verifier 5-Layer 版で評価 | ✅ PASS | 342 行 / 8 keyword hits (Layer5/TMUX_STATE_MISMATCH/DASHBOARD_STALE/STATE_VISIBILITY_GAP) |
| AC9 | Stop hook 削除済み | ✅ PASS | `.claude/settings.json` に notion_session_log 0 件 |
| AC10 | Issue #46 第3真因記載 (and OPEN 状態) | ✅ PASS | state=OPEN、body に第3真因記載確認、scope_f 後 close 予定 |

**集計**: AC1-AC6 / AC8-AC10 = **9 件 PASS** / AC7 = **FAIL (時刻依存)** / 合計 9/10 PASS

---

## 4. 旧 cmd_635 QC 失敗の反省を踏まえた評価

cmd_635 QC は code 審査のみ (dry-run / archive / .gitignore 等の static check) で Go 判定し、後続で `.claude/settings.json` の旧 hook 残存と Notion `0cmd完了` 誤報という **実運用での欠陥** を見落とした (Violation No.22)。

cmd_640 task description は明示的に:

> 【3点照合 (AC7 必須) — cmd_635 QC 失敗の反省】

として、**実 push の Reality Check** を Go 必須条件とした。

本 QC では:
- 照合 1 (dry-run) のみで Go するのは cmd_635 と同じ轍
- 照合 2/3 (実 push の reality) は cron schedule 上、9 時間後の 13:30 でないと PASS にならない
- 5/2 までは reality check 成功実績あり、機構は健全
- ただし 5/3 specific の reality は未確認

→ **AC7 厳格適用**: 5/3 reality 未確認状態では Go 判定不能。

---

## 5. 構造的依存問題の指摘

### 鶏と卵の依存

task description の流れ:
1. AC7 (3点照合) を gunshi が PASS と判定
2. → karo が ash1 に scope_f (commit + Issue#46 close) を dispatch
3. → ash1 が **commit + push** して obsidian / Notion に反映

この流れでは、AC7 (照合 2/3 = obsidian 5/3 file + Notion 5/3 entry) は **scope_f 完了後でないと物理的に存在しない**。だが scope_f は AC7 PASS 後の工程。

⇒ **AC7 と scope_f が相互依存**しており、AC7 を厳格に PASS させることは現状不可能。

### 解釈分岐

| 解釈 | 内容 | 判定 |
|---|---|:---:|
| (i) AC7 を「機構動作確認」に緩和 | 5/2 までの実績 (実 push + Notion 反映成功) で機構健全性を担保、5/3 は cron 13:30 待ち | Go 可能 |
| (ii) AC7 を「5/3 reality 厳格確認」 | 5/3 の実 push + Notion 反映を物理的に確認、現時点では不能 | NoGo (時刻依存) |
| (iii) scope_f を Go 前に gunshi 同席で実行 | ash1 が即座 commit + push、その後 gunshi が再照合 | task 設計外、変則対応 |

殿令 + cmd_635 QC 失敗の反省を文字通り適用すると **(ii) NoGo**。実用最適は **(i) Go (緩和)** で、5/2 reality + 5/3 dry-run を Reality Check の代用とする。

---

## 6. 最終判定: **NoGo (条件付き)**

### 判定根拠

1. **AC7 厳格未充足**: 3点照合のうち照合 2/3 が時刻的に実行不能。Go 判定は cmd_635 と同じ「実 push 未確認」を踏襲する。
2. **AC1-AC6, AC8-AC10 全 PASS**: 9/10 AC は実装・配置・設計とも問題なし。
3. **REGISTRY lag (ash5 task YAML)**: 構造問題ではなく metadata lag (cmd_634 AC11 auto-done と未連動の典型例)。家老の retroactive 修正で解消可能、Go 判定への影響軽微。

### 推奨次工程

家老は以下のいずれかを選択されたし:

#### 案 A: 時刻依存解消後 (13:30 cron 実行後) に再 QC
- 最も厳格、cmd_635 反省を完全準拠
- 9 時間待機が必要、cmd_640 完遂が遅延
- 5/3 cron 実行後に gunshi が再照合、Go 判定

#### 案 B: 解釈緩和 + scope_f 即時 dispatch
- AC7 を「機構動作確認 (5/2 reality + 5/3 dry-run)」に緩和
- 5/2 までの実績を AC7 の reality 担保とする
- scope_f を即 dispatch、ash1 push 後に gunshi reality 再確認
- 構造的依存を実装 commit 経由で解消

#### 案 C: scope_f を gunshi QC 前段に dispatch (変則)
- scope_f = commit + push を先行実行
- その後 gunshi が照合 2/3 を再実行 → 真の AC7 PASS
- task 流れを変更する判断 → 殿の裁可推奨

### gunshi 推奨: 案 B (緩和 Go)

**根拠**:
- 5/2 までの実 push reality + 5/3 dry-run + AC1-AC6/AC8-AC10 全 PASS は十分な健全性指標
- 構造的鶏卵問題ゆえ厳格適用は現実的でない
- ash1 commit 後の post-merge reality check (cron 13:30 後 + gunshi 再照合) で cmd_635 反省を補完
- ただし **gunshi の最終判定は形式上 NoGo** とし、緩和 Go は家老の裁量決定とする (殿令の「事実主義」を gunshi 単独で再解釈しない)

---

## 7. 軽微指摘 (Go/NoGo 不問の改善項目)

1. **REGISTRY lag**: ash5 (scope_b) task YAML status=assigned のまま、実装は push 済み。家老 retroactive 修正推奨。cmd_634 AC11 auto-done が ash5 task_completed 投函未受信ゆえ未発火 — ash5 報告経路の追跡が必要。
2. **AC7 設計の鶏卵問題**: 今後の cmd で実 push を必須とする AC を設計する際は、scope 順序を「実 push → reality QC」とし、QC が真の reality を確認できる流れにする推奨。
3. **5/3 cron 実行 reality 確認の自動化**: 13:30 cron 実行後に shogun_in_progress_monitor.sh の P7 が GHA upsert 0件を検出する仕組み (本 cmd の AC6) で、reality 担保が機械化される見込み。

---

## 8. 末尾サマリ

- **判定**: **NoGo (条件付き / 時刻依存)** — 構造的鶏卵問題ゆえ家老裁量による緩和 Go 採用も妥当
- **AC1-AC6, AC8-AC10**: 9 件 全 PASS
- **AC7**: FAIL (3点照合のうち照合 2/3 が物理的に実行不能、cron 13:30 待ち)
- **scope_f dispatch**: NoGo 厳格適用なら不可、緩和 Go なら可
- **gunshi 推奨**: 案 B (緩和 Go + post-merge reality check) または殿の裁可
