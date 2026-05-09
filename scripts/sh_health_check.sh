#!/usr/bin/env bash
# ============================================================================
# cmd_673 Scope B-D: sh 実行状況 週次集計 + dashboard 更新
#
# 役割: config/sh_health_targets.yaml に基づき、Tier1 sh ファミリの
#       last_run / 7d success / 7d failure / last_error / status を集計し、
#       dashboard.md の <!-- SH_HEALTH:START/END --> 間を原子的に更新する。
#
# 起動: systemd --user timer (sh-health-check.timer) — hourly
#       手動: bash scripts/sh_health_check.sh [--dry-run] [--no-dashboard]
# 出力: logs/sh_health_status.yaml + dashboard.md (SH_HEALTH section)
# 設計根拠: output/cmd_673_scope_a_integrated.md
# ============================================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
CONFIG="$SHOGUN_ROOT/config/sh_health_targets.yaml"
DASHBOARD="$SHOGUN_ROOT/dashboard.md"
LOG_DIR="$SHOGUN_ROOT/logs"
STATUS_OUT="$LOG_DIR/sh_health_status.yaml"
SECTION_OUT="$LOG_DIR/sh_health_section.md"
SCRIPT_LOG="$LOG_DIR/sh_health_check.log"
LOCK_FILE="/tmp/sh_health_check.lock"

DRY_RUN=false
NO_DASHBOARD=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --no-dashboard) NO_DASHBOARD=true ;;
    esac
done

# 並列実行抑止
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "[sh_health_check] another instance running, exit" | tee -a "$SCRIPT_LOG"
    exit 0
fi

TIMESTAMP_JST=$(bash "$SHOGUN_ROOT/scripts/jst_now.sh")
HOSTNAME_NOW=$(hostname)

mkdir -p "$LOG_DIR"

# ============================================================================
# 集計本体 (python3 + PyYAML)
# 出力: $SECTION_OUT (markdown), $STATUS_OUT (yaml)
# ============================================================================
SHOGUN_ROOT_ENV="$SHOGUN_ROOT" \
HOSTNAME_NOW_ENV="$HOSTNAME_NOW" \
TIMESTAMP_JST_ENV="$TIMESTAMP_JST" \
SECTION_OUT_ENV="$SECTION_OUT" \
STATUS_OUT_ENV="$STATUS_OUT" \
CONFIG_ENV="$CONFIG" \
python3 <<'PYEOF'
import os, sys, re, json, time, glob, subprocess, datetime, traceback
import yaml

SHOGUN_ROOT = os.environ["SHOGUN_ROOT_ENV"]
HOSTNAME_NOW = os.environ["HOSTNAME_NOW_ENV"]
TIMESTAMP_JST = os.environ["TIMESTAMP_JST_ENV"]
SECTION_OUT = os.environ["SECTION_OUT_ENV"]
STATUS_OUT = os.environ["STATUS_OUT_ENV"]
CONFIG = os.environ["CONFIG_ENV"]

LOG_DIR = os.path.join(SHOGUN_ROOT, "logs")
NOW = time.time()
WINDOW_SEC = 7 * 86400
TODAY = datetime.date.today().isoformat()


def load_config():
    with open(CONFIG, "r") as f:
        return yaml.safe_load(f)


def resolve_log_path(target, log_field="log"):
    log = target.get(log_field)
    if not log:
        return None
    if target.get("abs_log"):
        return log
    return os.path.join(LOG_DIR, log)


def file_mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


def try_parse_line_ts(line):
    """Extract UTC epoch from common log timestamp formats. Returns float or None."""
    # [Day Mon DD HH:MM:SS UTC YYYY] — inbox_watcher, bash date format
    m = re.match(r'\[(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (\w{3} +\d{1,2} \d{2}:\d{2}:\d{2}) UTC (\d{4})\]', line)
    if m:
        try:
            dt = datetime.datetime.strptime(f"{m.group(1)} {m.group(2)}", "%b %d %H:%M:%S %Y")
            return dt.replace(tzinfo=datetime.timezone.utc).timestamp()
        except Exception:
            pass
    # [YYYY-MM-DD HH:MM:SS] or [YYYY-MM-DDTHH:MM:SS...] — Python/shell logs
    m2 = re.match(r'\[(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})', line)
    if m2:
        try:
            s = m2.group(1).replace('T', ' ')
            dt = datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S")
            return dt.replace(tzinfo=datetime.timezone.utc).timestamp()
        except Exception:
            pass
    return None


