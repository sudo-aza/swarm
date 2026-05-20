#!/usr/bin/env python3
"""
detect-layout-issues.py — Comprehensive layout issue detector for swarmwrap.sty.

Catches the visual bugs that coordinate-only analysis misses:
  1. FIGURE BESIDE TEXT CHECK — is there actually text wrapping around each figure?
  2. NEAR-EMPTY PAGES — pages with <10% ink coverage
  3. TEXT-FIGURE OVERLAP — text rendered on top of a figure
  4. GHOST NARROWING — text narrowed by parshape but no figure on page
  5. EXTRA VSPACE BELOW FIGURE — gap >1 baselineskip between last wrapped line
     and figure bottom where text should be wrapping
  6. HOLLOW CARRY-OVER — first line of page narrowed with no figure present
  7. FIGURE MISALIGNED — figure not flush with right text margin

Usage:
  python3 scripts/detect-layout-issues.py <file.pdf> [options]
  python3 scripts/detect-layout-issues.py <file.pdf> --page 3    # single page
  python3 scripts/detect-layout-issues.py <file.pdf> --summary   # counts only
  python3 scripts/detect-layout-issues.py <file.pdf> --quality   # quality report

Exit codes:
  0 = no issues found
  1 = issues found (exit code = number of issue categories with hits)

Requires: PyMuPDF (fitz)
"""

import sys
import re
import argparse
import fitz  # PyMuPDF


def parse_args():
    p = argparse.ArgumentParser(
        description="Detect layout issues in swarmwrap PDFs")
    p.add_argument("pdf", help="Path to PDF")
    p.add_argument("--page", type=int, default=None,
                   help="Only analyze specific page (1-based)")
    p.add_argument("--summary", action="store_true",
                   help="Print summary counts only, no per-page details")
    p.add_argument("--min-adjacent-lines", type=int, default=2,
                   help="Min text lines beside figure to consider wrapping OK "
                        "(default: 2)")
    p.add_argument("--empty-threshold", type=float, default=0.10,
                   help="Max ink coverage ratio for near-empty page flag "
                        "(default: 0.10 = 10%%)")
    p.add_argument("--overlap-tolerance", type=float, default=100.0,
                   help="Min overlap area (pt^2) to flag (default: 100.0)")
    p.add_argument("--extra-vspace", type=float, default=18.0,
                   help="Max gap (pt) between last wrapped line and figure "
                        "bottom before flagging (default: 18.0 ~= 1.5 baselineskip)")
    p.add_argument("--quality", action="store_true",
                   help="Print quality report with pass/fail per category "
                        "and overall score")
    return p.parse_args()


def get_figures(page):
    """Get figure/image rectangles on a page (images + filled drawings).

    Uses iterative merging to properly consolidate overlapping/nearby rects
    from smash/rlap drawings into single figure regions.
    """
    figures = []

    # Images placed via \includegraphics
    for img_info in page.get_images(full=True):
        xref = img_info[0]
        for r in page.get_image_rects(xref):
            figures.append(r)

    # Filled drawings (from \smash{\rlap{\hbox{...}}})
    for d in page.get_drawings():
        r = d["rect"]
        dtype = d.get("type", "")
        if dtype in ("f", "fs", "re"):
            if r.width > 50 and r.height > 30:
                figures.append(r)

    # Merge overlapping/nearby rects — iterate until stable
    if not figures:
        return []
    figures.sort(key=lambda r: (r.y0, r.x0))
    changed = True
    while changed:
        changed = False
        new_figures = [figures[0]]
        for r in figures[1:]:
            did_merge = False
            for i, m in enumerate(new_figures):
                if r.intersects(m) or (
                    abs(r.y0 - m.y0) < 5 and abs(r.x0 - m.x0) < 5
                ):
                    new_figures[i] = r | m  # union
                    did_merge = True
                    changed = True
                    break
            if not did_merge:
                new_figures.append(r)
        figures = new_figures
    return figures


