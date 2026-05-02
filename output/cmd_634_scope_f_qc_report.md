# cmd_634 Scope F — 統合 QC レポート (gunshi/Opus)

- **task_id**: subtask_634_scope_f_integrated_qc
- **担当**: gunshi (Opus)
- **作成日時**: 2026-05-03 00:50 JST
- **対象**: cmd_634 全 Scope (A-E) の統合検証 + 旧版 vs 新版比較 + Violation No.25 追記
- **判定**: **Go** (全 N1-N4 PASS / 全 AC1-AC13 PASS / Violation No.25 追記済)

---

## 0. 全 Scope 成果物確認 (pre-check)

| Scope | 担当 | 成果物 | 行数/件数 | 存在 |
|---|---|---|---:|:---:|
| A: verifier 強化 | ash5 | `/home/ubuntu/.claude/agents/implementation-verifier.md` | 342 行 | ✅ |
| B: cmd 種別判定設計 | ash7 | `output/cmd_634_scope_b_cmd_type_design.md` | 347 行 | ✅ |
| C: 回帰テスト | ash6 | `output/cmd_634_scope_c_regression_report.md` | 141 行 | ✅ |
| D: REGISTRY lag fix | ash3 | `scripts/inbox_watcher.sh` (auto-done 関数追加) | 11 keyword hit | ✅ |
| E: dashboard stale alert | ash1 | `scripts/shogun_in_progress_monitor.sh` (P6 追加) | 6 keyword hit | ✅ |

前提充足。統合 QC を実施。

---

## 1. N1-N4 検証結果

### N1: commit ≠ 運用稼働 防止機構 (AC11 auto-done) — **PASS**

`scripts/inbox_watcher.sh` の `auto_done_on_task_completed()` (line 1062-1142) を確認。

| Check | 結果 | 根拠 |
|---|:---:|---|
| 関数定義存在 | ✅ | line 1065 `auto_done_on_task_completed()` |
| karo-only guard | ✅ | line 1066 `[ "${AGENT_ID:-}" = "karo" ] || return 0` |
| `task_completed` filter | ✅ | line 1086 `if msg.get("type") != "task_completed": continue` |
| read:true skip | ✅ | line 1084 `if msg.get("read", False): continue` |
| from_agent 妥当性検証 | ✅ | line 1089 `re.fullmatch(r'[a-z0-9_-]+', from_agent)` |
| 冪等性 (already done skip) | ✅ | line 1108 `if status in ("done", "completed", "failed"): ... continue` |
| 原子操作 (tempfile + os.replace) | ✅ | line 1130-1133 `tempfile.NamedTemporaryFile(...) ... os.replace(tmp_path, task_path)` |
| 失敗継続 (`|| true` + `sys.exit(0)`) | ✅ | line 1067 `<< 'PYEOF' 2>&1 || true` + 例外時 stderr ログ |
| jst_now.sh 利用 | ✅ | line 1113-1119 |
| main loop 呼出 | ✅ | line 1184-1185 (nudge 前に呼出) |

**所見**: 設計書 (scope_b §2) の指針通りに実装。allowlist は `[a-z0-9_-]+` の permissive regex で、設計書推奨の明示 allowlist (`ashigaru[1-7]|gunshi|karo`) より広いが、karo-only guard により対象 inbox は karo のみゆえ実害なし。

### N2: 5-Layer verifier 強化 (Layer 5 + 3新パターン + L5 Output 行) — **PASS**

`/home/ubuntu/.claude/agents/implementation-verifier.md` (342 行) を確認。

| Check | 結果 | 根拠 |
|---|:---:|---|
| Layer 5 セクション存在 | ✅ | line 246 `### Layer 5: Reporting Quality Check (報告品質検証)` |
| Layer 5 5チェック項目 | ✅ | line 251-255 (AC根拠 / ファイルパス / commit SHA / 数値根拠 / inline 実測値) |
| TMUX_STATE_MISMATCH 追加 | ✅ | line 207 (L4 内 detail) + line 298 (Output Format) |
| DASHBOARD_STALE 追加 | ✅ | line 219 + line 299 (`> 2h` 閾値) |
| STATE_VISIBILITY_GAP 追加 | ✅ | line 232 + line 300 |
| Output Format L5 行追加 | ✅ | line 302-306 (AC 根拠 / ファイルパス / commit SHA / 数値根拠) |
| scope_b 設計書 cmd 種別 4分類以上 | ✅ | scope_b 設計書に 6 分類 (cron / hook / git_push / script / doc_only / general) — 4 を超過 |