def grep_count(path, pattern, since_sec=None, ignore_pat=None, dedupe_lines=False):
    """7 日以内の log から pattern にマッチする行数をカウント。
    since_sec が指定された場合、行のタイムスタンプを解析して 7d window 外の行をスキップ。
    タイムスタンプなしの continuation 行は直前の有効タイムスタンプを継承する。
    直前タイムスタンプも不明な行はスキップしない (安全側に倒す)。"""
    if not path or not os.path.exists(path):
        return 0
    try:
        # fast-path: ファイル自体が 7d より古ければ全スキップ
        mtime = os.path.getmtime(path)
        if since_sec and mtime < since_sec:
            return 0
        # Quick approach: tail -n 5000 lines and grep
        result = subprocess.run(
            ["tail", "-n", "5000", path],
            capture_output=True, text=True, timeout=10
        )
        lines = result.stdout.splitlines()
        regex = re.compile(pattern, re.IGNORECASE)
        ignore_re = re.compile(ignore_pat, re.IGNORECASE) if ignore_pat else None
        count = 0
        last_line_ts = None
        seen = set()
        for line in lines:
            # Timestamp filter: skip lines older than since_sec (7d window)
            if since_sec:
                line_ts = try_parse_line_ts(line)
                if line_ts is not None:
                    last_line_ts = line_ts
                effective_ts = line_ts if line_ts is not None else last_line_ts
                if effective_ts is not None and effective_ts < since_sec:
                    continue
            if regex.search(line):
                if ignore_re and ignore_re.search(line):
                    continue
                if dedupe_lines:
                    dedupe_key = line.strip()
                    if dedupe_key in seen:
                        continue
                    seen.add(dedupe_key)
                count += 1
        return count
    except Exception:
        return 0


