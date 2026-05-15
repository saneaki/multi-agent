# cmd_730h δ-B: launcher spec consistency smoke tests

**作成日**: 2026-05-16 06:55 JST
**担当**: ashigaru2
**parent**: cmd_730 δ-B
**commit**: (後記)

---

## 概要

β/γ の回帰防止として launcher spec consistency smoke を新設した。
shu/shk/shx/shp の CLI/model spec、settings.yaml 不変性、pane meta 整合を静的解析 + dry-run で継続検証できる構造にした。

---

## テスト一覧

### tests/smoke/launcher_spec_consistency.sh

| ID | 区分 | 内容 | 結果 |
|----|------|------|------|
| T1-1 | static | settings.yaml 存在確認 | PASS |
| T1-2 | static | settings.yaml YAML parse | PASS |
| T1-3 | static | canonical baseline 10エージェント model 照合 | PASS |
| T1-4 | static | formations.hybrid ash6-7 = codex/gpt-5.5 不変確認 | PASS |
| T1-5 | static | shutsujin_departure.sh bash -n | PASS |
| T2-1 | static | --kessen フラグ存在 | PASS |
| T2-2 | static | KESSEN_MODE karo/ashigaru opus-4-7 コマンド確認 | PASS |
| T2-3 | static | KESSEN_MODE _karo_cli_type=claude 明示設定 (BETA-6) | PASS |
| T2-4 | static | KESSEN/HYBRID 排他ガード確認 | PASS |
| T3-1 | static | --hybrid フラグ存在 | PASS |
| T3-2 | static | shx ash6-7 codex/gpt-5.5/xhigh runtime overlay 確認 | PASS |
| T3-3 | static | shc deploy --settings-only 削除確認 (BETA-4 fix) | PASS |
| T3-4 | static | HYBRID_MODE path に settings.yaml write なし | PASS |
| T4-1 | static | scripts/shp.sh bash -n | PASS |
| T4-2 | static | shp transient path: settings.yaml write open 0件 | PASS |
| T4-3 | dry-run | shp 1 --dry-run 後 settings.yaml hash 不変 | PASS |
| T4-4 | static | --persist フラグ存在 (明示永続化のみ書込) | PASS |
| T5-1 | static | shutsujin_departure.sh settings.yaml 直接書込みなし | PASS |
| T5-2 | static | shu が cli_adapter 経由で settings.yaml を読む設計証跡 | PASS |
| T5-3 | static | scripts/shc.sh bash -n | PASS |
| **T6-1** | **static** | **update_dashboard_formation() 関数定義確認** | **PASS** |
| **T6-2** | **static** | **update_dashboard_formation() 起動パスで呼出確認** | **PASS** |
| **T6-3** | **static** | **dashboard model-update sed コマンド存在確認** | **PASS** |
| **T7-1** | **static** | **shogun pane @agent_cli 設定確認** | **PASS** |
| **T7-2** | **static** | **karo pane @agent_cli 設定確認** | **PASS** |
| **T7-3** | **static** | **ashigaru/gunshi pane @agent_cli 設定確認** | **PASS** |
| **T7-4** | **static** | **pane-border-format に @model_name 参照確認** | **PASS** |
| T8-1 | dry-run | shp all-Sonnet dry-run ≥10行確認 | PASS |
| T8-1-model | dry-run | Sonnet+T ≥10回出現 | PASS |
| T8-2 | dry-run | shp all-Opus dry-run ≥10行確認 | PASS |
| T8-2-model | dry-run | Opus+T ≥10回出現 | PASS |
| T8-3 | dry-run | shp all-Codex dry-run ≥10行確認 | PASS |
| T8-3-model | dry-run | Codex ≥10回出現 | PASS |
| T8-hash | dry-run | 3モデル dry-run 後 settings.yaml hash 不変 | PASS |

**合計: PASS=34 FAIL=0 SKIP=0**

### tests/unit/test_launcher_spec.bats (CI/手動 wrapper)

