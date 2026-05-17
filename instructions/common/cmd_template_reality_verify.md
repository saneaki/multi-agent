# cmd Template: reality_verify_step Default Inclusion

deploy / push / runtime 反映を要する cmd を起案する際、`acceptance_criteria` に **必ず `reality_verify_step` を含めること**。これは `instructions/gunshi.md §L022` (Reality Verification Rule) の必須要件である。

このテンプレートは将軍 (cmd 起案者) と家老 (task 分解) と軍師 (QC) の三役で共有する。

---

## 1. Scope (適用 cmd 種別)

以下のいずれかに該当する cmd で reality_verify_step が **必須**:

| カテゴリ | trigger keyword (cmd description / acceptance_criteria に含まれる) |
|---------|----------------------------------------------------------------|
| **clasp / GAS deploy** | `clasp push`, `clasp deploy`, GAS script update, `versionNumber` |
| **git push 系** | `git push`, GHA workflow trigger, branch publish |
| **n8n WF deploy** | n8n workflow activate, WF update via API, scheduled trigger 配備 |
| **Notion / Drive 反映** | Notion DB upsert, page create, Drive file create/update |
| **cron / systemd 配線** | crontab 追加/更新, systemd unit enable, timer 設定 |
| **dashboard / 通知配信** | dashboard.md 更新, ntfy 通知, Google Chat 配信, telegram 配信 |
| **API 外部書込** | REST API POST/PATCH/DELETE で外部 resource 変更 |

該当しない cmd (ローカル refactor / docs 更新 / 設計分析のみ等) では reality_verify_step は不要 (本 template の適用対象外)。

---

## 2. acceptance_criteria 標準テンプレート

### 2.1 clasp / GAS deploy 系

```yaml
acceptance_criteria:
  - id: AC-N
    check: "clasp push 後、`Pushed N files.` を output に明記し、`Skipping push.` のみの場合は再 push する"
  - id: AC-N+1
    check: "reality_verify_step: `clasp pull --rootDir /tmp/clasp_verify_$$` 実行後 `diff -r src/ /tmp/clasp_verify_$$/` が diff=0 であることを output に明記"
  - id: AC-N+2
    check: "reality_verify_step: `clasp versions | head -3` の最新 version 番号が今回 push 後に increment していることを output に明記"
```

### 2.2 git push 系

```yaml
acceptance_criteria:
  - id: AC-N
    check: "git push 後、`git log --oneline -1` の HEAD sha を output に明記"
  - id: AC-N+1
    check: "reality_verify_step: `git ls-remote origin <branch> | awk '{print $1}'` の sha が local HEAD と一致することを output に明記"
  - id: AC-N+2 (GHA trigger 含む場合)
    check: "reality_verify_step: GHA run ID を `gh run list --branch <branch> --limit 1 --json databaseId,conclusion` で取得し `conclusion: success` を output に明記"
```

### 2.3 n8n WF deploy 系

```yaml
acceptance_criteria:
  - id: AC-N
    check: "n8n API で WF update 後、`PUT /api/v1/workflows/{id}` の response status=200 を output に明記"
  - id: AC-N+1
    check: "reality_verify_step: `GET /api/v1/workflows/{id}` で `active: true` + `updatedAt` 更新を output に明記"
  - id: AC-N+2
    check: "reality_verify_step: `POST /api/v1/workflows/{id}/test` で test 実行後、`GET /api/v1/executions/{id}?includeData=true` で `finished: true, status: success` を output に明記"
```

### 2.4 cron / systemd 配線系

```yaml
acceptance_criteria:
  - id: AC-N
    check: "crontab 追加後、`crontab -l | grep '<keyword>'` の出力を output に明記"
  - id: AC-N+1
    check: "reality_verify_step: 次回 cron 実行時刻を待ち、`tail <log_file>` で実発火行 (時刻付き) を output に明記。即時確認不可な場合は karo に「実発火 ends 確認は subtask_XXX で別途」と引継ぎ"
  - id: AC-N+2 (systemd の場合)
    check: "reality_verify_step: `systemctl --user status <unit>` で `Active: active (running)` を output に明記"
```

### 2.5 dashboard / 通知配信系

