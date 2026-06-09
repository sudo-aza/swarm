#!/usr/bin/env python3
"""
analyze-wrapping.py — Automated PDF analysis for swarmwrap.sty QA.

Detects five categories of issues in LaTeX PDFs that use swarmwrap:
  1. TEXT-FIGURE OVERLAP — body text rendered on top of a figure/image
  2. CAPTION ANOMALY — figure labels missing or unexpected count
  3. GHOST NARROWING — narrow text on pages with NO figure present
  4. NEAR-EMPTY PAGES — pages with very little text content
  5. HOLLOW CARRY-OVER — first line of a new page narrowed with no figure

Usage:
  python3 scripts/analyze-wrapping.py <file.pdf> [--json] [--pages N]

Requires: PyMuPDF (fitz)
"""

import sys
import json
import re
import fitz


def extract_lines(page):
    """Extract line-level text from a page using dict mode."""
    lines = []
    for block in page.get_text("dict")["blocks"]:
        if block["type"] != 0:  # skip image blocks
            continue
        for line in block["lines"]:
            text = "".join(s["text"] for s in line["spans"]).strip()
            if text:
                bbox = line["bbox"]
                lines.append({
                    "text": text,
                    "x0": bbox[0], "y0": bbox[1],
                    "x1": bbox[2], "y1": bbox[3],
                    "width": bbox[2] - bbox[0],
                    "height": bbox[3] - bbox[1],
                })
    return lines


def find_figure_rects(page, min_height=30, min_width=20):
    """Find filled rectangles that represent figures."""
    figure_rects = []
    for d in page.get_drawings():
        r = d.get("rect")
        fill = d.get("fill")
        if r and fill and r.height > min_height and r.width > min_width:
            figure_rects.append(r)
    return figure_rects


def is_caption(text):
    """Check if text line looks like a figure caption."""
    return bool(re.search(r'Fig(?:ure)?\s+\d', text) or re.search(r'\d+\s*cm\s*x\s*\d+', text))


def is_short_label(text):
    """Check if text is too short to be body text."""
    return len(text) < 10


def detect_overlaps(lines, figure_rects):
    """Detect body-text overlaps with figures. Returns list of overlap dicts."""
    overlaps = []
    for line in lines:
        text = line["text"]
        if is_caption(text) or is_short_label(text):
            continue
        # Skip common non-body patterns
        if re.match(r'^\d+$', text):  # page numbers
            continue
        if text.startswith("\\"):  # LaTeX commands leaking
            continue
        text_rect = fitz.Rect(line["x0"], line["y0"], line["x1"], line["y1"])
        for fr in figure_rects:
            if text_rect.intersects(fr):
                overlap = text_rect & fr
                if overlap.width > 2 and overlap.height > 2:
                    overlaps.append({
                        "text": text[:60],
                        "overlap_w": round(overlap.width, 1),
                        "overlap_h": round(overlap.height, 1),
                        "text_rect": [round(line["x0"], 1), round(line["y0"], 1),
                                      round(line["x1"], 1), round(line["y1"], 1)],
                        "fig_rect": [round(fr.x0, 1), round(fr.y0, 1),
                                      round(fr.x1, 1), round(fr.y1, 1)],
                    })
    return overlaps


def detect_ghost_narrowing(lines, figure_rects, full_width_threshold=340, ghost_threshold=300):
    """Detect narrow lines on pages with NO figures."""
    if figure_rects:
        return []  # page has figures, not ghost narrowing
    ghost_lines = []
    for line in lines:
        if line["width"] < ghost_threshold:
            ghost_lines.append({
                "text": line["text"][:60],
                "width": round(line["width"], 1),
                "x0": round(line["x0"], 1),
                "y0": round(line["y0"], 1),
            })
    return ghost_lines


def detect_near_empty_page(lines, min_lines=3):
    """Detect pages with very few text lines."""
    return len(lines) < min_lines


def detect_hollow_carryover(lines, figure_rects, narrow_threshold=340):
    """Detect first line of page being narrowed with no figure (hollow carry-over)."""
    if not lines or figure_rects:
        return False
    first_line = lines[0]
    return first_line["width"] < narrow_threshold


def extract_figure_labels(lines, total_expected=None):
    """Extract figure labels from text lines. Returns found set and missing list."""
    found_nums = set()
    for line in lines:
        m = re.search(r'Fig(?:ure)?\s+(\d+)', line["text"])
        if m:
            found_nums.add(int(m.group(1)))
    if total_expected:
        expected = set(range(1, total_expected + 1))
        missing = sorted(expected - found_nums)
        return found_nums, missing
    return found_nums, []


