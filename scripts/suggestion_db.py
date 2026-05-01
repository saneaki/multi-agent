#!/usr/bin/env python3
"""cmd_618 Phase2 — suggestion DB TF-IDF similarity search CLI.

Commands:
    stats  : role別件数 / binary label分布 / category分布を表示
    query  : 指定roleの過去提案を類似度降順でtop-N表示

Usage:
    python3 scripts/suggestion_db.py stats
    python3 scripts/suggestion_db.py query --role karo --text "dashboard 更新自動化" --top 5
    python3 scripts/suggestion_db.py query --role gunshi --text "compact observer 修正" --top 3

Design:
    - sklearn TF-IDF with same jp_en_tokenizer as Phase1 (char 2-gram + ASCII words)
    - Phase0 jsonl (688 records) + shogun/karo/ashigaru augmentation = ~860 records
    - Imports suggestion_vectorize.py functions to avoid logic duplication
    - Warning: similarity > 0.85 かつ binary=neg → "⚠ 類似deferred提案あり"
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from suggestion_vectorize import (  # noqa: E402
    PHASE0_JSONL,
    REPORTS_DIR,
    SHOGUN_KARO_AUGMENT_LIMIT,
    SHOGUN_KARO_YAML,
    NEG_STATUSES,
    POS_STATUSES,
    augment_ashigaru,
    augment_shogun_karo,
    binary_label,
    jp_en_tokenizer,
    load_phase0_jsonl,
    normalize_role_group,
    parse_ashigaru_reports,
    parse_shogun_karo_yaml,
)

SIMILARITY_WARN_THRESHOLD = 0.85
DEFAULT_TOP_N = 5
CONTENT_PREVIEW_LEN = 80
VALID_ROLES = ("shogun", "karo", "gunshi", "ashigaru")


def _build_record_text(record: dict[str, Any]) -> str:
    """Build searchable text from a record — same prefix convention as Phase1."""
    role = normalize_role_group(record.get("role") or "")
    category = record.get("category") or ""
    status = record.get("status") or ""
    decision = record.get("decision") or ""
    content = record.get("content") or ""
    outcome = record.get("outcome") or ""
    return (
        f"[role={role}] [category={category}] [status={status}] "
        f"DECISION: {decision} CONTENT: {content} OUTCOME: {outcome}"
    )


def _load_all_records() -> list[dict[str, Any]]:
    """Load Phase0 jsonl + augment shogun/karo/ashigaru (same pipeline as Phase1)."""
    if not PHASE0_JSONL.exists():
        print(f"ERROR: Phase0 jsonl not found: {PHASE0_JSONL}", file=sys.stderr)
        sys.exit(1)

    records = load_phase0_jsonl(PHASE0_JSONL)

    if SHOGUN_KARO_YAML.exists():
        shogun_karo_entries = parse_shogun_karo_yaml(SHOGUN_KARO_YAML)
        records.extend(augment_shogun_karo(shogun_karo_entries, SHOGUN_KARO_AUGMENT_LIMIT))

    if REPORTS_DIR.exists():
        ashigaru_docs = parse_ashigaru_reports(REPORTS_DIR)
        records.extend(augment_ashigaru(ashigaru_docs))

    return records


class SuggestionDB:
    """TF-IDF based suggestion similarity search database.

    Lazy-builds the TF-IDF index on first use.
    Records are loaded once and cached for subsequent queries.
    """

    def __init__(self) -> None:
        self._records: list[dict[str, Any]] = []
        self._vectorizer: TfidfVectorizer | None = None
        self._tfidf_matrix: Any = None
        self._built = False

    def _ensure_built(self) -> None:
        if self._built:
            return
        self._records = _load_all_records()
        texts = [_build_record_text(r) for r in self._records]
        self._vectorizer = TfidfVectorizer(
            tokenizer=jp_en_tokenizer,
            token_pattern=None,
            min_df=1,
            max_df=0.98,
            max_features=30000,
            lowercase=False,
        )
        self._tfidf_matrix = self._vectorizer.fit_transform(texts)
        self._built = True

    def query(
        self, role: str, text: str, top_n: int = DEFAULT_TOP_N
    ) -> list[dict[str, Any]]:
        """Return top-N similar records for the given role, sorted by similarity desc."""
        self._ensure_built()

        role_indices = [
            i
            for i, r in enumerate(self._records)
            if normalize_role_group(r.get("role") or "") == role
        ]

        if not role_indices:
            return []

        query_vec = self._vectorizer.transform([text])  # type: ignore[union-attr]
        role_matrix = self._tfidf_matrix[role_indices]
        sims = cosine_similarity(query_vec, role_matrix).flatten()

        sorted_idx = np.argsort(sims)[::-1][:top_n]

        results = []
        for idx in sorted_idx:
            record = self._records[role_indices[int(idx)]]
            sim = float(sims[int(idx)])
            results.append(
                {
                    "record": record,
                    "similarity": sim,
                    "binary": binary_label(record.get("status") or ""),
                }
            )
        return results

    def stats(self) -> dict[str, Any]:
        """Compute role/binary/category distribution statistics."""
        self._ensure_built()

        role_counts: Counter[str] = Counter()
        binary_counts: Counter[str] = Counter()
        category_counts: Counter[str] = Counter()
        role_binary: dict[str, Counter[str]] = defaultdict(Counter)

        for r in self._records:
            role = normalize_role_group(r.get("role") or "")
            bl = binary_label(r.get("status") or "")
            category = r.get("category") or "unknown"
            role_counts[role] += 1
            binary_counts[bl] += 1
            category_counts[category] += 1
            role_binary[role][bl] += 1

        return {
            "total": len(self._records),
            "role_counts": dict(role_counts.most_common()),
            "binary_counts": dict(binary_counts.most_common()),
            "category_counts": dict(category_counts.most_common()),
            "role_binary": {
                role: dict(cnt) for role, cnt in sorted(role_binary.items())
            },
        }


def cmd_stats(db: SuggestionDB) -> None:
    s = db.stats()
    print(f"=== suggestion DB stats (total: {s['total']} records) ===\n")

    print("── 役職別件数 ──")
    for role, cnt in s["role_counts"].items():
        rb = s["role_binary"].get(role, {})
        pos = rb.get("pos", 0)
        neg = rb.get("neg", 0)
        pending = rb.get("pending", 0)
        print(f"  {role:<12} {cnt:4d}件  (pos={pos}, neg={neg}, pending={pending})")

    print("\n── binary label 分布 ──")
    total = s["total"]
    for label, cnt in s["binary_counts"].items():
        pct = cnt / total * 100 if total else 0
        print(f"  {label:<10} {cnt:4d}件  ({pct:.1f}%)")

    print("\n── category 分布 (top 10) ──")
    for cat, cnt in list(s["category_counts"].items())[:10]:
        print(f"  {cat:<30} {cnt:4d}件")


def cmd_query(db: SuggestionDB, role: str, text: str, top_n: int) -> None:
    if role not in VALID_ROLES:
        print(f"ERROR: --role は {VALID_ROLES} のいずれかを指定", file=sys.stderr)
        sys.exit(1)

    results = db.query(role, text, top_n)

    if not results:
        print(f"role={role} の提案データなし")
        return

    print(f"=== query: role={role}, top={top_n} ===")
    print(f"検索テキスト: {text!r}\n")

    has_warning = False
    for i, hit in enumerate(results, 1):
        r = hit["record"]
        sim = hit["similarity"]
        binary = hit["binary"]

        content_raw = r.get("content") or r.get("decision") or ""
        content_preview = content_raw[:CONTENT_PREVIEW_LEN]
        rec_id = r.get("id") or "unknown"
        category = r.get("category") or "unknown"
        status = r.get("status") or "unknown"
        priority = r.get("priority") or "unknown"

        print(f"[{i}] id={rec_id}")
        print(f"    category={category}  status={status}  priority={priority}  binary={binary}")
        print(f"    content: {content_preview}")
        print(f"    similarity: {sim:.4f}")

        if sim >= SIMILARITY_WARN_THRESHOLD and binary == "neg":
            print(f"    ⚠ 類似deferred提案あり (similarity={sim:.4f}, binary=neg)")
            has_warning = True
        print()

    if has_warning:
        print(
            "⚠ WARNING: 類似する却下/延期済み提案が存在します。採用前に内容を確認してください。"
        )


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="suggestion_db.py",
        description="suggestion DB — TF-IDF similarity search CLI (Phase2)",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("stats", help="role別件数 / binary label分布 / category分布を表示")

    query_p = sub.add_parser(
        "query", help="指定roleの過去提案を類似度降順でtop-N表示"
    )
    query_p.add_argument(
        "--role",
        required=True,
        choices=VALID_ROLES,
        help="対象役職 (shogun/karo/gunshi/ashigaru)",
    )
    query_p.add_argument("--text", required=True, help="検索クエリテキスト")
    query_p.add_argument(
        "--top",
        type=int,
        default=DEFAULT_TOP_N,
        dest="top_n",
        metavar="N",
        help=f"表示件数 (default: {DEFAULT_TOP_N})",
    )
    return parser


def main() -> None:
    args = _build_parser().parse_args()
    db = SuggestionDB()

    if args.command == "stats":
        cmd_stats(db)
    elif args.command == "query":
        cmd_query(db, args.role, args.text, args.top_n)


if __name__ == "__main__":
    main()
