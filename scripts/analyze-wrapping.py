#!/usr/bin/env python3
"""
analyze-wrapping.py — Automated PDF analysis for swarmwrap.sty QA.

Detects three categories of issues in LaTeX PDFs that use swarmwrap:
  1. TEXT-FIGURE OVERLAP — text rendered on top of a figure/image
  2. WRONGFUL WHITESPACE — large vertical gaps (>2x baselineskip) between body text lines
  3. GHOST NARROWING — body text narrowed by parshape but no figure present on that page

Usage:
  python3 scripts/analyze-wrapping.py <file.pdf> [options]
  python3 scripts/analyze-wrapping.py <file.pdf> --figures-only   # just show figure locations

Exit codes:
  0 = "no problem found; review the file yourself"
  1 = overlap found
  2 = wrongful whitespace found
  3 = ghost narrowing found
  4 = multiple issues found

Requires: PyMuPDF (fitz)
"""

import sys
import argparse
import fitz  # PyMuPDF


def parse_args():
    p = argparse.ArgumentParser(description="Analyze swarmwrap PDF for overlap/whitespace/narrowing issues")
    p.add_argument("pdf", help="Path to the PDF file to analyze")
    p.add_argument("--whitespace-threshold", type=float, default=36.0,
                   help="Min vertical gap (pt) to flag as wrongful whitespace (default: 36.0)")
    p.add_argument("--overlap-tolerance", type=float, default=2.0,
                   help="Tolerance (pt) for text-fig overlap — smaller ignored (default: 2.0)")
    p.add_argument("--ghost-min-width", type=float, default=150.0,
                   help="Min line width (pt) to consider for ghost narrowing — short titles ignored (default: 150.0)")
    p.add_argument("--ghost-threshold", type=float, default=40.0,
                   help="Min narrowing (pt) from full width to flag (default: 40.0)")
    p.add_argument("--figures-only", action="store_true",
                   help="Only show detected figure locations — skip all analysis")
    p.add_argument("--page", type=int, default=None,
                   help="Only analyze specific page number (1-based)")
    return p.parse_args()


def get_figures_on_page(page):
    """
    Get figure/image rectangles on a page.
    Returns list of fitz.Rect objects.
    Detects:
      - Image XObjects (included graphics like \\includegraphics)
      - Filled rectangles (from colorbox, TikZ, etc.)
    """
    figures = []

    # Method 1: Images placed via \includegraphics etc.
    images = page.get_images(full=True)
    for img_info in images:
        xref = img_info[0]
        rects = page.get_image_rects(xref)
        for r in rects:
            figures.append(r)

    # Method 2: Filled drawing rectangles (from \\smash{\\rlap{\\hbox{...}}})
    # swarmwrap places figures inside \\hbox which is then rlap'd to the right
    # These appear as filled rectangles in the PDF drawing stream
    drawings = page.get_drawings()
    for d in drawings:
        r = d["rect"]
        dtype = d.get("type", "")
        if dtype in ("f", "fs", "re"):
            # Figures are >50pt wide and >30pt tall (skip rules, underlines)
            if r.width > 50 and r.height > 30:
                figures.append(r)

    # Merge overlapping/adjacent figure rects
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


def get_text_lines_on_page(page):
    """
    Get text line bounding boxes.
    Returns list of dicts with text, rect, x0, y0, x1, y1, width, fontsize.
    """
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
            # Get dominant font size from spans
            font_size = max((span["size"] for span in line["spans"]), default=10.0)
            lines.append({
                "text": text[:80],
                "rect": bbox,
                "x0": bbox.x0,
                "y0": bbox.y0,
                "x1": bbox.x1,
                "y1": bbox.y1,
                "width": bbox.width,
                "fontsize": font_size,
            })
    return lines


def detect_overlaps(page_num, figures, text_lines, tolerance):
    """Detect text lines overlapping figure rectangles."""
    issues = []
    if not figures:
        return issues

    for line_info in text_lines:
        line_rect = line_info["rect"]
        for fig_rect in figures:
            if not line_rect.intersects(fig_rect):
                continue

            # Calculate horizontal and vertical overlap
            overlap_x0 = max(line_rect.x0, fig_rect.x0)
            overlap_x1 = min(line_rect.x1, fig_rect.x1)
            overlap_y0 = max(line_rect.y0, fig_rect.y0)
            overlap_y1 = min(line_rect.y1, fig_rect.y1)

            overlap_w = overlap_x1 - overlap_x0
            overlap_h = overlap_y1 - overlap_y0

            if overlap_w > tolerance and overlap_h > tolerance:
                snippet = line_info["text"][:50]
                issues.append(
                    f"  OVERLAP page {page_num + 1}: \"{snippet}\" "
                    f"(y={line_rect.y0:.0f}-{line_rect.y1:.0f}, "
                    f"w={line_rect.width:.0f}) overlaps figure "
                    f"(y={fig_rect.y0:.0f}-{fig_rect.y1:.0f}, "
                    f"x={fig_rect.x0:.0f}-{fig_rect.x1:.0f}) — "
                    f"overlap area: {overlap_w:.0f}x{overlap_h:.0f} pt"
                )
                break
    return issues