| ID | 内容 | 結果 |
|----|------|------|
| T1-syntax | shutsujin_departure.sh bash -n | PASS |
| T1-yaml | settings.yaml parse | PASS |
| T1-baseline | canonical agent models | PASS |
| T1-hybrid | formations.hybrid ash6-7 immutable | PASS |
| T2-kessen-flag | --kessen フラグ | PASS |
| T2-kessen-opus-cmd | KESSEN_MODE opus コマンド | PASS |
| T2-kessen-karo-cli | _karo_cli_type=claude (BETA-6) | PASS |
| T2-kessen-hybrid-mutex | KESSEN/HYBRID 排他 | PASS |
| T3-hybrid-flag | --hybrid フラグ | PASS |
| T3-hybrid-codex | shx ash6-7 codex/xhigh overlay | PASS |
| T3-beta4 | --settings-only 削除確認 | PASS |
| T3-no-yaml-write | settings.yaml 直接書込みなし | PASS |
| T4-syntax | shp.sh bash -n | PASS |
| T4-persist-flag | --persist フラグ | PASS |
| T4-dry-run-immutable | shp dry-run 後 hash 不変 | PASS |
| T5-no-shu-settings-write | shu settings.yaml write なし | PASS |
| T5-shc-syntax | shc.sh bash -n | PASS |
| T8-sonnet-matrix | Sonnet matrix dry-run | PASS |
| T8-opus-matrix | Opus matrix dry-run | PASS |
| T8-codex-matrix | Codex matrix dry-run | PASS |
| T8-matrix-hash | 3モデル後 hash 不変 | PASS |
| smoke-script-syntax | smoke script bash -n | PASS |
| smoke-full-run | smoke script full run PASS | PASS |

**合計: 23/23 PASS SKIP=0**

---

## 受入基準対応

| AC | チェック | 結果 |
|----|---------|------|
| DELTA-B1 | launcher_spec_consistency.sh 新設、隔離設計 | PASS — 静的解析+dry-runのみ、live tmux 操作なし |
| DELTA-B2 | T1/T2/T3 検証実装 | PASS — 34項目中 T1x5/T2x4/T3x4 が静的証跡を担保 |
| DELTA-B3 | T4/T5/T6/T7 実装または代替 | PASS — T4/T5: static+dry-run / T6/T7: 静的解析代替 |
| DELTA-B4 | T8 shp 10×3 matrix | PASS — 3モデル×12 DRY-RUN lines 確認 |
| DELTA-B5 | test_launcher_spec.bats 新設 | PASS — 23項目 CI/手動両対応 |
| DELTA-B6 | bash -n PASS + SKIP=0 | PASS — PASS=34 FAIL=0 SKIP=0 |
| DELTA-B7 | cmd_704 git preflight + Refs cmd_730 | PASS — git add -f smoke + tests only |
| DELTA-B8 | output に申し送り記録 | このファイル |

---

## T6/T7 静的代替の根拠

**T6 (dashboard sync)**: `update_dashboard_formation()` は `shutsujin_departure.sh` L95 に定義され、起動後 L914 で呼ばれる。関数内 L125/L131 で `sed -i "s/足軽${i}号..."` が dashboard.md を更新する。live セッションなしでも機構の存在と呼出経路を静的に証明できる。

**T7 (pane meta integrity)**: `@agent_cli` は shogun(L799)/karo(L827)/ashigaru(L844,L873)/gunshi(L898) の全ペインに `tmux set-option` で設定される。`@model_name` は `pane-border-format`(L720) で参照され可視化される。これらを静的 grep で確認することで「設定機構の実装」を証明する。ε フェーズでは live tmux ペインでの実値確認が追加予定。

---

## 残リスク・ε への申し送り

1. **T6/T7 live 確認**: ε フェーズで実際の multiagent セッション起動後に `tmux display-message -p '#{@agent_cli}'` で実値を確認すること
2. **T8-3-model Codex**: `gpt-5.5` モデルが実際に利用可能かの確認はε
3. **CI 安定性**: `tests/smoke/launcher_spec_consistency.sh` は `.gitignore` の `*` により通常の git status に出ない。CI では `git add -f` が必要
4. **T1-3 canonical baseline**: settings.yaml 変更時にテスト期待値も更新が必要

---

## commit SHA

(コミット後記載)