**軽微指摘** (機能には影響なし、後続 cmd で修正推奨):
- (a) section heading `## 4-Layer Checklist` (line 47) は `## 5-Layer Checklist` に更新すべき
- (b) 総合判定文「全4層クリア」(line 309) は「全5層クリア」に更新すべき

**所見**: Layer 5 の機能実体は完備。見出しのみ旧名称が残存するが、L5 の機能定義と Output 形式は揃っている。

### N3: REGISTRY_UPDATE_LAG 構造解消 (AC11 + AC12 両実装) — **PASS**

| Check | 結果 | 根拠 |
|---|:---:|---|
| AC11 (scope_d) 実装 | ✅ | `scripts/inbox_watcher.sh:1065-1142` (N1 で詳細検証済) |
| AC12 P6 (scope_e) 実装 | ✅ | `scripts/shogun_in_progress_monitor.sh:347-374` |
| dry-run 実行成功 | ✅ | `bash scripts/shogun_in_progress_monitor.sh --dry-run` exit 0、出力 `2026-05-03 00:49 JST [in_progress_monitor] DRY-RUN: 0件検出` |

**所見**: 二重防衛 (台帳更新漏れの自動検出 = P6 + 自動修復 = AC11 auto-done) が成立。両機構が共存することで、どちらか一方が失敗しても残る経路でカバーできる。

### N4: dashboard 鮮度 alert (P6) 機構化 — **PASS**

`scripts/shogun_in_progress_monitor.sh:347-374` を確認。

| Check | 結果 | 根拠 |
|---|:---:|---|
| `check_pattern_6()` 関数定義 | ✅ | line 347 |
| 2h (120分) 閾値 | ✅ | line 370 `if elapsed_minutes > 120:` |
| `already_sent` 流用 | ✅ | line 44 (bash side、P1-P5 共通) — alert_key で 1h 重複抑制 (line 16) |
| `send_alert` 流用 | ✅ | line 83 (bash side、P1-P5 共通) |
| `out()` 出力流用 | ✅ | line 118-119 (Python side、P6 も `out('P6-dashboard鮮度stale', ...)` で共通系統) |
| main 呼出登録 | ✅ | line 381 `check_pattern_6()` |

**所見**: 既存 P1-P5 の alert 機構を完全流用。新規重複コードなし、保守一元化。

---

## 2. 旧版 (4-Layer) vs 新版 (5-Layer) 差分比較

| 観点 | 旧版 4-Layer | 新版 5-Layer | 効果 |
|---|---|---|---|
| Layer 1 Existence | ファイル存在 / 行数 / git commit / push | (継承) | — |
| Layer 2 Content | AC キーワード確認 | (継承) | — |
| Layer 3 Hygiene | task YAML status / git status / report 更新 / dashboard | (継承) | — |
| Layer 4 Pattern | PUSH漏れ / STATUS漏れ / AGENT-ASSIGNEE / SCOPE混入 / DASHBOARD漏れ / FALLBACK / DIFF反映 / SILENT_FAILURE / 副作用 | + **TMUX_STATE_MISMATCH** / **DASHBOARD_STALE** / **STATE_VISIBILITY_GAP** | cmd_631/cmd_633 incident で旧版が PASS とした欠陥を WARN/FAIL に格上 |
| **Layer 5** Reporting Quality | (なし — 報告本文の文書品質は人手) | **AC根拠 / ファイルパス / commit SHA / 数値根拠 / inline 実測値** の 5 項目を WARN 化 | 「PASS」だけの根拠なし報告を抑止、report self-audit |
| AC11 auto-done | (なし — REGISTRY lag は手動検出) | **inbox_watcher が `task_completed` 受領で task YAML を auto-done** | 台帳更新漏れの自動修復 |
| AC12 P6 dashboard alert | (なし — dashboard stale は手動気付き) | **2h 閾値で `shogun_in_progress_monitor.sh` が ntfy アラート** | dashboard 鮮度劣化の自動検出 |
| 旧 incident への効果 | cmd_631 archive 後 hook 残存 / cmd_633 4新列 shelf-ware を見落とし | scope_c 回帰テストで **両 incident を WARN/FAIL として再現検出** | AC13 達成 |

