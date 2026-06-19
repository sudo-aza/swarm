#!/usr/bin/env python3
"""
detect-parshape-leak.py — Detect parshape leak across page boundaries.

Parshape leak signature: on a figure-less page that follows a page with a
figure, text lines are narrower than normal (<90% of the page's maximum
text width). This happens when TeX's parshape from the previous page's
figure wrapping carries over to the new page.

Two types of leak lines:
  1. FRAGMENTED: multiple text spans at the same Y coordinate (parshape
     defines multiple indent/width segments). These can also be caused by
     justified text with large inter-word gaps, so we filter by checking
     that the total span coverage is significantly less than full width.
  2. NARROW: a single text span whose right edge is well short of the
     page's maximum text right edge. This is the most common leak form.

False positive filter: justified text can produce 2 spans with small gaps.
We classify a multi-span row as FP if the total span width plus gaps
exceeds 85% of the page's full text width.

Usage:
  python3 scripts/detect-parshape-leak.py <file.pdf> [--json] [--pages N]
  python3 scripts/detect-parshape-leak.py <file.pdf> --all

Requires: PyMuPDF (fitz)
"""

import sys
import json
import fitz
from collections import defaultdict


# A line is "narrow" if its right edge is < this fraction of the page's
# maximum text right edge. 90% catches parshape-narrowed lines while
# excluding normal short last-lines of paragraphs.
NARROW_THRESHOLD = 0.90

# A multi-fragment row is classified as parshape leak (not justified text)
# only if the total span width is < this fraction of the page's full width.
# Justified text lines with 2 spans typically cover >90% of full width.
FRAG_COVERAGE_THRESHOLD = 0.85

# Minimum line width to consider as text (filters out page numbers, etc.)
MIN_LINE_WIDTH = 20

# Figure detection thresholds
FIG_MIN_HEIGHT = 50
FIG_MIN_WIDTH = 50


def get_page_max_text_right(page):
    """Get the maximum x1 coordinate of any text span on the page.
    This represents the right edge of the full-width text area."""
    max_x1 = 0
    for block in page.get_text("dict")["blocks"]:
        if block["type"] != 0:
            continue
        for line in block["lines"]:
            for span in line["spans"]:
                text = span["text"].strip()
                if text and len(text) > 2:  # skip tiny spans
                    if span["bbox"][2] > max_x1:
                        max_x1 = span["bbox"][2]
    return max_x1


def get_page_left_margin(page):
    """Get the typical left margin (minimum x0 of text spans)."""
    min_x0 = 9999
    count = 0
    for block in page.get_text("dict")["blocks"]:
        if block["type"] != 0:
            continue
        for line in block["lines"]:
            for span in line["spans"]:
                text = span["text"].strip()
                if text and len(text) > 5:  # skip short spans
                    if span["bbox"][0] < min_x0:
                        min_x0 = span["bbox"][0]
                    count += 1
    return min_x0 if count > 0 else 0


def find_figure_rects(page):
    """Find filled rectangles that represent figures."""
    figure_rects = []
    for d in page.get_drawings():
        r = d.get("rect")
        fill = d.get("fill")
        if r and fill and r.height > FIG_MIN_HEIGHT and r.width > FIG_MIN_WIDTH:
            figure_rects.append(r)
    return figure_rects


def extract_text_lines(page):
    """Extract all text lines from a page.

    Returns list of line dicts with:
      - y0, y1: Y position
      - x0, x1: bounding box X extent
      - width: x1 - x0
      - text: combined text
      - spans: list of {text, x0, x1, width}
      - span_count: number of spans
    """
    y_groups = defaultdict(list)
    for block in page.get_text("dict")["blocks"]:
        if block["type"] != 0:
            continue
        for line in block["lines"]:
            text = "".join(s["text"] for s in line["spans"]).strip()
            if not text:
                continue
            bbox = line["bbox"]
            y_key = round(bbox[1] * 2) / 2  # round to 0.5pt
            y_groups[y_key].append({
                "text": text,
                "x0": bbox[0],
                "y0": bbox[1],
                "x1": bbox[2],
                "y1": bbox[3],
                "width": bbox[2] - bbox[0],
            })

    lines = []
    for y_key in sorted(y_groups.keys()):
        spans = y_groups[y_key]
        min_x0 = min(s["x0"] for s in spans)
        max_x1 = max(s["x1"] for s in spans)
        min_y0 = min(s["y0"] for s in spans)
        max_y1 = max(s["y1"] for s in spans)
        total_span_width = sum(s["width"] for s in spans)
        combined_text = " | ".join(s["text"] for s in spans)

        lines.append({
            "y0": min_y0,
            "y1": max_y1,
            "x0": min_x0,
            "x1": max_x1,
            "width": max_x1 - min_x0,
            "total_span_width": total_span_width,
            "span_count": len(spans),
            "spans": spans,
            "text": combined_text,
        })
    return lines