```yaml
acceptance_criteria:
  - id: AC-N
    check: "dashboard.md 更新後、`git log -1 -- dashboard.md` の commit sha を output に明記"
  - id: AC-N+1 (ntfy / Google Chat / telegram 配信あり)
    check: "reality_verify_step: 配信先 (ntfy 履歴 / Google Chat channel / telegram chat) で実受信痕跡を screenshot or message_id で output に明記"
```

### 2.6 Notion / Drive 反映系

```yaml
acceptance_criteria:
  - id: AC-N
    check: "Notion API page create 後、response の `id` を output に明記"
  - id: AC-N+1
    check: "reality_verify_step: `GET /v1/pages/{id}` で `archived: false` + `last_edited_time` を output に明記"
  - id: AC-N+2 (DB 反映確認が必要な場合)
    check: "reality_verify_step: `POST /v1/databases/{db_id}/query` で filter 一致 page が 1 件以上返ることを output に明記"
```

---

## 3. 軍師 QC 時のチェック手順 (L022 連動)

軍師は QC 開始時に以下を順次判定:

```
Step 1: cmd が §1 Scope に該当するか判定
        → NO の場合: 本 template 適用外。通常 QC を実施。
        → YES の場合 Step 2 へ。

Step 2: task YAML の acceptance_criteria に reality_verify_step (§2 該当節)
        が含まれているか確認
        → 含まれていない場合: QC FAIL
          + karo inbox に「L022 違反: task YAML AC に reality_verify_step
          不足 (本 template §2.X 参照)」を通知。
          + task YAML 設計不備として cmd 起案者 (将軍 or 家老) に AC 補強を要求。
        → 含まれている場合 Step 3 へ。

Step 3: ash 報告 evidence が §2 reality_verify_step を満たすか確認
        → 満たさない場合: QC FAIL
          + ash に再検証要求 (karo 経由)。
        → 満たす場合: QC PASS 候補として通常 QC criteria へ。

Step 4: gunshi_report.yaml の latest.result.reality_verification に
        category / artifact / verdict を記録 (L022 mandatory)。
```

---

## 4. 起案時 checklist (将軍 + 家老共有)

cmd 起案時に以下を確認:

- [ ] cmd description / acceptance_criteria に §1 trigger keyword が含まれていないか確認
- [ ] 含まれている場合、§2 該当節の reality_verify_step を acceptance_criteria に **必ず含める**
- [ ] cmd の `editable_files` / `operational_writes_allowed` に reality verify 用 file path (例: `/tmp/clasp_verify_*`) を含める (必要に応じて)
- [ ] cron / systemd で即時確認不可な場合は、subtask 分割で「means cron 登録」と「ends 実発火確認」を分離する

---

## 5. 例外

以下は本 template 適用免除:

| 例外条件 | 例 | 理由 |
|---------|---|------|
| 完全 dry-run cmd | `--dry-run` flag のみ実行 | 副作用なし、reality 反映自体が不要 |
| local 完結 cmd | docs 更新 / script refactor (実行なし) | remote 反映が AC に含まれない |
| 設計分析 cmd | gunshi 戦略立案 / cmd_decomposition | 成果物が report のみ |
| 既存 reality 監査 cmd | 既存 system の reality check を読み出すだけ | reality verify そのものが目的 |

例外適用時は task YAML の `notes:` に「reality_verify_step 適用免除 (本 template §5 該当)」を明記すること。

---

## 6. Cross-Reference

- **`instructions/gunshi.md §L022`**: Reality Verification Rule (軍師 QC 必須化)
- **`instructions/shogun.md F007`**: 将軍 unverified_report 禁止 (殿報告段の reality verify)
- **`instructions/common/silent_failure_pattern.md §Incident #001`**: cmd_712 clasp push 事案 (本 template の起源)
- **`skills/shogun-silent-failure-audit-pattern/SKILL.md §Incident #6`**: clasp push 系 silent failure pattern
- **`instructions/common/north_star_outcome_check.md`**: north_star outcome 評価 (本 template の上位概念)

---

## 7. 改訂履歴

- 2026-05-17 (cmd_732): 初版作成。cmd_712 clasp push 事案を契機に L022 + 本 template を整備。