def analyze_pdf(pdf_path, expected_figures=None, pages_to_check=None):
    """Run full analysis on a PDF file."""
    doc = fitz.open(pdf_path)
    total_pages = len(doc)
    import os
    file_size = os.path.getsize(pdf_path)

    results = {
        "file": pdf_path,
        "pages": total_pages,
        "size": file_size,
        "engine": "",
        "findings": {},
        "per_page": [],
    }

    # Get engine from first page's metadata
    if total_pages > 0:
        meta = doc.metadata
        results["engine"] = meta.get("producer", "unknown")

    total_overlaps = 0
    total_ghost = 0
    total_near_empty = 0
    total_hollow = 0
    all_found_figures = set()
    all_missing_figures = []

    page_range = range(total_pages)
    if pages_to_check:
        page_range = range(min(pages_to_check, total_pages))

    for pno in page_range:
        page = doc[pno]
        lines = extract_lines(page)
        figure_rects = find_figure_rects(page)

        # Category 1: Overlaps
        overlaps = detect_overlaps(lines, figure_rects)
        total_overlaps += len(overlaps)

        # Category 2: Figure labels
        found, _ = extract_figure_labels(lines)
        all_found_figures |= found

        # Category 3: Ghost narrowing
        ghost = detect_ghost_narrowing(lines, figure_rects)
        total_ghost += len(ghost)

        # Category 4: Near-empty pages
        near_empty = detect_near_empty_page(lines)
        if near_empty:
            total_near_empty += 1

        # Category 5: Hollow carry-over
        hollow = detect_hollow_carryover(lines, figure_rects)
        if hollow:
            total_hollow += 1

        page_result = {
            "page": pno + 1,
            "lines": len(lines),
            "figures": len(figure_rects),
            "overlaps": len(overlaps),
            "ghost_narrow": len(ghost),
            "near_empty": near_empty,
            "hollow_carryover": hollow,
        }
        if overlaps:
            page_result["overlap_details"] = overlaps
        if ghost:
            page_result["ghost_details"] = ghost
        results["per_page"].append(page_result)

    results["findings"] = {
        "total_body_text_overlaps": total_overlaps,
        "total_ghost_narrow_lines": total_ghost,
        "total_near_empty_pages": total_near_empty,
        "total_hollow_carryover_pages": total_hollow,
        "figures_found": len(all_found_figures),
        "figures_missing": sorted(set(range(1, expected_figures + 1)) - all_found_figures) if expected_figures else [],
    }

    doc.close()
    return results


def format_report(results):
    """Format results as human-readable report."""
    lines = []
    lines.append(f"=== swarmwrap PDF Analysis ===")
    lines.append(f"File: {results['file']}")
    lines.append(f"Pages: {results['pages']}, Size: {results['size']} bytes")
    lines.append(f"Engine: {results['engine']}")
    lines.append("")

    f = results["findings"]
    lines.append(f"Body-text overlaps:    {f['total_body_text_overlaps']}")
    lines.append(f"Ghost narrow lines:     {f['total_ghost_narrow_lines']}")
    lines.append(f"Near-empty pages:       {f['total_near_empty_pages']}")
    lines.append(f"Hollow carry-over:      {f['total_hollow_carryover_pages']}")
    if f["figures_missing"]:
        lines.append(f"Missing figure labels:  {f['figures_missing']}")
    elif f["figures_found"] > 0:
        lines.append(f"Figure labels:          {f['figures_found']} found, all present")
    lines.append("")

    for pr in results["per_page"]:
        status_parts = []
        if pr["overlaps"]:
            status_parts.append(f"{pr['overlaps']} OVERLAPS")
        if pr["ghost_narrow"]:
            status_parts.append(f"{pr['ghost_narrow']} GHOST")
        if pr["near_empty"]:
            status_parts.append("NEAR-EMPTY")
        if pr["hollow_carryover"]:
            status_parts.append("HOLLOW-CARRYOVER")
        status = " *** " + ", ".join(status_parts) if status_parts else ""

        lines.append(
            f"Page {pr['page']:2d}: {pr['lines']:3d} lines, "
            f"{pr['figures']} figs{status}"
        )
        if "overlap_details" in pr:
            for o in pr["overlap_details"]:
                lines.append(
                    f"  OVERLAP: '{o['text']}' "
                    f"{o['overlap_w']}x{o['overlap_h']}pt"
                )
        if "ghost_details" in pr:
            for g in pr["ghost_details"][:5]:
                lines.append(
                    f"  GHOST: w={g['width']}pt: '{g['text']}'"
                )
            if len(pr["ghost_details"]) > 5:
                lines.append(
                    f"  ... and {len(pr['ghost_details'])-5} more"
                )

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze-wrapping.py <file.pdf> [--json] [--figures N] [--pages N]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    use_json = "--json" in sys.argv
    expected_figures = None
    pages_limit = None

    for i, arg in enumerate(sys.argv):
        if arg == "--figures" and i + 1 < len(sys.argv):
            expected_figures = int(sys.argv[i + 1])
        if arg == "--pages" and i + 1 < len(sys.argv):
            pages_limit = int(sys.argv[i + 1])

    results = analyze_pdf(pdf_path, expected_figures, pages_limit)

    if use_json:
        print(json.dumps(results, indent=2))
    else:
        print(format_report(results))

    # Exit code based on findings
    f = results["findings"]
    if f["total_body_text_overlaps"] > 0:
        sys.exit(1)
    elif f["total_ghost_narrow_lines"] > 0:
        sys.exit(3)
    elif f["total_near_empty_pages"] > 0:
        sys.exit(2)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
