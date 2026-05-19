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

Usage:
  python3 scripts/detect-layout-issues.py <file.pdf> [options]
  python3 scripts/detect-layout-issues.py <file.pdf> --page 3    # single page
  python3 scripts/detect-layout-issues.py <file.pdf> --summary   # counts only

Exit codes:
  0 = no issues found
  1 = issues found (exit code = number of issue categories with hits)

Requires: PyMuPDF (fitz)
"""

import sys
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
    return p.parse_args()


def get_figures(page):
    """Get figure/image rectangles on a page (images + filled drawings)."""
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

    # Merge overlapping rects
    if not figures:
        return []
    figures.sort(key=lambda r: (r.y0, r.x0))
    merged = [figures[0]]
    for r in figures[1:]:
        did_merge = False
        for i, m in enumerate(merged):
            if r.intersects(m) or (abs(r.y0 - m.y0) < 5 and abs(r.x0 - m.x0) < 5):
                merged[i] = r | m
                did_merge = True
                break
        if not did_merge:
            merged.append(r)
    return merged


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


def detect_figure_beside_text(page_num, figures, text_lines, min_adjacent):
    """
    CRITICAL CHECK: For each figure, verify text actually wraps BESIDE it.

    A figure has proper wrapping if text lines exist whose vertical range
    overlaps with the figure AND whose width is NARROWED (significantly less
    than the page's full text width) — proving the text gave up space for the figure.

    If all text is at full width, the figure is 'outside text' — the bug Zoe
    keeps finding. Text flows at full width and figures are just overlaid or
    placed beside without actual wrapping.
    """
    issues = []

    if not figures:
        return issues

    # Compute the page's full text width from the widest body lines
    body_lines = [l for l in text_lines if l["width"] > 150 and l["fontsize"] >= 9.0]
    if not body_lines:
        return issues

    widths = sorted([l["width"] for l in body_lines])
    # Full width = 90th percentile of body line widths
    idx = max(0, int(len(widths) * 0.9) - 1)
    full_width = widths[idx]

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
                    f"(page full_width={full_width:.0f}pt)."
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


def detect_overlaps(page_num, figures, text_lines, tolerance):
    """Detect text lines overlapping figure rectangles."""
    issues = []
    for line in text_lines:
        for fig in figures:
            if not line["rect"].intersects(fig):
                continue
            overlap_rect = line["rect"] & fig
            if overlap_rect.get_area() > tolerance:
                issues.append({
                    "page": page_num + 1,
                    "desc": (
                        f"  OVERLAP page {page_num + 1}: "
                        f"\"{line['text'][:40]}\" overlaps figure "
                        f"(area: {overlap_rect.width:.0f}x{overlap_rect.height:.0f}pt)"
                    ),
                })
                break
    return issues


def detect_ghost_narrowing(page_num, text_lines, figures):
    """Detect text narrowed by parshape with no figure on page."""
    issues = []
    if figures:
        return issues

    body_lines = [l for l in text_lines if l["width"] > 150 and l["fontsize"] >= 9.0]
    if not body_lines:
        return issues

    widths = sorted([l["width"] for l in body_lines])
    idx = max(0, int(len(widths) * 0.9) - 1)
    full_width = widths[idx]

    narrowed = [l for l in body_lines if full_width - l["width"] > 40]
    if narrowed:
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
    Detect hollow carry-over: first line of page is narrowed but no figure.

    This happens when parshape from a previous page's figure leaks to the
    next page's first line.
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

    # Sort by vertical position, take the first one
    body_lines.sort(key=lambda l: l["y0"])
    first_line = body_lines[0]

    # Check remaining lines for full width
    widths = sorted([l["width"] for l in body_lines], reverse=True)
    # Full width = the most common width among the top lines
    # Use the median of the top 10 widest lines
    top_widths = widths[:min(10, len(widths))]
    top_widths.sort()
    if len(top_widths) >= 3:
        full_width = top_widths[len(top_widths) // 2]
    else:
        full_width = max(widths) if widths else 400

    # First line is "hollow" if it's significantly narrower than full width
    if full_width - first_line["width"] > 40:
        issues.append({
            "page": page_num + 1,
            "desc": (
                f"  HOLLOW CARRY-OVER page {page_num + 1}: "
                f"first line \"{first_line['text'][:50]}\" is "
                f"{first_line['width']:.0f}pt wide "
                f"(page full width ~{full_width:.0f}pt, "
                f"narrowed by {full_width - first_line['width']:.0f}pt) "
                f"— no figure on this page"
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
        "ghost_narrow": [],
        "extra_vspace": [],
        "hollow_carryover": [],
    }

    for pn in range(total):
        if args.page is not None and args.page != pn + 1:
            continue

        page = doc[pn]
        figs = get_figures(page)
        lines = get_text_lines(page)

        results["figure_beside_text"].extend(
            detect_figure_beside_text(pn, figs, lines, args.min_adjacent_lines))
        results["near_empty"].extend(
            detect_near_empty_pages(pn, page, lines, args.empty_threshold))
        results["overlap"].extend(
            detect_overlaps(pn, figs, lines, args.overlap_tolerance))
        results["ghost_narrow"].extend(
            detect_ghost_narrowing(pn, lines, figs))
        results["extra_vspace"].extend(
            detect_extra_vspace(pn, figs, lines, args.extra_vspace))
        results["hollow_carryover"].extend(
            detect_hollow_carryover(pn, lines, figs))

    doc.close()

    # Print results
    print(f"=== detect-layout-issues: {pdf_path} ===")
    print(f"Total pages: {total}")
    print()

    categories = [
        ("FIGURE BESIDE TEXT", "figure_beside_text"),
        ("NEAR-EMPTY PAGES", "near_empty"),
        ("TEXT-FIGURE OVERLAP", "overlap"),
        ("GHOST NARROWING", "ghost_narrow"),
        ("EXTRA VSPACE", "extra_vspace"),
        ("HOLLOW CARRY-OVER", "hollow_carryover"),
    ]

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
