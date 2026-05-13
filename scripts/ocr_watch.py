#!/usr/bin/env python3
"""ocr_watch.py — Pattern B watchdog daemon for cmd_721.

Watches a folder for new PDF files and invokes ``scripts/ocr_pdf.py`` to
produce a searchable ``_ocr.pdf`` next to each original. Designed for
Windows + Google Drive Desktop sync, but runs on any OS Python supports.

Behavior (固定設計 per cmd_721 task YAML):
  * 起動時に未処理 PDF を検出して順次処理する。
  * ``_ocr.pdf`` suffix 付きファイルは対象外。tmp/lock/part suffix も除外。
  * ``.processed.json`` に成功記録を残し、再起動後の重複処理を避ける。
  * エラー時は ``errors.log`` に追記し、リトライしない (殿の判断待ち)。
  * 原本 PDF は読み込み専用扱い。ocr_pdf.py が別名出力する前提。

CLI:
  python ocr_watch.py --watch-dir "G:\\My Drive\\OCR\\input"
                      [--ocr-script scripts/ocr_pdf.py]
                      [--state-file .processed.json]
                      [--errors-log errors.log]
                      [--enable-tcy]
                      [--python python]
                      [--scan-once]
                      [--dry-run]

Default state/log paths are placed next to ``--watch-dir`` so that one
runtime per folder remains isolated.

Compatibility: stdlib + ``watchdog`` (third-party).
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Optional, Sequence

LOGGER = logging.getLogger("ocr_watch")

EXCLUDED_SUFFIXES = ("_ocr.pdf",)
EXCLUDED_NAME_FRAGMENTS = (
    ".tmp", ".part", ".crdownload", ".filepart", ".download", "~$",
)
PROCESSED_SCHEMA_VERSION = 1
SETTLE_SECONDS = 5.0
SETTLE_POLL = 0.5


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

class ProcessedStore:
    """Append-only JSON state keyed by absolute path.

    Each entry holds size, mtime_ns and processed_at to allow re-processing
    when the original is intentionally replaced (size or mtime change).
    """

    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        self._data: dict = {"schema": PROCESSED_SCHEMA_VERSION, "items": {}}
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            return
        try:
            raw = self.path.read_text(encoding="utf-8")
            loaded = json.loads(raw) if raw.strip() else {}
        except (OSError, json.JSONDecodeError) as exc:
            LOGGER.warning("processed state unreadable (%s); starting fresh", exc)
            return
        if isinstance(loaded, dict) and "items" in loaded:
            self._data = {
                "schema": loaded.get("schema", PROCESSED_SCHEMA_VERSION),
                "items": dict(loaded.get("items", {})),
            }
        else:
            LOGGER.warning("processed state shape unknown; ignoring")

    def _save_locked(self) -> None:
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        tmp.write_text(json.dumps(self._data, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(tmp, self.path)

    def already_done(self, pdf_path: Path) -> bool:
        key = str(pdf_path.resolve())
        with self._lock:
            entry = self._data["items"].get(key)
        if not entry:
            return False
        try:
            stat = pdf_path.stat()
        except FileNotFoundError:
            return True
        return entry.get("size") == stat.st_size and entry.get("mtime_ns") == stat.st_mtime_ns

    def mark_done(self, pdf_path: Path, output_path: Path) -> None:
        stat = pdf_path.stat()
        key = str(pdf_path.resolve())
        entry = {
            "size": stat.st_size,
            "mtime_ns": stat.st_mtime_ns,
            "output": str(output_path.resolve()),
            "processed_at": now_iso(),
        }
        with self._lock:
            self._data["items"][key] = entry
            self._save_locked()


# ---------------------------------------------------------------------------
# Error log
# ---------------------------------------------------------------------------

class ErrorLog:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()

    def record(self, pdf_path: Path, message: str, *, detail: str = "") -> None:
        line = f"[{now_iso()}] {pdf_path} :: {message}"
        if detail:
            line += f" :: {detail.strip()}"
        line += "\n"
        with self._lock:
            with self.path.open("a", encoding="utf-8") as fh:
                fh.write(line)
        LOGGER.error("logged error for %s -> %s", pdf_path, self.path)


# ---------------------------------------------------------------------------
# File filtering and stability detection
# ---------------------------------------------------------------------------

def is_candidate_pdf(path: Path) -> bool:
    if not path.is_file():
        return False
    name = path.name.lower()
    if not name.endswith(".pdf"):
        return False
    for suffix in EXCLUDED_SUFFIXES:
        if name.endswith(suffix):
            return False
    for fragment in EXCLUDED_NAME_FRAGMENTS:
        if fragment in name:
            return False
    if path.name.startswith("."):
        return False
    return True


def wait_until_stable(path: Path, *, timeout: float = 120.0) -> bool:
    """Return True once the file size stays constant across two polls.

    Used to avoid acting while Drive Desktop is still writing the file.
    """

    deadline = time.monotonic() + timeout
    last_size = -1
    stable_polls = 0
    while time.monotonic() < deadline:
        try:
            size = path.stat().st_size
        except FileNotFoundError:
            return False
        if size == last_size and size > 0:
            stable_polls += 1
            if stable_polls >= int(SETTLE_SECONDS / SETTLE_POLL):
                return True
        else:
            stable_polls = 0
        last_size = size
        time.sleep(SETTLE_POLL)
    return False


# ---------------------------------------------------------------------------
# OCR invocation
# ---------------------------------------------------------------------------

class OcrInvoker:
    def __init__(
        self,
        *,
        python_exe: str,
        ocr_script: Path,
        enable_tcy: bool,
        store: ProcessedStore,
        error_log: ErrorLog,
        dry_run: bool,
    ) -> None:
        self.python_exe = python_exe
        self.ocr_script = ocr_script
        self.enable_tcy = enable_tcy
        self.store = store
        self.error_log = error_log
        self.dry_run = dry_run

    def _output_for(self, pdf_path: Path) -> Path:
        return pdf_path.with_name(f"{pdf_path.stem}_ocr.pdf")

    def process(self, pdf_path: Path) -> None:
        if self.store.already_done(pdf_path):
            LOGGER.info("skip already-processed: %s", pdf_path)
            return
        output = self._output_for(pdf_path)
        cmd: list[str] = [
            self.python_exe,
            str(self.ocr_script),
            str(pdf_path),
            "--output",
            str(output),
        ]
        if self.enable_tcy:
            cmd.append("--enable-tcy")

        LOGGER.info("ocr start: %s", pdf_path)
        if self.dry_run:
            LOGGER.info("dry-run: would invoke %s", " ".join(cmd))
            return

        if not self.ocr_script.exists():
            self.error_log.record(
                pdf_path,
                "ocr_pdf script missing",
                detail=f"expected at {self.ocr_script}",
            )
            return

        if not wait_until_stable(pdf_path):
            self.error_log.record(pdf_path, "file did not stabilize before OCR")
            return

        try:
            completed = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=60 * 30,
                check=False,
            )
        except FileNotFoundError as exc:
            self.error_log.record(pdf_path, "python executable missing", detail=str(exc))
            return
        except subprocess.TimeoutExpired as exc:
            self.error_log.record(pdf_path, "ocr timed out", detail=str(exc))
            return

        if completed.returncode != 0:
            detail = (completed.stderr or completed.stdout or "").strip()
            self.error_log.record(
                pdf_path,
                f"ocr_pdf returncode={completed.returncode}",
                detail=detail[:2000],
            )
            return

        if not output.exists():
            self.error_log.record(
                pdf_path,
                "ocr_pdf reported success but output missing",
                detail=str(output),
            )
            return

        self.store.mark_done(pdf_path, output)
        LOGGER.info("ocr done: %s -> %s", pdf_path, output)


# ---------------------------------------------------------------------------
# Folder scan + watchdog
# ---------------------------------------------------------------------------

def initial_scan(watch_dir: Path, invoker: OcrInvoker) -> None:
    LOGGER.info("initial scan: %s", watch_dir)
    for pdf in sorted(watch_dir.rglob("*.pdf")):
        if is_candidate_pdf(pdf):
            invoker.process(pdf)


def make_handler(invoker: OcrInvoker):
    from watchdog.events import FileSystemEventHandler  # type: ignore

    class _Handler(FileSystemEventHandler):
        def on_created(self, event):  # type: ignore[override]
            self._handle(event)

        def on_moved(self, event):  # type: ignore[override]
            dest = getattr(event, "dest_path", "")
            if dest:
                self._handle_path(Path(dest))

        def _handle(self, event) -> None:
            if event.is_directory:
                return
            self._handle_path(Path(event.src_path))

        def _handle_path(self, path: Path) -> None:
            if not is_candidate_pdf(path):
                return
            try:
                invoker.process(path)
            except Exception as exc:  # noqa: BLE001 — last-resort guard
                invoker.error_log.record(path, "unhandled exception", detail=repr(exc))

    return _Handler()


def run_watch(watch_dir: Path, invoker: OcrInvoker) -> None:
    try:
        from watchdog.observers import Observer  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "watchdog package is required. Install via `pip install watchdog`.\n"
            f"detail: {exc}"
        )

    observer = Observer()
    observer.schedule(make_handler(invoker), str(watch_dir), recursive=True)
    observer.start()
    LOGGER.info("watching %s (recursive=True)", watch_dir)

    stop_event = threading.Event()

    def _stop(signum, _frame):  # type: ignore[no-untyped-def]
        LOGGER.info("signal %s received; stopping", signum)
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            signal.signal(sig, _stop)
        except (OSError, ValueError):
            pass

    try:
        while not stop_event.wait(timeout=1.0):
            pass
    finally:
        observer.stop()
        observer.join(timeout=10.0)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ocr_watch",
        description="Watch a folder and OCR new PDFs via ocr_pdf.py (cmd_721 Pattern B).",
    )
    parser.add_argument("--watch-dir", required=True, help="Folder to watch (Drive Desktop sync path)")
    parser.add_argument(
        "--ocr-script",
        default=str(Path(__file__).resolve().parent / "ocr_pdf.py"),
        help="Path to ocr_pdf.py (default: sibling of this script)",
    )
    parser.add_argument(
        "--state-file",
        default=None,
        help="Processed state JSON path (default: <watch-dir>/.processed.json)",
    )
    parser.add_argument(
        "--errors-log",
        default=None,
        help="Error log path (default: <watch-dir>/errors.log)",
    )
    parser.add_argument(
        "--enable-tcy",
        action="store_true",
        help="Forward --enable-tcy to ocr_pdf.py (improves 縦中横 for vertical text)",
    )
    parser.add_argument(
        "--python",
        default=sys.executable,
        help="Python executable used to run ocr_pdf.py (default: current interpreter)",
    )
    parser.add_argument(
        "--scan-once",
        action="store_true",
        help="Run initial scan only; do not start the watchdog loop",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log actions without invoking ocr_pdf.py",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        help="Logging level (DEBUG/INFO/WARNING/ERROR)",
    )
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=getattr(logging, args.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

    watch_dir = Path(args.watch_dir).expanduser()
    if not watch_dir.exists():
        parser.error(f"watch-dir does not exist: {watch_dir}")
    if not watch_dir.is_dir():
        parser.error(f"watch-dir is not a directory: {watch_dir}")

    state_path = Path(args.state_file).expanduser() if args.state_file else watch_dir / ".processed.json"
    errors_path = Path(args.errors_log).expanduser() if args.errors_log else watch_dir / "errors.log"
    ocr_script = Path(args.ocr_script).expanduser()

    state_path.parent.mkdir(parents=True, exist_ok=True)
    errors_path.parent.mkdir(parents=True, exist_ok=True)

    store = ProcessedStore(state_path)
    error_log = ErrorLog(errors_path)
    invoker = OcrInvoker(
        python_exe=args.python,
        ocr_script=ocr_script,
        enable_tcy=args.enable_tcy,
        store=store,
        error_log=error_log,
        dry_run=args.dry_run,
    )

    LOGGER.info(
        "config watch_dir=%s ocr_script=%s state=%s errors=%s enable_tcy=%s dry_run=%s",
        watch_dir, ocr_script, state_path, errors_path, args.enable_tcy, args.dry_run,
    )

    initial_scan(watch_dir, invoker)

    if args.scan_once:
        LOGGER.info("--scan-once specified; exiting after initial scan")
        return 0

    run_watch(watch_dir, invoker)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