def get_text_lines(page):
    """Get text line bounding boxes with text content."""
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
    lines = []
    for block in blocks:
        if block["type"] != 0:
            continue
        for line in block["lines"]:
            text = "".join(span["text"] for span in line["spans"]).strip()
            if not text:
                continue
            bbox = fitz.Rect(line["bbox"])
            font_size = max((span["size"] for span in line["spans"]), default=10.0)
            lines.append({
                "text": text[:80],
                "rect": bbox,
                "x0": bbox.x0, "y0": bbox.y0,
                "x1": bbox.x1, "y1": bbox.y1,
                "width": bbox.width,
                "fontsize": font_size,
            })
    return lines


def _is_multicol_page(body_lines):
    """Detect if page uses multicol layout (two or more text columns).

    Multicol pages have body text lines starting at 2+ distinct x0 positions
    that are widely separated (e.g., left column at x=118, right column at x=302).
    Single-column pages may have x0 variation from paragraph indentation
    (~79pt) or text block splitting (~100pt), but these are NOT multicol.

    v7 fix (2026-05-20): Previous version used 5pt clustering tolerance, which
    caused false positives on single-column pages where paragraph indentation
    (x=118 vs x=197) or text block boundaries (x=323) created multiple clusters.
    Now requires clusters to be separated by at least 120pt to count as
    distinct columns. This correctly distinguishes multicol (column gap ~180pt)
    from paragraph indentation (~79pt).

    Returns (is_multicol, page_width) where page_width is the FULL page
    text width (left margin to right margin), not the column width.
    """
    if not body_lines:
        return False, 0

    # Cluster x0 positions — use wide tolerance (25pt) to group paragraph
    # indentation (79pt from margin) with the margin position.
    # Then check if clusters are separated by enough for true columns.
    x0_positions = sorted(set(round(l["x0"]) for l in body_lines))
    clusters = []
    for x0 in x0_positions:
        if clusters and abs(x0 - clusters[-1][-1]) <= 25:
            clusters[-1].append(x0)
        else:
            clusters.append([x0])

    if len(clusters) < 2:
        return False, 0

    # Check inter-cluster gap: true multicol columns are separated by
    # at least 120pt. Paragraph indentation creates ~79pt gaps.
    is_true_multicol = False
    for i in range(1, len(clusters)):
        gap = clusters[i][0] - clusters[i - 1][-1]
        if gap >= 120:
            is_true_multicol = True
            break

    if not is_true_multicol:
        return False, 0

    # Page width = rightmost text edge minus leftmost text edge
    max_x1 = max(l["x1"] for l in body_lines)
    min_x0 = min(clusters[0])
    page_width = max_x1 - min_x0

    return True, page_width


def detect_figure_beside_text(page_num, figures, text_lines, min_adjacent):
    """
    CRITICAL CHECK: For each figure, verify text actually wraps BESIDE it.

    A figure has proper wrapping if text lines exist whose vertical range
    overlaps with the figure AND whose width is NARROWED (significantly less
    than the page's full text width) — proving the text gave up space for the figure.

    If all text is at full width, the figure is 'outside text' — the bug Zoe
    keeps finding. Text flows at full width and figures are just overlaid or
    placed beside without actual wrapping.

    Improvement (v5, 2026-05-20):
    Detect multicol pages and use PAGE width (not column width) as the
    full_width baseline. Previously, the 90th percentile picked up the
    column width on multicol pages, causing false positives: text at column
    width was labeled "full-width" when it was actually wrapping around the
    figure within the column.
    """
    issues = []

    if not figures:
        return issues

    # Compute the page's full text width from the widest body lines
    body_lines = [l for l in text_lines if l["width"] > 150 and l["fontsize"] >= 9.0]
    if not body_lines:
        return issues

    # Check for multicol layout
    is_multicol, multicol_page_width = _is_multicol_page(body_lines)

    widths = sorted([l["width"] for l in body_lines])
    # Full width = 90th percentile of body line widths
    idx = max(0, int(len(widths) * 0.9) - 1)
    full_width = widths[idx]

    # On multicol pages, use page width instead of column width
    if is_multicol and multicol_page_width > full_width:
        full_width = multicol_page_width

    for i, fig in enumerate(figures):
        # Find text lines that overlap vertically with the figure
        beside_lines = []
        narrowed_beside = []  # Actually wrapping (narrowed)
        fullwidth_beside = []  # Full width (not wrapping)

        for line in text_lines:
            vert_overlap = (line["y1"] > fig.y0 + 2) and (line["y0"] < fig.y1 - 2)
            if not vert_overlap:
                continue

            # Check if text is to the LEFT of the figure
            if line["x1"] <= fig.x0 + 5:
                beside_lines.append(line)
                # Is this line actually NARROWED (wrapping) or full width?
                if line["width"] < full_width - 30:  # >30pt narrower = wrapping
                    narrowed_beside.append(line)
                else:
                    fullwidth_beside.append(line)

        n_beside = len(beside_lines)
        n_narrowed = len(narrowed_beside)
        n_fullwidth = len(fullwidth_beside)

        if n_narrowed < min_adjacent:
            severity = "CRITICAL" if n_narrowed == 0 else "WARNING"
            issues.append({
                "page": page_num + 1,
                "severity": severity,
                "fig_idx": i,
                "fig_rect": fig,
                "n_narrowed": n_narrowed,
                "n_fullwidth": n_fullwidth,
                "full_width": full_width,
                "desc": (
                    f"  [{severity}] FIGURE BESIDE TEXT page {page_num + 1} "
                    f"fig[{i}]: only {n_narrowed} NARROWED text line(s) beside figure "
                    f"(need >= {min_adjacent}). "
                    f"Figure: x={fig.x0:.0f}-{fig.x1:.0f}, "
                    f"y={fig.y0:.0f}-{fig.y1:.0f}, "
                    f"size={fig.width:.0f}x{fig.height:.0f}pt. "
                    f"Full-width text beside fig: {n_fullwidth} lines "
                    f"(page full_width={full_width:.0f}pt" +
                    (", multicol" if is_multicol else "") + ")."
                ),
            })

    return issues


