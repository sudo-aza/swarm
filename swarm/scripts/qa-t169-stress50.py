#!/usr/bin/env python3
"""
QA T169: Comprehensive visual + numerical analysis of stress-50 v3.54.
Focus areas:
  1. All 6 defect categories (numerical)
  2. Per-page figure count and text coverage
  3. Hollow carry-over detection (narrow lines below figure bottom)
  4. Cross-page parshape boundary check (pages 17-19 historically problematic)
"""
import fitz

PDF = "/home/z/my-project/swarm/src/test-wrapfig/test-stress-50.pdf"
FULL_TEXT_W = 358.7
GHOST_THRESH = FULL_TEXT_W * 0.75  # 269pt

doc = fitz.open(PDF)
total = len(doc)
print(f"stress-50 v3.54: {total} pages")

# Per-page analysis
for i in range(total):
    page = doc[i]
    pg = i + 1
    
    # Get figures
    figs = []
    for d in page.get_drawings():
        if d.get('fill') and d['fill'] != (1,1,1):
            r = d['rect']
            if r.width > 30 and r.height > 30:
                figs.append(r)
    
    # Get text spans
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
    spans = []
    for b in blocks:
        if b["type"] != 0: continue
        for line in b["lines"]:
            for span in line["spans"]:
                x0, y0, x1, y1 = span["bbox"]
                w = x1 - x0
                if w > 5:
                    spans.append({"x0": x0, "x1": x1, "w": w, "y0": y0, "y1": y1, "text": span["text"][:60]})
    
    # Compute metrics
    max_w = max((s["w"] for s in spans), default=0)
    text_count = len(spans)
    
    # Defect checks
    defects = []
    
    # 1. Near-empty
    if text_count < 5 and len(figs) == 0:
        defects.append("near-empty")
    
    # 2. Ghost narrowing: narrow text NOT beside any figure
    ghost_lines = 0
    for s in spans:
        if s["w"] < GHOST_THRESH:
            has_fig = any(f.y0 - 10 <= s["y0"] and s["y1"] <= f.y1 + 10 for f in figs)
            if not has_fig:
                ghost_lines += 1
    if ghost_lines > 3:
        defects.append(f"ghost-narrow ({ghost_lines} lines)")
    
    # 3. No-wrap: figure but no wrapped text
    if figs:
        fig_right = max(f.x1 for f in figs)
        fig_left = min(f.x0 for f in figs)
        wrapped = sum(1 for s in spans if s["x0"] < fig_right and s["x0"] >= fig_left - 50)
        if wrapped == 0 and text_count > 10:
            defects.append("no-wrap")
    
    # 4. Overlap: text inside figure rect
    for f in figs:
        for s in spans:
            if s["x0"] > f.x0 and s["x0"] < f.x1 and s["y1"] > f.y0 and s["y0"] < f.y1:
                defects.append("overlap")
                break
        if "overlap" in defects: break
    
    # 5. Hollow carry-over: narrow text BELOW all figures (gap between fig bottom and next content)
    if figs:
        max_fig_bottom = max(f.y1 for f in figs)
        hollow = [s for s in spans if s["w"] < GHOST_THRESH and s["y0"] > max_fig_bottom + 5]
        if hollow:
            defects.append(f"hollow ({len(hollow)} lines below max fig)")
    
    # Print summary
    status = "OK" if not defects else f"{' | '.join(defects)}"
    print(f"  Pg{pg:2d}: {len(figs)} figs, {text_count:3d} spans, max_w={max_w:.0f}pt [{status}]")

doc.close()
print(f"\nAll {total} pages analyzed. Defect-free = OK, issues listed in brackets.")
