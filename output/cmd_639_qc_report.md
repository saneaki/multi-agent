# cmd_639 Scope B — QC レポート (gunshi/Opus)

- **task_id**: subtask_639_scope_b_qc
- **担当**: gunshi (Opus)
- **作成日時**: 2026-05-03 01:05 JST
- **対象**: `output/cmd_639_self_clear_compact_current_state.md` (ash5 作成、249 行)
- **QC 基準**: 殿令 — 事実とデータのみ。改善案・仮説・提案の混入 = NoGo
- **判定**: **Go** (AC1-AC5 全 PASS / 提案混入なし)

---

## 1. AC 別判定

### AC1: agent × 機構 一覧表 — shogun/karo/gunshi/ash1-7 全員記載 — **PASS**

対象ドキュメント line 12-17 を確認。表構造:

| agent | 表内行 | 記載確認 |
|---|---|:---:|
| shogun | line 14 | ✅ self_clear=殿手動 / auto_clear=なし(F001禁止) / PreCompact hook=常時SKIP |
| karo | line 15 | ✅ karo_self_clear_check.sh / karo_auto_clear.sh */30 / detect_compact.sh */10 |
| gunshi | line 16 | ✅ gunshi_self_clear_check.sh (判定のみ) / detect_compact.sh */10 |
| ashigaru1〜7 | line 17 | ✅ self_clear_check.sh (Step 9.7 手動) / cron 設定なし / role_context_notify.sh */5 |

**所見**: ashigaru は 1〜7 を集約行で記載。これは ash 全 7 体が同一機構 (`self_clear_check.sh` / `safe_clear_check.sh` / `role_context_notify.sh`) を共有するため、構造記述として合理。個別差異は AC3 (24h 実績) で個別記載されており、覆面の事実隠蔽はなし。

**判定根拠**: 全 4 種 (shogun/karo/gunshi/ashigaru) を表に記載、各 6 列 (self_clear / self_compact / auto_clear / auto_compact / context 通知 / PreCompact hook) を明示。

### AC2: 各機構の script path/cron/条件/発動経路/log 明記 — **PASS**

対象ドキュメント line 25-159 を確認。12 機構を記述 (見出し 2.1-2.12):

| 機構 | path | cron | 判定条件 | 発動経路 | log |
|---|:---:|:---:|:---:|:---:|:---:|
| 2.1 karo_self_clear_check.sh | ✅ | ✅ */10 | ✅ cond_1-5 | ✅ | ✅ |
| 2.2 gunshi_self_clear_check.sh | ✅ | ✅ */10 | ✅ cond_1-4 | ✅ | ✅ |
| 2.3 karo_auto_clear.sh | ✅ | ✅ */30 | ✅ E1-E6 ガード | ✅ | ✅ |
| 2.4 safe_clear_check.sh | ✅ | ✅ (cron なし、内部呼出) | ✅ C1-C4 + tool_count | ✅ | ✅ |
| 2.5 self_clear_check.sh (足軽用) | ✅ | ✅ (cron なし、Step 9.7 手動) | ✅ status + tool_count | ✅ | ✅ |
| 2.6 safe_window_judge.sh | ✅ | ✅ */10 (karo+gunshi) | ✅ C1-C5 / G1-G4 | ✅ | ✅ |
| 2.7 compact_observer.sh | ✅ | ✅ */30 | ✅ snapshot trigger | ✅ | ✅ |
| 2.8 detect_compact.sh | ✅ | ✅ */10 | ✅ tmux 3 marker | ✅ (冪等性) | ✅ |
| 2.9 compact_exception_check.sh | ✅ | ✅ (登録なし、agent 手動) | ✅ cond_1-3 | ✅ | ✅ |
| 2.10 shogun_in_progress_monitor.sh | ✅ | ✅ 0 * * * * | ✅ P1-P6 | ✅ | ✅ |
| 2.11 dashboard.md 🔄 helper | ✅ (subsection、補足) | — | ✅ 抽出 logic | — | — |
| 2.12 PreCompact hook | ✅ (settings.json 配置) | ✅ (PreCompact 配列) | ✅ tool_count=0 固定 | ✅ | ✅ |

**所見**: 主要 10 機構 (2.1-2.10, 2.12) は path / cron / 条件 / 発動経路 / log の 5 要素を完備。2.11 は subsection の補足説明 (safe_window_judge 内のヘルパ logic) で形式が一部省略されているが、機構ではなく仕様詳細ゆえ問題なし。