def syslog_cron_check(pattern, days=7):
    """/var/log/syslog から CRON 行を検索し、pattern マッチの最新時刻と件数を返す。
    silent_design な sh の cron 起動を syslog で代替検知する。
    return: (latest_epoch or None, count)"""
    try:
        regex = re.compile(r"CRON\[\d+\]:.*" + pattern)
        # syslog のうち最新ファイルのみ参照 (過去ローテーションは無視)
        candidates = ["/var/log/syslog"]
        latest = None
        count = 0
        cutoff = NOW - days * 86400
        for sl in candidates:
            if not os.path.exists(sl) or not os.access(sl, os.R_OK):
                continue
            try:
                with open(sl, "r", errors="replace") as f:
                    for line in f:
                        if regex.search(line):
                            # syslog の timestamp は ISO 8601 (例: 2026-05-08T04:20:02.095347+00:00)
                            m = re.match(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", line)
                            if m:
                                try:
                                    dt = datetime.datetime.strptime(m.group(1), "%Y-%m-%dT%H:%M:%S")
                                    epoch = dt.replace(tzinfo=datetime.timezone.utc).timestamp()
                                    if epoch < cutoff:
                                        continue
                                    count += 1
                                    if latest is None or epoch > latest:
                                        latest = epoch
                                except Exception:
                                    pass
            except Exception:
                pass
        return latest, count
    except Exception:
        return None, 0


def grep_last_error(path, pattern, ignore_pat=None, since_sec=None):
    if not path or not os.path.exists(path):
        return ""
    try:
        result = subprocess.run(
            ["tail", "-n", "500", path],
            capture_output=True, text=True, timeout=10
        )
        lines = result.stdout.splitlines()
        regex = re.compile(pattern, re.IGNORECASE)
        ignore_re = re.compile(ignore_pat, re.IGNORECASE) if ignore_pat else None
        line_ts_cache = []
        last_line_ts = None
        for line in lines:
            line_ts = try_parse_line_ts(line)
            if line_ts is not None:
                last_line_ts = line_ts
            line_ts_cache.append(line_ts if line_ts is not None else last_line_ts)
        for line, effective_ts in reversed(list(zip(lines, line_ts_cache))):
            # Timestamp filter: skip lines older than since_sec
            if since_sec:
                if effective_ts is not None and effective_ts < since_sec:
                    continue
            if regex.search(line):
                if ignore_re and ignore_re.search(line):
                    continue
                # 100 char で truncate
                return line.strip()[:100]
        return ""
    except Exception:
        return ""


def proc_alive(pattern):
    """ps aux | grep pattern (-v grep)"""
    try:
        result = subprocess.run(
            ["pgrep", "-f", pattern],
            capture_output=True, text=True, timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False


def systemctl_active(unit):
    try:
        result = subprocess.run(
            ["systemctl", "--user", "is-active", unit],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip() == "active"
    except Exception:
        return False


def journal_count(unit, days=7):
    try:
        result = subprocess.run(
            ["journalctl", "--user", "-u", unit, "-S", f"{days} days ago",
             "--no-pager", "-q"],
            capture_output=True, text=True, timeout=10
        )
        return len(result.stdout.splitlines())
    except Exception:
        return 0


def fmt_age(seconds):
    if seconds is None or seconds < 0:
        return "-"
    if seconds < 60:
        return f"{int(seconds)}s"
    if seconds < 3600:
        return f"{int(seconds/60)}m"
    if seconds < 86400:
        return f"{seconds/3600:.1f}h"
    return f"{seconds/86400:.1f}d"


def fmt_jst(epoch):
    if epoch is None:
        return "-"
    try:
        # JST = UTC+9
        return datetime.datetime.utcfromtimestamp(epoch + 9*3600).strftime("%m-%d %H:%M")
    except Exception:
        return "-"


def parse_jst_epoch(value):
    try:
        dt = datetime.datetime.strptime(value, "%Y-%m-%d %H:%M JST")
        return dt.replace(tzinfo=datetime.timezone(datetime.timedelta(hours=9))).timestamp()
    except Exception:
        return None


def supervisor_roll_call_latest(agent, roll_call_log="roll_call.log"):
    """Return latest supervisor roll-call evidence for an agent."""
    path = os.path.join(LOG_DIR, roll_call_log)
    if not os.path.exists(path):
        return None, ""
    try:
        result = subprocess.run(
            ["tail", "-n", "2000", path],
            capture_output=True, text=True, timeout=10
        )
        regex = re.compile(
            r"\[ROLL-CALL\] \[(\d{4}-\d{2}-\d{2} \d{2}:\d{2} JST)\] "
            + re.escape(agent)
            + r": (ALIVE|REVIVED|DEAD(?: \(unreachable after retry\))?)"
        )
        latest_epoch = None
        latest_state = ""
        for line in result.stdout.splitlines():
            m = regex.search(line)
            if not m:
                continue
            epoch = parse_jst_epoch(m.group(1))
            if epoch is None:
                continue
            if latest_epoch is None or epoch > latest_epoch:
                latest_epoch = epoch
                latest_state = m.group(2)
        return latest_epoch, latest_state
    except Exception:
        return None, ""


def evaluate_target(t, defaults):
    """1 target を評価し (status, last_run_age, success_7d, failure_7d, last_error) を返す"""
    name = t["name"]
    cat = t["category"]

    # Display name (instance 含む)
    display = name
    if "instance_val" in t:
        display = f"{name}[{t['instance_val']}]"

    # host_guard チェック (本ホストでない場合は skip)
    if t.get("host_guard") and t["host_guard"] != HOSTNAME_NOW:
        return {
            "name": display, "status": "skip", "reason": "host_guard mismatch",
            "last_run_age": None, "success_7d": 0, "failure_7d": 0,
            "last_error": "", "last_run_str": "-",
        }

    # 共通 pattern (override 可)
    success_pat = t.get("success_pattern", defaults.get("success_pattern", "OK"))
    failure_pat = t.get("failure_pattern", defaults.get("failure_pattern", "ERROR"))
    ignore_pat = "|".join(defaults.get("ignore_patterns", []) + (t.get("ignore_patterns") or []))

    since_sec = NOW - WINDOW_SEC

    if cat in ("cron", "cron_per_role"):
        log_field = t.get("log") or t.get("log_pattern")
        if cat == "cron_per_role" and "instance_val" in t:
            log_field = t["log_pattern"].format(role=t["instance_val"])
        if t.get("abs_log"):
            log_path = log_field
        else:
            log_path = os.path.join(LOG_DIR, log_field)

        mt = file_mtime(log_path)
        age = (NOW - mt) if mt else None
        success = grep_count(log_path, success_pat, since_sec, ignore_pat)
        failure = grep_count(log_path, failure_pat, since_sec, ignore_pat, t.get("dedupe_failure_lines", False))
        last_err = grep_last_error(log_path, failure_pat, ignore_pat, since_sec)

        # silent_design: log が更新されない sh は syslog の CRON 起動記録で代替検知
        if t.get("silent_design"):
            sp = t.get("syslog_pattern", "")
            if cat == "cron_per_role" and "instance_val" in t:
                sp = sp.format(role=t["instance_val"])
            sl_latest, sl_count = syslog_cron_check(sp, days=7) if sp else (None, 0)
            if sl_latest:
                age = NOW - sl_latest
                success = max(success, sl_count)

        status = "green"
        red_after = t.get("red_after", 86400)
        yellow_after = t.get("yellow_after", red_after // 2)
        if age is None or age > red_after:
            status = "red"
        elif age > yellow_after or failure >= 1:
            status = "yellow"

        return {
            "name": display, "status": status,
            "last_run_age": age, "last_run_str": fmt_age(age),
            "success_7d": success, "failure_7d": failure,
            "last_error": last_err,
        }

    if cat in ("daemon", "daemon_per_agent"):
        roll_call_age = None
        roll_call_state = ""
        if cat == "daemon_per_agent" and "instance_val" in t:
            log_path = os.path.join(LOG_DIR, t["log_pattern"].format(agent=t["instance_val"]))
            proc_pat = t.get("process_pattern", "").format(agent=t["instance_val"])
            if t.get("supervisor_roll_call"):
                roll_call_latest, roll_call_state = supervisor_roll_call_latest(
                    t["instance_val"],
                    t.get("supervisor_roll_call_log", "roll_call.log")
                )
                roll_call_age = (NOW - roll_call_latest) if roll_call_latest else None
        else:
            log_path = os.path.join(LOG_DIR, t.get("log", ""))
            proc_pat = t.get("process_pattern", t.get("name", ""))

        mt = file_mtime(log_path)
        age = (NOW - mt) if mt else None
        success = grep_count(log_path, success_pat, since_sec, ignore_pat)
        failure = grep_count(log_path, failure_pat, since_sec, ignore_pat, t.get("dedupe_failure_lines", False))
        last_err = grep_last_error(log_path, failure_pat, ignore_pat, since_sec)

        # daemon は process 生存も判定材料
        process_alive = proc_alive(proc_pat) if proc_pat else True

        # PID 確認
        pid_alive = True
        if t.get("pid"):
            pid_path = os.path.join(LOG_DIR, t["pid"])
            if os.path.exists(pid_path):
                try:
                    with open(pid_path) as f:
                        pid = int(f.read().strip())
                    os.kill(pid, 0)
                    pid_alive = True
                except (OSError, ValueError):
                    pid_alive = False
            else:
                pid_alive = process_alive

        status = "green"
        red_after = t.get("red_after", 7200)
        yellow_after = t.get("yellow_after", red_after // 2)
        if not process_alive or not pid_alive:
            status = "red"
            if not last_err:
                last_err = "process not running"
        elif age is None or age > red_after:
            stale_status = t.get("alive_log_stale_status", "yellow")
            roll_call_green_after = t.get("supervisor_roll_call_green_after", red_after)
            if (
                t.get("supervisor_roll_call")
                and roll_call_state in ("ALIVE", "REVIVED")
                and roll_call_age is not None
                and roll_call_age <= roll_call_green_after
            ):
                status = "green" if stale_status == "green_with_roll_call" else stale_status
                if not last_err:
                    last_err = f"log idle; process alive; supervisor roll-call {roll_call_state} age={fmt_age(roll_call_age)}"
            else:
                # A daemon can be healthy while idle and therefore not append to its
                # own log. Process death is RED; stale log with a live process is a
                # warning unless a target-specific heartbeat source proves health.
                status = "yellow"
                if not last_err:
                    last_err = f"log stale > {red_after}s; process alive"
        elif age > yellow_after or failure >= 1:
            status = "yellow"
            if not last_err and roll_call_state in ("ALIVE", "REVIVED"):
                last_err = f"process alive; supervisor roll-call {roll_call_state} age={fmt_age(roll_call_age)}"

        health_evidence = f"process_alive={process_alive}; pid_alive={pid_alive}; log_age={fmt_age(age)}"
        if t.get("supervisor_roll_call"):
            health_evidence += f"; supervisor_roll_call={roll_call_state or 'missing'} age={fmt_age(roll_call_age)}"

        return {
            "name": display, "status": status,
            "last_run_age": age, "last_run_str": fmt_age(age),
            "success_7d": success, "failure_7d": failure,
            "last_error": last_err, "health_evidence": health_evidence,
        }

    if cat == "systemd_unit":
        unit = t["unit"]
        active = systemctl_active(unit)
        jcount = journal_count(unit, days=7)

        status = "green" if active else "red"
        last_err = "" if active else f"systemctl --user {unit} not active"
        return {
            "name": display, "status": status,
            "last_run_age": 0 if active else None,
            "last_run_str": "active" if active else "inactive",
            "success_7d": jcount, "failure_7d": 0 if active else 1,
            "last_error": last_err,
        }

    if cat == "claude_hook":
        script = t.get("script", "")
        script_path = os.path.join(SHOGUN_ROOT, script)
        side_effect_pat = t.get("side_effect_pattern", "")

        # スクリプト存在
        script_exists = os.path.exists(script_path)
        # settings.json 登録 (両方の location チェック)
        settings_paths = [
            os.path.join(SHOGUN_ROOT, ".claude/settings.json"),
            os.path.expanduser("~/.claude/settings.json"),
        ]
        registered = False
        for sp in settings_paths:
            if os.path.exists(sp):
                try:
                    with open(sp) as f:
                        content = f.read()
                    # script のファイル名で簡易マッチ (basename)
                    if os.path.basename(script) in content:
                        registered = True
                        break
                except Exception:
                    pass

        # side_effect の最終発火
        side_age = None
        side_target = os.path.join(SHOGUN_ROOT, side_effect_pat)
        try:
            matches = glob.glob(side_target)
            if matches:
                latest = max(os.path.getmtime(m) for m in matches)
                side_age = NOW - latest
        except Exception:
            pass

        yellow_window_sec = t.get("yellow_window_days", 14) * 86400

        if not script_exists or not registered:
            status = "red"
            last_err = ""
            if not script_exists:
                last_err = f"script missing: {script}"
            elif not registered:
                last_err = "not registered in settings.json"
        elif side_age is None or side_age > yellow_window_sec:
            status = "yellow"
            last_err = f"no side effect for {fmt_age(side_age) if side_age else 'unknown'}"
        else:
            status = "green"
            last_err = ""

        return {
            "name": display, "status": status,
            "last_run_age": side_age, "last_run_str": fmt_age(side_age),
            "success_7d": 1 if status != "red" else 0, "failure_7d": 1 if status == "red" else 0,
            "last_error": last_err,
        }

    # unknown category
    return {
        "name": display, "status": "skip", "reason": f"unknown cat:{cat}",
        "last_run_age": None, "last_run_str": "-",
        "success_7d": 0, "failure_7d": 0, "last_error": "",
    }


def expand_targets(cfg):
    """retired_after フィルタ + per-role/per-agent expand"""
    out = []
    for t in cfg.get("targets", []):
        if t.get("retired_after") and TODAY > t["retired_after"]:
            continue
        cat = t.get("category", "")
        if cat in ("cron_per_role", "daemon_per_agent"):
            for inst in t.get("instances", []):
                t2 = dict(t)
                t2["instance_key"] = list(inst.keys())[0]
                t2["instance_val"] = list(inst.values())[0]
                out.append(t2)
        else:
            out.append(t)
    return out


def main():
    cfg = load_config()
    defaults = cfg.get("defaults", {})
    targets = expand_targets(cfg)

    results = []
    for t in targets:
        try:
            r = evaluate_target(t, defaults)
            r["category"] = t.get("category", "")
        except Exception as e:
            r = {
                "name": t.get("name", "?"), "status": "skip",
                "reason": f"exception: {e}", "category": t.get("category", ""),
                "last_run_age": None, "last_run_str": "-",
                "success_7d": 0, "failure_7d": 0, "last_error": str(e)[:80],
            }
        results.append(r)

    # 集計
    counts = {"green": 0, "yellow": 0, "red": 0, "skip": 0}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1

    # markdown 生成 (境界マーカー間に貼り込まれる本体のみ — START/END タグは update_dashboard 側で付与)
    lines = []
    lines.append(f"## 📊 sh 実行状況 (週次)")
    lines.append("")
    lines.append(f"最終確認: {TIMESTAMP_JST} / 監視対象 = {len(results) - counts['skip']} ファミリ")
    lines.append("")
    lines.append("### サマリー")
    lines.append(f"- 🟢 健全: {counts['green']}")
    lines.append(f"- 🟡 警告: {counts['yellow']}")
    lines.append(f"- 🔴 停止: {counts['red']}")
    if counts["skip"]:
        lines.append(f"- ⏭️  除外 (host_guard等): {counts['skip']}")
    lines.append("")

    # Yellow 詳細
    yellow_rows = [r for r in results if r["status"] == "yellow"]
    if yellow_rows:
        lines.append("### 🟡 警告詳細")
        lines.append("")
        lines.append("| sh ファミリ | 最終実行 | 7d success | 7d failure | last_error | health_evidence |")
        lines.append("|------------|---------|-----------|-----------|-----------|-----------------|")
        for r in yellow_rows:
            err = (r["last_error"] or "-").replace("|", "\\|")[:80]
            evidence = (r.get("health_evidence") or "-").replace("|", "\\|")[:100]
            lines.append(f"| {r['name']} | {r['last_run_str']} | {r['success_7d']} | {r['failure_7d']} | {err} | {evidence} |")
        lines.append("")

    # Red 詳細
    red_rows = [r for r in results if r["status"] == "red"]
    if red_rows:
        lines.append("### 🔴 停止詳細")
        lines.append("")
        lines.append("| sh ファミリ | 最終実行 | 7d success | 7d failure | last_error | health_evidence |")
        lines.append("|------------|---------|-----------|-----------|-----------|-----------------|")
        for r in red_rows:
            err = (r["last_error"] or "-").replace("|", "\\|")[:80]
            evidence = (r.get("health_evidence") or "-").replace("|", "\\|")[:100]
            lines.append(f"| {r['name']} | {r['last_run_str']} | {r['success_7d']} | {r['failure_7d']} | {err} | {evidence} |")
        lines.append("")

    # Green 折りたたみ
    green_rows = [r for r in results if r["status"] == "green"]
    if green_rows:
        lines.append("<details>")
        lines.append(f"<summary>🟢 健全 sh 一覧 ({len(green_rows)})</summary>")
        lines.append("")
        lines.append("| sh ファミリ | 最終実行 | 7d success | 7d failure | health_evidence |")
        lines.append("|------------|---------|-----------|-----------|-----------------|")
        for r in green_rows:
            evidence = (r.get("health_evidence") or "-").replace("|", "\\|")[:100]
            lines.append(f"| {r['name']} | {r['last_run_str']} | {r['success_7d']} | {r['failure_7d']} | {evidence} |")
        lines.append("")
        lines.append("</details>")
        lines.append("")

    # Skip
    skip_rows = [r for r in results if r["status"] == "skip"]
    if skip_rows:
        lines.append("<details>")
        lines.append(f"<summary>⏭️  除外 ({len(skip_rows)})</summary>")
        lines.append("")
        for r in skip_rows:
            lines.append(f"- {r['name']}: {r.get('reason', '-')}")
        lines.append("")
        lines.append("</details>")
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
        yaml.safe_dump(status_doc, f, allow_unicode=True, sort_keys=False, width=120)

    print(f"sh_health_check OK — green={counts['green']} yellow={counts['yellow']} red={counts['red']} skip={counts['skip']}")


if __name__ == "__main__":
    main()
PYEOF

PY_RC=$?
if [ $PY_RC -ne 0 ]; then
    echo "[$TIMESTAMP_JST] python evaluation failed (rc=$PY_RC)" >> "$SCRIPT_LOG"
    exit $PY_RC
fi

# ============================================================================
# dashboard.md の <!-- SH_HEALTH:START/END --> 間を原子的更新
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

if ! grep -q "<!-- SH_HEALTH:START -->" "$DASHBOARD"; then
    echo "[$TIMESTAMP_JST] SH_HEALTH markers not found in dashboard, skip update" >> "$SCRIPT_LOG"
    exit 0
fi

# 原子的書換え (python3 で安全に処理)
DASHBOARD_ENV="$DASHBOARD" SECTION_OUT_ENV="$SECTION_OUT" python3 <<'PYEOF2'
import os, tempfile
dashboard = os.environ["DASHBOARD_ENV"]
section_path = os.environ["SECTION_OUT_ENV"]

with open(dashboard, "r") as f:
    content = f.read()
with open(section_path, "r") as f:
    section = f.read().rstrip("\n")

START = "<!-- SH_HEALTH:START -->"
END = "<!-- SH_HEALTH:END -->"
si = content.find(START)
ei = content.find(END)
if si < 0 or ei < 0 or ei < si:
    raise SystemExit("SH_HEALTH markers malformed")

new_block = f"{START}\n{section}\n{END}"
new = content[:si] + new_block + content[ei + len(END):]

# atomic write via tempfile + rename in same dir
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

echo "[$TIMESTAMP_JST] sh_health_check completed" >> "$SCRIPT_LOG"
exit 0
