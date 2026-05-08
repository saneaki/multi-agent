# cmd_682 Skill Legacy Integration — 実装記録

**作成日**: 2026-05-08 17:01 JST
**担当**: 足軽6号 (ashigaru6 / Opus+T)
**親 cmd**: cmd_682 (subtask_682_skill_legacy_integration)
**前段 audit**: `output/cmd_682_legacy_audit.md`
**目的**: cmd_682_legacy_audit の §3 統合検討マトリクス判定に従い、skill 群を整合状態へ
反映する実装作業の記録。

---

## 1. 実施概要

### 1.1 編集ファイル一覧

| ファイル | 変更種別 | 概要 |
|---------|---------|------|
| `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` | 追記 | 62→110L: cmd_676/680 「scope 不足 vs RAPT 切り分け」セクション追加 |
| `skills/shogun-gas-automated-verification/SKILL.md` | 追記 | 129→191L: cmd_680 「中期戦略: clasp run 依存からの脱却」セクション追加 |
| `queue/skill_candidates.yaml` | append + summary 更新 | cmd_682 entries 10 件追加 (silent_inconsistency 2 / merged_legacy 6 / merged_cmd680 2) + total_entries 12→22 |
| `memory/skill_history.md` | append (top) | cmd_682 関連 10 行を冒頭テーブルに追加 |
| `output/cmd_682_legacy_audit.md` | 新規 | 本前段監査文書 |
| `output/cmd_682_skill_legacy_integration.md` | 新規 | 本実装記録 |

### 1.2 行数チェック (skill-creation-workflow §3 品質チェックリスト)

| skill | 旧行数 | 新行数 | 制約 | 結果 |
|-------|--------|--------|------|------|
| shogun-gas-clasp-rapt-reauth-fallback | 62 | 110 | < 500L | ✅ |
| shogun-gas-automated-verification | 129 | 191 | < 500L | ✅ |

---

## 2. cmd_680 GAS 知見統合の詳細

### 2.1 shogun-gas-clasp-rapt-reauth-fallback (G-1)

追加セクション「scope 不足 vs RAPT 切り分け (cmd_676/680 統合)」の構成:

1. **切り分けマトリクス**: 3 症状 (`invalid_grant`/`invalid_rapt`、HTTP 403 + scope 不足、HTTP 403 + Cloud project 不一致) を別 runbook に分離
2. **推奨フラグ**: `clasp login --creds creds.json --use-project-scopes --include-clasp-scopes` (clasp 3.x で必須)
3. **scope 確認手順**: `tokeninfo` API で `script.scriptapp` 含有を secret 値出さず確認
4. **Battle-Tested**: cmd_676 / cmd_680 の 2 件を表形式で記録
5. **Non-goals**: `clasp login --adc` (NOT WORKING) / SA `scripts.run` (公式不可) / `--no-localhost` (OOB 廃止)
6. **関連 cmd**: cmd_676 (scope 修正) / cmd_680 (Codex 独立調査)

### 2.2 shogun-gas-automated-verification (G-2)

追加セクション「中期戦略: clasp run 依存からの脱却 (cmd_680 統合)」の構成:

1. **役割分担表**: 日常 run = Web App / deploy = clasp push / 緊急 = clasp run の 3 役割
2. **Web App endpoint 設計**: `doPost` + HMAC 署名 + route whitelist のテンプレート + `gas_run_webapp.sh` 雛形 (cmd_682 候補)
3. **Service Account 制約マトリクス**: `--adc` / `scripts.run` SA / `--creds <SA-key>` の 3 試行と公式制約
4. **scope 不足 runbook 分離**: 3 症状 → shogun-gas-clasp-rapt-reauth-fallback 案A への参照
5. **関連 cmd**: cmd_567 / cmd_676 / cmd_680 / cmd_682 候補

---

## 3. legacy 8 件処理の詳細

### 3.1 silent inconsistency 解消 (status: created)

#### SC-475 shogun-n8n-notion-trigger-v1-flat-access

- **状況**: SKILL.md 既配置 (`~/.claude/skills/shogun-n8n-notion-trigger-v1-flat-access/SKILL.md`, 105L) だが skill_history.md 未登録 (cmd_675b 監査から漏れた残存 silent inconsistency)
- **対応**: skill_candidates.yaml に SC-475 として status:created 登録 + skill_history.md に ✅実装済 行追加
- **由来 cmd**: cmd_475 (n8n Notion Trigger v1 の properties トップレベルフラット展開仕様)

#### SC-296 shogun-n8n-manual-execution-api

- **状況**: SKILL.md 既配置 (`~/.claude/skills/shogun-n8n-manual-execution-api/SKILL.md`, 418L) だが skill_history.md は「(補足)/承認待ち」表記 → 実体不一致
- **対応**: skill_candidates.yaml SC-296 status:created + skill_history.md ✅実装済 化
- **由来 cmd**: cmd_296 (n8n 内部 API `/rest/workflows/{id}/run` の Cookie 認証 + workflowData/triggerToStartFrom 必須仕様)

### 3.2 既存スキルへの merged 反映 (status: merged)

