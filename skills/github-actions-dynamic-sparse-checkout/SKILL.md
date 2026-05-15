---
name: github-actions-dynamic-sparse-checkout
description: >
  [English] Use when GitHub Actions checkout fails with disk exhaustion or OOM on a large
  monorepo. Covers dynamic sparse-checkout using runtime data (mapping CSV, config files)
  to pull only the required subdirectories, fixing disk/checkout failures in CI.
  [日本語] 巨大リポジトリで GHA checkout がディスク枯渇・OOM で失敗する時に使用。
  実行時データ (mapping CSV 等) から sparse-checkout パスを動的生成してリカバリする手順。
tags: [github-actions, sparse-checkout, disk-space, large-repo, checkout, ci]
---

# GitHub Actions Dynamic Sparse-Checkout

巨大 repo の GHA checkout がディスク枯渇・OOM で失敗する場合に、
実行時データ (mapping CSV 等) から sparse-checkout 対象パスを動的に生成して修復するパターン。

## Problem Statement

- `actions/checkout` でディスク不足エラー (`No space left on device`) または OOM
- Runner の disk quota が repo 全体のサイズを下回る
- 実行時に必要なサブディレクトリが動的に決まる (mapping CSV 等から生成)

## Solution: Dynamic Sparse-Checkout

### Step 1: `actions/checkout` に sparse-checkout オプションを付加

```yaml
- uses: actions/checkout@v4
  with:
    sparse-checkout: |
      src/
      scripts/
    sparse-checkout-cone-mode: true
```

cone-mode = true で `src/` 以下の全ファイルを取得。パスリストは改行区切り。

### Step 2: 実行時データから動的にパスリストを生成する場合

```yaml
- name: Generate sparse-checkout paths
  run: |
    # mapping.csv の第2列からディレクトリリストを生成
    python3 - <<'EOF'
    import csv, sys
    paths = set()
    with open("mapping.csv") as f:
        for row in csv.reader(f):
            if len(row) >= 2:
                paths.add(row[1].split("/")[0] + "/")
    print("\n".join(sorted(paths)))
    EOF

- uses: actions/checkout@v4
  with:
    sparse-checkout-cone-mode: true
    # または後段で git sparse-checkout add を使う
```

### Step 3: 後段で `git sparse-checkout add` を使う方法 (checkout 後に追加)

```bash
git sparse-checkout init --cone
# mapping.csv からパスを読んで追加
python3 -c "
import csv
paths = set()
with open('mapping.csv') as f:
    for row in csv.reader(f):
        if len(row) >= 2:
            paths.add(row[1].rsplit('/', 1)[0])
for p in sorted(paths):
    print(p)
" | xargs -I{} git sparse-checkout add {}
```

## Disk Space 追加節約

```yaml
- name: Free up disk space
  run: |
    sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc
    df -h
```

checkout 前に不要な大容量パッケージを削除すると数GB確保できる。

## よくある落とし穴

| 症状 | 原因 | 対処 |
|------|------|------|
| sparse-checkout 後もファイルが存在しない | cone-mode で parent dir 指定ミス | 末尾 `/` を含める |
| `.github/` が取得できない | sparse-checkout 対象に含まれていない | `.github/` を明示追加 |
| 動的パス生成後に古いスパースリストが残る | `git sparse-checkout set` で上書きすべきところを `add` のみ | `set` で全リセットしてから `add` |

## Battle-Tested Examples

| cmd | Situation | Result |
|-----|-----------|--------|
| cmd_652 | 巨大 repo GHA disk failure 初発 | sparse-checkout 導入でリカバリ |
| cmd_690 | 同一 repo で再発 (mapping CSV 変更後) | 動的パス生成ロジック追加 |
| cmd_691 | A-2: さらに再発 → 汎用化 | runtime data driven sparse-checkout pattern 確立 |

## Related Skills

- `github-actions-release-artifact` — GHA Release job と artifact upload/download パターン
- `github-actions-docs-check-template` — GHA docs 検証テンプレート

## Source

- cmd_652: GHA disk failure 初発・sparse-checkout 初適用
- cmd_690 A-2: 再発時の動的パス生成対応
- cmd_691: 汎用化・battle-tested 確立
