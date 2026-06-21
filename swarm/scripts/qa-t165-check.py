#!/usr/bin/env python3
"""Quick check for v3.53 — verify 1000-fig 1-fig pages match v3.49 pattern."""
import fitz
import os

pdf_path = "/home/z/my-project/swarm/src/test-wrapfig/test-1000fig.pdf"
doc = fitz.open(pdf_path)
npages = len(doc)

# Check pages with only 1 figure
single_fig_pages = []
for pg_i in range(npages):
    page = doc[pg_i]
    pg_num = pg_i + 1
    pw = page.rect.width
    figs = [d for d in page.get_drawings() if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect') and d['rect'].width > 10 and d['rect'].height > 10]
    if len(figs) == 1:
        r = figs[0]['rect']
        ink = len(page.get_text().strip())
        single_fig_pages.append((pg_num, ink, r.width, r.height))

print(f"v3.53 1000-fig: {npages} pages, {os.path.getsize(pdf_path)} bytes")
print(f"\nSingle-figure pages: {len(single_fig_pages)}")
for pg, ink, fw, fh in single_fig_pages:
    print(f"  pg{pg:3d}: {ink:5d} chars ink, fig {fw:.0f}x{fh:.0f}pt")

# Also check stress-50 ghost narrowing area (pg17-19)
print("\n--- stress-50 ghost narrowing check (pg17-19) ---")
stress_path = "/home/z/my-project/swarm/src/test-wrapfig/test-stress-50.pdf"
doc2 = fitz.open(stress_path)
for pg_i in range(16, min(20, len(doc2))):
    page = doc2[pg_i]
    pg_num = pg_i + 1
    pw = page.rect.width
    figs = [d for d in page.get_drawings() if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect') and d['rect'].width > 10 and d['rect'].height > 10]
    spans = []
    for blk in page.get_text("dict")["blocks"]:
        if blk["type"] == 0:
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    if len(span["text"].strip()) > 3:
                        spans.append({"w": span["bbox"][2]-span["bbox"][0], "y": span["bbox"][1], "text": span["text"].strip()[:40]})
    narrow = [s for s in spans if s["w"] < pw * 0.85 and s["w"] > 20]
    status = f"{len(narrow)} narrow, {len(figs)} figs"
    print(f"  pg{pg_num}: {status}")
    for s in narrow[:3]:
        print(f"    w={s['w']:.0f}pt y={s['y']:.0f} '{s['text']}'")

doc.close()
doc2.close()