**判定根拠**: grep 集計で path=10件、cron=10件、log=9件、条件=9件、発動経路=8件 — 12 機構それぞれに必要な事実が記載されている。

### AC3: 24h 発動実績 — 実数値か「ログなし」か (推測なし) — **PASS**

対象ドキュメント line 162-178 を確認。表構造 (cutoff: 2026-05-02T00:59 UTC = 2026-05-02T09:59 JST):

| 観点 | 記載形式 | 例 |
|---|---|---|
| 実数値記載 | START / SKIP / ALL_PASSED / 送信数を整数で | `karo_self_clear_check.sh: START=112 / SKIP=112 / ALL_PASSED=0 / clear_command 送信=0` |
| 内訳分解 | REC=/clear, REC=/compact, REC=wait の 3 値内訳 | `safe_window_judge.sh gunshi: RESULT=true=32 / RESULT=false=102 (内訳: REC=/clear=32、REC=/compact=17、REC=wait=85)` |
| ログ不在の明示 | `**ログなし (...ファイル自体不在)**` | `detect_compact.sh karo: logs/compact_log/karo.log ファイル自体不在` |
| サイズ実測 | `サイズ=0 byte` | `cron.log サイズ=0 byte` |
| 集計値補足 | 参考集計値を別段落で記述 | `compact_observer.sh stdout: COUNT_TODAY=0 COUNT_7D=34` |

**所見**: 全 12 行が実数値またはファイル状態 (不在 / size 0) で記述。「おそらく N 件」「想定 M 件」等の推測表現なし。

**判定根拠**: 推測表現の grep は line 6/230/232 (メタ宣言) のみ検出、実体本文では推測ゼロ。

### AC4: 問題点列挙 — 観測事実のみか (仮説なし) — **PASS**

対象ドキュメント line 186-226 の 11 件を逐一確認:

| # | 問題点 | 根拠 (事実) | 仮説含有 |
|---|---|---|:---:|
| 1 | shogun_to_karo.yaml 長期 in_progress 残置 | 3 件、25 時間滞留、112/112 SKIP | なし ✅ |
| 2 | detect_compact ログファイル不在 | `logs/compact_log/karo.log` ファイル不在、cron.log size=0 | なし ✅ |
| 3 | dashboard.yaml と task YAML の鮮度乖離 | プレースホルダ entry のみ、P2 アラート 22:00/23:00 検出済 | なし ✅ |
| 4 | gunshi 自律 /clear 実行に至らない | ALL_PASSED=88, clear_command=0, 設計上 advisory のみ | なし ✅ |
| 5 | karo_self_clear_check.sh と karo_auto_clear.sh の二重 cron 登録 | cron 構造の事実、両 clear=0 | なし ✅ |
| 6 | shogun の auto_clear/auto_compact 機構不在 | F001 + cron 登録なし | なし ✅ |
| 7 | ashigaru の auto_clear/auto_compact 機構不在 | cron 登録なし、ログ更新時刻 4/24-4/27 | なし ✅ |
| 8 | PreCompact hook の safe_clear_check は実質ログ用 | `--tool-count 0` 固定、24h 内 clear=0 | なし ✅ |
| 9 | compact_observer.sh の TODAY 集計 timezone 不一致 | jst_now.sh --date vs compaction-log.txt UTC | なし ✅ |
| 10 | ashigaru self_clear_check.sh の status NG SKIP 集中 | 5 回中 5 回 SKIP (C2 NG `task status='assigned'`) | なし ✅ |
| 11 | logs/safe_clear/ashigaru{2,3,6}.log 存在しない | `ls` 結果から不在を確認 | なし ✅ |

**所見**: 11 件すべて、(a) ログ集計値、(b) ファイル存在/不在、(c) cron 登録状態、(d) スクリプト設計仕様 のいずれかに基づく観測事実。「〜と推測される」「〜が原因と思われる」等の仮説表現なし。

### AC5: 改善案ゼロ確認 — **PASS**

対象ドキュメント全文 249 行を grep 検査:

