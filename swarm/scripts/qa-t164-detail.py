#!/usr/bin/env python3
"""Detailed stress-50 analysis — check pg18 ghost narrowing, fig positioning, text widths."""
import fitz
import sys

pdf_path = "/home/z/my-project/swarm/src/test-wrapfig/test-stress-50.pdf"
doc = fitz.open(pdf_path)

print(f"stress-50 v3.52: {len(doc)} pages")
print()

# Detailed per-page analysis
for pg_i in range(len(doc)):
    page = doc[pg_i]
    pg_num = pg_i + 1
    pw = page.rect.width
    
    # Get figures
    drawings = page.get_drawings()
    figs = []
    for d in drawings:
        if d.get('fill') and d['fill'] != (1, 1, 1):
            r = d.get('rect')
            if r and r.width > 10 and r.height > 10:
                figs.append(r)
    
    # Get all text spans with positions
    spans = []
    for blk in page.get_text("dict")["blocks"]:
        if blk["type"] == 0:
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    spans.append({
                        "text": span["text"].strip(),
                        "x0": span["bbox"][0],
                        "x1": span["bbox"][2],
                        "y0": span["bbox"][1],
                        "y1": span["bbox"][3],
                        "w": span["bbox"][2] - span["bbox"][0],
                        "size": span["size"]
                    })
    
    # Check narrow lines
    narrow_threshold = pw * 0.85
    narrow_spans = [s for s in spans if s["w"] < narrow_threshold and s["w"] > 20 and len(s["text"]) > 5]
    
    # Check first line carry-over
    if spans:
        first = min(spans, key=lambda x: (x["y0"], x["x0"]))
        first_narrow = first["w"] < narrow_threshold and first["w"] > 20
    else:
        first_narrow = False
        first = None
    
    # Summary
    fig_desc = []
    for f in figs:
        fig_desc.append(f"({f.x0:.0f},{f.y0:.0f})-{f.width:.0f}x{f.height:.0f}")
    
    narrow_info = ""
    if narrow_spans:
        widths = sorted(set(round(s["w"]) for s in narrow_spans))
        narrow_info = f" narrow_lines={len(narrow_spans)} widths={widths}"
    
    first_info = ""
    if first:
        first_info = f" first_line_w={first['w']:.0f}pt {'NARROW' if first_narrow else 'full'}"
    
    print(f"pg{pg_num:2d}: {len(figs)} figs{narrow_info}{first_info}")

doc.close()

# Also check for the specific pg18 parshape leak from v3.49
print("\n--- Ghost narrowing check (was pg18 in v3.49) ---")
doc = fitz.open(pdf_path)
# In v3.49, Fig 43 was on pg17, ghost narrowing on pg18
# In v3.52 with 19pg, need to check around same area
for pg_i in range(15, min(20, len(doc))):
    page = doc[pg_i]
    pg_num = pg_i + 1
    pw = page.rect.width
    spans = []
    for blk in page.get_text("dict")["blocks"]:
        if blk["type"] == 0:
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    if len(span["text"].strip()) > 3:
                        spans.append({
                            "w": span["bbox"][2] - span["bbox"][0],
                            "y": span["bbox"][1],
                            "text": span["text"].strip()[:40]
                        })
    figs = [d for d in page.get_drawings() if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect', None) and d['rect'].width > 10]
    narrow = [s for s in spans if s["w"] < pw * 0.85 and s["w"] > 20]
    if narrow:
        print(f"  pg{pg_num}: {len(narrow)} narrow lines, {len(figs)} figs")
        for s in narrow[:3]:
            print(f"    w={s['w']:.0f}pt y={s['y']:.0f} '{s['text']}'")
    else:
        print(f"  pg{pg_num}: 0 narrow lines, {len(figs)} figs")

doc.close()
