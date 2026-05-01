#!/usr/bin/env python3
"""cmd_618 Phase1 — suggestion DB role-conditioned vector + augmentation.

Pipeline:
    1. Load Phase0 jsonl (688 records) from output/cmd_618_phase0_mining_output.jsonl.
    2. Augment shogun/karo records from queue/shogun_to_karo.yaml (last 30 cmd).
    3. Augment ashigaru records from queue/reports/ashigaru*_report.yaml (multi-doc).
    4. Build role-conditioned TF-IDF and emit top-20 keywords per role.
    5. Compute binary outcome label (pos/neg/pending) distribution per role.
    6. Write output/cmd_618_phase1_vectors.json with stats + keywords.

Design notes:
    - sklearn TfidfVectorizer with custom Japanese tokenizer (char 2-4grams + ASCII words).
    - shogun_to_karo.yaml has parser-fragile blocks → block-split fallback.
    - ashigaru_report.yaml is multi-document → safe_load_all + per-block recovery.
    - status mapping aligns with Phase0 outcome semantics (pos/neg/pending 3-class).
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import yaml
from sklearn.feature_extraction.text import TfidfVectorizer

REPO_ROOT = Path("/home/ubuntu/shogun")
PHASE0_JSONL = REPO_ROOT / "output" / "cmd_618_phase0_mining_output.jsonl"
SHOGUN_KARO_YAML = REPO_ROOT / "queue" / "shogun_to_karo.yaml"
REPORTS_DIR = REPO_ROOT / "queue" / "reports"
OUTPUT_JSON = REPO_ROOT / "output" / "cmd_618_phase1_vectors.json"

ROLES_OF_INTEREST = ("shogun", "karo", "gunshi", "ashigaru")
TOP_K_KEYWORDS = 20
SHOGUN_KARO_AUGMENT_LIMIT = 60
DECISION_TRUNCATE = 500
OUTCOME_TRUNCATE = 300

POS_STATUSES = {"accepted", "resolved", "promoted", "done"}
NEG_STATUSES = {"rejected", "deferred", "postponed"}
PENDING_STATUSES = {"pending", "unknown", ""}

JP_STOPWORDS = {
    "する", "した", "して", "せよ", "こと", "もの", "ため", "よう", "から", "まで",
    "より", "として", "について", "における", "において", "により", "を行", "を行う",
    "確認", "実行", "実施", "対応", "対象", "現在", "今回", "本件", "今日", "昨日",
    "全て", "全件", "場合", "結果", "報告", "完了",
}
EN_STOPWORDS = {
    "the", "a", "an", "and", "or", "of", "to", "for", "in", "on", "at", "is",
    "be", "was", "are", "this", "that", "with", "by", "as", "from", "it", "its",
}


def load_phase0_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return records


def parse_shogun_karo_yaml(path: Path) -> list[dict[str, Any]]:
    """Block-split tolerant parser for queue/shogun_to_karo.yaml.

    The file contains 411+ entries but a long quoted string (around cmd_359) breaks
    yaml.safe_load. We split on `\n- id: cmd_<digits>\n` and parse each block alone.
    """
    text = path.read_text(encoding="utf-8")
    blocks = re.split(r"\n(?=- id: cmd_\d+\n)", text)
    parsed: list[dict[str, Any]] = []
    for block in blocks:
        try:
            data = yaml.safe_load(block)
        except yaml.YAMLError:
            continue
        if isinstance(data, list):
            parsed.extend(d for d in data if isinstance(d, dict))
    return parsed


def parse_ashigaru_reports(reports_dir: Path) -> list[dict[str, Any]]:
    """Multi-document YAML parse with per-block fallback for malformed reports."""
    docs: list[dict[str, Any]] = []
    for f in sorted(reports_dir.glob("ashigaru*_report.yaml")):
        try:
            with open(f, encoding="utf-8") as fh:
                for d in yaml.safe_load_all(fh):
                    if isinstance(d, dict):
                        docs.append(d)
        except yaml.YAMLError:
            text = f.read_text(encoding="utf-8")
            for chunk in text.split("\n---\n"):
                try:
                    d = yaml.safe_load(chunk)
                    if isinstance(d, dict):
                        docs.append(d)
                except yaml.YAMLError:
                    continue
    return docs


def map_cmd_status(status: str | None) -> str:
    """Map shogun_to_karo cmd status → suggestion-style status."""
    s = (status or "").lower()
    if s in {"done", "completed", "merged"}:
        return "accepted"
    if s in {"dispatched", "in_progress", "started", "active"}:
        return "pending"
    if s in {"rejected", "cancelled", "abandoned"}:
        return "rejected"
    if s in {"deferred", "postponed", "blocked"}:
        return "deferred"
    if s in {"pending", "queued"}:
        return "pending"
    return "unknown"


def map_report_status(status: str | None) -> str:
    s = (status or "").lower()
    if s == "done":
        return "accepted"
    if s in {"blocked", "deferred"}:
        return "deferred"
    if s in {"in_progress", "pending"}:
        return "pending"
    if s == "rejected":
        return "rejected"
    return "unknown"


def _karo_decision_for_cmd(entry: dict[str, Any]) -> tuple[str, str]:
    """Return (decision_text, source_label) for karo augmentation.

    Priority chain: result → notes → decomposition_hint → ''. The fallback chain
    ensures karo coverage hits AC4 even on fresh cmds where karo's outcome is
    not yet recorded as `result`.
    """
    result = (entry.get("result") or "").strip()
    if result:
        return result, "shogun_to_karo.result"
    notes = entry.get("notes")
    if isinstance(notes, list):
        notes = " ".join(str(n) for n in notes)
    notes_str = (notes or "").strip()
    if notes_str:
        return notes_str, "shogun_to_karo.notes"
    hint_raw = entry.get("decomposition_hint")
    if isinstance(hint_raw, dict):
        hint_raw = " ".join(f"{k}={v}" for k, v in hint_raw.items())
    elif isinstance(hint_raw, list):
        hint_raw = " ".join(str(h) for h in hint_raw)
    hint = (hint_raw or "").strip() if isinstance(hint_raw, str) else ""
    if hint:
        return hint, "shogun_to_karo.decomposition_hint"
    return "", ""


def augment_shogun_karo(entries: list[dict[str, Any]], limit: int) -> list[dict[str, Any]]:
    """Last `limit` cmd entries → augmentation records for shogun + karo.

    karo augmentation uses a fallback chain (result → notes → decomposition_hint)
    so even fresh cmds without finalized result still contribute keyword signal.
    """
    additions: list[dict[str, Any]] = []
    tail = entries[-limit:]
    for entry in tail:
        cmd_id = entry.get("id") or "cmd_unknown"
        status = map_cmd_status(entry.get("status"))
        purpose = (entry.get("purpose") or "").strip()
        command = (entry.get("command") or "").strip()
        result = (entry.get("result") or "").strip()
        north_star = (entry.get("north_star") or "").strip()
        priority = (entry.get("priority") or "unknown").strip().lower()
        timestamp = entry.get("timestamp") or ""

        if purpose or command:
            decision = (purpose + ("\n" + command if command else ""))[:DECISION_TRUNCATE]
            content = north_star or purpose
            outcome = f"[{status}] {result[:OUTCOME_TRUNCATE]}".strip()
            additions.append({
                "id": f"aug_{cmd_id}_shogun",
                "role": "shogun",
                "cmd_ref": cmd_id,
                "category": "augmented_cmd",
                "status": status,
                "priority": priority,
                "decision": decision,
                "outcome": outcome,
                "content": content[:DECISION_TRUNCATE],
                "created_at": timestamp,
                "decided_at": entry.get("completed_at") or "",
                "task_ref": "",
                "_aug_source": "shogun_to_karo.command",
            })

        karo_decision, karo_source = _karo_decision_for_cmd(entry)
        if karo_decision:
            outcome = f"[{status}] {result[:OUTCOME_TRUNCATE]}".strip()
            additions.append({
                "id": f"aug_{cmd_id}_karo",
                "role": "karo",
                "cmd_ref": cmd_id,
                "category": "augmented_cmd",
                "status": status,
                "priority": priority,
                "decision": karo_decision[:DECISION_TRUNCATE],
                "outcome": outcome,
                "content": purpose[:DECISION_TRUNCATE],
                "created_at": timestamp,
                "decided_at": entry.get("completed_at") or "",
                "task_ref": "",
                "_aug_source": karo_source,
            })
    return additions


def augment_ashigaru(docs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    additions: list[dict[str, Any]] = []
    for d in docs:
        worker = (d.get("worker_id") or "ashigaru").strip()
        task_id = d.get("task_id") or "task_unknown"
        cmd_ref = d.get("parent_cmd") or ""
        status = map_report_status(d.get("status"))
        result = d.get("result") or {}
        summary = ""
        if isinstance(result, dict):
            summary = str(result.get("summary") or "")
        elif isinstance(result, str):
            summary = result
        notes = d.get("notes") or ""
        if isinstance(notes, list):
            notes = " ".join(str(n) for n in notes)
        timestamp = d.get("timestamp") or ""

        if not (summary or notes):
            continue
        decision = (summary or str(notes))[:DECISION_TRUNCATE]
        outcome = f"[{status}] {str(notes)[:OUTCOME_TRUNCATE]}".strip()
        additions.append({
            "id": f"aug_{cmd_ref}_{worker}",
            "role": worker,
            "cmd_ref": cmd_ref,
            "category": "augmented_report",
            "status": status,
            "priority": "unknown",
            "decision": decision,
            "outcome": outcome,
            "content": str(notes)[:DECISION_TRUNCATE],
            "created_at": timestamp,
            "decided_at": timestamp,
            "task_ref": task_id,
            "_aug_source": f"reports/{worker}_report",
        })
    return additions


def normalize_role_group(role: str) -> str:
    """ashigaru1..7 → ashigaru group; preserve shogun/karo/gunshi."""
    if role.startswith("ashigaru"):
        return "ashigaru"
    if role in ROLES_OF_INTEREST:
        return role
    return "other"


def jp_en_tokenizer(text: str) -> list[str]:
    """Tokenizer that mixes Japanese char-bigrams with English/code words.

    - Pull contiguous CJK runs of length 2+ → emit char 2-grams within each run.
    - Pull alphanumeric/underscore/hyphen tokens → keep as-is, lowercased.
    - Skip stopwords (JP/EN).
    """
    if not text:
        return []
    tokens: list[str] = []
    text = text.replace("\n", " ").replace("\r", " ")

    for run in re.findall(r"[぀-ヿ一-鿿々]{2,}", text):
        if run in JP_STOPWORDS:
            continue
        for i in range(len(run) - 1):
            bg = run[i:i + 2]
            if bg in JP_STOPWORDS:
                continue
            tokens.append(bg)

    for word in re.findall(r"[A-Za-z][A-Za-z0-9_\-]{1,}", text):
        w = word.lower()
        if len(w) < 2 or w in EN_STOPWORDS:
            continue
        tokens.append(w)
    return tokens


def role_top_keywords(records: list[dict[str, Any]], top_k: int) -> dict[str, list[dict[str, Any]]]:
    role_texts: dict[str, list[str]] = defaultdict(list)
    for r in records:
        role = normalize_role_group(r.get("role", ""))
        if role == "other":
            continue
        text_parts = [
            f"[role={r.get('role','')}]",
            f"[category={r.get('category','')}]",
            f"[status={r.get('status','')}]",
            r.get("decision", "") or "",
            r.get("content", "") or "",
            r.get("outcome", "") or "",
        ]
        role_texts[role].append(" ".join(text_parts))

    role_keywords: dict[str, list[dict[str, Any]]] = {}
    for role, docs in role_texts.items():
        if len(docs) < 2:
            role_keywords[role] = []
            continue
        vectorizer = TfidfVectorizer(
            tokenizer=jp_en_tokenizer,
            token_pattern=None,
            min_df=1,
            max_df=0.95,
            lowercase=False,
        )
        matrix = vectorizer.fit_transform(docs)
        feature_names = vectorizer.get_feature_names_out()
        mean_scores = matrix.mean(axis=0).A1  # type: ignore[attr-defined]
        order = mean_scores.argsort()[::-1][:top_k]
        role_keywords[role] = [
            {"keyword": feature_names[i], "tfidf_mean": round(float(mean_scores[i]), 5)}
            for i in order
        ]
    return role_keywords


def binary_label(status: str) -> str:
    s = (status or "").lower()
    if s in POS_STATUSES:
        return "pos"
    if s in NEG_STATUSES:
        return "neg"
    return "pending"


def compute_distributions(records: list[dict[str, Any]]) -> dict[str, Any]:
    role_counts: Counter[str] = Counter()
    role_group_counts: Counter[str] = Counter()
    binary_counts: Counter[str] = Counter()
    role_binary: dict[str, Counter[str]] = defaultdict(Counter)
    for r in records:
        role = r.get("role", "unknown")
        group = normalize_role_group(role)
        role_counts[role] += 1
        role_group_counts[group] += 1
        bl = binary_label(r.get("status", ""))
        binary_counts[bl] += 1
        role_binary[group][bl] += 1
    return {
        "role_counts": dict(role_counts.most_common()),
        "role_group_counts": dict(role_group_counts.most_common()),
        "binary_counts": dict(binary_counts.most_common()),
        "role_binary": {g: dict(c) for g, c in role_binary.items()},
    }


def main() -> int:
    if not PHASE0_JSONL.exists():
        sys.stderr.write(f"ERROR: phase0 jsonl not found: {PHASE0_JSONL}\n")
        return 1

    phase0 = load_phase0_jsonl(PHASE0_JSONL)
    cmd_entries = parse_shogun_karo_yaml(SHOGUN_KARO_YAML) if SHOGUN_KARO_YAML.exists() else []
    report_docs = parse_ashigaru_reports(REPORTS_DIR) if REPORTS_DIR.exists() else []

    aug_sk = augment_shogun_karo(cmd_entries, SHOGUN_KARO_AUGMENT_LIMIT)
    aug_ash = augment_ashigaru(report_docs)
    combined = phase0 + aug_sk + aug_ash

    pre_dist = compute_distributions(phase0)
    post_dist = compute_distributions(combined)
    keywords = role_top_keywords(combined, TOP_K_KEYWORDS)

    output = {
        "schema_version": 1,
        "phase": "cmd_618_phase1",
        "input": {
            "phase0_jsonl": str(PHASE0_JSONL.relative_to(REPO_ROOT)),
            "phase0_count": len(phase0),
            "shogun_to_karo_yaml": str(SHOGUN_KARO_YAML.relative_to(REPO_ROOT)),
            "shogun_to_karo_parsed_cmds": len(cmd_entries),
            "ashigaru_reports_dir": str(REPORTS_DIR.relative_to(REPO_ROOT)),
            "ashigaru_report_docs": len(report_docs),
        },
        "augmentation": {
            "shogun_to_karo_added": len(aug_sk),
            "ashigaru_added": len(aug_ash),
            "shogun_to_karo_limit_cmds": SHOGUN_KARO_AUGMENT_LIMIT,
            "shogun_added": sum(1 for r in aug_sk if r["role"] == "shogun"),
            "karo_added": sum(1 for r in aug_sk if r["role"] == "karo"),
            "ashigaru_added_breakdown": dict(Counter(r["role"] for r in aug_ash)),
        },
        "totals": {
            "before": len(phase0),
            "after": len(combined),
            "delta": len(combined) - len(phase0),
        },
        "distributions": {
            "before": pre_dist,
            "after": post_dist,
        },
        "binary_label_definition": {
            "pos": sorted(POS_STATUSES),
            "neg": sorted(NEG_STATUSES),
            "pending": sorted(s for s in PENDING_STATUSES if s),
        },
        "role_top_keywords": keywords,
        "notes": [
            "Tokenizer = Japanese char-bigrams + ASCII alphanumeric words (sklearn TfidfVectorizer).",
            "Role grouping: ashigaru1..7 → 'ashigaru'; gunshi/karo/shogun preserved.",
            "Augmentation purposeful: Phase0 had gunshi=669/688 (97.2%); Phase1 lifts shogun/karo/ashigaru floor.",
        ],
    }

    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    sys.stdout.write(
        f"OK: wrote {OUTPUT_JSON.relative_to(REPO_ROOT)} "
        f"(before={len(phase0)}, after={len(combined)}, +{len(combined)-len(phase0)})\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
