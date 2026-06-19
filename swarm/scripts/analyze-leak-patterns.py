#!/usr/bin/env python3
"""
Parshape Leak Pattern Analyzer v2 (QA T92)
Properly calibrated thresholds based on actual text area dimensions.

Text area in test PDFs:
  - Left margin: ~118pt
  - Right margin: ~477pt
  - Full width: ~359pt
  - Narrowed (figure active): ~273-287pt (ends at figure left edge ~391-405pt)
  - Figure zone captions: x0~395, width~78pt

Leak definition: text line < 320pt wide, starting near left margin (x0 < 200),
NOT within the Y range of any figure on the SAME page.
"""

import sys
import fitz

FULL_WIDTH_MIN = 330    # pt - clearly full width text
NARROW_THRESHOLD = 320  # pt - below this = potentially narrowed
LEFT_MARGIN_MAX = 200   # pt - line must start near left margin
FIG_ZONE_MIN_X = 350    # pt - lines starting here are in figure zone (captions)

def get_figures(page, page_w):
    """Find figure rectangles via vector drawing detection."""
    figures = []
    for d in page.get_drawings():
        if d["type"] not in ("f", "fs", "re"):
            continue
        r = d["rect"]
        if r.width > 50 and r.height > 25 and r.x0 > page_w * 0.4:
            figures.append({"x0": r.x0, "y0": r.y0, "x1": r.x1, "y1": r.y1,
                           "width": r.width, "height": r.height})
    return figures

def analyze_pdf(pdf_path):
    doc = fitz.open(pdf_path)
    page_w = doc[0].rect.width
    page_h = doc[0].rect.height
    
    print(f"=== {pdf_path} ===")
    print(f"Pages: {len(doc)}, Size: {page_w:.1f} x {page_h:.1f} pt\n")
    
    all_data = []
    total_leaks = 0
    total_narrow_in_fig = 0  # narrow lines explained by figure on same page
    total_full_width = 0
    total_fig_zone = 0  # lines in figure zone (captions)
    total_artifact = 0  # tiny lines
    
    for i, page in enumerate(doc):
        pnum = i + 1
        figs = get_figures(page, page_w)
        blocks = page.get_text("blocks")
        
        # Get figure Y ranges on this page
        fig_y_ranges = [(f["y0"], f["y1"]) for f in figs]
        
        leaks = []
        narrow_explained = []
        full_width_lines = 0
        fig_zone_lines = 0
        artifacts = 0
        
        for b in blocks:
            if b[6] != 0:  # not text
                continue
            x0, y0, x1, y1 = b[0], b[1], b[2], b[3]
            w = x1 - x0
            y_mid = (y0 + y1) / 2
            
            # Skip artifacts (tiny lines)
            if w < 20:
                artifacts += 1
                continue
            
            # Skip figure zone lines (captions, labels in figure area)
            if x0 > FIG_ZONE_MIN_X:
                fig_zone_lines += 1
                continue
            
            # Skip indented paragraph starts (not leak-related)
            if x0 > LEFT_MARGIN_MAX:
                artifacts += 1
                continue
            
            if w >= FULL_WIDTH_MIN:
                full_width_lines += 1
            elif w < NARROW_THRESHOLD:
                # Narrow line - check if explained by a figure on this page
                covered = False
                for fy0, fy1 in fig_y_ranges:
                    if fy0 - 5 <= y_mid <= fy1 + 5:
                        covered = True
                        break
                if covered:
                    narrow_explained.append({"y": y_mid, "w": w, "x0": x0})
                    total_narrow_in_fig += 1
                else:
                    leaks.append({"y0": y0, "y1": y1, "w": w, "x0": x0,
                                 "y_mid": y_mid,
                                 "text": b[4].strip()[:50]})
                    total_leaks += 1
        
        # Text coverage
        text_area = sum((b[2]-b[0])*(b[3]-b[1]) for b in blocks if b[6]==0)
        coverage = text_area / (page_w * page_h) * 100
        
        pd = {
            "page": pnum, "figs": figs, "leaks": leaks,
            "narrow_explained": narrow_explained,
            "full_width": full_width_lines,
            "fig_zone": fig_zone_lines,
            "artifacts": artifacts,
            "coverage": coverage
        }
        all_data.append(pd)
        
        status = "LEAK" if leaks else "ok"
        print(f"  Pg {pnum:>2}: {len(figs)} figs, {len(leaks)} leaks, "
              f"{len(narrow_explained)} narrow-ok, {full_width_lines} full, "
              f"cov {coverage:.1f}% {status}")
    
    # Summary
    leak_pages = [p for p in all_data if p["leaks"]]
    print(f"\n  SUMMARY:")
    print(f"    Total leaked narrow lines: {total_leaks}")
    print(f"    Pages with leaks: {len(leak_pages)}/{len(doc)}")
    print(f"    Narrow lines explained by figs: {total_narrow_in_fig}")
    print(f"    Full-width lines (total): {total_full_width}")
    
    # Leak propagation
    print(f"\n  LEAK PROPAGATION:")
    for pd in all_data:
        if not pd["leaks"]:
            continue
        has_fig = len(pd["figs"]) > 0
        fig_status = "figs on page" if has_fig else "NO figs"
        
        # Find nearest preceding page with figure
        source = None
        for prev in reversed(all_data[:pd["page"]-1]):
            if prev["figs"]:
                source = prev
                break
        dist = f"{pd['page'] - source['page']}pg back" if source else "first page"
        
        # Check if leak lines are BELOW all figures on this page
        if has_fig and pd["figs"]:
            max_fig_bottom = max(f["y1"] for f in pd["figs"])
            below_fig = sum(1 for l in pd["leaks"] if l["y_mid"] > max_fig_bottom + 5)
            within_fig = len(pd["leaks"]) - below_fig
            print(f"    Pg {pd['page']}: {len(pd['leaks'])} leaks ({fig_status}), "
                  f"src: {dist}, "
                  f"below figs: {below_fig}, within fig Y: {within_fig}")
        else:
            print(f"    Pg {pd['page']}: {len(pd['leaks'])} leaks ({fig_status}), "
                  f"src: {dist}")
    
    # Width distribution of leaks
    if total_leaks > 0:
        all_leak_w = []
        for p in all_data:
            for l in p["leaks"]:
                all_leak_w.append(l["w"])
        avg_w = sum(all_leak_w) / len(all_leak_w)
        print(f"\n  LEAK WIDTH: avg={avg_w:.1f}, min={min(all_leak_w):.1f}, "
              f"max={max(all_leak_w):.1f}")
        
        # Categorize leaks by width
        very_narrow = sum(1 for w in all_leak_w if w < 200)
        moderate = sum(1 for w in all_leak_w if 200 <= w < 300)
        near_full = sum(1 for w in all_leak_w if w >= 300)
        print(f"    <200pt (very narrow): {very_narrow}")
        print(f"    200-300pt (moderate): {moderate}")
        print(f"    300-320pt (near full): {near_full}")
    
    doc.close()
    return total_leaks

if __name__ == "__main__":
    pdfs = [
        "/home/z/my-project/swarm/src/test-wrapfig/test-stress-50.pdf",
        "/home/z/my-project/swarm/src/test-wrapfig/test-customwrap.pdf",
        "/home/z/my-project/swarm/src/test-wrapfig/test-pagebreak-variations.pdf",
    ]
    total = 0
    for pdf in pdfs:
        n = analyze_pdf(pdf)
        total += n
        print()
    print(f"GRAND TOTAL LEAKED LINES: {total}")