def detect_ghost_narrowing(page_num, text_lines, figures, ghost_threshold, min_line_width):
    """
    Detect ghost narrowing: body text narrowed by parshape but no figure on this page.

    Strategy:
    1. Skip pages that HAVE figures (narrowing is expected there)
    2. Compute the page's "full text width" from the longest body text lines
       (excluding page numbers, short labels, etc.)
    3. Flag body text lines that are significantly narrower than full width
    4. Only consider lines > min_line_width to avoid flagging titles/labels
    """
    issues = []
    if figures:
        return issues

    # Filter to body text lines: must be long enough and use normal font size
    body_lines = [l for l in text_lines if l["width"] > min_line_width and l["fontsize"] >= 9.0]
    if not body_lines:
        return issues

    # Full width = 90th percentile of body line widths (robust against outliers)
    widths = sorted([l["width"] for l in body_lines])
    idx = max(0, int(len(widths) * 0.9) - 1)
    full_width = widths[idx]

    # Now check ALL body text lines for significant narrowing
    narrowed_lines = []
    for line_info in body_lines:
        narrowing = full_width - line_info["width"]
        if narrowing > ghost_threshold:
            narrowed_lines.append((line_info, narrowing))

    if narrowed_lines:
        issues.append(
            f"  GHOST NARROWING page {page_num + 1}: "
            f"{len(narrowed_lines)} body text lines narrowed "
            f"(full_width={full_width:.0f}pt, "
            f"narrowest={min(l['width'] for l, _ in narrowed_lines):.0f}pt) "
            f"— no figure on this page"
        )
        # Show a few examples
        for line_info, narrowing in narrowed_lines[:3]:
            snippet = line_info["text"][:50]
            issues.append(
                f"    \"{snippet}\" width={line_info['width']:.0f}pt "
                f"(narrowed by {narrowing:.0f}pt)"
            )
        if len(narrowed_lines) > 3:
            issues.append(f"    ... and {len(narrowed_lines) - 3} more")

    return issues


def detect_wrongful_whitespace(page_num, text_lines, threshold):
    """
    Detect large vertical gaps between consecutive body text lines.
    Skips short lines (page numbers, labels) to avoid false positives.
    """
    issues = []

    # Only consider body text lines (>100pt wide, normal font size)
    body_lines = [l for l in text_lines if l["width"] > 100 and l["fontsize"] >= 9.0]
    if len(body_lines) < 2:
        return issues

    # Sort by vertical position
    sorted_lines = sorted(body_lines, key=lambda l: (l["y0"], l["x0"]))

    prev = sorted_lines[0]
    for line in sorted_lines[1:]:
        # Skip lines in very different horizontal positions (side by side)
        if abs(prev["x0"] - line["x0"]) > 80:
            prev = line
            continue

        gap = line["y0"] - prev["y1"]
        if gap > threshold:
            issues.append(
                f"  WRONGFUL WHITESPACE page {page_num + 1}: "
                f"{gap:.0f}pt gap between \"{prev['text'][:40]}\" "
                f"(y={prev['y1']:.0f}) and \"{line['text'][:40]}\" "
                f"(y={line['y0']:.0f})"
            )
        prev = line

    return issues


def analyze_pdf(pdf_path, args):
    """Main analysis."""
    doc = fitz.open(pdf_path)
    total_pages = len(doc)

    all_overlaps = []
    all_ghost_narrowing = []
    all_whitespace = []

    for page_num in range(total_pages):
        if args.page is not None and args.page != page_num + 1:
            continue

        page = doc[page_num]
        figures = get_figures_on_page(page)
        text_lines = get_text_lines_on_page(page)

        if args.figures_only:
            if figures:
                print(f"  Page {page_num + 1}: {len(figures)} figure(s)")
                for i, f in enumerate(figures):
                    print(f"    fig[{i}]: x={f.x0:.0f}-{f.x1:.0f}, "
                          f"y={f.y0:.0f}-{f.y1:.0f}, "
                          f"size={f.width:.0f}x{f.height:.0f}pt")
            continue

        overlaps = detect_overlaps(page_num, figures, text_lines, args.overlap_tolerance)
        all_overlaps.extend(overlaps)

        ghosts = detect_ghost_narrowing(page_num, text_lines, figures,
                                        args.ghost_threshold, args.ghost_min_width)
        all_ghost_narrowing.extend(ghosts)

        whitespace = detect_wrongful_whitespace(page_num, text_lines, args.whitespace_threshold)
        all_whitespace.extend(whitespace)

    doc.close()

    # Print results
    print(f"=== swarmwrap analysis: {pdf_path} ===")
    print(f"Total pages: {total_pages}")
    print()

    if all_overlaps:
        print(f"OVERLAP FOUND ({len(all_overlaps)} instances):")
        for issue in all_overlaps:
            print(issue)
        print()

    if all_whitespace:
        print(f"WRONGFUL WHITESPACE FOUND ({len(all_whitespace)} instances):")
        for issue in all_whitespace:
            print(issue)
        print()

    if all_ghost_narrowing:
        print(f"GHOST NARROWING FOUND ({len(all_ghost_narrowing)} pages affected):")
        for issue in all_ghost_narrowing:
            print(issue)
        print()

    if not args.figures_only and not all_overlaps and not all_whitespace and not all_ghost_narrowing:
        print("no problem found; review the file yourself")
        return 0

    if all_overlaps:
        return 1 if not all_whitespace and not all_ghost_narrowing else 4
    if all_whitespace:
        return 2 if not all_ghost_narrowing else 4
    return 3


def main():
    args = parse_args()
    if not args.pdf.endswith(".pdf"):
        print(f"Error: {args.pdf} is not a PDF file", file=sys.stderr)
        sys.exit(99)
    try:
        sys.exit(analyze_pdf(args.pdf, args))
    except Exception as e:
        print(f"Error analyzing {args.pdf}: {e}", file=sys.stderr)
        sys.exit(99)


if __name__ == "__main__":
    main()
