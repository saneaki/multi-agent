#!/usr/bin/env python3
"""
ocr_pdf.py — cmd_721 Pattern B core OCR (NDL OCR Lite + PyMuPDF)

Takes an input PDF, runs each page through NDL OCR Lite CLI, and embeds a
transparent (searchable) text layer into a new PDF named "{stem}_ocr.pdf".

Design (cmd_721):
  - Original PDF is never overwritten — output is always a new file.
  - Fully offline. No commercial API calls.
  - NDL OCR Lite GUI beta features are NOT used; we drive its CLI and embed
    text ourselves with PyMuPDF.
  - --enable-tcy is passed through to NDL OCR Lite to improve 縦中横.
  - --dry-run validates inputs / dependencies without performing OCR; safe
    on the VPS where NDL OCR Lite is not installed.

CLI (stable I/F for β `ocr_watch.py`):

    python ocr_pdf.py INPUT_PDF [-o OUTPUT_PDF] [--dpi N] [--enable-tcy]
                                 [--ndl-cmd CMD | --ndl-home PATH]
                                 [--dry-run] [--keep-temp] [-v]

Exit codes:
   0 — success (or dry-run validation passed)
   2 — input not found / output would overwrite input
   3 — PyMuPDF (fitz) not installed
   4 — NDL OCR Lite command not found
   5 — OCR or PDF write failure
"""

from __future__ import annotations

import argparse
import json
import logging
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

try:
    import fitz  # PyMuPDF
except ImportError:
    fitz = None  # type: ignore[assignment]


LOG = logging.getLogger("ocr_pdf")

DEFAULT_DPI = 300
DEFAULT_NDL_CMD = "ndlocr-lite"
DEFAULT_OUTPUT_SUFFIX = "_ocr"
CJK_FONT_NAME = "japan"  # PyMuPDF built-in CJK CIDFont


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="ocr_pdf.py",
        description=(
            "cmd_721 Pattern B core OCR. Rasterize a PDF, run NDL OCR Lite, "
            "and embed a transparent searchable text layer. Original PDF is "
            "never overwritten."
        ),
    )
    p.add_argument("input", help="Path to the input PDF.")
    p.add_argument(
        "-o",
        "--output",
        default=None,
        help=(
            "Output PDF path or directory. Defaults to "
            "'<input_stem>_ocr.pdf' next to the input."
        ),
    )
    p.add_argument(
        "--dpi",
        type=int,
        default=DEFAULT_DPI,
        help=f"Rasterization DPI for OCR (default: {DEFAULT_DPI}).",
    )
    p.add_argument(
        "--enable-tcy",
        action="store_true",
        help="Pass --enable-tcy to NDL OCR Lite (improves 縦中横 in 縦書き).",
    )
    p.add_argument(
        "--ndl-cmd",
        default=None,
        help=(
            "Command to invoke NDL OCR Lite (default: 'ndlocr-lite'). "
            "Mutually exclusive with --ndl-home."
        ),
    )
    p.add_argument(
        "--ndl-home",
        default=None,
        help=(
            "Path to a cloned NDL OCR Lite repo. When set, the script runs "
            "'<python> <ndl-home>/src/ocr.py ...' instead of the installed "
            "console script."
        ),
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Validate inputs, output path, PyMuPDF, and NDL OCR Lite command "
            "without performing rasterization or OCR. Returns exit 0 on PASS."
        ),
    )
    p.add_argument(
        "--keep-temp",
        action="store_true",
        help="Keep the temporary rasterization/JSON directory for inspection.",
    )
    p.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Increase verbosity (-v=INFO, -vv=DEBUG).",
    )
    return p


# ---------------------------------------------------------------------------
# Path & dependency resolution
# ---------------------------------------------------------------------------


def resolve_output_path(input_pdf: Path, output_arg: Optional[str]) -> Path:
    if not output_arg:
        return input_pdf.with_name(f"{input_pdf.stem}{DEFAULT_OUTPUT_SUFFIX}.pdf")
    out = Path(output_arg).expanduser()
    # If the user pointed at a directory (existing or with trailing sep),
    # place "<stem>_ocr.pdf" inside it.
    looks_like_dir = output_arg.endswith(("/", "\\")) or out.is_dir()
    if looks_like_dir:
        return out / f"{input_pdf.stem}{DEFAULT_OUTPUT_SUFFIX}.pdf"
    return out


