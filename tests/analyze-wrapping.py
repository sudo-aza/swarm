#!/usr/bin/env python3
"""
analyze-wrapping.py — QA tool for swarmwrap.sty text wrapping analysis

Usage:
    python3 analyze-wrapping.py <pdf_file> [--verbose]
    python3 analyze-wrapping.py <pdf_file> [--json]

Detects three categories of issues in swarmwrap-rendered PDFs:

  1. OVERLAP — Body text extends into the figure's bounding rectangle.
     Reported as: "overlap found (page N, M line(s))"
     A real overlap means a text line whose LEFT edge starts at the normal
     body margin (x0 ~117pt for A4 11pt) and whose RIGHT edge extends
     past the figure's left edge (x0 ~391pt), while the text is within
     the figure's vertical range (y0 to y1). Caption text that starts
     INSIDE the figure (x0 ~391pt) is correctly identified as caption,
     not body text, and is excluded.

  2. WRONGFUL WHITESPACE — Narrow text lines appear below the figure's
     bottom edge with nothing to wrap around. This is "ghost narrowing"
     caused by parshape persisting across paragraph/page boundaries while
     the figure (placed via \\smash{\\rlap}) does not persist.
     Reported as: "wrongful whitespace found at page N (M line(s))"

  3. CLEAN — No overlaps or ghost narrowing detected.
     Reported as: "no problem found; review the file yourself"

Requires: PyMuPDF (fitz)
    pip3 install --break-system-packages pymupdf
"""

import sys
import json
import fitz  # PyMuPDF


# ── Configuration ────────────────────────────────────────────────────────────

# Minimum figure rectangle size (pt) to be considered a swarmwrap figure.
# Filters out small decorations, table rules, etc.
MIN_FIG_WIDTH = 30
MIN_FIG_HEIGHT = 30

# Tolerance (pt) for "text starts at figure's left edge" detection.
# Caption text starts at approximately the figure's x0; body text starts
# at the page margin (~117pt). A text line whose x0 is within this
# tolerance of the figure's x0 is classified as caption, not body text.
CAPTION_X_TOLERANCE = 10

# How many pt narrower than full-width text must a line be to count as
# "narrow" (i.e., wrapped around a figure).
NARROW_THRESHOLD = 40

# Text below this y-coordinate on a page is treated as page number /
# footer and excluded from analysis. For A4 at 11pt, the page number
# typically appears around y=738.
FOOTER_Y_MIN = 700

# How far (pt) below the EFFECTIVE figure bottom (including caption)
# a narrow body-text line must be to count as ghost narrowing.
# The effective figure bottom is computed from caption text extent.
GHOST_MARGIN = 10

# How close (pt) a narrow line's x1 must be to the expected parshape
# narrow width to count as ghost narrowing. The expected parshape
# narrow width is approximately fig.x0 - 14pt (the gap). Lines that
# are narrower than this are just short last lines of paragraphs
# (ragged-right), not parshape ghost narrowing.
GHOST_PARSHAPE_TOLERANCE = 25

# The gap between the narrowed text area and the figure, in pt.
# swarmwrap.sty uses 14pt. Used to compute expected narrow width.
FIGURE_GAP_PT = 14


# ── Data Extraction ──────────────────────────────────────────────────────────

def get_text_lines(page):
    """
    Extract text lines from a PDF page with bounding box info.

    Returns a list of dicts:
        {x0, y0, x1, y1, width, text}

    Sorted by y (top to bottom), then x (left to right).
    Lines with no text or outside the body area (x0 < 80) are excluded.
    """
    blocks = page.get_text("dict")["blocks"]
    lines = []

    for block in blocks:
        if block["type"] != 0:  # skip image blocks
            continue
        for line in block["lines"]:
            if not line["spans"]:
                continue
            x0 = min(s["bbox"][0] for s in line["spans"])
            y0 = min(s["bbox"][1] for s in line["spans"])
            x1 = max(s["bbox"][2] for s in line["spans"])
            y1 = max(s["bbox"][3] for s in line["spans"])
            text = "".join(s["text"] for s in line["spans"]).strip()
            if text and x0 > 80:  # skip headers, footers, margin notes
                lines.append({
                    "x0": x0, "y0": y0, "x1": x1, "y1": y1,
                    "width": x1 - x0,
                    "text": text,
                })

    lines.sort(key=lambda l: (l["y0"], l["x0"]))
    return lines