### scope_c 回帰テスト実証 (AC13)

`output/cmd_634_scope_c_regression_report.md` より:

| cmd | 旧版判定 | 新版判定 | 検出 pattern |
|---|:---:|:---:|---|
| cmd_631 | Go (旧 QC) | **WARN** | `STATE_VISIBILITY_GAP` (`.claude/settings.json:66` に旧 hook 残存) + L5 報告品質 |
| cmd_633 | Go (旧 QC) | **FAIL** | `STATE_VISIBILITY_GAP` (4新列の data supply 欠落) + L5 報告品質 |

旧版は「ファイル追加・列追加・cron登録・syntax・表示」中心の確認ゆえ、後続経路への接続性検証が不足していた。新版は state/schema と data 供給の整合性を必須化することで構造的に検出する。

---

## 3. AC1-AC13 一覧

| AC | 内容 | 判定 | 根拠 |
|---|---|:---:|---|
| AC1 | 旧 verifier の lessons 反映 | PASS | scope_a 342 行に既存 4-Layer + L5 統合 |
| AC2 | tmux capture-pane 必須化 (No.17 対策) | PASS | TMUX_STATE_MISMATCH pattern 追加 |
| AC3 | DASHBOARD 鮮度自動検証 (No.18 対策) | PASS | DASHBOARD_STALE pattern + P6 alert |
| AC4 | action_required 記載確認 (No.19 対策) | PASS | DASHBOARD_STALE 内に action_required check |
| AC5 | external 依存 SPOF 検出 (No.20 対策) | PASS | scope_a の L4 拡充 (single point of failure pattern) |
| AC6 | 4段確認 (commit/配置/登録/実ログ, No.21 対策) | PASS | Layer 1-4 の各 stage 確認に対応 |
| AC7 | 旧 incident 回帰テストで欠陥検出 (No.22 系) | PASS | scope_c で cmd_631/cmd_633 検出済 |
| AC8 | TMUX 切替系 cmd の Stage 3 確認 | PASS | TMUX_STATE_MISMATCH detection |
| AC9 | Reporting Quality 機械化 | PASS | Layer 5 の 5 項目 |
| AC10 | 列添加系 cmd の Layer 4 必須化 | PASS | STATE_VISIBILITY_GAP pattern |
| AC11 | inbox_watcher task_completed auto-done | PASS | scope_d 実装 (N1 で詳細検証) |
| AC12 | shogun_in_progress_monitor P6 dashboard stale alert | PASS | scope_e 実装 (N4 で詳細検証) |
| AC13 | 回帰テストで旧版見落とし → 新版検出 | PASS | cmd_631 WARN + cmd_633 FAIL を実証 (scope_c) |

**全 13 AC PASS。**

---

## 4. Violation.md No.25 追記

**追記項目**: `### No.25 | cmd_634 真未発令 (Reporting Quality Gap)`

| 項目 | 内容要約 |
|---|---|
| 発生 | 2026-05-02 |
| 影響 | 将軍が「cmd_634 発令済み」と発言したが、shogun_to_karo.yaml + inbox_write の formal 系統が未実行 (口頭止まり) |
| 根因 | Reporting Quality Gap (発言と実態の乖離) — L014 (家老申告鵜呑み禁止) の鏡像 |
| 対策 | cmd_634 AC9 / Layer 5 Reporting Quality Check で機械化、SO-24 強化 |
| 参照 | shogun_to_karo.yaml / Violation No.17-21 / 本レポート |

> Note: No.24 は cmd_639 で先行記録予定。task 指示通り No.25 として追記 (連番空欠は cmd_639 完了で解消)。

**追記済 (memory/Violation.md 末尾)。AC_N25 PASS。**

---

## 5. Go / NoGo 判定と根拠

### 判定: **Go**

| 評価軸 | 判定 |
|---|:---:|
| N1 commit≠運用稼働防止 | ✅ PASS |
| N2 5-Layer verifier 強化 | ✅ PASS |
| N3 REGISTRY_UPDATE_LAG 解消 | ✅ PASS |
| N4 dashboard 鮮度 alert | ✅ PASS |
| AC1-AC13 | ✅ 全 PASS |
| Violation No.25 追記 | ✅ PASS |
| dry-run 実行 | ✅ exit 0 |

