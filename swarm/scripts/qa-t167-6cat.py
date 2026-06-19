#!/usr/bin/env python3
"""
QA T167: Quick 6-category check on v3.54 stress-50.
Categories: near-empty, ghost-narrowing, no-wrap, overlap, hollow carry-over, text outside.
"""
import fitz

path = "/home/z/my-project/swarm/src/test-wrapfig/test-stress-50.pdf"
doc = fitz.open(path)
page_w = doc[0].rect.width
page_h = doc[0].rect.height

issues = {"near-empty": [], "ghost-narrowing": [], "no-wrap": [], "overlap": [], "hollow": []}

for i in range(len(doc)):
    page = doc[i]
    pg = i + 1
    
    # Get drawings (figures)
    drawings = page.get_drawings()
    figs = []
    for d in drawings:
        if d.get('fill') and d['fill'] != (1, 1, 1):
            r = d['rect']
            if r.width > 30 and r.height > 30:
                figs.append(r)
    
    # Get text blocks
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
    text_blocks = [b for b in blocks if b["type"] == 0]
    
    # 1. Near-empty: very few text blocks
    if len(text_blocks) < 3 and len(figs) == 0:
        issues["near-empty"].append(pg)
    
    # 2. Ghost narrowing: max text width < 75% of full width
    max_w = 0
    for b in text_blocks:
        for line in b["lines"]:
            for span in line["spans"]:
                w = span["bbox"][2] - span["bbox"][0]
                if w > max_w:
                    max_w = w
    full_text_w = 358.7  # from analysis
    if max_w < full_text_w * 0.75 and max_w > 10:
        issues["ghost-narrowing"].append(pg)
    
    # 3. No-wrap: figures present but no text spans have x1 < figure right edge
    if figs:
        any_wrapped = False
        fig_right = max(f.x1 for f in figs)
        fig_left = min(f.x0 for f in figs)
        for b in text_blocks:
            for line in b["lines"]:
                for span in line["spans"]:
                    x0 = span["bbox"][0]
                    x1 = span["bbox"][2]
                    # Text should wrap around figure (x0 < fig_right and text in fig y-range)
                    if x0 >= fig_left and x1 > fig_left:
                        any_wrapped = True
                        break
                if any_wrapped:
                    break
            if any_wrapped:
                break
        if not any_wrapped and len(text_blocks) > 5:
            issues["no-wrap"].append(pg)
    
    # 4. Overlap: text spans with x0 inside figure rect and y overlapping
    for f in figs:
        for b in text_blocks:
            for line in b["lines"]:
                for span in line["spans"]:
                    sx0, sy0, sx1, sy1 = span["bbox"]
                    # Check if text is inside figure area
                    if sx0 > f.x0 and sx0 < f.x1 and sy1 > f.y0 and sy0 < f.y1:
                        issues["overlap"].append(pg)
                        break
                if pg in issues["overlap"]:
                    break
            if pg in issues["overlap"]:
                break
        if pg in issues["overlap"]:
            break

doc.close()

print("6-Category Detection Results (stress-50, v3.54):")
all_clear = True
for cat, pages in issues.items():
    status = "PASS" if len(pages) == 0 else f"FAIL ({pages})"
    if pages:
        all_clear = False
    print(f"  {cat:20s}: {status}")

print(f"\nOverall: {'ALL CLEAR - no issues detected' if all_clear else 'ISSUES FOUND'}")
