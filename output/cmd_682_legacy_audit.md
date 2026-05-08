# cmd_682 Legacy Skill Audit — cmd_500 以前 + cmd_680 GAS 認証知見

**作成日**: 2026-05-08 17:01 JST
**担当**: 足軽6号 (ashigaru6 / Opus+T)
**親 cmd**: cmd_682 (subtask_682_skill_legacy_integration)
**目的**: cmd_674 audit 残課題「cmd_500 以前 (3ヶ月以上) の遡及スキャン未実施」の解消、
および cmd_680 Codex 独立調査結果 (clasp run scope / RAPT / Web App / SA 制約) の既存
shogun-gas-* skill 群への統合判定。

---

## 1. 監査範囲

### 1.1 遡及対象

- 期間: 2026-01-01 ～ 2026-04-19 (cmd_499 以前 = cmd_500 未満)
- 対象ファイル: `queue/reports/{ashigaru1-7,gunshi}_report.yaml` の git history
- 補完対象: `memory/skill_history.md`「承認待ち」エントリ + skill ディレクトリ実体

### 1.2 監査手法

```bash
# 1) git log で cmd_500 未満の reports 変更を抽出
git log --all --since="2026-01-01" --until="2026-04-19" -p -- "queue/reports/*report*.yaml"

# 2) skill_candidate found:true ブロックを抽出 (32 lines hit)
grep -nE "^\+.*found: true" /tmp/cmd_682/all_reports_diff.txt

# 3) skill_history.md の cmd_500 未満 entries を確認
grep -E "cmd_[1-4][0-9]{1,2}" memory/skill_history.md

# 4) skill ファイル実体存在チェック
for s in <候補名>; do
  ls skills/$s/SKILL.md ~/.claude/skills/$s/SKILL.md 2>/dev/null
done
```

---

## 2. 監査結果サマリ

### 2.1 検出件数

| 区分 | 件数 |
|------|------|
| reports git history で skill_candidate found:true 検出 | 2 件 (cmd_475 / cmd_439) |
| skill_history.md「承認待ち」(cmd_500 未満) | 7 件 |
| 重複除去後 ユニーク候補 | 8 件 |
| cmd_680 知見統合候補 | 2 件 (clasp scope / Web App pivot) |
| **合計処理対象** | **10 件** |

### 2.2 git history hit 詳細

| commit | parent_cmd | skill_candidate.name | 既存処理状況 |
|--------|-----------|----------------------|------------|
| 9e75a803 | cmd_475 | shogun-n8n-notion-trigger-v1-flat-access | SKILL.md 既配置 (105L) / skill_history.md 未登録 → silent inconsistency |
| ac2ac43 系 | cmd_439 | github-release-version-migration | skill_history.md ✅実装済み 既登録 (cmd_440) |

### 2.3 skill_history.md「承認待ち」(cmd_500 未満)

| 候補名 | 出典 cmd | 実体ファイル | §2 統合判定 |
|--------|---------|------------|-----------|
| shogun-n8n-notion-stale-data-cleanup | cmd_291/293 | なし | a=既存統合 (notion-property-sync) |
| shogun-n8n-gmail-trigger-manual-exec-single-item | cmd_297 | なし | a=既存統合 (sib-trigger-incompatibility §4) |
| shogun-n8n-sib-loopback-multi-input-guard | cmd_297 | なし | a=既存統合 (sib-trigger-incompatibility §2) |
| shogun-n8n-manual-execution-api | cmd_296 | 既配置 (418L) | silent inconsistency → ✅実装済 化 |
| shogun-n8n-code-node-multi-item-index | cmd_290 | なし | a=既存統合 (sib-trigger-incompatibility §3) |
| shogun-n8n-gmail-oauth2-http-request | cmd_287c3 | なし | a=既存統合 (n8n-http-credential-patterns §3) |
| n8n-http-predefined-credential | cmd_277 | なし | a=既存統合 (n8n-http-credential-patterns §2) |

---

## 3. skill-creation-workflow §2 統合検討マトリクス

### 3.1 a=既存統合 / b=新規必要 / c=棄却 分類

