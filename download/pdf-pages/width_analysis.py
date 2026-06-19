"""Analyze text width usage across ALL pages of both PDFs."""
import fitz
import json

def analyze_text_width(pdf_path, label):
    doc = fitz.open(pdf_path)
    pw = doc[0].rect.width
    
    page_stats = []
    all_narrow_pages = []
    all_ghost_pages = []
    
    for pi in range(len(doc)):
        page = doc[pi]
        blocks = page.get_text("blocks")
        drawings = page.get_drawings()
        
        fig_rects = [d["rect"] for d in drawings if d.get("fill") and d["rect"].width > 10 and d["rect"].height > 10]
        has_fig = len(fig_rects) > 0
        
        text_blocks = []
        for b in blocks:
            x0, y0, x1, y1, text, bno, btype = b
            if btype == 0 and len(text.strip()) > 30:
                text_blocks.append({"x0": x0, "x1": x1, "width": x1-x0, "chars": len(text.strip())})
        
        if not text_blocks:
            page_stats.append({"page": pi+1, "status": "empty"})
            continue
        
        max_width = max(t["width"] for t in text_blocks)
        min_width = min(t["width"] for t in text_blocks if t["chars"] > 50) if any(t["chars"] > 50 for t in text_blocks) else 0
        width_pct = max_width / pw * 100
        
        has_narrow = any(t["width"] < pw * 0.45 and t["chars"] > 50 for t in text_blocks)
        
        stat = {
            "page": pi+1,
            "figs": len(fig_rects),
            "max_text_width": round(max_width, 1),
            "min_text_width": round(min_width, 1),
            "width_pct": round(width_pct, 1),
            "has_narrow": has_narrow,
            "blocks": len(text_blocks),
        }
        
        if has_narrow and not has_fig:
            stat["status"] = "GHOST NARROW"
            all_ghost_pages.append(pi+1)
        elif width_pct < 50:
            stat["status"] = "VERY NARROW"
            all_narrow_pages.append(pi+1)
        elif has_narrow and has_fig:
            stat["status"] = "wrapped"
        else:
            stat["status"] = "ok"
        
        page_stats.append(stat)
    
    doc.close()
    
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    
    # Overall width distribution
    width_pcts = [s["width_pct"] for s in page_stats if "width_pct" in s]
    if width_pcts:
        print(f"Text width usage: min={min(width_pcts):.0f}%, max={max(width_pcts):.0f}%, mean={sum(width_pcts)/len(width_pcts):.0f}%")
    
    pages_full_width = sum(1 for s in page_stats if s.get("width_pct", 0) >= 70)
    pages_narrow = sum(1 for s in page_stats if s.get("width_pct", 0) < 50)
    pages_wrapped = sum(1 for s in page_stats if s["status"] == "wrapped")
    pages_ghost = sum(1 for s in page_stats if s["status"] == "GHOST NARROW")
    
    print(f"Full-width pages (>=70%): {pages_full_width}/{len(page_stats)}")
    print(f"Very narrow pages (<50%): {pages_narrow}/{len(page_stats)}")
    print(f"Properly wrapped pages: {pages_wrapped}/{len(page_stats)}")
    print(f"Ghost-narrowed pages (narrow but no figure): {pages_ghost}/{len(page_stats)}")
    
    if all_ghost_pages:
        print(f"  Ghost pages: {all_ghost_pages}")
    
    # Per-page detail
    print(f"\nPer-page detail:")
    for s in page_stats:
        marker = ""
        if s["status"] == "GHOST NARROW":
            marker = " <<< GHOST"
        elif s["status"] == "VERY NARROW":
            marker = " <<< NARROW"
        print(f"  p{s['page']:3d}: {s.get('width_pct',0):5.1f}% width, figs={s.get('figs',0)}, blocks={s.get('blocks',0)}, status={s['status']}{marker}")
    
    return page_stats

r50 = analyze_text_width("/home/z/my-project/swarm/tests/test-stress-50.pdf", "50-PAGE PDF (ALL 50 pages)")
r1000 = analyze_text_width("/home/z/my-project/swarm/tests/test-stress-1000.pdf", "1000-PAGE PDF (ALL 1234 pages)")

with open("/home/z/my-project/download/pdf-pages/width-analysis.json", 'w') as f:
    json.dump({"50page": r50, "1000page": r1000}, f, indent=2)