| ID | 候補名 | 統合先 | 既包含確認箇所 |
|----|--------|--------|---------------|
| SC-291 | shogun-n8n-notion-stale-data-cleanup | shogun-n8n-notion-property-sync (461L) | L345-: stale draftId / L406-: pagination / L458-459: cmd_291/293 record |
| SC-297a | shogun-n8n-gmail-trigger-manual-exec-single-item | shogun-n8n-sib-trigger-incompatibility (244L) | §4 (Gmail Trigger 手動実行制約) |
| SC-297b | shogun-n8n-sib-loopback-multi-input-guard | 同上 | §2 (SiB 複数ループバック JOIN 停止) |
| SC-290 | shogun-n8n-code-node-multi-item-index | 同上 | §3 (Code node `$input.all()` インデックスバグ cmd_290) |
| SC-287c3 | shogun-n8n-gmail-oauth2-http-request | n8n-http-credential-patterns (360L) | §3 (Gmail OAuth2 HTTP Request SC-024) |
| SC-277 | n8n-http-predefined-credential | 同上 | §2 (predefinedCredentialType パターン SC-026) |

各エントリは skill_candidates.yaml に `status: merged` + `merged_into: <path>` で明示登録。
新規追記は不要 (skill-creation-workflow §2「同一ドメイン → 統合優先」+「既存に既包含 → 相互参照注記のみ」原則)。

### 3.3 cmd_680 統合 entry (status: merged into existing skills)

| ID | 領域 | 統合先 |
|----|------|--------|
| SC-680-clasp-scope | clasp scope vs RAPT 切り分け | shogun-gas-clasp-rapt-reauth-fallback |
| SC-680-webapp-pivot | Web App pivot + SA 制約 | shogun-gas-automated-verification |

---

## 4. acceptance_criteria 自己照合

| AC | 内容 | 状態 | 根拠 |
|----|------|------|------|
| A-1 | cmd_500 以前の queue/reports/* を全走査し skill_candidate found:true を一覧化 | ✅ PASS | git log diff 走査 (2026-01-01〜04-19) + skill_history.md「承認待ち」抽出。output §2.2/2.3 記載 |
| A-2 | skill-creation-workflow §2 統合検討マトリクスを作成 | ✅ PASS | output/cmd_682_legacy_audit.md §3.1 + §3.2 |
| A-3 | a 統合 / b 新規 / c 棄却 を理由つきで処理 | ✅ PASS | a=既存統合 6 件 + silent inconsistency 解消 2 件 + cmd_680 統合 2 件 = 計 10 件、新規 0 / 棄却 0 |
| A-4 | cmd_680 知見 (script.scriptapp scope / RAPT / Web App / SA 制約) を既存 shogun-gas-* skill 群へ統合 | ✅ PASS | shogun-gas-clasp-rapt-reauth-fallback (62→110L) + shogun-gas-automated-verification (129→191L) |
| A-5 | queue/skill_candidates.yaml に status 明示で反映 | ✅ PASS | 10 entries 追加、total 12→22、by_status 更新 |
| A-6 | memory/skill_history.md を更新 | ✅ PASS | 冒頭テーブルに 10 行追加 (cmd_682 関連) |
| D-1 | output/cmd_682_skill_legacy_integration.md を作成 | ✅ PASS | 本ファイル |

---

## 5. 制約遵守確認

| 制約 | 対応 |
|------|------|
| dashboard.md/yaml は cmd_681 作業中につき編集禁止 | ✅ 編集なし。skills/ + queue/skill_candidates.yaml + memory/skill_history.md + output/ のみ編集 |
| 新規 SKILL.md 作成は最小限 | ✅ 新規作成 0 件 |
| secret 値記載禁止 | ✅ creds.json / .clasprc.json / token は path / 構造のみ言及 (実値なし) |
| RACE-001 (同時編集禁止) | ✅ shogun-gas-* / shogun-n8n-* / queue/skill_candidates.yaml は他足軽未着手 |
| skill-creation-workflow §2 厳守 | ✅ 既存スキル統合検討先行 → 行数チェック (110L/191L < 500L) → 統合実施 |

---

## 6. 北斗整合 (north_star alignment)

### north_star

cmd_674 audit 残課題「cmd_500 以前 (3 ヶ月以上) の遡及スキャン未実施」と
cmd_680 で得た clasp run 開発 cycle の根本解決方針を、skill 群へ正しく反映し、
将来の同類 cmd で同じ知見にすぐアクセスできる体制を確立する。

### N1 / N2 / N3 整合

- **N1 (予防)**: skill_candidates.yaml の by_status (created/rejected/merged/deferred) で全候補の処理状態が即時確認可能となり、silent inconsistency の再発を防ぐ
- **N2 (検出)**: skill_history.md の冒頭テーブルに cmd_682 関連 10 行を append し、grep `cmd_682` で本 cmd の処理を 1 コマンドで追跡可能
- **N3 (是正)**: cmd_500 未満の候補が全て処理済となり cmd_674 audit 残課題を解消。cmd_680 知見は shogun-gas-* 2 skill に追記され、次回 GAS 認証 cmd で `tokeninfo` / Web App pivot を即座に参照可能

---

## 7. 完了報告 (next step)

```bash
git add skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md \
        skills/shogun-gas-automated-verification/SKILL.md \
        queue/skill_candidates.yaml \
        memory/skill_history.md \
        output/cmd_682_legacy_audit.md \
        output/cmd_682_skill_legacy_integration.md \
        queue/inbox/ashigaru6.yaml \
        queue/snapshots/ashigaru6_snapshot.yaml \
        queue/reports/ashigaru6_report.yaml
git commit -m "feat(cmd_682): skill 3ヶ月遡及 + cmd_680 GAS知見統合"
git push origin main

bash /home/ubuntu/shogun/scripts/inbox_write.sh karo \
  "【subtask_682_skill_legacy_integration 完了】cmd_682 skill 遡及+GAS認証知見統合完了。commit <hash>。report 確認されたし。" \
  task_completed ashigaru6
```