| ID | 候補 | 既存統合先 | 既存行数 → 統合後 | 判定 | 根拠 |
|----|------|----------|------------------|------|------|
| L-1 | notion-stale-data-cleanup (cmd_291/293) | shogun-n8n-notion-property-sync | 461L (既包含) | a=既存統合 (新規追記不要) | L345-/L406-/L458-459 で stale draftId / 偽陽性 checkbox の 116/328 件修復パターンが既記載 |
| L-2 | gmail-trigger-manual-exec (cmd_297) | shogun-n8n-sib-trigger-incompatibility | 244L (既包含) | a=既存統合 (新規追記不要) | §4 (Gmail Trigger 手動実行制約) に 1 通/exec 仕様 + active 化 + ポーリング待機が既記載 |
| L-3 | sib-loopback-multi-input (cmd_297) | shogun-n8n-sib-trigger-incompatibility | 同上 | a=既存統合 (新規追記不要) | §2 (SiB 複数ループバック JOIN 停止) + Merge(append) 1 本化が既記載 |
| L-4 | manual-execution-api (cmd_296) | (独立 skill 既存) | 418L | silent inconsistency | SKILL.md 既配置 / skill_history.md「(補足)/承認待ち」表記 → ✅実装済 化に格上げ |
| L-5 | code-node-multi-item-index (cmd_290) | shogun-n8n-sib-trigger-incompatibility | 同上 | a=既存統合 (新規追記不要) | §3 (Code node `$input.all()` インデックスバグ cmd_290) が既記載。n8n-code-javascript SC-023 にも関連 |
| L-6 | gmail-oauth2-http-request (cmd_287c3) | n8n-http-credential-patterns | 360L (既包含) | a=既存統合 (新規追記不要) | §3 (Gmail OAuth2 HTTP Request SC-024) が既記載 |
| L-7 | http-predefined-credential (cmd_277) | n8n-http-credential-patterns | 同上 | a=既存統合 (新規追記不要) | §2 (predefinedCredentialType パターン SC-026) が既記載 |
| L-8 | notion-trigger-v1-flat-access (cmd_475) | (独立 skill 既存) | 105L | silent inconsistency | SKILL.md 既配置 / skill_history.md 未登録 → ✅実装済 化 |

### 3.2 cmd_680 GAS 知見統合検討

| ID | 知見領域 | 既存統合先 | 行数推移 | 判定 | 根拠 |
|----|---------|----------|---------|------|------|
| G-1 | clasp run scope 不足 vs RAPT 切り分け | shogun-gas-clasp-rapt-reauth-fallback | 62→110L | a=既存統合 (追記) | 同一ドメイン (clasp 認証復旧)。500L 未満で統合可能。切り分けマトリクス + 推奨フラグ + tokeninfo 確認 + Non-goals が既存補完として自然 |
| G-2 | Web App pivot + SA 制約 + scope runbook 分離 | shogun-gas-automated-verification | 129→191L | a=既存統合 (追記) | 同一ドメイン (GAS 自動検証基盤)。500L 未満。中期戦略として既存「セットアップ」セクションの自然な拡張 |

### 3.3 棄却なし、新規 SKILL 作成なし

cmd_682 では新規 SKILL.md 作成 0 件、棄却 0 件。
理由: cmd_500 未満候補は全て既存 skill に既包含 (L-1〜L-3, L-5〜L-7) または
silent inconsistency (L-4, L-8) のため、§2 統合検討フローで「同一ドメイン → 統合優先」
原則に従い merged または created 化のみで十分。

---

## 4. 実施可否マトリクス (RACE-001 / 制約遵守)

| 制約 | 対応 |
|------|------|
| dashboard.md/yaml は cmd_681 作業中につき編集禁止 | ✅ skill_candidates.yaml + skill_history.md + skills/ のみ編集 |
| 新規 SKILL.md 作成は最小限 | ✅ 新規作成 0 件 (全件既存統合 or silent inconsistency 解消) |
| secret 値記載禁止 | ✅ creds.json / .clasprc.json / token は path / 構造のみ言及 |
| RACE-001 (同時編集禁止) | ✅ 編集対象 skills/shogun-gas-* は他足軽未着手 (cmd_681 は dashboard 担当) |

---

## 5. 残課題

### 5.1 本 cmd で解消したもの

- cmd_674 audit 残課題「cmd_500 以前 (3ヶ月以上) の遡及スキャン未実施」 → 解消
- silent inconsistency 2 件 (notion-trigger-v1-flat-access / manual-execution-api) → ✅実装済 化
- 「承認待ち」7 件 (cmd_500 未満) → merged 化

### 5.2 deferred 維持 (cmd_675b 判定継続)

- SC-suggestions-lifecycle (cmd_596): 2026-06-08 まで観察継続
- SC-667 codex-context-pane-border (cmd_667/671): 2026-06-08 まで観察継続

### 5.3 後続 cmd 候補

- cmd_682 候補 (cmd_680 §7 提案): Web App run endpoint 設計 + `gas_run_webapp.sh` 作成
- 「承認待ち」最近 3 件 (shogun-tmux-busy-aware-send-keys / shogun-l017-dual-model-smoke-qc /
  shogun-dual-model-layered-research) は cmd_500 以降のため本 cmd 対象外

---

## 6. 結論

cmd_682 audit の結論として、cmd_500 以前の skill 候補は **新規作成不要**
(全件既存スキルに包含済または silent inconsistency)。cmd_680 GAS 知見は既存
shogun-gas-* skill 2 件への追記で完結。これにより skill 群の整合性が回復し、
cmd_674 audit 残課題が完全解消する。