def get_figure_rects(page):
    """
    Extract filled rectangles from page drawings (potential swarmwrap figures).

    swarmwrap.sty places figures via \\smash{\\rlap{...}}, which overlays
    the figure content at a specific position. The figure body (e.g.,
    \\rule{\\linewidth}{2.5cm}) renders as a filled rectangle.

    Returns a list of fitz.Rect objects, filtered by minimum size.
    """
    rects = []
    for drawing in page.get_drawings():
        fill = drawing.get("fill")
        if fill is None:
            continue
        for item in drawing.get("items", []):
            if item[0] == "re":  # rectangle path
                r = item[1]  # fitz.Rect
                if r.width >= MIN_FIG_WIDTH and r.height >= MIN_FIG_HEIGHT:
                    rects.append(r)
    return rects


def compute_effective_fig_bottom(fig_rect, lines):
    """
    Compute the effective bottom of a figure, including caption text.

    The \rule in the swarmwrap figure renders as a filled rectangle, but
    the caption text (\\captionof) extends below it. This function finds
    the lowest text line that starts within the figure's x-range (i.e.,
    caption text) and returns that as the effective figure bottom.

    If no caption text is found, returns the \rule rectangle's bottom.
    """
    fig_left = fig_rect.x0
    fig_right = fig_rect.x1
    effective_bottom = fig_rect.y1

    for line in lines:
        # Skip footer text
        if line["y0"] > FOOTER_Y_MIN:
            continue
        # Caption text starts near the figure's left edge
        if abs(line["x0"] - fig_left) <= CAPTION_X_TOLERANCE:
            line_bottom = line["y1"]
            if line_bottom > effective_bottom:
                effective_bottom = line_bottom

    return effective_bottom


