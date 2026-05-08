#!/usr/bin/env bash
# ============================================================================
# cmd_678: GitHub repo 同期状況の自動検知 + dashboard 反映
#
# 役割: config/repo_health_targets.yaml に基づき、各 repo の
#       uncommitted long-stale / push漏れ / pull遅れ / divergence /
#       merge conflict / 別branch を検知し、dashboard.md の
#       <!-- REPO_HEALTH:START/END --> 間を原子的に更新する。
#
# 起動: systemd --user timer (repo-health-check.timer) — hourly *:35
#       手動: bash scripts/repo_health_check.sh [--dry-run] [--no-dashboard]
# 出力: logs/repo_health_status.yaml + dashboard.md (REPO_HEALTH section)
# 設計根拠: queue/shogun_to_karo.yaml cmd_678 / scripts/sh_health_check.sh 踏襲
# RACE-001: REPO_HEALTH 境界の中だけを書換える。境界外には触れない。
# ============================================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
CONFIG="$SHOGUN_ROOT/config/repo_health_targets.yaml"
DASHBOARD="$SHOGUN_ROOT/dashboard.md"
LOG_DIR="$SHOGUN_ROOT/logs"
STATUS_OUT="$LOG_DIR/repo_health_status.yaml"
SECTION_OUT="$LOG_DIR/repo_health_section.md"
SCRIPT_LOG="$LOG_DIR/repo_health_check.log"
LOCK_FILE="/tmp/repo_health_check.lock"

DRY_RUN=false
NO_DASHBOARD=false
NO_FETCH=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --no-dashboard) NO_DASHBOARD=true ;;
        --no-fetch) NO_FETCH=true ;;
    esac
done

# 並列実行抑止
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "[repo_health_check] another instance running, exit" | tee -a "$SCRIPT_LOG"
    exit 0
fi

TIMESTAMP_JST=$(bash "$SHOGUN_ROOT/scripts/jst_now.sh")
HOSTNAME_NOW=$(hostname)

mkdir -p "$LOG_DIR"

# ============================================================================
# 集計本体 (python3 + PyYAML + git CLI)
# 出力: $SECTION_OUT (markdown), $STATUS_OUT (yaml)
# ============================================================================
SHOGUN_ROOT_ENV="$SHOGUN_ROOT" \
HOSTNAME_NOW_ENV="$HOSTNAME_NOW" \
TIMESTAMP_JST_ENV="$TIMESTAMP_JST" \
SECTION_OUT_ENV="$SECTION_OUT" \
STATUS_OUT_ENV="$STATUS_OUT" \
CONFIG_ENV="$CONFIG" \
NO_FETCH_ENV="$NO_FETCH" \
python3 <<'PYEOF'
import os, sys, time, subprocess, datetime, traceback
import yaml

SHOGUN_ROOT = os.environ["SHOGUN_ROOT_ENV"]
HOSTNAME_NOW = os.environ["HOSTNAME_NOW_ENV"]
TIMESTAMP_JST = os.environ["TIMESTAMP_JST_ENV"]
SECTION_OUT = os.environ["SECTION_OUT_ENV"]
STATUS_OUT = os.environ["STATUS_OUT_ENV"]
CONFIG = os.environ["CONFIG_ENV"]
NO_FETCH = os.environ.get("NO_FETCH_ENV", "false") == "true"

NOW = time.time()


def load_config():
    with open(CONFIG, "r") as f:
        return yaml.safe_load(f)


