---
name: github-actions-release-please-workflow-permissions
description: >
  [English] Use when release-please-action fails to create PRs despite correct workflow YAML
  permissions. The fix requires both workflow-level permissions AND repo-level "workflow
  permissions: write + allow creating PRs" in GitHub repository settings.
  [日本語] release-please-action が workflow YAML に permissions を設定しているのに PR 作成で失敗する時に使用。
  workflow YAML の設定に加え、リポジトリ設定での repo-level 権限変更が必要。
tags: [github-actions, release-please, permissions, pr-creation, repository-settings]
---

# release-please-action Workflow Permissions

`release-please-action` が PR 作成に失敗する場合、workflow YAML の `permissions` 設定だけでは不足で
リポジトリ設定の repo-level workflow permissions も変更が必要な2段階対処パターン。

## Problem Statement

```
Error: HttpError: Resource not accessible by integration
  at /home/runner/work/_actions/googleapis/release-please-action/...
```

`release-please-action` が Release PR の作成・更新に失敗する。

## Root Cause: 2段階の権限が必要

| 層 | 設定箇所 | 必要な設定 |
|----|---------|------------|
| workflow YAML | `.github/workflows/*.yml` | `permissions: contents: write, pull-requests: write` |
| repo-level | Settings > Actions > General > Workflow permissions | **Read and write permissions** + **Allow GitHub Actions to create and approve pull requests** |

**workflow YAML だけ設定しても repo-level がデフォルト (read-only) のままだと PR 作成が失敗する。**

## Fix

### Step 1: workflow YAML に permissions を追加

```yaml
permissions:
  contents: write
  pull-requests: write
```

### Step 2: リポジトリ設定を変更 (手動)

GitHub リポジトリ > Settings > Actions > General > Workflow permissions:
1. **Read and write permissions** を選択
2. **Allow GitHub Actions to create and approve pull requests** にチェック
3. Save

### Step 2 (自動化): gh CLI で変更

```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/{owner}/{repo}/actions/permissions/workflow \
  -f default_workflow_permissions='write' \
  -f can_approve_pull_request_reviews=true
```

複数リポジトリに一括適用する場合:

```bash
repos=("owner/repo1" "owner/repo2")
for repo in "${repos[@]}"; do
  gh api --method PUT \
    /repos/${repo}/actions/permissions/workflow \
    -f default_workflow_permissions='write' \
    -f can_approve_pull_request_reviews=true
  echo "Updated: $repo"
done
```

## 確認方法

```bash
gh api /repos/{owner}/{repo}/actions/permissions/workflow
# → {"default_workflow_permissions":"write","can_approve_pull_request_reviews":true}
```

## よくある落とし穴

| 症状 | 原因 | 対処 |
|------|------|------|
| workflow YAML 修正後も同じエラー | repo-level が変更されていない | Settings > Actions > General を確認 |
| Organization repo で設定できない | Org-level で強制 read-only | Org settings > Actions > General で override 許可が必要 |
| Fine-grained PAT 使用時 | PAT の権限が不足 | PAT に `pull_requests: write`, `contents: write` 権限追加 |

## Battle-Tested Examples

| cmd | Situation | Result |
|-----|-----------|--------|
| cmd_690 A-3 | release-please-action PR 作成 403 エラー | repo-level permissions 変更で解決 |

## Related Skills

- `github-actions-release-artifact` — GHA Release job, GITHUB_TOKEN の `contents: write` 設定
- `github-release-version-migration` — GitHub Release バージョン管理

## Source

- cmd_690 A-3: ash7 調査。workflow YAML 設定済みでも repo-level permissions が原因と判明
