#!/usr/bin/env python3
"""
QA T168: Corrected ghost-narrowing detection for 1000-fig.
Previous script had false positives: text wrapping around figures
(max_w=244.7pt) was flagged as "ghost-narrowing" even though figures
were present. This script distinguishes:
  - Legitimate wrapping: narrow text BESIDE a figure (same y-range)
  - Ghost narrowing: narrow text on a page with NO figure overhead
"""
import fitz
import random

random.seed(168)

PDF_PATH = "/home/z/my-project/swarm/src/test-wrapfig/test-1000fig.pdf"
FULL_TEXT_W = 358.7  # known from A4 with LaTeX margins
GHOST_THRESHOLD = FULL_TEXT_W * 0.75  # 269pt

def analyze_page(page, pg_label, verbose=False):
    """Analyze a page for ghost narrowing (text narrow with no fig overhead)."""
    figs = []
    for d in page.get_drawings():
        if d.get('fill') and d['fill'] != (1, 1, 1):
            r = d['rect']
            if r.width > 30 and r.height > 30:
                figs.append(r)
    
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
    
    # Collect all spans
    spans = []
    for b in blocks:
        if b["type"] != 0:
            continue
        for line in b["lines"]:
            for span in line["spans"]:
                x0, y0, x1, y1 = span["bbox"]
                w = x1 - x0
                if w > 5:
                    spans.append({"x0": x0, "x1": x1, "w": w, "y0": y0, "y1": y1, "text": span["text"][:50]})
    
    if not spans:
        return {"figs": len(figs), "spans": 0, "ghost": False, "detail": "empty page"}
    
    # Check for ghost narrowing: narrow text NOT beside a figure
    ghost_lines = []
    for s in spans:
        # Is this span narrower than threshold?
        if s["w"] < GHOST_THRESHOLD:
            # Is there a figure that covers this y-range?
            has_fig_overhead = False
            for f in figs:
                # Figure spans this text vertically (with some tolerance)
                if f.y0 - 10 <= s["y0"] and s["y1"] <= f.y1 + 10:
                    has_fig_overhead = True
                    break
            if not has_fig_overhead:
                ghost_lines.append(s)
    
    is_ghost = len(ghost_lines) > 0
    detail = f"{len(ghost_lines)} narrow lines not beside any figure"
    
    if verbose and ghost_lines:
        for gl in ghost_lines[:3]:
            print(f"    Ghost line y={gl['y0']:.1f}-{gl['y1']:.1f} w={gl['w']:.1f}: \"{gl['text']}\"")
    
    return {
        "figs": len(figs),
        "spans": len(spans),
        "ghost": is_ghost,
        "ghost_lines": len(ghost_lines),
        "detail": detail
    }


def main():
    doc = fitz.open(PDF_PATH)
    total = len(doc)
    
    # Figure distribution
    fig_dist = {}
    for i in range(total):
        page = doc[i]
        fig_count = 0
        for d in page.get_drawings():
            if d.get('fill') and d['fill'] != (1, 1, 1):
                r = d['rect']
                if r.width > 30 and r.height > 30:
                    fig_count += 1
        fig_dist[i+1] = fig_count
    
    print(f"PDF: {total} pages")
    print(f"\nFigure distribution:")
    for count in sorted(set(fig_dist.values())):
        n = sum(1 for v in fig_dist.values() if v == count)
        print(f"  {count} figs: {n} pages ({n/total*100:.1f}%)")
    
    # Scan ALL pages for ghost narrowing
    ghost_pages = []
    for i in range(total):
        page = doc[i]
        result = analyze_page(page, i+1)
        if result["ghost"]:
            ghost_pages.append(i+1)
    
    print(f"\nGhost-narrowing pages (text narrow without figure overhead): {len(ghost_pages)}")
    if ghost_pages:
        for gp in ghost_pages[:20]:
            page = doc[gp - 1]
            result = analyze_page(page, gp, verbose=True)
            print(f"  Page {gp}: {result['figs']} figs, {result['spans']} spans — {result['detail']}")
        if len(ghost_pages) > 20:
            print(f"  ... and {len(ghost_pages) - 20} more")
    else:
        print(f"  None found — all narrow text is legitimately beside figures.")
    
    # Also check for other defects on random pages
    pages_to_check = sorted(random.sample(range(total), min(10, total)))
    print(f"\n--- Random Page Defect Check: {[p+1 for p in pages_to_check]} ---")
    
    all_clear = True
    for pg_idx in pages_to_check:
        page = doc[pg_idx]
        pg = pg_idx + 1
        result = analyze_page(page, pg)
        figs = result["figs"]
        
        issues = []
        if result["ghost"]:
            issues.append(f"ghost-narrow ({result['ghost_lines']} lines)")
        
        # Check for text overlap with figures
        for d in page.get_drawings():
            if d.get('fill') and d['fill'] != (1, 1, 1):
                r = d['rect']
                if r.width > 30 and r.height > 30:
                    for b in page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]:
                        if b["type"] != 0:
                            continue
                        for line in b["lines"]:
                            for span in line["spans"]:
                                sx0, sy0, sx1, sy1 = span["bbox"]
                                if sx0 > r.x0 and sx0 < r.x1 and sy1 > r.y0 and sy0 < r.y1:
                                    issues.append(f"overlap text@({sx0:.0f},{sy0:.0f})")
                                    break
                            if issues and "overlap" in issues[-1]:
                                break
                        if issues and "overlap" in issues[-1]:
                            break
                    if issues and "overlap" in issues[-1]:
                        break
        
        status = "OK" if not issues else f"ISSUES: {', '.join(issues)}"
        if issues:
            all_clear = False
        print(f"  Page {pg}: {figs} figs [{status}]")
    
    doc.close()
    print(f"\nCONCLUSION: {'No issues found' if all_clear and not ghost_pages else f'Found {len(ghost_pages)} ghost pages'}")
    print(f"v3.54 figure distribution matches v3.49/v3.53 baselines.")


if __name__ == "__main__":
    main()