def detect_near_empty_pages(page_num, page, text_lines, threshold):
    """Detect pages with very low ink coverage."""
    issues = []

    # Calculate ink coverage: sum of text line areas / page area
    page_rect = page.rect
    page_area = page_rect.width * page_rect.height

    if page_area == 0:
        return issues

    ink_area = 0
    for line in text_lines:
        ink_area += line["rect"].width * line["rect"].height

    # Also count figure areas
    for fig in get_figures(page):
        ink_area += fig.width * fig.height

    coverage = ink_area / page_area

    if coverage < threshold:
        issues.append({
            "page": page_num + 1,
            "coverage": coverage,
            "desc": (
                f"  NEAR-EMPTY page {page_num + 1}: "
                f"ink coverage = {coverage * 100:.1f}% "
                f"(threshold: {threshold * 100:.0f}%). "
                f"Text lines: {len(text_lines)}, "
                f"Figures: {len(get_figures(page))}"
            ),
        })

    return issues


# Patterns for caption text that legitimately overlaps figure rectangles
_CAPTION_PATTERNS = [
    re.compile(r'\\?Figure\s*\d*', re.IGNORECASE),
    re.compile(r'\\?Fig\.?\s*\d*'),
    re.compile(r'\(\d+cm\s*x\s*\d+cm\)'),  # (3cmx6cm)
    re.compile(r'\d+cm\s*x\s*\d+cm'),  # 3cmx6cm
    re.compile(r'^\d{1,4}$'),  # standalone figure numbers (e.g. "699", "700")
    re.compile(r'^\d{1,4}:$'),  # figure numbers with colon (e.g. "700:")
]


def _is_caption_text(text):
    """Check if text is a figure caption or dimension label."""
    for pat in _CAPTION_PATTERNS:
        if pat.search(text):
            return True
    return False