def run_git(repo_path, args, timeout=30):
    """git コマンドを repo_path で実行。 (returncode, stdout, stderr) を返す。"""
    try:
        result = subprocess.run(
            ["git", "-C", repo_path] + args,
            capture_output=True, text=True, timeout=timeout
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except Exception as e:
        return 1, "", str(e)[:200]


def fmt_age(seconds):
    if seconds is None or seconds < 0:
        return "-"
    if seconds < 60:
        return f"{int(seconds)}s"
    if seconds < 3600:
        return f"{int(seconds / 60)}m"
    if seconds < 86400:
        return f"{seconds / 3600:.1f}h"
    return f"{seconds / 86400:.1f}d"


def evaluate_repo(t, defaults):
    """1 repo を評価し dict を返す。
    フィールド: name / path / branch / uncommitted_count / oldest_uncommitted_age /
    ahead / behind / divergence / conflict / status / anomalies / last_error"""
    name = t["name"]
    path = t["path"]
    expected_branch = t.get("expected_branch", "main")
    host_guard = t.get("host_guard", "")
    fetch_remote = t.get("fetch_remote", True) and not NO_FETCH
    remote = t.get("remote", "origin")

    base = {
        "name": name, "path": path, "branch": "?",
        "uncommitted_count": 0, "oldest_uncommitted_age": None,
        "ahead": 0, "behind": 0,
        "divergence": False, "conflict": False, "branch_mismatch": False,
        "status": "skip", "anomalies": [], "last_error": "",
    }

    # host_guard
    if host_guard and host_guard != HOSTNAME_NOW:
        base["status"] = "skip"
        base["last_error"] = f"host_guard mismatch ({host_guard})"
        return base

    # repo パス確認
    if not os.path.isdir(path):
        base["status"] = "red"
        base["last_error"] = f"path not found: {path}"
        base["anomalies"].append("path_missing")
        return base

    rc, _, _ = run_git(path, ["rev-parse", "--git-dir"])
    if rc != 0:
        base["status"] = "red"
        base["last_error"] = "not a git repository"
        base["anomalies"].append("not_a_repo")
        return base

    # 現在 branch
    rc, out, err = run_git(path, ["rev-parse", "--abbrev-ref", "HEAD"])
    branch = out.strip() if rc == 0 else "?"
    base["branch"] = branch
    if branch != expected_branch:
        base["branch_mismatch"] = True
        base["anomalies"].append(f"branch={branch}≠{expected_branch}")

    # uncommitted (porcelain)
    rc, out, err = run_git(path, ["status", "--porcelain=v1"])
    if rc != 0:
        base["last_error"] = (err or "git status failed")[:120]
        base["status"] = "red"
        base["anomalies"].append("status_failed")
        return base

    porcelain_lines = [l for l in out.splitlines() if l.strip()]
    base["uncommitted_count"] = len(porcelain_lines)

    # conflict 検出 (UU / AA / DD / AU / UA / DU / UD prefix)
    conflict_prefixes = ("UU", "AA", "DD", "AU", "UA", "DU", "UD")
    for line in porcelain_lines:
        head = line[:2]
        if head in conflict_prefixes:
            base["conflict"] = True
            break
    if base["conflict"]:
        base["anomalies"].append("merge_conflict")

    # uncommitted の最古 mtime (track 対象ファイルのみ)
    oldest_age = None
    for line in porcelain_lines:
        # porcelain v1: 各行 "XY filename" / 改名は "XY orig -> new"
        rest = line[3:]
        if " -> " in rest:
            rest = rest.split(" -> ", 1)[1]
        # quoted path 対応 (簡易): " で囲まれていれば剥がす
        rest = rest.strip()
        if rest.startswith('"') and rest.endswith('"'):
            rest = rest[1:-1]
        full = os.path.join(path, rest)
        if os.path.exists(full):
            try:
                mt = os.path.getmtime(full)
                age = NOW - mt
                if oldest_age is None or age > oldest_age:
                    oldest_age = age
            except OSError:
                pass
    base["oldest_uncommitted_age"] = oldest_age

    # fetch (失敗してもローカル評価は続行)
    fetch_failed = False
    if fetch_remote:
        rc, _, ferr = run_git(
            path, ["fetch", remote, "--prune"],
            timeout=defaults.get("fetch_timeout", 30)
        )
        if rc != 0:
            fetch_failed = True
            base["anomalies"].append("fetch_failed")
            if not base["last_error"]:
                base["last_error"] = (ferr or "fetch failed")[:120]

    # ahead / behind (upstream は origin/expected_branch を優先)
    ab_ref = f"{remote}/{expected_branch}"
    rc, out, _ = run_git(path, ["rev-list", "--left-right", "--count", f"HEAD...{ab_ref}"])
    if rc == 0 and out.strip():
        try:
            ahead_str, behind_str = out.split()
            base["ahead"] = int(ahead_str)
            base["behind"] = int(behind_str)
        except Exception:
            pass
    else:
        # upstream 不明の場合は upstream@{u} で再試行
        rc2, out2, _ = run_git(path, ["rev-list", "--left-right", "--count", "HEAD...@{u}"])
        if rc2 == 0 and out2.strip():
            try:
                ahead_str, behind_str = out2.split()
                base["ahead"] = int(ahead_str)
                base["behind"] = int(behind_str)
            except Exception:
                pass
        else:
            base["anomalies"].append("upstream_unknown")

    # divergence: ahead > 0 AND behind > 0
    if base["ahead"] > 0 and base["behind"] > 0:
        base["divergence"] = True
        base["anomalies"].append("divergence")

    # status 判定
    status = "green"

    # 致命的 (red): conflict / divergence / branch_mismatch / push大量未済
    if base["conflict"]:
        status = "red"
    elif base["divergence"]:
        status = "red"
    elif base["branch_mismatch"]:
        status = "red"
    elif base["ahead"] >= defaults.get("ahead_red_after", 5):
        status = "red"
    elif base["behind"] >= defaults.get("behind_red_after", 10):
        status = "red"
    elif base["uncommitted_count"] >= defaults.get("uncommitted_count_red", 30):
        status = "red"
    elif oldest_age is not None and oldest_age >= defaults.get("uncommitted_red_after", 21600):
        status = "red"

    # 警告 (yellow)
    if status == "green":
        if base["ahead"] >= defaults.get("ahead_yellow_after", 1):
            status = "yellow"
            base["anomalies"].append(f"ahead={base['ahead']}")
        elif base["behind"] >= defaults.get("behind_yellow_after", 1):
            status = "yellow"
            base["anomalies"].append(f"behind={base['behind']}")
        elif base["uncommitted_count"] >= defaults.get("uncommitted_count_yellow", 5):
            status = "yellow"
            base["anomalies"].append(f"uncommitted={base['uncommitted_count']}")
        elif oldest_age is not None and oldest_age >= defaults.get("uncommitted_yellow_after", 3600):
            status = "yellow"
            base["anomalies"].append(f"oldest_age={fmt_age(oldest_age)}")
        elif fetch_failed:
            status = "yellow"

    # red の anomaly 追記 (まだ追加されていなければ)
    if status == "red":
        if base["conflict"] and "merge_conflict" not in base["anomalies"]:
            base["anomalies"].append("merge_conflict")
        if base["ahead"] >= defaults.get("ahead_red_after", 5):
            base["anomalies"].append(f"ahead={base['ahead']}_critical")
        if base["uncommitted_count"] >= defaults.get("uncommitted_count_red", 30):
            base["anomalies"].append(f"uncommitted={base['uncommitted_count']}_critical")
        if oldest_age is not None and oldest_age >= defaults.get("uncommitted_red_after", 21600):
            base["anomalies"].append(f"stale={fmt_age(oldest_age)}_critical")

    base["status"] = status
    return base


def main():
    cfg = load_config()
    defaults = cfg.get("defaults", {})
    targets = cfg.get("targets", [])

    results = []
    for t in targets:
        try:
            r = evaluate_repo(t, defaults)
        except Exception as e:
            r = {
                "name": t.get("name", "?"), "path": t.get("path", ""),
                "branch": "?", "uncommitted_count": 0, "oldest_uncommitted_age": None,
                "ahead": 0, "behind": 0, "divergence": False, "conflict": False,
                "branch_mismatch": False, "status": "red",
                "anomalies": ["exception"], "last_error": str(e)[:120],
            }
        results.append(r)

    counts = {"green": 0, "yellow": 0, "red": 0, "skip": 0}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1

    # markdown 生成 (境界マーカー間の本体のみ)
    lines = []
    lines.append("## 📊 repo 同期状況")
    lines.append("")
    monitored = len(results) - counts["skip"]
    lines.append(f"最終確認: {TIMESTAMP_JST} / 監視対象 = {monitored} repo / 自動修正なし (警告のみ)")
    lines.append("")
    lines.append("### サマリー")
    lines.append(f"- 🟢 健全: {counts['green']}")
    lines.append(f"- 🟡 警告: {counts['yellow']}")
    lines.append(f"- 🔴 異常: {counts['red']}")
    if counts["skip"]:
        lines.append(f"- ⏭️  除外 (host_guard等): {counts['skip']}")
    lines.append("")

    # 全 repo 一覧 (常時表示 — 件数少ないので折りたたまず)
    lines.append("| repo | branch | uncommitted | 最古変更 | ahead | behind | 異常項目 | status |")
    lines.append("|------|--------|------------|---------|-------|--------|---------|--------|")
    for r in results:
        emoji = {"green": "🟢", "yellow": "🟡", "red": "🔴", "skip": "⏭️"}.get(r["status"], "?")
        anomalies = ", ".join(r.get("anomalies", [])) or "-"
        anomalies = anomalies.replace("|", "\\|")[:60]
        lines.append(
            f"| {r['name']} | {r['branch']} | {r['uncommitted_count']} | "
            f"{fmt_age(r.get('oldest_uncommitted_age'))} | {r['ahead']} | {r['behind']} | "
            f"{anomalies} | {emoji} {r['status']} |"
        )
    lines.append("")

    # 異常詳細 (last_error)
    red_rows = [r for r in results if r["status"] == "red"]
    if red_rows:
        lines.append("### 🔴 異常詳細")
        lines.append("")
        for r in red_rows:
            err = (r.get("last_error") or "-").replace("|", "\\|")[:160]
            lines.append(f"- `{r['name']}` — {err}")
        lines.append("")

    section_md = "\n".join(lines)
    with open(SECTION_OUT, "w") as f:
        f.write(section_md)

    # YAML status
    status_doc = {
        "timestamp": TIMESTAMP_JST,
        "hostname": HOSTNAME_NOW,
        "summary": counts,
        "total_targets": len(results),
        "results": results,
    }
    with open(STATUS_OUT, "w") as f:
        yaml.safe_dump(status_doc, f, allow_unicode=True, sort_keys=False, width=160)

    print(
        f"repo_health_check OK — green={counts['green']} yellow={counts['yellow']} "
        f"red={counts['red']} skip={counts['skip']}"
    )


if __name__ == "__main__":
    main()
PYEOF

PY_RC=$?
if [ $PY_RC -ne 0 ]; then
    echo "[$TIMESTAMP_JST] python evaluation failed (rc=$PY_RC)" >> "$SCRIPT_LOG"
    exit $PY_RC
fi

# ============================================================================
# dashboard.md の <!-- REPO_HEALTH:START/END --> 間を原子的更新
# ============================================================================
if [ "$NO_DASHBOARD" = "true" ] || [ "$DRY_RUN" = "true" ]; then
    echo "[$TIMESTAMP_JST] dry-run / no-dashboard mode, skip dashboard update" >> "$SCRIPT_LOG"
    cat "$SECTION_OUT"
    exit 0
fi

if [ ! -f "$DASHBOARD" ]; then
    echo "[$TIMESTAMP_JST] dashboard.md not found: $DASHBOARD" >> "$SCRIPT_LOG"
    exit 1
fi

if ! grep -q "<!-- REPO_HEALTH:START -->" "$DASHBOARD"; then
    echo "[$TIMESTAMP_JST] REPO_HEALTH markers not found in dashboard, skip update" >> "$SCRIPT_LOG"
    exit 0
fi

DASHBOARD_ENV="$DASHBOARD" SECTION_OUT_ENV="$SECTION_OUT" python3 <<'PYEOF2'
import os, tempfile
dashboard = os.environ["DASHBOARD_ENV"]
section_path = os.environ["SECTION_OUT_ENV"]

with open(dashboard, "r") as f:
    content = f.read()
with open(section_path, "r") as f:
    section = f.read().rstrip("\n")

START = "<!-- REPO_HEALTH:START -->"
END = "<!-- REPO_HEALTH:END -->"
si = content.find(START)
ei = content.find(END)
if si < 0 or ei < 0 or ei < si:
    raise SystemExit("REPO_HEALTH markers malformed")

new_block = f"{START}\n{section}\n{END}"
new = content[:si] + new_block + content[ei + len(END):]

d = os.path.dirname(dashboard)
fd, tmp = tempfile.mkstemp(prefix=".dashboard.", suffix=".tmp", dir=d)
try:
    with os.fdopen(fd, "w") as f:
        f.write(new)
    os.replace(tmp, dashboard)
except Exception:
    if os.path.exists(tmp):
        os.unlink(tmp)
    raise
print(f"dashboard updated: {dashboard}")
PYEOF2

PY_RC=$?
if [ $PY_RC -ne 0 ]; then
    echo "[$TIMESTAMP_JST] dashboard atomic update failed (rc=$PY_RC)" >> "$SCRIPT_LOG"
    exit $PY_RC
fi

echo "[$TIMESTAMP_JST] repo_health_check completed" >> "$SCRIPT_LOG"
exit 0
