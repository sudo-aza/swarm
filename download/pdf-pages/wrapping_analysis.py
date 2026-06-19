"""
Comprehensive layout analysis: Does text actually WRAP around figures,
or are figures just floating as separate blocks?
"""
import fitz
import json
import sys

def analyze_wrapping(pdf_path, pages_to_check=None):
    doc = fitz.open(pdf_path)
    total = doc.page_count
    pw = doc[0].rect.width  # page width (A4 = 595)
    
    if pages_to_check is None:
        pages_to_check = range(total)
    
    results = []
    wrapping_failures = []
    ghost_narrow_count = 0
    float_count = 0
    proper_wrap_count = 0
    
    for pi in pages_to_check:
        if pi >= total:
            continue
        page = doc[pi]
        
        # Get all drawings (the colored rectangles = figures)
        drawings = page.get_drawings()
        fig_rects = []
        for d in drawings:
            r = d["rect"]
            fill = d.get("fill")
            if fill and r.width > 10 and r.height > 10:  # actual figure rectangles
                fig_rects.append(r)
        
        # Get text blocks
        blocks = page.get_text("blocks")
        text_rects = []
        for b in blocks:
            x0, y0, x1, y1, text, bno, btype = b
            if btype == 0 and len(text.strip()) > 30:
                text_rects.append({"rect": fitz.Rect(x0, y0, x1, y1), "chars": len(text.strip())})
        
        page_info = {
            "page": pi + 1,
            "figures": len(fig_rects),
            "text_blocks": len(text_rects),
            "fig_rects": [{"x": round(r.x0,1), "y": round(r.y0,1), "w": round(r.width,1), "h": round(r.height,1)} for r in fig_rects],
            "issues": []
        }
        
        # Check for each figure: is there text on BOTH sides of it?
        for fi, fig in enumerate(fig_rects):
            has_text_left = False
            has_text_right = False
            has_text_overlapping = False
            
            for tr in text_rects:
                # Check vertical overlap
                if tr["rect"].y1 > fig.y0 + 10 and tr["rect"].y0 < fig.y1 - 10:
                    # Text vertically overlaps with figure
                    if tr["rect"].x1 <= fig.x0 + 5:
                        has_text_left = True
                    elif tr["rect"].x0 >= fig.x1 - 5:
                        has_text_right = True
                    else:
                        # Text overlaps horizontally with figure = BAD
                        has_text_overlapping = True
            
            if has_text_overlapping:
                page_info["issues"].append(f"Fig {fi}: TEXT OVERLAPS FIGURE")
            
            # Check for ghost-narrowing: text blocks that are unusually narrow
            for tr in text_rects:
                if tr["chars"] > 50 and tr["rect"].width < pw * 0.45:
                    # Check if this narrow block is beside a figure
                    beside_figure = False
                    for fig2 in fig_rects:
                        if (tr["rect"].y1 > fig2.y0 + 10 and tr["rect"].y0 < fig2.y1 - 10):
                            beside_figure = True
                            break
                    
                    if beside_figure:
                        ghost_narrow_count += 1
                    else:
                        page_info["issues"].append(f"NARROW text ({tr['rect'].width:.0f}pt) NOT beside any figure")
        
        # Key diagnostic: how much of page width is used by text?
        if text_rects:
            all_x0 = min(tr["rect"].x0 for tr in text_rects)
            all_x1 = max(tr["rect"].x1 for tr in text_rects)
            used_width = all_x1 - all_x0
            page_info["text_span"] = f"{all_x0:.0f}-{all_x1:.0f} ({used_width:.0f}pt / {pw:.0f}pt = {used_width/pw*100:.0f}%)"
            
            # Full width text blocks (no wrapping) vs narrow (wrapped)
            full_width_blocks = sum(1 for tr in text_rects if tr["rect"].width > pw * 0.7)
            narrow_blocks = sum(1 for tr in text_rects if tr["rect"].width < pw * 0.45 and tr["chars"] > 50)
            page_info["full_width_blocks"] = full_width_blocks
            page_info["narrow_blocks"] = narrow_blocks
        
        if fig_rects and not text_rects:
            page_info["issues"].append("Page has figures but NO text blocks!")
        
        if page_info["issues"]:
            wrapping_failures.append(page_info)
        
        results.append(page_info)
    
    doc.close()
    
    # Summary
    print(f"PDF: {pdf_path} ({total} pages)")
    print(f"Analyzed {len(results)} pages")
    print(f"\n--- Layout Summary ---")
    
    pages_with_figures = sum(1 for r in results if r["figures"] > 0)
    pages_with_text = sum(1 for r in results if r["text_blocks"] > 0)
    print(f"Pages with figures: {pages_with_figures}")
    print(f"Pages with text: {pages_with_text}")
    print(f"Ghost-narrowed text blocks: {ghost_narrow_count}")
    print(f"Pages with issues: {len(wrapping_failures)}")
    
    if wrapping_failures:
        print(f"\n--- Pages with Issues ---")
        for pf in wrapping_failures:
            print(f"  Page {pf['page']}: figs={pf['figures']}, text_blocks={pf['text_blocks']}")
            for issue in pf["issues"]:
                print(f"    ⚠ {issue}")
            if "text_span" in pf:
                print(f"    Text span: {pf['text_span']}, narrow_blocks={pf.get('narrow_blocks',0)}, full_width_blocks={pf.get('full_width_blocks',0)}")
    
    # Check the overall pattern: does text actually flow around figures?
    print(f"\n--- Text Width Pattern Analysis ---")
    narrow_ratio_pages = []
    for r in results:
        if r.get("narrow_blocks", 0) > 0 and r.get("full_width_blocks", 0) > 0:
            narrow_ratio_pages.append(r["page"])
        elif r.get("narrow_blocks", 0) > 0 and r["figures"] == 0:
            print(f"  ⚠ Page {r['page']}: Has narrow text but NO figures — ghost narrowing without cause!")
    
    if narrow_ratio_pages:
        print(f"  Pages with BOTH narrow and full-width text (proper wrapping): {narrow_ratio_pages[:20]}...")
    
    return results

# Analyze 50-page PDF
print("=" * 80)
print("50-PAGE PDF ANALYSIS")
print("=" * 80)
r50 = analyze_wrapping("/home/z/my-project/swarm/tests/test-stress-50.pdf", range(50))

# Analyze sample from 1000-page PDF
print("\n" + "=" * 80)
print("1000-PAGE PDF ANALYSIS (sample)")
print("=" * 80)
r1000 = analyze_wrapping("/home/z/my-project/swarm/tests/test-stress-1000.pdf", 
                          [0,1,2,3,4, 49,99,199,499,799,999, 1233])

# Save
with open("/home/z/my-project/download/pdf-pages/full-layout-analysis.json", 'w') as f:
    json.dump({"50page": r50, "1000page_sample": r1000}, f, indent=2)
print(f"\nFull results saved to /home/z/my-project/download/pdf-pages/full-layout-analysis.json")
