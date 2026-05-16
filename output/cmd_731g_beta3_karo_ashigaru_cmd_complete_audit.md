# cmd_731 β-3: karo/ashigaru cmd_complete 漏れ監査

**作成**: 2026-05-16T12:30 JST  
**担当**: ashigaru6 (subtask_731g_beta3_karo_ashigaru_cmd_complete_audit)  
**親 cmd**: cmd_731 (監視層補強・silent silence 構造除去)  
**commit**: 43ee727

---

## 実装概要

### AC-4 Patch A: instructions/ashigaru.md step 6 変更

`value: done` → `value: completed_pending_karo` に変更し、note を追加。

- karo が将軍 inbox に cmd_complete を送付するまで `completed_pending_karo` を保持
- reality_check が 30 分以上経過で上限なし PENDING として継続監視 (多層防御)
- 自分で done に更新することを禁止 — karo 検収完了後に karo が更新する

### AC-5: instructions/karo.md Step 11.7 step 6 強化

`inbox_write shogun (dashboard updated)` → `🚨 MUST: shogun cmd_complete 送付 (AC-5)` に拡張。

- 未実行は **完了不可条件違反** として明文化
- 送付後に ashigaru YAML `completed_pending_karo` → `done` 更新規律を追記
- `bash scripts/karo_cmd_complete_audit.sh` による自動監査への参照を追加
- 末尾警告文も Step 6 省略リスクを明示する内容に更新

### AC-5: scripts/karo_cmd_complete_audit.sh 新設

done cmd（cmd_700 以上）に shogun inbox 内 cmd_complete が存在するか突合する監査スクリプト。

```bash
bash scripts/karo_cmd_complete_audit.sh \
  [--repo-root PATH] [--min-cmd-num N] [--quiet]
```

| 検出条件 | 動作 |
|---------|------|
| done cmd かつ cmd_complete なし | exit 1 (FAIL) |
| done cmd かつ cmd_complete あり | exit 0 (PASS) |
| in_progress / assigned など | スキップ (監査対象外) |

---

## 検証結果

```
bash -n scripts/karo_cmd_complete_audit.sh → SYNTAX_OK

bats tests/unit/test_karo_cmd_complete_audit.bats
1..4
ok 1 T-KCA-001: bash -n 構文チェック
ok 2 T-KCA-002: done cmd に cmd_complete なし → exit 1 (FAIL)
ok 3 T-KCA-003: done cmd に cmd_complete あり → exit 0 (PASS)
ok 4 T-KCA-004: in_progress cmd はスキップ → exit 0 (PASS)
```

SKIP=0 / 全 PASS

---

## AC チェックリスト

| AC | 内容 | 結果 |
|----|------|------|
| B3-1 | karo.md に cmd_complete 送付 MUST USE 明文化 + 未送付完了不可条件 | PASS |
| B3-2 | ashigaru.md step 6 → completed_pending_karo + 検収待ち規律追記 | PASS |
| B3-3 | scripts/karo_cmd_complete_audit.sh 新設、done cmd に cmd_complete なし → exit 1 | PASS |
| B3-4 | tests/unit/test_karo_cmd_complete_audit.bats 追加、3系統 SKIP=0 PASS | PASS |
| B3-5 | bash -n PASS + bats 4/4 PASS、commit に Refs cmd_731 AC-4/5 含む | PASS |

---

## 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `instructions/karo.md` | Step 11.7 step 6 を MUST USE cmd_complete 規律に拡張 |
| `instructions/ashigaru.md` | step 6 value: done → completed_pending_karo + note |
| `scripts/karo_cmd_complete_audit.sh` | 新設 (AC-5 監査スクリプト) |
| `tests/unit/test_karo_cmd_complete_audit.bats` | 新設 (4テスト、3系統) |
| `.gitignore` | karo_cmd_complete_audit.sh をホワイトリストに追加 |

---

## 差戻し修復記録 (2026-05-16T12:28 JST)

### 差戻し理由 (karo 検収)

1. `queue/reports/ashigaru6_report.yaml` が旧 subtask_730y のままだった
2. commit 43ee727 の `.gitignore` に CRLF 余剰差分が混入（スキル6行が LF→CRLF に変換された）

### .gitignore scope exception / whitelist 理由

`scripts/karo_cmd_complete_audit.sh` は `scripts/` ディレクトリが `.gitignore` でデフォルト除外されているため、
明示的な `!scripts/karo_cmd_complete_audit.sh` ホワイトリスト追加が必要。
これは既存パターン (`!scripts/self_clear_check.sh` 等) と同一の理由による正当な追加。

### CRLF 修復内容

commit 43ee727 にて `.gitignore` skills セクションの6行が意図せず LF → CRLF 変換された。
対象行: `!skills/shogun-tmux-busy-aware-send-keys/` 等6行 (lines 313-318)

修復: `sed -i '313,318s/\r//'` により CRLF→LF に戻し、HEAD~1 との net diff を
`+!scripts/karo_cmd_complete_audit.sh` の1行のみに最小化。

### 修復後の検証

```
bash -n scripts/karo_cmd_complete_audit.sh → SYNTAX_OK

bats tests/unit/test_karo_cmd_complete_audit.bats
1..4
ok 1 T-KCA-001: bash -n 構文チェック
ok 2 T-KCA-002: done cmd に cmd_complete なし → exit 1 (FAIL)
ok 3 T-KCA-003: done cmd に cmd_complete あり → exit 0 (PASS)
ok 4 T-KCA-004: in_progress cmd はスキップ → exit 0 (PASS)

SKIP=0 / 全 PASS

git diff HEAD~1 -- .gitignore → +!scripts/karo_cmd_complete_audit.sh のみ（CRLF余剰差分除去確認済み）
```