def detect_parshape_leak(page, page_num, prev_page=None):
    """Detect parshape leak on a figure-less page.

    A page has a parshape leak if:
    1. It has NO figures
    2. The PREVIOUS page has at least one figure (leak source)
    3. Text lines are narrower than normal (<90% of page max text width)

    Returns dict with leak analysis.
    """
    figure_rects = find_figure_rects(page)
    lines = extract_text_lines(page)

    result = {
        "page": page_num,
        "has_figures": len(figure_rects) > 0,
        "figure_count": len(figure_rects),
        "line_count": len(lines),
        "leaked_lines": [],
        "leak_severity": "none",
        "prev_page_figures": [],
    }

    # Pages WITH figures are not leak targets
    if figure_rects:
        if prev_page is not None:
            prev_figs = find_figure_rects(prev_page)
            result["prev_page_figures"] = _format_figs(prev_figs)
        return result

    if not lines:
        if prev_page is not None:
            prev_figs = find_figure_rects(prev_page)
            result["prev_page_figures"] = _format_figs(prev_figs)
        return result

    # Get previous page figures (leak source)
    prev_figs = []
    if prev_page is not None:
        prev_figs = find_figure_rects(prev_page)
        result["prev_page_figures"] = _format_figs(prev_figs)

    # No leak source — cannot be a parshape leak
    if not prev_figs:
        return result

    # Determine full text width from this page's widest lines
    max_text_right = get_page_max_text_right(page)
    left_margin = get_page_left_margin(page)
    full_width = max_text_right - left_margin

    if full_width < 50:
        return result  # Can't determine width

    for line in lines:
        if line["width"] < MIN_LINE_WIDTH:
            continue  # Skip page numbers, etc.

        is_narrow = line["x1"] < max_text_right * NARROW_THRESHOLD

        if line["span_count"] >= 2:
            # Multi-span line: check if it's parshape fragmentation or justified text
            # Compute total coverage: span widths + gaps between spans
            sorted_spans = sorted(line["spans"], key=lambda s: s["x0"])
            total_coverage = sorted_spans[-1]["x1"] - sorted_spans[0]["x0"]
            coverage_ratio = total_coverage / full_width if full_width > 0 else 1.0

            if coverage_ratio < FRAG_COVERAGE_THRESHOLD and is_narrow:
                # Real parshape fragmentation: spans are narrow AND don't
                # cover most of the page width
                result["leaked_lines"].append({
                    "y0": round(line["y0"], 1),
                    "text": line["text"][:80],
                    "width": round(line["width"], 1),
                    "coverage_ratio": round(coverage_ratio, 2),
                    "span_count": line["span_count"],
                    "spans": [
                        {"text": s["text"][:40], "x0": round(s["x0"], 1),
                         "width": round(s["width"], 1)}
                        for s in sorted_spans
                    ],
                    "type": "fragmented",
                })
            # else: justified text FP — coverage is near full width, skip

        elif is_narrow:
            # Single-span narrow line: definitive leak indicator on a
            # figure-less page with a previous-page figure
            result["leaked_lines"].append({
                "y0": round(line["y0"], 1),
                "text": line["text"][:80],
                "width": round(line["width"], 1),
                "span_count": 1,
                "type": "narrow",
            })

    # Classify severity
    total = len(result["leaked_lines"])
    frag_count = sum(1 for l in result["leaked_lines"] if l.get("type") == "fragmented")
    if total == 0:
        result["leak_severity"] = "none"
    elif frag_count <= 2 and total <= 3:
        result["leak_severity"] = "mild"
    elif frag_count <= 5 and total <= 10:
        result["leak_severity"] = "moderate"
    else:
        result["leak_severity"] = "severe"

    return result


def _format_figs(figs):
    """Format figure rectangles for output."""
    return [
        {"x0": round(r.x0, 1), "y0": round(r.y0, 1),
         "x1": round(r.x1, 1), "y1": round(r.y1, 1),
         "width": round(r.width, 1), "height": round(r.height, 1)}
        for r in figs
    ]