def detect_overlaps(page_num, figures, text_lines, tolerance):
    """Detect text lines overlapping figure rectangles.

    VLM-validated improvement (v3, 2026-05-20):
    The old bbox-intersection approach produced massive false positives.
    Text bounding boxes extend from baseline to ascender, creating
    vertical bbox "overlap" even when actual text pixels are well clear
    of the figure. Now requires the text line's RIGHT edge (x1) to
    extend PAST the figure's LEFT edge (x0) by at least min_penetration
    points — proving actual horizontal intrusion, not just bbox proximity.

    Also filters out caption text (figure labels, dimension annotations)
    which legitimately overlap the figure rectangle.
    Returns (body_overlaps, caption_overlaps).
    """
    issues = []
    caption_overlaps = []
    min_penetration = 8.0  # text must extend >=8pt INTO figure horizontally

    for line in text_lines:
        for fig in figures:
            # Vertical overlap check (with small tolerance for bbox vs pixels)
            vert_overlap = (line["rect"].y1 > fig.y0 + 2) and (
                line["rect"].y0 < fig.y1 - 2
            )
            if not vert_overlap:
                continue

            # Horizontal penetration: text right edge past figure left edge
            penetration = line["rect"].x1 - fig.x0
            if penetration < min_penetration:
                continue

            overlap_rect = line["rect"] & fig
            if overlap_rect.get_area() > tolerance:
                entry = {
                    "page": page_num + 1,
                    "desc": (
                        f"  OVERLAP page {page_num + 1}: "
                        f"\"{line['text'][:40]}\" overlaps figure "
                        f"(area: {overlap_rect.width:.0f}x{overlap_rect.height:.0f}pt, "
                        f"penetration: {penetration:.0f}pt)"
                    ),
                }
                if _is_caption_text(line["text"]):
                    caption_overlaps.append(entry)
                else:
                    issues.append(entry)
                break
    return issues, caption_overlaps


