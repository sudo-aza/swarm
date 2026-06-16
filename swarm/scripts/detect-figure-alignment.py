#!/usr/bin/env python3
"""
detect-figure-alignment.py — Figure right-edge alignment audit for swarmwrap.sty tests.

Checks that all wrapped figures are right-edge aligned (per spec: "wrap figure on right").
Uses page.get_drawings() to find vector-rect figures (filled rects from \\rule commands).

Reports:
- Right-edge (x1) consistency per PDF
- Left-edge (x0) variance (should vary by figure width)
- Width/height of each figure rect
- Vertical gaps between figures on the same page
- Any figures extending beyond page text area bounds

Usage: python3 detect-figure-alignment.py <pdf_file> [--threshold N]
  --threshold: max allowed x1 deviation in points (default: 0.5)
"""

import sys
import fitz  # PyMuPDF

# Default to A4 (test suites use A4 with geometry package)
PAGE_W = 595.276  # A4 width in points
PAGE_H = 841.890  # A4 height in points
MARGIN_LEFT = 72.0
MARGIN_RIGHT = 72.0
MARGIN_TOP = 72.0
MARGIN_BOTTOM = 72.0
TEXT_RIGHT = PAGE_W - MARGIN_RIGHT  # ~523.3pt — page right margin
FIG_RIGHT = None  # Auto-detected from first figure's x1


def get_figure_rects(page):
    """Extract figure rectangles from page drawings (vector rects from \\rule)."""
    drawings = page.get_drawings()
    figures = []
    for d in drawings:
        if d.get("type") in ("f", "fs", "re"):
            rect = d.get("rect")
            if rect is None:
                continue
            w = rect.width
            h = rect.height
            # Filter: must be a substantial rectangle (figure, not a rule/line)
            if w > 50 and h > 25:
                figures.append({
                    "x0": rect.x0,
                    "y0": rect.y0,
                    "x1": rect.x1,
                    "y1": rect.y1,
                    "w": w,
                    "h": h,
                    "fill": d.get("fill"),
                    "type": d.get("type"),
                })
    return figures


