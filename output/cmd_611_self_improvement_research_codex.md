# cmd_611 Scope B Codex: shogun multi-agent 自己改善ループ実装調査

## 0. 調査対象と根拠URL
- 記事1: https://zenn.dev/hrmtz/articles/8fb837b9cfac57
- 記事2: https://github.com/karpathy/autoresearch

統合方針: 記事1の「会話ログ mining + hook注入」を shogun 運用へ移植し、記事2の「小さく固定された実験ループ」を cmd 単位改善サイクルへ適用する。

## 1. T1 jsonl mining 技術詳細

### 1.1 実データ配置と構造
- パス: `/home/ubuntu/.claude/projects/-home-ubuntu-shogun/**/*.jsonl`
- 代表構造（観測）:
  - `type`: `user|assistant|system|queue-operation|file-history-snapshot|last-prompt`
  - `assistant.message.content[]` 内に `tool_use`
  - `user.message.content[]` 内に `tool_result`
  - `timestamp`, `cwd`, `sessionId`, `uuid`, `parentUuid`

### 1.2 失敗パターン抽出で参照すべきフィールド
- 実行文脈: `sessionId`, `cwd`, `timestamp`, `gitBranch`
- 失敗イベント候補:
  - `type=system` かつ `level=error`
  - `tool_result` の `is_error=true`
  - assistant応答に `error:` プレフィックス
  - 同一 `promptId` 内で `tool_use -> tool_result(error)` の連鎖
- 回復有無:
  - 直後N件で成功結果が出たか（再試行成功/未成功）

### 1.3 pattern catalog データ構造案
```yaml
version: 1
patterns:
  - pattern_id: P_TOOL_TIMEOUT
    signature:
      tool: Bash
      error_regex: "(timed out|TimeoutExpired)"
      scope: "scripts/*"
    severity: high
    first_seen: "2026-04-30T00:00:00+09:00"
    count_7d: 12
    impacted_roles: [karo, ashigaru]
    candidate_fix:
      hook_delta: "preflight timeout check"
      instruction_delta: "retry once after web search"
    evaluation_metric:
      - "timeout_rate_7d"
      - "mean_recovery_turns"
```

### 1.4 実装スクリプト案（Python）
```python
#!/usr/bin/env python3
import json, re, glob
from collections import Counter, defaultdict

ERR_RE = re.compile(r"(error|forbidden|timeout|not found)", re.I)

stats = Counter()
by_pattern = defaultdict(int)

for fp in glob.glob('/home/ubuntu/.claude/projects/-home-ubuntu-shogun/**/*.jsonl', recursive=True):
    with open(fp, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                ev = json.loads(line)
            except Exception:
                continue
            t = ev.get('type', '')
            stats[t] += 1

            # tool_result error detection
            msg = ev.get('message', {})
            content = msg.get('content')
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'tool_result':
                        if c.get('is_error'):
                            by_pattern['tool_result_is_error'] += 1
                        txt = str(c.get('content', ''))
                        if ERR_RE.search(txt):
                            by_pattern['tool_result_error_text'] += 1

            # system error detection
            if t == 'system' and str(ev.get('level', '')).lower() == 'error':
                by_pattern['system_level_error'] += 1

print('event_type_counts', dict(stats))
print('error_pattern_counts', dict(by_pattern))
```

bash版最小構成:
- `find ... -name '*.jsonl' -print0 | xargs -0 jq ...` で抽出
- `rg -i 'error|forbidden|timeout'` で粗分類
- 日次集計を `logs/improvement_mining/*.json` に保存

## 2. T2 autoresearch流ループの shogun 適用

### 2.1 3ファイル分離の対応
- `problem.md`: 失敗パターン catalog（上記P_*）
- `solution.md`: instruction/hook/scripts の差分案（deltaのみ）
- `eval.md`: 成否判定KPIと観測窓

### 2.2 shogun cmd サイクルへの 5min ループ写像
1. `mine` (5分): 前日jsonl+queue/reportsから失敗上位3件抽出
2. `propose` (5分): solution delta を1件だけ作る（多変更禁止）
3. `apply` (5分): feature flag 付きで反映
4. `evaluate` (5分): 直近cmd N件で改善率算出
5. `keep/discard` (5分): KPI向上なら採用、悪化ならrevert

