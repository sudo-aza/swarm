#!/usr/bin/env python3
"""
QA T168: Random-page deep inspection of 1000-fig stress test PDF.
Picks 10 random pages and analyzes each for all 6 defect categories.
Also computes overall statistics: figure distribution, text coverage patterns.
"""
import fitz
import random

random.seed(168)  # reproducible for audit

PDF_PATH = "/home/z/my-project/swarm/src/test-wrapfig/test-1000fig.pdf"

def get_figures(page):
    """Get figure rectangles from drawings (filled black rects)."""
    figs = []
    for d in page.get_drawings():
        if d.get('fill') and d['fill'] != (1, 1, 1):
            r = d['rect']
            if r.width > 30 and r.height > 30:
                figs.append(r)
    return figs

def get_text_widths(page):
    """Get all text span widths and positions."""
    widths = []
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
    for b in blocks:
        if b["type"] != 0:
            continue
        for line in b["lines"]:
            for span in line["spans"]:
                x0, y0, x1, y1 = span["bbox"]
                w = x1 - x0
                if w > 5:
                    widths.append((x0, x1, w, y0, y1, span["text"][:50]))
    return widths

def classify_page(page, pg_label):
    """Classify a single page for all defect categories."""
    figs = get_figures(page)
    spans = get_text_widths(page)
    
    defects = []
    page_w = page.rect.width
    
    # 1. Near-empty: very few text spans
    if len(spans) < 5 and len(figs) == 0:
        defects.append(("near-empty", f"{len(spans)} text spans, 0 figures"))
    
    # 2. Ghost narrowing: max text width < 75% of full page width
    max_w = max((s[2] for s in spans), default=0)
    full_w = 358.7  # known from A4 with LaTeX margins
    if max_w < full_w * 0.75 and max_w > 10:
        defects.append(("ghost-narrowing", f"max_text_w={max_w:.1f}pt (threshold={full_w*0.75:.1f}pt)"))
    
    # 3. No-wrap: figure present but no text has x0 inside figure x-range
    if figs:
        fig_right = max(f.x1 for f in figs)
        fig_left = min(f.x0 for f in figs)
        wrapped_spans = [s for s in spans if s[0] < fig_right and s[0] >= fig_left - 50]
        if not wrapped_spans and len(spans) > 10:
            defects.append(("no-wrap", f"{len(figs)} figs, 0 wrapped spans out of {len(spans)}"))
    
    # 4. Overlap: text inside figure rect
    for f in figs:
        for s in spans:
            sx0, sy0, sx1, sy1 = s[0], s[3], s[1], s[4]
            if sx0 > f.x0 and sx0 < f.x1 and sy1 > f.y0 and sy0 < f.y1:
                defects.append(("overlap", f"text at ({sx0:.0f},{sy0:.0f})-({sx1:.0f},{sy1:.0f}) inside fig ({f.x0:.0f},{f.y0:.0f})-({f.x1:.0f},{f.y1:.0f})"))
                break
    
    # 5. Hollow carry-over: narrow first lines on a page with no figure in that area
    if spans and len(spans) > 1:
        first_w = spans[0][2]
        if first_w < full_w * 0.7 and first_w > 10:
            # Check if any figure covers this y-position
            first_y = spans[0][3]
            has_fig_above = any(f.y0 < first_y + 20 and f.y1 > first_y - 20 for f in figs)
            if not has_fig_above and not figs:
                defects.append(("hollow-carry", f"first line w={first_w:.1f}pt, no figure nearby"))
    
    return figs, spans, defects


def main():
    doc = fitz.open(PDF_PATH)
    total = len(doc)
    print(f"PDF: {total} pages, {doc[0].rect.width:.1f}x{doc[0].rect.height:.1f}pt")
    
    # Pick 10 random pages
    pages_to_check = sorted(random.sample(range(total), min(10, total)))
    print(f"\nRandom pages to inspect: {[p+1 for p in pages_to_check]}")
    
    all_defects = []
    fig_dist = {}  # page -> fig count
    
    for i in range(total):
        page = doc[i]
        figs = get_figures(page)
        fig_dist[i+1] = len(figs)
    
    print(f"\nFigure distribution summary:")
    for count in sorted(set(fig_dist.values())):
        pages_with = sum(1 for v in fig_dist.values() if v == count)
        print(f"  {count} figs: {pages_with} pages ({pages_with/total*100:.1f}%)")
    
    print(f"\n--- Detailed Random Page Analysis ---")
    for pg_idx in pages_to_check:
        page = doc[pg_idx]
        pg_label = pg_idx + 1
        figs, spans, defects = classify_page(page, pg_label)
        
        status = "CLEAN" if not defects else "DEFECTS"
        print(f"\nPage {pg_label}: {len(figs)} figures, {len(spans)} text spans [{status}]")
        
        if defects:
            for cat, detail in defects:
                print(f"  !! {cat}: {detail}")
            all_defects.append((pg_label, defects))
        else:
            # Show widest span for sanity
            if spans:
                widest = max(spans, key=lambda s: s[2])
                print(f"  Max text width: {widest[2]:.1f}pt at y={widest[3]:.1f}")
    
    print(f"\n{'='*60}")
    print(f"OVERALL: {len(all_defects)} pages with defects out of {len(pages_to_check)} inspected")
    
    # Also check last 5 pages for edge effects
    print(f"\n--- Last 5 Pages Edge Check ---")
    for i in range(total - 5, total):
        page = doc[i]
        pg_label = i + 1
        figs, spans, defects = classify_page(page, pg_label)
        status = "CLEAN" if not defects else "DEFECTS"
        print(f"  Page {pg_label}: {len(figs)} figs, {len(spans)} spans [{status}]")
        if defects:
            for cat, detail in defects:
                print(f"    !! {cat}: {detail}")
                if cat not in [d[0] for _, dlist in all_defects for d in dlist]:
                    all_defects.append((pg_label, defects))
    
    doc.close()
    print(f"\nFINAL: {len(all_defects)} defect instances found")


if __name__ == "__main__":
    main()