def compute_full_text_width(lines, page_width):
    """
    Compute the typical full (unwrapped) text width for a page.

    Uses the median of the top 20% widest lines to avoid being skewed
    by section headers, captions, or other short lines.
    """
    if not lines:
        return page_width - 117  # rough estimate for A4 11pt

    widths = sorted([l["width"] for l in lines], reverse=True)
    top_n = max(1, len(widths) // 5)
    return sum(widths[:top_n]) / top_n


# ── Analysis ─────────────────────────────────────────────────────────────────

def classify_line_overlap(line, fig_rect, page_margin_x0):
    """
    Classify whether a text line overlaps with a figure rectangle.

    Returns:
        "body_overlap" — body text (starting at page margin) extends into
            the figure's horizontal range while within the figure's
            vertical range. This is a REAL overlap.
        "caption" — text starts at approximately the figure's left edge,
            indicating it's caption text INSIDE the figure. NOT an overlap.
        "below" — text is entirely below the figure. NOT an overlap.
        "above" — text is entirely above the figure. NOT an overlap.
        "none" — text does not overlap the figure's horizontal range.
    """
    fig_left = fig_rect.x0
    fig_right = fig_rect.x1
    fig_top = fig_rect.y0
    fig_bottom = fig_rect.y1

    line_top = line["y0"]
    line_bottom = line["y1"]
    line_left = line["x0"]
    line_right = line["x1"]

    # Vertical check
    if line_bottom <= fig_top:
        return "above"
    if line_top >= fig_bottom:
        return "below"

    # Vertical overlap exists. Check horizontal.
    if line_right <= fig_left + 2:
        return "none"  # text ends before figure starts

    # Text extends into figure's x-range. Is it body text or caption?
    if abs(line_left - fig_left) <= CAPTION_X_TOLERANCE:
        return "caption"  # starts at figure's left edge → caption text

    if line_left < fig_left - CAPTION_X_TOLERANCE:
        # Starts well before the figure → body text extending into figure
        return "body_overlap"

    # Ambiguous: starts near figure but not exactly at it
    return "caption"


def analyze_page(page_num, page, full_text_width):
    """
    Analyze a single page for overlaps and ghost narrowing.

    Returns a dict:
        {
            "page": <1-based page number>,
            "figures": [<fig_rect>],
            "overlaps": [<detail dict>],
            "ghost_lines": [<detail dict>],
        }
    """
    result = {
        "page": page_num,
        "figures": [],
        "overlaps": [],
        "ghost_lines": [],
    }

    lines = get_text_lines(page)
    fig_rects = get_figure_rects(page)

    if not fig_rects:
        return result

    result["figures"] = [{"x0": r.x0, "y0": r.y0, "x1": r.x1, "y1": r.y1}
                         for r in fig_rects]

    narrow_cutoff = full_text_width - NARROW_THRESHOLD

    for fig in fig_rects:
        for line in lines:
            classification = classify_line_overlap(line, fig, 117.8)

            if classification == "body_overlap":
                result["overlaps"].append({
                    "text": line["text"][:80],
                    "line_y": round(line["y0"], 1),
                    "line_x0": round(line["x0"], 1),
                    "line_x1": round(line["x1"], 1),
                    "fig_y_range": (round(fig.y0, 1), round(fig.y1, 1)),
                })

            elif classification == "below":
                # Skip footer text
                if line["y0"] > FOOTER_Y_MIN:
                    continue
                # Check for ghost narrowing: narrow body text below the figure
                # Use effective figure bottom (includes caption text)
                effective_bottom = compute_effective_fig_bottom(fig, lines)
                is_body_text = line["x0"] < fig.x0 - CAPTION_X_TOLERANCE
                # Expected parshape narrow width: fig.x0 - gap
                expected_narrow_x1 = fig.x0 - FIGURE_GAP_PT
                is_parshape_narrow = abs(line["x1"] - expected_narrow_x1) \
                    <= GHOST_PARSHAPE_TOLERANCE
                if (is_body_text
                        and is_parshape_narrow
                        and line["y0"] > effective_bottom + GHOST_MARGIN):
                    result["ghost_lines"].append({
                        "text": line["text"][:80],
                        "line_y": round(line["y0"], 1),
                        "line_x1": round(line["x1"], 1),
                        "line_width": round(line["width"], 1),
                        "effective_fig_bottom": round(effective_bottom, 1),
                    })

    return result


def analyze_pdf(pdf_path, verbose=False):
    """
    Analyze an entire PDF for swarmwrap wrapping issues.

    Returns a list of per-page analysis results.
    """
    doc = fitz.open(pdf_path)
    page_results = []

    for page_num in range(len(doc)):
        page = doc[page_num]
        lines = get_text_lines(page)
        full_width = compute_full_text_width(lines, page.rect.width)

        result = analyze_page(page_num + 1, page, full_width)
        page_results.append(result)

        if verbose:
            print(f"\n{'='*60}")
            print(f"Page {page_num + 1}  (full_width={full_width:.1f}pt)")
            if result["figures"]:
                for fig in result["figures"]:
                    print(f"  Figure: ({fig['x0']:.1f},{fig['y0']:.1f})"
                          f"-({fig['x1']:.1f},{fig['y1']:.1f})")
            if result["overlaps"]:
                print(f"  OVERLAPS: {len(result['overlaps'])}")
                for o in result["overlaps"]:
                    print(f"    y={o['line_y']} x=[{o['line_x0']},{o['line_x1']}]"
                          f" | {o['text']}")
            if result["ghost_lines"]:
                print(f"  GHOST: {len(result['ghost_lines'])}")
                for g in result["ghost_lines"]:
                    print(f"    y={g['line_y']} x1={g['line_x1']}"
                          f" (eff_fig_bottom={g['effective_fig_bottom']})"
                          f" | {g['text']}")
            if not result["overlaps"] and not result["ghost_lines"]:
                if result["figures"]:
                    print("  CLEAN (figure present, no issues)")
                else:
                    print("  (no figures)")

    doc.close()
    return page_results


# ── Output Formatting ────────────────────────────────────────────────────────

def format_report(page_results):
    """
    Format the analysis results as human-readable text.

    Returns one of three messages:
      - "overlap found (page N, M line(s))"
      - "wrongful whitespace found at page N (M line(s))"
      - "no problem found; review the file yourself"
    """
    all_overlaps = []
    all_ghost = []

    for r in page_results:
        if r["overlaps"]:
            all_overlaps.append(r)
        if r["ghost_lines"]:
            all_ghost.append(r)

    messages = []

    if all_overlaps:
        for r in all_overlaps:
            n = len(r["overlaps"])
            messages.append(f"overlap found (page {r['page']}, {n} line(s))")

    if all_ghost:
        for r in all_ghost:
            n = len(r["ghost_lines"])
            messages.append(
                f"wrongful whitespace found at page {r['page']} ({n} line(s))")

    if messages:
        return "\n".join(messages)
    else:
        return "no problem found; review the file yourself"


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze-wrapping.py <pdf_file> [--verbose] [--json]",
              file=sys.stderr)
        sys.exit(1)

    pdf_path = sys.argv[1]
    verbose = "--verbose" in sys.argv
    as_json = "--json" in sys.argv

    try:
        results = analyze_pdf(pdf_path, verbose=verbose)
    except FileNotFoundError:
        print(f"Error: file not found: {pdf_path}", file=sys.stderr)
        sys.exit(1)
    except fitz.FileDataError:
        print(f"Error: not a valid PDF: {pdf_path}", file=sys.stderr)
        sys.exit(1)

    if as_json:
        # Remove empty fields for cleaner JSON output
        clean = []
        for r in results:
            entry = {"page": r["page"]}
            if r["figures"]:
                entry["figures"] = r["figures"]
            if r["overlaps"]:
                entry["overlaps"] = r["overlaps"]
            if r["ghost_lines"]:
                entry["ghost_lines"] = r["ghost_lines"]
            clean.append(entry)
        print(json.dumps(clean, indent=2))
    else:
        print(format_report(results))


if __name__ == "__main__":
    main()
