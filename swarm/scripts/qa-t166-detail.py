#!/usr/bin/env python3
"""Detailed overlap analysis for customwrap pg8 and ghost narrowing verification."""
import fitz

pdf_path = "/home/z/my-project/swarm/src/test-wrapfig/test-customwrap.pdf"
doc = fitz.open(pdf_path)
pw = doc[0].rect.width

# Check all pages for overlaps (more refined)
for pg_i in range(len(doc)):
    page = doc[pg_i]
    pg_num = pg_i + 1
    
    # Get figure rects
    fig_rects = []
    for d in page.get_drawings():
        if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect') and d['rect'].width > 10 and d['rect'].height > 10:
            fig_rects.append(d['rect'])
    
    if not fig_rects:
        continue
    
    # Get text spans with positions
    spans = []
    for blk in page.get_text("dict")["blocks"]:
        if blk["type"] == 0:
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    if len(span["text"].strip()) > 3:
                        spans.append({
                            "text": span["text"].strip()[:40],
                            "x0": span["bbox"][0],
                            "x1": span["bbox"][2],
                            "y0": span["bbox"][1],
                            "y1": span["bbox"][3],
                            "w": span["bbox"][2] - span["bbox"][0]
                        })
    
    # For each figure, check for text overlaps
    for fi, fr in enumerate(fig_rects):
        overlaps = []
        for s in spans:
            # Y overlap: text bottom is below figure top, text top is above figure bottom
            if s["y1"] > fr.y0 + 2 and s["y0"] < fr.y1 - 2:
                # X overlap: text extends into figure area
                if s["x1"] > fr.x0 + 2:
                    # This IS an overlap: text reaches into the figure's X region
                    overlaps.append(f"  text x=[{s['x0']:.0f},{s['x1']:.0f}] y=[{s['y0']:.0f},{s['y1']:.0f}] w={s['w']:.0f} fig x=[{fr.x0:.0f},{fr.x1:.0f}] y=[{fr.y0:.0f},{fr.y1:.0f}] '{s['text']}'")
        
        if overlaps:
            print(f"pg{pg_num} fig{fi+1} ({fr.width:.0f}x{fr.height:.0f}): {len(overlaps)} overlaps")
            for o in overlaps[:5]:
                print(o)

# Ghost narrowing check: pages with narrowed text but NO figure
print("\n--- Ghost narrowing analysis ---")
for pg_i in range(len(doc)):
    page = doc[pg_i]
    pg_num = pg_i + 1
    
    fig_rects = [d['rect'] for d in page.get_drawings() if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect') and d['rect'].width > 10 and d['rect'].height > 10]
    
    spans = []
    for blk in page.get_text("dict")["blocks"]:
        if blk["type"] == 0:
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    if len(span["text"].strip()) > 3:
                        spans.append({"w": span["bbox"][2]-span["bbox"][0], "y": span["bbox"][1], "x0": span["bbox"][0], "text": span["text"].strip()[:40]})
    
    narrow = [s for s in spans if s["w"] < pw * 0.85 and s["w"] > 20]
    
    if narrow and len(fig_rects) == 0:
        print(f"pg{pg_num}: GHOST NARROW ({len(narrow)} narrow lines, 0 figs)")
        for s in narrow[:3]:
            print(f"  w={s['w']:.0f}pt y={s['y']:.0f} x0={s['x0']:.0f} '{s['text']}'")
    elif narrow and len(fig_rects) > 0:
        print(f"pg{pg_num}: {len(narrow)} narrow lines, {len(fig_rects)} figs (normal wrapping)")

doc.close()

# Also check pagebreak-variations
print("\n\n--- pagebreak-variations ghost narrowing ---")
pdf2 = "/home/z/my-project/swarm/src/test-wrapfig/test-pagebreak-variations.pdf"
doc2 = fitz.open(pdf2)
pw2 = doc2[0].rect.width

for pg_i in range(len(doc2)):
    page = doc2[pg_i]
    pg_num = pg_i + 1
    
    fig_rects = [d['rect'] for d in page.get_drawings() if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect') and d['rect'].width > 10 and d['rect'].height > 10]
    
    spans = []
    for blk in page.get_text("dict")["blocks"]:
        if blk["type"] == 0:
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    if len(span["text"].strip()) > 3:
                        spans.append({"w": span["bbox"][2]-span["bbox"][0], "y": span["bbox"][1], "x0": span["bbox"][0], "text": span["text"].strip()[:40]})
    
    narrow = [s for s in spans if s["w"] < pw2 * 0.85 and s["w"] > 20]
    
    if narrow and len(fig_rects) == 0:
        print(f"pg{pg_num}: GHOST NARROW ({len(narrow)} narrow lines, 0 figs)")
        for s in narrow[:2]:
            print(f"  w={s['w']:.0f}pt y={s['y']:.0f} '{s['text']}'")
    elif len(fig_rects) > 0:
        print(f"pg{pg_num}: {len(fig_rects)} figs, {len(narrow)} narrow (normal)")

doc2.close()
