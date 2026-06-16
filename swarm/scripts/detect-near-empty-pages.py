#!/usr/bin/env python3
"""
Near-Empty Page Detector for swarmwrap test PDFs.
A page is "near-empty" if its text content (union of all text line bounding boxes)
occupies less than a threshold percentage of the page height.
Also detects "figure-only" pages (has figure rects but minimal text).

Usage: python3 detect-near-empty-pages.py <pdf_path> [--threshold <pct>] [--min-height-ratio <ratio>]
"""

import sys
import fitz  # PyMuPDF

def get_figure_rects(page):
    """Get filled rectangles that represent figures (vector \rule graphics)."""
    rects = []
    for d in page.get_drawings():
        if d.get("type") in ("f", "fs", "re"):
            r = d.get("rect")
            if r and r.width > 50 and r.height > 25:
                rects.append(r)
    return rects

def _is_page_number(page, spans_text, bbox):
    """Check if a text line is a page number (article class default footer).
    Page numbers are: centered horizontally, in the bottom 1/5 of the page,
    and contain only digits matching the page number.
    """
    page_w = page.rect.width
    page_h = page.rect.height
    page_num = str(int(page.number + 1))  # page.number is 0-indexed

    # Must be in the bottom 25% of the page
    if bbox[3] < page_h * 0.75:
        return False

    # Must be roughly centered (within 40pt of center)
    line_cx = (bbox[0] + bbox[2]) / 2
    if abs(line_cx - page_w / 2) > 40:
        return False

    # Text content must be just the page number (digits only)
    text = spans_text.strip()
    if text == page_num:
        return True

    return False


def get_text_coverage(page):
    """Get the vertical coverage of text on a page.
    Returns (min_y, max_y, total_text_height, page_height, num_text_lines, num_figure_rects).
    Excludes page numbers from the vertical span calculation to avoid false negatives
    on orphan pages where the page number inflates the apparent fill ratio.
    """
    page_h = page.rect.height
    figure_rects = get_figure_rects(page)

    text_min_y = page_h
    text_max_y = 0
    num_lines = 0
    num_pn_skipped = 0

    blocks = page.get_text("dict")["blocks"]
    for block in blocks:
        if block["type"] != 0:  # skip image blocks
            continue
        for line in block["lines"]:
            bbox = line["bbox"]
            line_top = bbox[1]
            line_bottom = bbox[3]
            if line_bottom <= line_top:  # invalid bbox
                continue

            # Collect spans text for page number detection
            spans_text = " ".join(s["text"] for s in line["spans"])

            if _is_page_number(page, spans_text, bbox):
                num_pn_skipped += 1
                continue

            text_min_y = min(text_min_y, line_top)
            text_max_y = max(text_max_y, line_bottom)
            num_lines += 1

    if num_lines == 0:
        return (None, None, 0, page_h, 0, len(figure_rects))

    text_span = text_max_y - text_min_y
    return (text_min_y, text_max_y, text_span, page_h, num_lines, len(figure_rects))

def classify_page(page_num, text_min_y, text_max_y, text_span, page_h, num_lines, num_figures, threshold=0.25):
    """Classify a page's fullness. Returns (category, detail_string)."""
    if num_lines == 0 and num_figures == 0:
        return ("BLANK", f"no text, no figures")
    if num_lines == 0 and num_figures > 0:
        return ("FIGURE-ONLY", f"{num_figures} figure(s), no text")
    if num_lines > 0 and num_figures == 0:
        ratio = text_span / page_h
        if ratio < threshold:
            return ("NEAR-EMPTY", f"{num_lines} lines, text span {text_span:.1f}pt = {ratio*100:.1f}% of page")
        else:
            return ("OK", f"{num_lines} lines, text span {text_span:.1f}pt = {ratio*100:.1f}% of page")
    # Both text and figures
    ratio = text_span / page_h
    if ratio < threshold:
        return ("NEAR-EMPTY-WITH-FIG", f"{num_lines} lines + {num_figures} fig(s), text span {ratio*100:.1f}%")
    return ("OK-WITH-FIG", f"{num_lines} lines + {num_figures} fig(s), text span {ratio*100:.1f}%")

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <pdf_path> [--threshold <pct>]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    threshold = 0.25
    if "--threshold" in sys.argv:
        idx = sys.argv.index("--threshold")
        threshold = float(sys.argv[idx + 1]) / 100.0

    doc = fitz.open(pdf_path)
    total_pages = len(doc)

    print(f"Near-Empty Page Analysis: {pdf_path}")
    print(f"Pages: {total_pages} | Threshold: text < {threshold*100:.0f}% of page height")
    print("=" * 72)
    print(f"{'Pg':>3} {'Category':<22} {'Lines':>5} {'Figs':>4} {'Text Span':>10} {'% Page':>7} {'Detail'}")
    print("-" * 72)

    issues = []
    for i, page in enumerate(doc):
        text_min_y, text_max_y, text_span, page_h, num_lines, num_figures = get_text_coverage(page)
        cat, detail = classify_page(i + 1, text_min_y, text_max_y, text_span, page_h, num_lines, num_figures, threshold)

        pct = (text_span / page_h * 100) if page_h > 0 and text_span > 0 else 0
        print(f"{i+1:>3} {cat:<22} {num_lines:>5} {num_figures:>4} {text_span:>8.1f}pt {pct:>6.1f}%  {detail}")

        if cat.startswith("NEAR-EMPTY") or cat == "BLANK" or cat == "FIGURE-ONLY":
            issues.append((i + 1, cat, detail))

    print("-" * 72)
    print(f"\nSummary: {len(issues)} issue(s) found out of {total_pages} pages")
    if issues:
        for pg, cat, detail in issues:
            print(f"  Page {pg}: [{cat}] {detail}")
    else:
        print("  All pages have adequate text coverage.")

    # Also compute overall text density (how much of total page area is text)
    total_text_area = 0
    total_page_area = 0
    for page in doc:
        pw, ph = page.rect.width, page.rect.height
        total_page_area += pw * ph
        for block in page.get_text("dict")["blocks"]:
            if block["type"] != 0:
                continue
            for line in block["lines"]:
                bbox = line["bbox"]
                total_text_area += (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])

    density = total_text_area / total_page_area * 100 if total_page_area > 0 else 0
    print(f"\nOverall text area density: {density:.1f}% of total page area")

    doc.close()

if __name__ == "__main__":
    main()