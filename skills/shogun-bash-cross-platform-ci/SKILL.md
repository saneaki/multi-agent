---
name: shogun-bash-cross-platform-ci
description: bash script の Linux+macOS CI 両対応パターン集。flock BSD fallback / sed -i 互換 / python3 .venv 優先解決 / hostname guard opt-in / SHOGUN_ROOT self-resolve の 5 カテゴリ。BSD macOS CI cross-platform bash flock sed -i hostname python3 BASH_SOURCE で起動。
---

# shogun-bash-cross-platform-ci

## North Star

Linux(Ubuntu CI)と macOS(CI / 開発者環境)の両対応 bash script を書くための再利用可能パターン集。
cmd_532 Phase B で 14 テスト失敗(Linux 6 + macOS 8)を根治した知見を昇華したもの。
同種ミスで再び「macOS だけ失敗」「CI でパス解決ミス」に陥らないための一次対処集。

**Trigger**: 「macOS CI でだけ落ちる」「bats test が macOS で flock not found」
「sed -i で BSD/GNU エラー」「python3 で PyYAML not found」「hostname guard で CI が早期 exit」

**Scope**: bash 4.x+, Ubuntu 22.04+, macOS 13+(arm64/x86_64)。Windows/PowerShell は対象外。

**参照**: `output/cmd_532_macos_compatibility_report.md` (14 失敗分類表)

---

## 5 カテゴリ一覧(早見表)

| Cat | 問題 | 影響テスト | Fix 複雑度 | 頻度 |
|-----|------|-----------|-----------|------|
| A | SHOGUN_ROOT ハードコード | T-IR1-022/023 | 低(1 行) | 高(新規 script 全件) |
| B | `flock` コマンド非存在(macOS) | T-IR1-022/023 | 中(20 行) | 中(排他 lock 使用箇所) |
| C | `sed -i` BSD/GNU 引数差 | T-DT-001/003 | 低(4 行) | 高(sed -i 使用箇所全件) |
| D | system `python3` に PyYAML 欠落 | T-IR1-006/014/016/019-021 | 低(12 行) | 中(python3 依存 hook) |
| E | hostname guard で CI 早期 exit | T-ACK-001/003/004/008 | 低(1 行) | 低(ntfy リスナー系) |

---

## Category A: SHOGUN_ROOT self-resolve

### Problem

`SHOGUN_ROOT="/home/ubuntu/shogun"` のようにパスをハードコードすると、
macOS CI / 別ディレクトリへのクローンで script がプロジェクト外のパスを参照して失敗する。

- 失敗テスト: `T-IR1-022`, `T-IR1-023`
- 症状: `[ERROR] violation log not found` — ファイルが CI パスに書かれず assertion 失敗
- 発生環境: macOS CI runner(パスは `/Users/runner/work/...`)

### Detection

```bash
grep -r 'SHOGUN_ROOT="/home/ubuntu' scripts/
```

再現: `__IR1_SHOGUN_ROOT=/tmp/fake bats tests/unit/test_ir1.bats`

### Fix

`BASH_SOURCE[0]` を使ってスクリプト自身の位置からルートを自己解決する。

```bash
# Before
SHOGUN_ROOT="/home/ubuntu/shogun"

# After — BASH_SOURCE[0] は source 経由でも呼び出し元ファイルパスを指す
SHOGUN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

> commit 992e155 — `scripts/log_violation.sh` L13

**注意**: macOS の `/usr/bin/readlink` は `-f` 非対応。`cd + pwd` が最高移植性。
`realpath` も macOS では `brew install coreutils` 依存のため本番 script では使わない。

### Verification

```bash
bats tests/unit/test_ir1.bats
# CI matrix: ubuntu-latest + macos-latest 両 PASS
```

---

## Category B: flock BSD fallback (mkdir mutex)

### Problem

Linux では `flock(1)` が標準で存在するが、macOS にはデフォルトで存在しない。
`flock -w 5 200 || exit 1` が macOS で `flock: command not found` → `set -e` により exit。

- 失敗テスト: `T-IR1-022`, `T-IR1-023`
- 症状: `command not found: flock` → `exit 1` → lock ブロック内の処理が未実行
- 発生環境: macOS CI(flock は Homebrew util-linux で提供されるが非標準)

### Detection

```bash
command -v flock >/dev/null 2>&1 && echo "GNU flock available" || echo "BSD/macOS: flock unavailable"
```

CI log: `grep 'flock: command not found' /path/to/runner.log`

### Fix

`command -v flock` で可用性を確認し、非存在時は `mkdir` ベースのスピンロックに fallback。

```bash
_critical_section() { : ; }  # critical section をここに実装