固定短周期にすることで「大改修で原因不明」を防ぐ。

### 2.3 既存スクリプト統合
- `scripts/context_snapshot.sh`
  - 失敗時の `decisions/blockers` を自動で pattern miner 入力に連携
- `scripts/inbox_write.sh`
  - `compact_suggestion` と同様に `improvement_suggestion` type を追加可能
- 出力先
  - `output/improvement/problem.md`
  - `output/improvement/solution.md`
  - `output/improvement/eval.md`

## 3. T3 hook injection 技術詳細

### 3.1 現在hook体系（`~/.claude/settings.json`）
- `PreToolUse`: dev server制御、tmux推奨、push警告、Edit/Write compact提案
- `PreCompact`: snapshot, dispatch persist, safe_clear_check
- `SessionStart`: post_compact dispatch restore
- `PostToolUse`: counter, cmd_squash_pub_hook, formatter/tsc/check-console-log

### 3.2 pattern -> hook delta 自動生成案
入力:
- pattern catalog (`P_*`)
- hook template（JSON fragment）

生成ロジック:
1. `severity >= high` かつ `count_7d >= threshold` パターンを対象化
2. パターン別 matcher をテンプレに埋め込む
3. settings.json へ dry-run patch（差分提示のみ）
4. karo承認後に apply

例:
- P_DEV_SERVER_NON_TMUX 多発 -> PreToolUse に blocker hook 追加
- P_MISSING_CONTEXT_LOAD -> SessionStart にガードメッセージ追加

## 4. T4 各agent別 最小変更案

### shogun
- 変更: 発令前チェックhook（cmd YAML必須項目・AC空欄検知）
- 最小実装: `scripts/shogun_reality_check.sh` に1関数追加

### karo
- 変更: evidence-first 判定スクリプト（dashboard二次情報のみ参照を警告）
- 最小実装: `scripts/lib/status_check_rules.py` に `check_primary_yaml_consistency`

### gunshi
- 変更: blind spot checklist 自動生成
- 最小実装: `scripts/qc_auto_check.sh` から `output/qc_blindspots_<cmd>.md` 生成

### ashigaru
- 変更: task完了時 cleanup protocol 自動化
- 最小実装: `scripts/self_clear_check.sh` 実行前に未読inbox・task status整合を検査

## 5. T5 既存 scripts 活用可能性
- 直接流用候補:
  - `scripts/context_snapshot.sh` (失敗文脈採取)
  - `scripts/safe_window_judge.sh` (軽量判定枠組みの再利用)
  - `scripts/validate_ashigaru_report.py` (report quality gate)
  - `scripts/cmd_kpi_observer.sh` (時系列KPI算出の土台)
- 新規追加が必要な最小単位:
  - `scripts/improvement_mine_jsonl.py`
  - `scripts/improvement_build_hook_delta.py`
  - `scripts/improvement_eval.sh`

## 6. 実装シーケンス図（簡易）
```text
jsonl/reports -> mine_jsonl.py -> problem.md
problem.md -> build_solution.py -> solution.md
solution.md -> apply(feature-flag) -> hooks/scripts delta
delta -> eval.sh -> eval.md
if improved: keep / else: rollback
```

## 7. 工数見積（最小実装）
- Scope M1: miner + catalog
  - 目安: 220-300 LOC / 3-4h
- Scope M2: 3ファイル loop orchestrator
  - 目安: 180-260 LOC / 2-3h
- Scope M3: hook delta generator + dry-run patch
  - 目安: 180-240 LOC / 2-3h
- Scope M4: agent別 guard 4点
  - 目安: 120-200 LOC / 2h
- Scope M5: KPI/eval integration
  - 目安: 120-180 LOC / 1.5-2h

合計: 820-1180 LOC / 約10.5-14h（1日実装 + 半日検証）

## 8. 結論
- 記事1の deployment-time alignment は、shogun 運用では「hook注入による再発防止」に相当。
- 記事2の autoresearch は「単一差分・固定短周期・客観KPI」の実験運用規律を提供。
- 両者を統合すると、multi-agent 全体を対象にした自己改善ループを低リスクで段階導入できる。