def analyze_pdf(pdf_path, pages_limit=None):
    """Analyze a PDF for parshape leak across page boundaries."""
    doc = fitz.open(pdf_path)
    total_pages = len(doc)

    results = {
        "file": pdf_path,
        "pages": total_pages,
        "findings": {
            "total_leaked_pages": 0,
            "total_fragmented_lines": 0,
            "total_narrow_lines": 0,
            "total_leaked_lines": 0,
            "severity_counts": {"none": 0, "mild": 0, "moderate": 0, "severe": 0},
        },
        "per_page": [],
    }

    page_range = range(total_pages)
    if pages_limit:
        page_range = range(min(pages_limit, total_pages))

    for pno in page_range:
        page = doc[pno]
        prev_page = doc[pno - 1] if pno > 0 else None
        result = detect_parshape_leak(page, pno + 1, prev_page)
        results["per_page"].append(result)

        if result["leak_severity"] != "none":
            results["findings"]["total_leaked_pages"] += 1
            results["findings"]["severity_counts"][result["leak_severity"]] += 1

        for l in result["leaked_lines"]:
            results["findings"]["total_leaked_lines"] += 1
            if l.get("type") == "fragmented":
                results["findings"]["total_fragmented_lines"] += 1
            elif l.get("type") == "narrow":
                results["findings"]["total_narrow_lines"] += 1

    doc.close()
    return results


def format_report(results):
    """Format results as human-readable report."""
    lines = []
    lines.append("=== Parshape Leak Detection ===")
    lines.append(f"File: {results['file']}")
    lines.append(f"Pages: {results['pages']}")
    f = results["findings"]
    lines.append(f"Leaked pages:    {f['total_leaked_pages']}")
    lines.append(f"Fragmented lines: {f['total_fragmented_lines']}")
    lines.append(f"Narrow lines:    {f['total_narrow_lines']}")
    lines.append(f"Total leaked:     {f['total_leaked_lines']}")
    lines.append(f"Severity: none={f['severity_counts']['none']}, "
                 f"mild={f['severity_counts']['mild']}, "
                 f"moderate={f['severity_counts']['moderate']}, "
                 f"severe={f['severity_counts']['severe']}")
    lines.append("")

    for pr in results["per_page"]:
        if pr["leak_severity"] == "none" and not pr["prev_page_figures"]:
            continue  # Skip uninteresting pages

        status = ""
        if pr["leak_severity"] != "none":
            status = f" *** {pr['leak_severity'].upper()} LEAK ({len(pr['leaked_lines'])} lines)"
        elif pr["prev_page_figures"]:
            status = f" (prev page has {len(pr['prev_page_figures'])} fig(s) — clean)"

        lines.append(f"Page {pr['page']:2d}: {pr['line_count']:3d} lines, "
                     f"{pr['figure_count']} figs{status}")

        if pr["prev_page_figures"] and pr["leak_severity"] != "none":
            for fig in pr["prev_page_figures"]:
                lines.append(f"  LEAK SOURCE: prev-page fig at "
                             f"({fig['x0']},{fig['y0']})-({fig['x1']},{fig['y1']})")

        for l in pr["leaked_lines"]:
            if l.get("type") == "fragmented":
                frags = " + ".join(
                    f'"{s["text"]}" w={s["width"]}' for s in l["spans"]
                )
                cov = l.get("coverage_ratio", "?")
                lines.append(f"  FRAG y={l['y0']:6.1f}: {frags} (cov={cov})")
            else:
                lines.append(f"  NARROW y={l['y0']:6.1f}: w={l.get('width', '?')} "
                             f'"{l["text"]}"')

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 detect-parshape-leak.py <file.pdf> [--json] [--pages N] [--all]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    use_json = "--json" in sys.argv
    pages_limit = None

    for i, arg in enumerate(sys.argv):
        if arg == "--pages" and i + 1 < len(sys.argv):
            pages_limit = int(sys.argv[i + 1])

    results = analyze_pdf(pdf_path, pages_limit)

    if use_json:
        print(json.dumps(results, indent=2))
    else:
        print(format_report(results))

    # Exit code
    f = results["findings"]
    if f["total_leaked_lines"] > 0:
        sys.exit(1)  # Has parshape leak
    else:
        sys.exit(0)  # Clean


if __name__ == "__main__":
    main()