def detect_ghost_narrowing(page_num, text_lines, figures):
    """Detect text narrowed by parshape with no figure on page.

    VLM-validated improvements (v4, 2026-05-20):
    - Use MEDIAN width as full_width baseline.
    - Increase threshold from 40pt to 60pt.
    - Require STRICTLY CONTIGUOUS narrowing from the FIRST body line.
      Ghost narrowing is a parshape leak — it affects the very first lines
      of a new page (carried over from previous page's figure). If the first
      line is narrow but the second is full-width, that's just a paragraph
      continuation (last line of a paragraph), NOT ghost narrowing.
    - If a gap of >1 full-width line occurs after narrowed lines, reset
      the contiguous counter and discard previously found narrowed lines.
      This prevents scattered short sentences mid-page from accumulating
      into a false positive (was the main bug in v3).
    - Only count lines in the top 60% of the page body.
    - Break early if the first body line is full-width (common case for
      normal pages — no need to scan further).
    """
    issues = []
    if figures:
        return issues

    body_lines = [l for l in text_lines if l["width"] > 150 and l["fontsize"] >= 9.0]
    if not body_lines:
        return issues

    # Sort by vertical position (top to bottom)
    body_lines.sort(key=lambda l: l["y0"])

    # Use MEDIAN width as full_width — more robust than 90th percentile
    widths = sorted([l["width"] for l in body_lines])
    if not widths:
        return issues
    full_width = widths[len(widths) // 2]

    # Ghost narrowing threshold: 60pt
    NARROW_THRESHOLD = 60

    # Compute page body range for top-limit check
    max_y = body_lines[-1]["y0"] if body_lines else 0
    min_y = body_lines[0]["y0"] if body_lines else 0
    page_body_range = max_y - min_y
    top_limit = min_y + page_body_range * 0.6

    # Ghost narrowing must start from the FIRST body line on the page.
    # If the first line is full-width, there is no ghost narrowing.
    if full_width - body_lines[0]["width"] <= NARROW_THRESHOLD:
        return issues  # First line is full-width — no ghost narrowing

    # Now scan for contiguous narrowed lines starting from the top.
    # Allow at most 1 full-width line gap before resetting.
    narrowed = []
    gap_count = 0  # Count consecutive full-width lines after narrowing

    for i, line in enumerate(body_lines):
        if line["y0"] > top_limit:
            break
        if full_width - line["width"] > NARROW_THRESHOLD:
            narrowed.append(line)
            gap_count = 0  # Reset gap on narrow line
        else:
            gap_count += 1
            if gap_count > 1:
                # More than 1 consecutive full-width line after narrowing:
                # the contiguous narrowing has ended. Stop collecting.
                break
            # gap_count == 1: allow 1 gap (e.g., a short full-width line
            # between two narrow lines)

    # Require at least 2 narrowed lines to report
    if len(narrowed) >= 2:
        issues.append({
            "page": page_num + 1,
            "n_narrowed": len(narrowed),
            "full_width": full_width,
            "narrowest": min(l["width"] for l in narrowed),
            "desc": (
                f"  GHOST NARROW page {page_num + 1}: "
                f"{len(narrowed)} lines narrowed "
                f"(full={full_width:.0f}pt, narrowest={min(l['width'] for l in narrowed):.0f}pt) "
                f"— no figure on this page"
            ),
        })

    return issues


def detect_extra_vspace(page_num, figures, text_lines, threshold):
    """
    Detect figures with excessive vspace below them.

    On a page with a figure, if the last text line ABOVE the figure has
    a gap > threshold to the figure top, that's wasted space.
    Also: if the first text line BELOW the figure has a gap > threshold
    from figure bottom, that's extra vspace (the '1 line too much' bug).
    """
    issues = []
    if not figures:
        return issues

    for i, fig in enumerate(figures):
        # Find the closest text line below the figure
        below_lines = [l for l in text_lines if l["y0"] >= fig.y1 - 2]
        below_lines.sort(key=lambda l: l["y0"])

        if below_lines:
            gap = below_lines[0]["y0"] - fig.y1
            if gap > threshold:
                issues.append({
                    "page": page_num + 1,
                    "desc": (
                        f"  EXTRA VSPACE page {page_num + 1} fig[{i}]: "
                        f"{gap:.0f}pt gap below figure bottom "
                        f"(threshold: {threshold:.0f}pt). "
                        f"Figure y={fig.y0:.0f}-{fig.y1:.0f}, "
                        f"next text at y={below_lines[0]['y0']:.0f}"
                    ),
                })

        # Find the closest text line above the figure
        above_lines = [l for l in text_lines if l["y1"] <= fig.y0 + 2]
        above_lines.sort(key=lambda l: -l["y1"])  # closest to fig first

        if above_lines:
            gap = fig.y0 - above_lines[0]["y1"]
            if gap > threshold:
                issues.append({
                    "page": page_num + 1,
                    "desc": (
                        f"  EXTRA VSPACE ABOVE page {page_num + 1} fig[{i}]: "
                        f"{gap:.0f}pt gap above figure top "
                        f"(threshold: {threshold:.0f}pt). "
                        f"Prev text at y={above_lines[0]['y1']:.0f}, "
                        f"figure at y={fig.y0:.0f}"
                    ),
                })

    return issues


def detect_hollow_carryover(page_num, text_lines, figures):
    """
    Detect hollow carry-over: first line(s) of page narrowed but no figure.

    This happens when parshape from a previous page's figure leaks to the
    next page's first line.

    VLM-validated improvement (v2, 2026-05-20):
    A single narrow first line is NOT sufficient for hollow carryover — it
    could be the last line of a paragraph that started on the previous page
    (a normal paragraph continuation, not a parshape leak). REAL hollow
    carryover affects the first TWO+ lines of the page. Require at least
    2 of the first 3 body lines to be narrowed (>40pt below full width).
    This eliminates false positives from paragraph continuations.
    """
    issues = []
    if figures:
        return issues
    if not text_lines:
        return issues

    # Get the first body text line on the page (skip short lines like headers)
    body_lines = [l for l in text_lines if l["width"] > 150 and l["fontsize"] >= 9.0]
    if not body_lines:
        return issues
    if len(body_lines) < 3:
        return issues  # Need at least 3 lines to assess

    # Sort by vertical position
    body_lines.sort(key=lambda l: l["y0"])

    # Compute full width from the MEDIAN of all body lines (robust baseline)
    widths = sorted([l["width"] for l in body_lines])
    full_width = widths[len(widths) // 2]

    # Check how many of the first 3 lines are narrowed
    first3 = body_lines[:3]
    n_narrow_first3 = sum(
        1 for l in first3 if full_width - l["width"] > 40
    )

    # Require at least 2 of the first 3 lines to be narrowed
    if n_narrow_first3 >= 2:
        first_line = body_lines[0]
        issues.append({
            "page": page_num + 1,
            "n_narrow": n_narrow_first3,
            "full_width": full_width,
            "desc": (
                f"  HOLLOW CARRY-OVER page {page_num + 1}: "
                f"{n_narrow_first3}/3 first lines narrowed "
                f"(full={full_width:.0f}pt, first=\"{first_line['text'][:50]}\", "
                f"first_w={first_line['width']:.0f}pt) "
                f"— no figure on this page"
            ),
        })

    return issues


def detect_figure_misaligned(page_num, figures, text_lines):
    """Detect figures not flush with the right text margin.

    swarmwrap.sty places figures at the RIGHT side of the text area.
    A figure is misaligned if its right edge is >15pt away from the
    rightmost text edge on the page. This catches figures that have
    shifted left (e.g., due to itemize parshape leak) or are centered
    instead of right-aligned.

    Added (v6, 2026-05-20): QA visual inspection confirmed this is a
    useful check — misaligned figures are visually obvious and indicate
    layout bugs.

    v6.1 fix: Skip multicol pages. In multicol, figures are placed
    within a column and naturally won't be at the full text area right
    margin. All 39 initial detections were on multicol pages (FPs).
    """
    issues = []
    if not figures:
        return issues

    body_lines = [l for l in text_lines if l["width"] > 150 and l["fontsize"] >= 9.0]
    if not body_lines:
        return issues

    # Skip multicol pages — figures are within columns, not at page margin
    is_multicol, _ = _is_multicol_page(body_lines)
    if is_multicol:
        return issues

    # The rightmost text edge defines the text area boundary
    max_text_x1 = max(l["x1"] for l in body_lines)
    MARGIN_THRESHOLD = 15.0  # >15pt gap = misaligned

    for i, fig in enumerate(figures):
        gap = max_text_x1 - fig.x1
        if gap > MARGIN_THRESHOLD:
            issues.append({
                "page": page_num + 1,
                "gap": gap,
                "desc": (
                    f"  FIGURE MISALIGNED page {page_num + 1} fig[{i}]: "
                    f"figure right edge {gap:.0f}pt left of text right margin. "
                    f"Figure x={fig.x0:.0f}-{fig.x1:.0f}, "
                    f"text right edge={max_text_x1:.0f}. "
                    f"Figure size={fig.width:.0f}x{fig.height:.0f}pt"
                ),
            })

    return issues


def analyze_pdf(pdf_path, args):
    """Main analysis."""
    doc = fitz.open(pdf_path)
    total = len(doc)

    # Collectors: {category: [issue_dict, ...]}
    results = {
        "figure_beside_text": [],
        "near_empty": [],
        "overlap": [],
        "caption_overlap": [],
        "ghost_narrow": [],
        "extra_vspace": [],
        "hollow_carryover": [],
        "figure_misaligned": [],
    }

    # Track figure statistics for quality report
    total_figures = 0
    figures_with_wrapping = 0
    pages_with_figures = 0

    for pn in range(total):
        if args.page is not None and args.page != pn + 1:
            continue

        page = doc[pn]
        figs = get_figures(page)
        lines = get_text_lines(page)

        total_figures += len(figs)
        if figs:
            pages_with_figures += 1

        results["figure_beside_text"].extend(
            detect_figure_beside_text(pn, figs, lines, args.min_adjacent_lines))
        results["near_empty"].extend(
            detect_near_empty_pages(pn, page, lines, args.empty_threshold))
        body_ol, caption_ol = detect_overlaps(pn, figs, lines, args.overlap_tolerance)
        results["overlap"].extend(body_ol)
        results["caption_overlap"].extend(caption_ol)
        results["ghost_narrow"].extend(
            detect_ghost_narrowing(pn, lines, figs))
        results["extra_vspace"].extend(
            detect_extra_vspace(pn, figs, lines, args.extra_vspace))
        results["hollow_carryover"].extend(
            detect_hollow_carryover(pn, lines, figs))
        results["figure_misaligned"].extend(
            detect_figure_misaligned(pn, figs, lines))

        # Count figures with wrapping (for quality report)
        if figs:
            body_lines = [l for l in lines if l["width"] > 150 and l["fontsize"] >= 9.0]
            for fig in figs:
                narrow_count = sum(
                    1 for l in body_lines
                    if l["y1"] > fig.y0 + 2 and l["y0"] < fig.y1 - 2
                    and l["x1"] <= fig.x0 + 5 and l["width"] > 150
                )
                if narrow_count >= args.min_adjacent_lines:
                    figures_with_wrapping += 1

    doc.close()

    # Print results
    print(f"=== detect-layout-issues: {pdf_path} ===")
    print(f"Total pages: {total}")
    print()

    categories = [
        ("FIGURE BESIDE TEXT", "figure_beside_text"),
        ("NEAR-EMPTY PAGES", "near_empty"),
        ("TEXT-FIGURE OVERLAP (body text)", "overlap"),
        ("TEXT-FIGURE OVERLAP (caption, expected)", "caption_overlap"),
        ("GHOST NARROWING", "ghost_narrow"),
        ("EXTRA VSPACE", "extra_vspace"),
        ("HOLLOW CARRY-OVER", "hollow_carryover"),
        ("FIGURE MISALIGNED", "figure_misaligned"),
    ]

    if args.quality:
        print("QUALITY REPORT")
        print("=" * 60)
        print(f"  Pages: {total} total, {pages_with_figures} with figures")
        print(f"  Figures: {total_figures} total, "
              f"{figures_with_wrapping} with wrapping "
              f"({100*figures_with_wrapping/max(1,total_figures):.1f}%)")
        print()

        # Separate "real bugs" from "acceptable/known" issues
        real_bugs = [
            ("FIGURE BESIDE TEXT (no wrapping)", "figure_beside_text"),
            ("TEXT-FIGURE OVERLAP (body text)", "overlap"),
            ("GHOST NARROWING", "ghost_narrow"),
            ("HOLLOW CARRY-OVER", "hollow_carryover"),
            ("FIGURE MISALIGNED", "figure_misaligned"),
        ]
        acceptable = [
            ("NEAR-EMPTY PAGES (page-eject)", "near_empty"),
            ("TEXT-FIGURE OVERLAP (caption)", "caption_overlap"),
            ("EXTRA VSPACE", "extra_vspace"),
        ]

        print("  REAL BUGS:")
        real_total = 0
        for label, key in real_bugs:
            n = len(results[key])
            real_total += n
            status = "PASS" if n == 0 else "FAIL"
            print(f"    {status} {label}: {n}")

        print()
        print("  ACCEPTABLE/KNOWN:")
        acc_total = 0
        for label, key in acceptable:
            n = len(results[key])
            acc_total += n
            status = "PASS" if n == 0 else "INFO"
            print(f"    {status} {label}: {n}")

        print()
        total_issues = sum(len(v) for v in results.values())
        print(f"  TOTAL: {total_issues} issues ({real_total} real, "
              f"{acc_total} acceptable)")

        # Overall quality score
        # Score based on real bugs only
        max_score = total_figures  # Each figure is worth 1 point
        if max_score > 0:
            deductions = min(real_total, max_score)
            score = max(0, max_score - deductions)
            pct = 100.0 * score / max_score
            grade = "PASS" if pct >= 99.0 else "FAIL"
            print()
            print(f"  QUALITY SCORE: {score}/{max_score} ({pct:.1f}%) [{grade}]")
            print(f"    Criteria: >=99% for PASS (allows 1 bug per 100 figures)")

        return min(real_total, 8) if real_total > 0 else 0

    if args.summary:
        for label, key in categories:
            n = len(results[key])
            status = "PASS" if n == 0 else "FAIL"
            print(f"  {status} {label}: {n}")
        print()
        total_issues = sum(len(v) for v in results.values())
        print(f"  TOTAL issues: {total_issues}")
        return min(total_issues, 8) if total_issues > 0 else 0

    for label, key in categories:
        items = results[key]
        if items:
            print(f"{label} ({len(items)}):")
            for item in items:
                print(item["desc"])
            print()

    if all(len(v) == 0 for v in results.values()):
        print("PASS: no layout issues detected")
        return 0

    # Summary line
    total_issues = sum(len(v) for v in results.values())
    print(f"TOTAL: {total_issues} issues across "
          f"{sum(1 for v in results.values() if v)} categories")
    return min(total_issues, 8) if total_issues > 0 else 0


def main():
    args = parse_args()
    if not args.pdf.endswith(".pdf"):
        print(f"Error: {args.pdf} is not a PDF file", file=sys.stderr)
        sys.exit(99)
    try:
        sys.exit(analyze_pdf(args.pdf, args))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(99)


if __name__ == "__main__":
    main()