if command -v flock >/dev/null 2>&1; then
    (
        flock -w 5 200 || { echo "Failed to acquire lock" >&2; exit 1; }
        _critical_section
    ) 200>"$LOCKFILE"
else
    # macOS fallback: mkdir は POSIX 原子操作(失敗時に既存 dir を変えない)
    _ld="${LOCKFILE}.d"
    _i=0
    while ! mkdir "$_ld" 2>/dev/null; do
        sleep 0.1
        _i=$((_i+1))
        [ $_i -ge 50 ] && { echo "Failed to acquire lock" >&2; exit 1; }
    done
    trap 'rmdir "$_ld" 2>/dev/null' EXIT
    _critical_section
fi
```

> commit 8d4ee94 — `scripts/log_violation.sh` L34-61

- `mkdir` は POSIX 原子操作。sleep 0.1×50 = 最大 5 秒(flock -w 5 相当)
- `trap EXIT` で lock ディレクトリのクリーンアップを保証
- `brew install util-linux` / `lockf` は却下(CI 依存追加 / macOS 固有)

### Verification

```bash
bats tests/unit/test_ir1.bats
# ubuntu-latest(flock あり) + macos-latest(flock なし) 両 PASS
```

---

## Category C: sed -i 互換(BSD vs GNU)

### Problem

GNU sed の `sed -i "s/foo/bar/"` は macOS の BSD sed では構文エラー。
BSD sed では `-i` の直後に extension 引数(空文字でも可)が必須。

- 失敗テスト: `T-DT-001`, `T-DT-003`
- 症状: `sed: 1: "...": extra characters at the end of s command`
- 発生環境: macOS(BSD sed `/usr/bin/sed`)

### Detection

```bash
sed --version >/dev/null 2>&1 && echo "GNU sed" || echo "BSD sed (macOS)"
```

CI log: `grep 'extra characters' runner.log`

### Fix

`sed --version` の exit code で GNU/BSD を分岐する。

```bash
# Before
sed -i "s|^最終更新:.*|最終更新: $JST_NOW|" "$DASHBOARD"

# After — macOS BSD sed / GNU sed 両対応
if sed --version >/dev/null 2>&1; then
    sed -i   "s|^最終更新:.*|最終更新: $JST_NOW|" "$DASHBOARD"  # GNU
else
    sed -i '' "s|^最終更新:.*|最終更新: $JST_NOW|" "$DASHBOARD"  # BSD
fi
```

> commit 992e155 — `scripts/update_dashboard_timestamp.sh` L31-41

`sed --version` は GNU sed のみ exit 0 を返す。BSD sed は `--version` 非対応で exit 1。

**汎用ヘルパー**:
```bash
_sed_inplace() { local p="$1" f="$2"
    if sed --version >/dev/null 2>&1; then sed -i "$p" "$f"; else sed -i '' "$p" "$f"; fi; }
```

### Verification

```bash
bats tests/unit/test_dashboard_timestamp.bats
# ubuntu-latest(GNU sed) + macos-latest(BSD sed) 両 PASS
```

---

## Category D: python3 / .venv 優先解決

### Problem

macOS の CI runner では system `python3` に PyYAML が入っていない。
`python3 -c "import yaml"` が `ModuleNotFoundError` → hook が ERROR で素通りする。
PATH 優先順位の問題でプロジェクト内 `.venv/bin/python3` が選ばれない。

- 失敗テスト: `T-IR1-006`, `T-IR1-014`, `T-IR1-016`, `T-IR1-019`, `T-IR1-020`, `T-IR1-021`
- 症状: `ModuleNotFoundError: No module named 'yaml'` → hook が無音で失敗
- 発生環境: macOS runner(`/usr/bin/python3` に PyYAML 欠落)

### Detection

```bash
python3 -c "import yaml" 2>&1 || echo "PyYAML missing"
.venv/bin/python3 -c "import yaml" && echo "venv OK"
```

### Fix

Python バイナリを優先順で解決する: (1)テスト override → (2)`.venv` → (3)system。

```bash
# Resolve python3: 1=test-override 2=.venv 3=system
_HOOK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -n "${__IR1_PYTHON_BIN:-}" ]; then
    PYTHON_BIN="$__IR1_PYTHON_BIN"
elif [ -x "${_HOOK_ROOT}/.venv/bin/python3" ]; then
    PYTHON_BIN="${_HOOK_ROOT}/.venv/bin/python3"