### 根拠

1. **構造的解決**: REGISTRY_UPDATE_LAG (cmd_637 follow-up 系で再発した台帳更新漏れ) を **検出側 (P6) と修復側 (auto-done) の二重防衛** で解消。一方が失敗しても残る経路がカバー。
2. **横展開可能**: 5-Layer verifier は cmd_631/cmd_633 で旧版見落とし → 新版検出を実証 (scope_c)。今後の cmd でも同種 pattern (列添加 / hook 残存) を機械的に WARN/FAIL 化できる。
3. **規律補完**: Violation No.25 (cmd_634 真未発令 = Reporting Quality Gap) を文書化、L5 報告品質検証 + SO-24 と接続。

### 残課題 (Go 判定に影響しない軽微指摘)

1. **N2 軽微**: implementation-verifier.md の section title `4-Layer Checklist` (line 47) と総合判定文「全4層クリア」(line 309) を 5-Layer 表記へ更新 — 後続 cmd または scope_g 直前に修正推奨
2. **N1 軽微**: from_agent 妥当性検証の regex `[a-z0-9_-]+` は permissive で、設計書推奨の明示 allowlist (`ashigaru[1-7]|gunshi|karo`) より広い — karo-only guard で実害なしだが、後続強化案として allowlist 厳格化を提案
3. **N3 補強**: dashboard.md の `最終更新:` 行が rotate 失敗で空になった場合 P6 は no-op (line 360-361 で early return)。stale 検出の死角ゆえ別 check (`P7-dashboard更新行欠落`) を将来的に検討推奨

---

## 6. scope_g (ash1 commit + push) dispatch 可否

### **可** — scope_g dispatch を許可

理由:
- 全 N1-N4 PASS / 全 AC1-AC13 PASS / Violation No.25 追記済
- dry-run でエラーなし、syntax 健全
- 軽微指摘 (5.残課題) は Go 判定に影響しない後続改善項目

ash1 commit 対象 (推定):
- `/home/ubuntu/.claude/agents/implementation-verifier.md` (scope_a, +61 行)
- `output/cmd_634_scope_b_cmd_type_design.md` (scope_b, 347 行新設)
- `output/cmd_634_scope_c_regression_report.md` (scope_c, 141 行新設)
- `scripts/inbox_watcher.sh` (scope_d, +86 行)
- `scripts/shogun_in_progress_monitor.sh` (scope_e, +32 行)
- `memory/Violation.md` (No.25 追記)
- `output/cmd_634_scope_f_qc_report.md` (本レポート、新設)

**dispatch 推奨 commit message 案** (scope_g 担当 ash1 へのヒント):
```
feat(cmd_634): 5-Layer verifier + AC11 auto-done + AC12 P6 dashboard stale alert

- scope_a: implementation-verifier.md に Layer 5 (Reporting Quality Check) +
  3 新パターン (TMUX_STATE_MISMATCH/DASHBOARD_STALE/STATE_VISIBILITY_GAP) 追加
- scope_b: cmd 種別判定設計書 (cron/hook/git_push/script/doc_only/general 6分類)
- scope_c: 回帰テスト (cmd_631 WARN + cmd_633 FAIL を新版で検出、AC13 達成)
- scope_d: inbox_watcher に auto_done_on_task_completed (REGISTRY lag 修復)
- scope_e: shogun_in_progress_monitor に P6 (dashboard 2h stale alert)
- scope_f: 統合 QC レポート + Violation No.25 (Reporting Quality Gap) 追記
```

---

## 7. 末尾サマリ

- **判定**: **Go** (cmd_634 全 Scope 統合 QC 完遂)
- **N1/N2/N3/N4**: 全 **PASS**
- **AC1-AC13**: 全 **PASS**
- **Violation No.25 追記**: **PASS** (memory/Violation.md 更新済)
- **scope_g dispatch**: **可**

家老 (karo) は本レポートを根拠に scope_g (ash1 commit + push) を dispatch されたし。dispatch 後は、ash1 報告受領で `auto_done_on_task_completed` が発火し、N1 で実装した REGISTRY lag 修復機構の **本番 first-hit** が観測できる見込み (= cmd_634 自身が新機構の最初の運用実証となる)。
