#!/usr/bin/env python3
"""
QA T167: Verify v3.54 parshape reset fix for ghost narrowing.
Analyzes customwrap and pagebreak-variations PDFs.

Ghost narrowing detection: Pages where text width is significantly less
than the full page text width, indicating parshape leaked from a previous page.

T166 (v3.53) found:
  - customwrap: 5 ghost-narrowing pages (pg2, 5, 7, 9, 10)
  - pagebreak-variations: 7 ghost-narrowing pages (pg1, 4, 6, 8, 10, 12, 14)

v3.54 fix: Patches \newpage and \clearpage to reset parshape before page break.
Should fix scenario 'a' (explicit \newpage). Scenario 'b' (natural page breaks) NOT fixed.
"""

import fitz
import sys

def analyze_pdf(path, name):
    print(f"\n{'='*60}")
    print(f"  {name}")
    print(f"  File: {path}")
    print(f"{'='*60}")

    doc = fitz.open(path)
    total_pages = len(doc)
    print(f"  Total pages: {total_pages}")

    ghost_pages = []
    narrow_threshold_ratio = 0.75  # Text width < 75% of page width = ghost narrowing
    page_w_mm = doc[0].rect.width  # A4 = ~595pt ≈ 210mm

    for pg_num in range(total_pages):
        page = doc[pg_num]
        pg_label = pg_num + 1

        # Get all text blocks
        blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]

        # Find max text width on this page
        max_text_w = 0
        text_spans_info = []

        for block in blocks:
            if block["type"] != 0:  # text block
                continue
            for line in block["lines"]:
                for span in line["spans"]:
                    x0, y0, x1, y1 = span["bbox"]
                    w = x1 - x0
                    if w > 5:  # ignore tiny spans
                        text_spans_info.append((x0, x1, w, span["text"][:40]))
                        if w > max_text_w:
                            max_text_w = w

        # Also check page margins: effective text area
        # A4 with typical LaTeX margins: text area ~345pt (612pt - 2*~133.5pt margins)
        # Ghost narrowing shows text at ~200pt width (reduced by parshape)
        
        full_width = page.rect.width
        # Typical LaTeX text width with default margins ~ 345pt
        expected_text_width = full_width * 0.58  # ~345pt on A4 595pt
        
        is_ghost = False
        if max_text_w < expected_text_width * narrow_threshold_ratio and max_text_w > 10:
            is_ghost = True
            ghost_pages.append(pg_label)

        # Show details for narrow pages
        if is_ghost or pg_label <= 3:  # Always show first 3 pages
            print(f"\n  Page {pg_label}: max_text_w={max_text_w:.1f}pt, "
                  f"expected>{expected_text_width * narrow_threshold_ratio:.1f}pt "
                  f"{'*** GHOST NARROW ***' if is_ghost else 'OK'}")
            # Show widest span
            if text_spans_info:
                text_spans_info.sort(key=lambda s: s[2], reverse=True)
                for x0, x1, w, txt in text_spans_info[:3]:
                    print(f"    x0={x0:.1f} x1={x1:.1f} w={w:.1f} '{txt}'")

        # Also check for figures (drawings) on this page
        drawings = page.get_drawings()
        fig_count = 0
        for d in drawings:
            if d.get('fill') and d['fill'] != (1,1,1):
                r = d['rect']
                if r.width > 30 and r.height > 30:  # figure-sized
                    fig_count += 1

    print(f"\n  SUMMARY:")
    print(f"    Ghost-narrowing pages: {ghost_pages}")
    print(f"    Total ghost pages: {len(ghost_pages)} / {total_pages}")

    doc.close()
    return ghost_pages


def main():
    base = "/home/z/my-project/swarm/src/test-wrapfig"

    # Analyze customwrap
    customwrap_ghosts = analyze_pdf(f"{base}/test-customwrap.pdf", "customwrap")

    # Analyze pagebreak-variations
    pb_ghosts = analyze_pdf(f"{base}/test-pagebreak-variations.pdf", "pagebreak-variations")

    print(f"\n{'='*60}")
    print(f"  COMPARISON WITH T166 (v3.53) FINDINGS")
    print(f"{'='*60}")
    print(f"  customwrap:")
    print(f"    T166 (v3.53): 5 ghost pages [2, 5, 7, 9, 10]")
    print(f"    T167 (v3.54): {len(customwrap_ghosts)} ghost pages {customwrap_ghosts}")
    print(f"  pagebreak-variations:")
    print(f"    T166 (v3.53): 7 ghost pages [1, 4, 6, 8, 10, 12, 14]")
    print(f"    T167 (v3.54): {len(pb_ghosts)} ghost pages {pb_ghosts}")

    # Check for regressions in stress-50
    print(f"\n{'='*60}")
    print(f"  STRESS-50 REGRESSION CHECK")
    print(f"{'='*60}")
    stress_ghosts = analyze_pdf(f"{base}/test-stress-50.pdf", "stress-50")
    print(f"  v3.53 baseline: 0 ghost pages in stress-50")
    print(f"  v3.54 result:   {len(stress_ghosts)} ghost pages {stress_ghosts}")


if __name__ == "__main__":
    main()