def assert_safe_output(input_pdf: Path, output_pdf: Path) -> None:
    try:
        same = input_pdf.resolve() == output_pdf.resolve()
    except OSError:
        same = str(input_pdf) == str(output_pdf)
    if same:
        print(
            "ERROR: refusing to overwrite original PDF.\n"
            f"  input  = {input_pdf}\n"
            f"  output = {output_pdf}\n"
            "Pattern B contract: original is read-only; pick a different -o.",
            file=sys.stderr,
        )
        sys.exit(2)


def find_ndl_command(
    ndl_cmd: Optional[str],
    ndl_home: Optional[str],
) -> List[str]:
    """Return the argv prefix for invoking NDL OCR Lite (raises if missing)."""
    if ndl_cmd and ndl_home:
        raise SystemExit("Specify only one of --ndl-cmd or --ndl-home.")
    if ndl_home:
        home = Path(ndl_home).expanduser()
        ocr_py = home / "src" / "ocr.py"
        if not ocr_py.exists():
            raise FileNotFoundError(
                f"NDL OCR Lite not found at {ocr_py}. "
                "Clone https://github.com/ndl-lab/ndlocr-lite and pass --ndl-home <repo>."
            )
        return [sys.executable, str(ocr_py)]
    cmd = ndl_cmd or DEFAULT_NDL_CMD
    parts = shlex.split(cmd)
    if not parts:
        raise SystemExit("--ndl-cmd is empty.")
    binary = parts[0]
    if shutil.which(binary) is None and not Path(binary).exists():
        raise FileNotFoundError(
            f"NDL OCR Lite command not on PATH: '{binary}'. "
            "Install with 'uv tool install <ndlocr-lite repo>' or pass --ndl-home."
        )
    return parts


# ---------------------------------------------------------------------------
# Rasterization
# ---------------------------------------------------------------------------


def _require_fitz() -> None:
    if fitz is None:
        raise SystemExit(
            "PyMuPDF (fitz) is required but not installed. "
            "Run: pip install -r requirements.txt"
        )


def rasterize_pdf(
    input_pdf: Path,
    out_dir: Path,
    dpi: int,
) -> List[dict]:
    """Rasterize each page to PNG at the given DPI.

    Returns a list of per-page records:
      [{
         "page_index": int,
         "png_path": Path,
         "img_w": int, "img_h": int,
         "page_w": float, "page_h": float,
       }, ...]
    """
    _require_fitz()
    out_dir.mkdir(parents=True, exist_ok=True)
    records: List[dict] = []
    with fitz.open(input_pdf) as doc:
        n = len(doc)
        for i in range(n):
            page = doc[i]
            png_path = out_dir / f"page_{i + 1:04d}.png"
            pix = page.get_pixmap(dpi=dpi, alpha=False)
            pix.save(str(png_path))
            records.append(
                {
                    "page_index": i,
                    "png_path": png_path,
                    "img_w": pix.width,
                    "img_h": pix.height,
                    "page_w": float(page.rect.width),
                    "page_h": float(page.rect.height),
                }
            )
    return records


# ---------------------------------------------------------------------------
# NDL OCR Lite invocation
# ---------------------------------------------------------------------------


def run_ndl_ocr(
    ndl_cmd_parts: List[str],
    image_path: Path,
    output_dir: Path,
    enable_tcy: bool,
) -> Path:
    """Run NDL OCR Lite CLI on a single image. Returns the JSON output path."""
    output_dir.mkdir(parents=True, exist_ok=True)
    cmd = list(ndl_cmd_parts) + [
        "--sourceimg",
        str(image_path),
        "--output",
        str(output_dir),
        "--json-only",
    ]
    if enable_tcy:
        cmd.append("--enable-tcy")
    LOG.debug("NDL OCR Lite cmd: %s", " ".join(shlex.quote(c) for c in cmd))
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(
            "NDL OCR Lite failed for "
            f"{image_path}: exit={proc.returncode}\n"
            f"--- stdout ---\n{proc.stdout}\n"
            f"--- stderr ---\n{proc.stderr}"
        )
    expected = output_dir / f"{image_path.stem}.json"
    if not expected.exists():
        raise RuntimeError(
            f"NDL OCR Lite produced no JSON at {expected}.\n"
            f"--- stdout ---\n{proc.stdout}\n"
            f"--- stderr ---\n{proc.stderr}"
        )
    return expected