else
    PYTHON_BIN="python3"
fi

EDITABLE_RESULT=$("$PYTHON_BIN" -c "...")
```

> commit 992e155 — `scripts/hooks/ir1_editable_files_check.sh` L19-32

- `[ -x ... ]` で存在 + 実行可能を確認(broken venv 対応)
- PATH への `.venv/bin` 追加は避ける(他 script への副作用を防ぐ)
- bats 内上書き: `export __IR1_PYTHON_BIN=".venv/bin/python3"`

### Verification

```bash
__IR1_PYTHON_BIN=".venv/bin/python3" bats tests/unit/test_ir1.bats
# ubuntu-latest + macos-latest 両 PASS(.venv が setup-python で準備済みであること前提)
```

---

## Category E: hostname guard opt-in

### Problem

`ntfy_listener.sh` が `$(hostname)` と VPS 名を比較し、不一致なら即 `exit 0` する。
CI runner の hostname は VPS と一致しないため、リスナーが一切動作せずテストが全失敗。
macOS では `hostname` が `macbook.local` 等の FQDN になり、さらに不一致が起きやすい。

- 失敗テスト: `T-ACK-001`, `T-ACK-003`, `T-ACK-004`, `T-ACK-008`
- 症状: 起動直後に exit → inbox に応答が書かれない → assertion timeout

### Detection

```bash
hostname  # CI では fv-az... 等、VPS 名と不一致
NTFY_SKIP_HOST_CHECK=0 timeout 2 bash scripts/ntfy_listener.sh 2>&1 | head
```

### Fix

`NTFY_SKIP_HOST_CHECK=1` 環境変数で guard をバイパスできる opt-in を追加する。

```bash
# Before
if [ "$(hostname)" != "$NTFY_ALLOWED_HOST" ]; then exit 0; fi

# After — NTFY_SKIP_HOST_CHECK=1 で CI から回避可能
if [ "${NTFY_SKIP_HOST_CHECK:-0}" != "1" ] && [ "$(hostname)" != "$NTFY_ALLOWED_HOST" ]; then
    echo "ホスト名が一致しません..." >&2; exit 0
fi
```

> commit 992e155 — `scripts/ntfy_listener.sh` L15-20

opt-in 方式(デフォルト 0): 本番は何も変えずに guard が有効のまま。

### Verification

```bash
NTFY_SKIP_HOST_CHECK=1 bats tests/unit/test_ntfy_ack.bats
# ubuntu-latest + macos-latest 両 PASS
```

---

## 共通チェックリスト(新規 script 作成時)

新規 bash script を書く前に以下 6 問を確認せよ。

| # | 問診 | 対処パターン |
|---|------|-------------|
| 1 | PATH をハードコードしていないか? | Cat A: `BASH_SOURCE[0]` で self-resolve |
| 2 | `flock` を使うか? | Cat B: `command -v flock` で分岐、fallback は `mkdir` mutex |
| 3 | `sed -i` を使うか? | Cat C: `sed --version` で GNU/BSD 分岐 |
| 4 | `python3` を直接呼ぶか? | Cat D: `.venv/bin/python3` 優先解決 |
| 5 | hostname/環境固有チェックがあるか? | Cat E: `OPT_IN=1` 環境変数で CI 迂回 |
| 6 | `set -euo pipefail` との組み合わせは? | コマンド失敗の exit code に注意。`flock` / `command -v` は要確認 |

**追加アンチパターン**:
- `grep -P`: macOS BSD grep は PCRE 非対応。`grep -E`(ERE)で代替
- `date -d`: BSD `date` 非対応。日時計算は `jst_now.sh` 経由に統一
- `readlink -f`: macOS 非対応。`cd + pwd` パターンを使う(Cat A 参照)

---

## References

| 種別 | 内容 | ID |
|------|------|----|
| commit | Phase B 主要修正(Cat A/C/D/E) | `992e155` |
| commit | Phase B flock fallback(Cat B) | `8d4ee94` |
| report | macOS 互換性分析(14 失敗分類表) | `output/cmd_532_macos_compatibility_report.md` |
| issue | CI main branch 4 連続失敗 | `#31` |
| cmd | CI 復旧 Phase B | `cmd_532` |
| test | IR1 / flock / python3 venv テスト | `tests/unit/test_ir1.bats` |
| test | ACK リスナーテスト | `tests/unit/test_ntfy_ack.bats` |
| test | sed タイムスタンプテスト | `tests/unit/test_dashboard_timestamp.bats` |