def audit_pdf(filepath, threshold=0.5):
    """Audit figure alignment in a PDF."""
    doc = fitz.open(filepath)
    print(f"=== Figure Alignment Audit: {filepath} ===")
    print(f"Pages: {len(doc)}")
    print(f"Expected figure right edge (x1): auto-detect from first figure")
    print(f"Allowed deviation: ±{threshold:.1f}pt")
    print()

    all_x1 = []
    all_figures = []
    issues = []
    fig_ref_x1 = None  # Auto-detect right-edge from first figure

    for pg_num in range(len(doc)):
        page = doc[pg_num]
        figs = get_figure_rects(page)

        if not figs:
            continue

        page_label = pg_num + 1
        for i, fig in enumerate(figs):
            fig["page"] = page_label
            all_figures.append(fig)
            all_x1.append(fig["x1"])

            # Check right-edge alignment (auto-detect from first figure)
            if fig_ref_x1 is None:
                fig_ref_x1 = fig["x1"]
            else:
                x1_dev = abs(fig["x1"] - fig_ref_x1)
                if x1_dev > threshold:
                    issues.append({
                        "page": page_label,
                        "fig_idx": i,
                        "type": "RIGHT_EDGE_MISALIGN",
                        "detail": f"x1={fig['x1']:.1f}pt (expected {fig_ref_x1:.1f}pt, deviation={x1_dev:.1f}pt)",
                        "fig": fig,
                    })

            # Check if figure extends below text area bottom
            text_bottom = PAGE_H - MARGIN_BOTTOM
            if fig["y1"] > text_bottom + 1.0:  # 1pt tolerance
                overflow = fig["y1"] - text_bottom
                issues.append({
                    "page": page_label,
                    "fig_idx": i,
                    "type": "BELOW_TEXT_AREA",
                    "detail": f"y1={fig['y1']:.1f}pt exceeds text area bottom {text_bottom:.1f}pt by {overflow:.1f}pt",
                    "fig": fig,
                })
            # Check if figure extends below PAGE boundary (would be clipped)
            if fig["y1"] > PAGE_H + 0.5:
                clip_amt = fig["y1"] - PAGE_H
                pct = clip_amt / fig["h"] * 100
                issues.append({
                    "page": page_label,
                    "fig_idx": i,
                    "type": "CLIPPED_AT_PAGE_BOUNDARY",
                    "detail": (f"y1={fig['y1']:.1f}pt extends {clip_amt:.1f}pt below page ({PAGE_H:.1f}pt). "
                               f"{pct:.1f}% of figure height ({fig['h']:.1f}pt) is clipped."),
                    "fig": fig,
                })

            # Check if figure extends above text area top
            if fig["y0"] < MARGIN_TOP - 1.0:  # 1pt tolerance
                issues.append({
                    "page": page_label,
                    "fig_idx": i,
                    "type": "ABOVE_TEXT_AREA",
                    "detail": f"y0={fig['y0']:.1f}pt above text area top {MARGIN_TOP:.1f}pt",
                    "fig": fig,
                })

        # Check vertical overlap between figures on the same page
        if len(figs) > 1:
            sorted_figs = sorted(figs, key=lambda f: f["y0"])
            for j in range(len(sorted_figs) - 1):
                a = sorted_figs[j]
                b = sorted_figs[j + 1]
                # Overlap: a.y1 > b.y0 (in PDF coords, y increases downward)
                overlap = a["y1"] - b["y0"]
                if overlap > 1.0:  # More than 1pt overlap
                    issues.append({
                        "page": page_label,
                        "fig_idx": j,
                        "type": "FIG_FIG_VERTICAL_OVERLAP",
                        "detail": (f"Fig {j} y0={a['y0']:.1f} y1={a['y1']:.1f} overlaps "
                                   f"Fig {j+1} y0={b['y0']:.1f} y1={b['y1']:.1f} by {overlap:.1f}pt"),
                        "fig": a,
                    })

    # Summary statistics
    if all_x1:
        unique_x1 = sorted(set(round(v, 1) for v in all_x1))
        print(f"Total figures: {len(all_figures)}")
        print(f"Right-edge (x1) values: {unique_x1}")
        print(f"  min x1 = {min(all_x1):.2f}pt, max x1 = {max(all_x1):.2f}pt")
        print(f"  range  = {max(all_x1) - min(all_x1):.2f}pt")
        if len(unique_x1) == 1:
            print(f"  ALL figures right-aligned at x1={unique_x1[0]}pt (perfect consistency)")
        else:
            print(f"  WARNING: Multiple right-edge positions detected")

        # Left-edge statistics
        all_x0 = [f["x0"] for f in all_figures]
        unique_x0 = sorted(set(round(v, 1) for v in all_x0))
        print(f"\nLeft-edge (x0) values: {unique_x0}")
        print(f"  min x0 = {min(all_x0):.2f}pt, max x0 = {max(all_x0):.2f}pt")

        # Width statistics
        all_w = [f["w"] for f in all_figures]
        unique_w = sorted(set(round(v, 1) for v in all_w))
        print(f"\nWidth values: {unique_w}")
        print(f"  min w = {min(all_w):.2f}pt, max w = {max(all_w):.2f}pt")

        # Height statistics
        all_h = [f["h"] for f in all_figures]
        unique_h = sorted(set(round(v, 1) for v in all_h))
        print(f"\nHeight values: {unique_h}")
        print(f"  min h = {min(all_h):.2f}pt, max h = {max(all_h):.2f}pt")
    else:
        print("No figures found.")

    print()

    # Report issues
    if issues:
        print(f"ISSUES FOUND: {len(issues)}")
        for iss in issues:
            print(f"  [pg{iss['page']} fig{iss['fig_idx']}] {iss['type']}: {iss['detail']}")
    else:
        print("NO ALIGNMENT ISSUES: All figures are right-edge aligned within tolerance.")

    print()
    doc.close()
    return len(issues)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 detect-figure-alignment.py <pdf_file> [--threshold N]")
        sys.exit(1)

    filepath = sys.argv[1]
    threshold = 0.5
    if "--threshold" in sys.argv:
        idx = sys.argv.index("--threshold")
        threshold = float(sys.argv[idx + 1])

    total_issues = audit_pdf(filepath, threshold)
    sys.exit(0 if total_issues == 0 else 1)


if __name__ == "__main__":
    main()