def parse_ndl_json(json_path: Path) -> Tuple[List[dict], Optional[int], Optional[int]]:
    """Parse NDL OCR Lite JSON.

    NDL JSON structure (NDLOCR-Lite v1.2.1):
      {
        "contents": [[
          {
            "boundingBox": [[xmin,ymin], [xmin,ymin+h], [xmin+w,ymin], [xmin+w,ymin+h]],
            "id": int, "isVertical": "true", "text": "...",
            "isTextline": "true", "confidence": float, "class_index": int
          }, ...
        ]],
        "imginfo": {"img_width": int, "img_height": int, "img_path": str, "img_name": str}
      }

    The bbox corners are NOT in a clockwise order — we just take min/max of the
    four points, which is robust regardless of corner order.

    Note: `isVertical` is reported as the string "true" for every line in v1.2.1;
    we derive verticality from bbox aspect ratio instead.
    """
    with json_path.open(encoding="utf-8") as f:
        data = json.load(f)

    img_info = data.get("imginfo") or {}
    img_w = img_info.get("img_width")
    img_h = img_info.get("img_height")

    items: List[dict] = []
    contents = data.get("contents") or []
    if not contents:
        return items, img_w, img_h
    # contents is documented as [[line, line, ...]] (list of lists); accept both
    # the nested and flat forms in case the schema changes.
    first = contents[0]
    page_lines = first if isinstance(first, list) else contents

    for line in page_lines:
        if not isinstance(line, dict):
            continue
        text = line.get("text") or ""
        if not text:
            continue
        bbox = line.get("boundingBox") or line.get("bbox")
        if not bbox:
            continue
        try:
            xs = [float(pt[0]) for pt in bbox]
            ys = [float(pt[1]) for pt in bbox]
        except (TypeError, IndexError, ValueError):
            LOG.warning("Unexpected bbox shape in %s: %r", json_path.name, bbox)
            continue
        if not xs or not ys:
            continue
        xmin, xmax = min(xs), max(xs)
        ymin, ymax = min(ys), max(ys)
        items.append(
            {
                "text": text,
                "xmin": xmin,
                "ymin": ymin,
                "xmax": xmax,
                "ymax": ymax,
                "is_vertical": (ymax - ymin) > (xmax - xmin),
                "confidence": float(line.get("confidence") or 0.0),
            }
        )
    return items, img_w, img_h


# ---------------------------------------------------------------------------
# Text layer embedding
# ---------------------------------------------------------------------------


def _embed_line(page, item: dict, scale_x: float, scale_y: float) -> None:
    """Embed a single OCR line as invisible text on a PyMuPDF page."""
    text = item["text"]
    if not text.strip():
        return
    x0 = item["xmin"] * scale_x
    y0 = item["ymin"] * scale_y
    x1 = item["xmax"] * scale_x
    y1 = item["ymax"] * scale_y
    rect = fitz.Rect(x0, y0, x1, y1)
    rect_h = max(rect.height, 1.0)
    fontsize = max(min(rect_h * 0.85, 14.0), 3.0)

    # Try a fitted textbox first; fall back to insert_text at a baseline point
    # if the text doesn't fit (long strings in vertical bboxes are common).
    try:
        rc = page.insert_textbox(
            rect,
            text,
            fontsize=fontsize,
            fontname=CJK_FONT_NAME,
            render_mode=3,  # invisible (searchable)
            align=0,
        )
    except Exception as exc:  # pragma: no cover - PyMuPDF specifics
        LOG.debug("insert_textbox raised %s; falling back to insert_text", exc)
        rc = -1

    if rc is None or rc < 0:
        try:
            page.insert_text(
                fitz.Point(x0, y1),  # PDF text baseline at bbox bottom-left
                text,
                fontsize=fontsize,
                fontname=CJK_FONT_NAME,
                render_mode=3,
            )
        except Exception as exc:
            LOG.warning(
                "Could not embed text for bbox=%s (page=%s): %s",
                rect,
                page.number,
                exc,
            )


def embed_text_layer(
    input_pdf: Path,
    output_pdf: Path,
    page_ocr_results: Iterable[dict],
) -> None:
    """Write a copy of input_pdf with invisible OCR text layered on each page."""
    _require_fitz()
    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    with fitz.open(input_pdf) as doc:
        for page_data in page_ocr_results:
            idx = page_data["page_index"]
            if idx < 0 or idx >= len(doc):
                LOG.warning("page_index %d out of range; skipping", idx)
                continue
            page = doc[idx]
            img_w = page_data.get("img_w") or 0
            img_h = page_data.get("img_h") or 0
            if not img_w or not img_h:
                LOG.warning(
                    "page %d missing image dimensions; skipping text embed",
                    idx,
                )
                continue
            scale_x = page.rect.width / float(img_w)
            scale_y = page.rect.height / float(img_h)
            for item in page_data.get("items", []):
                _embed_line(page, item, scale_x, scale_y)
        doc.save(str(output_pdf), garbage=4, deflate=True)


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