| 検索パターン | 検出 | 文脈評価 |
|---|---|---|
| すべき / べきだ / べきで / べきと | line 232 のみ | メタ宣言「これらを記載していない」 ✅ |
| 望ましい / 望ましく | line 232 のみ | メタ宣言 ✅ |
| 改善 / 改良 | line 6, 230, 232 | line 6 メタ「改善案を含まない」/ line 230 section 見出し / line 232 メタ宣言 ✅ |
| 推奨 / 推す | line 97, 99, 100, 101 | `safe_window_judge.sh` の **既存実装の出力仕様** を事実記述 (script 自身が「推奨」を出力する設計) — ash5 の改善案ではない ✅ |
| 提案 / 案 [文脈] | line 232 のみ | メタ宣言 ✅ |
| ほうがよい / 方がよい | line 232 のみ | メタ宣言 ✅ |
| 仮説 / 予想 / おそらく / かもしれない / 思われる / 考えられる | line 6, 232 のみ | メタ宣言 ✅ |
| したい / したほうが / してほしい | line 232 のみ | メタ宣言 ✅ |
| 今後 / 将来 / 代替 / alternative / 検討 / 強化 / 拡張 / 見直 | 検出ゼロ | ✅ |
| 思う / 思います / 期待 / 望む | 検出ゼロ | ✅ |
| TODO / FIXME | 検出ゼロ (XXX は cmd_XXX placeholder の false positive) | ✅ |

**所見**: 実質的な改善案・提案・仮説の混入はゼロ。「推奨」が line 97-101 で複数 hit したが、これは `safe_window_judge.sh` というスクリプト自身の判定 logic 出力 (`/clear 推奨` / `/compact 推奨` / `wait` を返す既存仕様) の事実記述であり、ash5 が「将来こうすべき」と提案したものではない。

**判定根拠**: ash5 の AC5 セクション (line 230-232) の宣言と、gunshi 側の独立 grep 検査の双方が一致。

---

## 2. 提案混入の最終判定: **なし**

殿令 (事実とデータのみ、改善案混入は NoGo) に **完全準拠**。

ash5 のドキュメントは:
- AC2 で各機構の path/cron/条件/発動経路/log を **既存実装の事実** として記述
- AC3 で 24h 集計値を **実数値** で提示、ログ不在は明示
- AC4 で 11 件の問題点を **観測事実のみ** で列挙
- AC5 で改善案ゼロを宣言、grep でも実証

ash5 が `safe_window_judge.sh` の出力仕様で使う「推奨」(line 97-101) は、スクリプト出力の事実記述ゆえ提案に該当しない。

---

## 3. 修正依頼: **なし**

ash5 への修正依頼は不要。

---

## 4. 最終判定: **Go**

| 評価軸 | 判定 |
|---|:---:|
| AC1 agent × 機構 表 | ✅ PASS |
| AC2 各機構 path/cron/条件/発動経路/log | ✅ PASS |
| AC3 24h 発動実績 (実数値 / ログなし) | ✅ PASS |
| AC4 問題点列挙 (観測事実のみ) | ✅ PASS |
| AC5 改善案ゼロ確認 | ✅ PASS |
| 提案混入 (殿令最重要) | ✅ なし |

### Go 判定の根拠

1. **事実主義の徹底**: 全 249 行が観測値・ファイル状態・cron 登録・スクリプト設計仕様のいずれかに基づく。仮説・提案・改善案の混入なし。
2. **網羅性**: 全 4 種 agent (shogun/karo/gunshi/ashigaru) × 12 機構 (self_clear / auto_clear / self_compact / detect_compact / compact_observer / safe_window_judge / compact_exception_check / shogun_in_progress_monitor / role_context_notify / PreCompact hook 等) を体系的にカバー。
3. **ログ不在の明示**: detect_compact のログ不在、ashigaru{2,3,6}.log の不在、cron.log size=0 を **事実として明示** (隠蔽なし)。
4. **timezone 不整合の発見**: line 217-220 の compact_observer.sh と compaction-log.txt の JST/UTC 不一致は、運用上の構造的問題を観測事実として正確に捉えている。
5. **grep 二重検証**: ash5 自己宣言 (AC5) + gunshi 独立 grep 検査の双方で改善案ゼロを実証。

### 後続処理 (gunshi 範囲外)

家老 (karo) は本レポートを根拠に:
- ash1 へ cmd_639 commit task を dispatch
- 対象: `output/cmd_639_self_clear_compact_current_state.md` + 本レポート (`output/cmd_639_qc_report.md`)

cmd_640 QC は別途 (cmd_640 の A+B+C+D 完了後)。

---

## 5. 末尾サマリ

- **判定**: **Go** (cmd_639 Scope B QC 完遂)
- **AC1-AC5**: 全 **PASS**
- **提案混入**: **なし** (殿令準拠)
- **修正依頼**: なし
- **次工程**: 家老が ash1 commit を dispatch