def _log_level(verbose: int) -> int:
    if verbose >= 2:
        return logging.DEBUG
    if verbose >= 1:
        return logging.INFO
    return logging.WARNING


def _dry_run(args: argparse.Namespace, input_pdf: Path, output_pdf: Path) -> int:
    print("[DRY-RUN] cmd_721 Pattern B — ocr_pdf.py")
    print(f"  input PDF  : {input_pdf}")
    print(f"  output PDF : {output_pdf}")
    print(f"  dpi        : {args.dpi}")
    print(f"  enable-tcy : {args.enable_tcy}")
    if args.ndl_home:
        print(f"  ndl-home   : {args.ndl_home}")
    else:
        print(f"  ndl-cmd    : {args.ndl_cmd or DEFAULT_NDL_CMD}")

    # PyMuPDF presence
    if fitz is None:
        print("  PyMuPDF    : NOT INSTALLED (will fail at run time)")
    else:
        print(f"  PyMuPDF    : OK (fitz {getattr(fitz, '__doc__', '').splitlines()[0] if fitz.__doc__ else ''})")
        try:
            with fitz.open(input_pdf) as doc:
                print(f"  pdf pages  : {len(doc)}")
        except Exception as exc:
            print(f"  pdf open   : FAILED ({exc})")
            return 5

    # NDL command presence
    try:
        parts = find_ndl_command(args.ndl_cmd, args.ndl_home)
        printable = " ".join(shlex.quote(p) for p in parts)
        print(f"  ndl invoke : OK ({printable})")
    except FileNotFoundError as exc:
        print(f"  ndl invoke : MISSING ({exc})")
        # Dry-run does not fail just because NDL is missing on the VPS —
        # the actual deployment is Windows. We report status and return 0.
    except SystemExit as exc:
        print(f"  ndl invoke : MISCONFIG ({exc})")
        return 2

    print("[DRY-RUN] OK")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(
        level=_log_level(args.verbose),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    input_pdf = Path(args.input).expanduser()
    if not input_pdf.exists():
        print(f"ERROR: input PDF not found: {input_pdf}", file=sys.stderr)
        return 2
    input_pdf = input_pdf.resolve()

    output_pdf = resolve_output_path(input_pdf, args.output).resolve()
    assert_safe_output(input_pdf, output_pdf)

    if args.dry_run:
        return _dry_run(args, input_pdf, output_pdf)

    _require_fitz()
    try:
        ndl_parts = find_ndl_command(args.ndl_cmd, args.ndl_home)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 4

    tmp_ctx = tempfile.TemporaryDirectory(prefix="ocr_pdf_")
    tmp_root = Path(tmp_ctx.name)
    keep = args.keep_temp
    try:
        images_dir = tmp_root / "images"
        json_dir = tmp_root / "json"

        LOG.info("Rasterizing %s at %d dpi", input_pdf.name, args.dpi)
        pages = rasterize_pdf(input_pdf, images_dir, args.dpi)
        LOG.info("Rasterized %d pages", len(pages))

        for rec in pages:
            png_path: Path = rec["png_path"]
            LOG.info(
                "OCR page %d/%d (%s)",
                rec["page_index"] + 1,
                len(pages),
                png_path.name,
            )
            json_path = run_ndl_ocr(
                ndl_parts,
                png_path,
                json_dir,
                args.enable_tcy,
            )
            items, ndl_img_w, ndl_img_h = parse_ndl_json(json_path)
            rec["items"] = items
            # Prefer NDL-reported dimensions; fall back to PyMuPDF pixmap size.
            rec["img_w"] = ndl_img_w or rec["img_w"]
            rec["img_h"] = ndl_img_h or rec["img_h"]
            LOG.info("  -> %d text line(s)", len(items))

        LOG.info("Embedding transparent text layer into %s", output_pdf)
        embed_text_layer(input_pdf, output_pdf, pages)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 5
    finally:
        if keep:
            LOG.warning("Temp dir kept at %s", tmp_root)
            tmp_ctx._finalizer.detach()  # type: ignore[attr-defined]
        else:
            tmp_ctx.cleanup()

    LOG.info("Done. Output: %s", output_pdf)
    print(str(output_pdf))
    return 0


if __name__ == "__main__":
    sys.exit(main())
