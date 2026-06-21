"""Analyze PDF page layout to understand visual quality issues."""
import fitz
import json
import sys

def analyze_page_layout(pdf_path, page_num, dpi=150):
    """Analyze the layout of a single page."""
    doc = fitz.open(pdf_path)
    page = doc[page_num]
    rect = page.rect
    
    # Get all text blocks
    blocks = page.get_text("blocks")
    # Get all images
    images = page.get_images(full=True)
    
    # Get text dict for detailed analysis
    text_dict = page.get_text("dict")
    
    results = {
        "page": page_num + 1,
        "page_size": f"{rect.width:.0f}x{rect.height:.0f}",
        "text_blocks": len(blocks),
        "images": len(images),
        "text_spans": [],
        "image_rects": [],
    }
    
    # Analyze text blocks
    for block in blocks:
        x0, y0, x1, y1, text, block_no, block_type = block
        if block_type == 0:  # text block
            width = x1 - x0
            results["text_spans"].append({
                "bbox": [round(x0,1), round(y0,1), round(x1,1), round(y1,1)],
                "width": round(width, 1),
                "lines": text.strip().count('\n') + 1 if text.strip() else 0,
                "char_count": len(text.strip()),
            })
    
    # Get image positions via drawing commands
    for img_info in images:
        xref = img_info[0]
        img_rects = page.get_image_rects(xref)
        for r in img_rects:
            results["image_rects"].append({
                "bbox": [round(r.x0,1), round(r.y0,1), round(r.x1,1), round(r.y1,1)],
                "width": round(r.width, 1),
                "height": round(r.height, 1),
            })
    
    # Analyze text column width distribution
    text_widths = [s["width"] for s in results["text_spans"] if s["char_count"] > 20]
    if text_widths:
        results["text_width_stats"] = {
            "min": round(min(text_widths), 1),
            "max": round(max(text_widths), 1),
            "mean": round(sum(text_widths)/len(text_widths), 1),
            "unique_widths": len(set(round(w, 0) for w in text_widths)),
        }
    
    doc.close()
    return results

def main():
    pdf_path = sys.argv[1] if len(sys.argv) > 1 else "/home/z/my-project/swarm/tests/test-stress-50.pdf"
    pages = [int(x) for x in sys.argv[2:]] if len(sys.argv) > 2 else list(range(5))
    
    doc = fitz.open(pdf_path)
    total_pages = len(doc)
    doc.close()
    
    print(f"PDF: {pdf_path}")
    print(f"Total pages: {total_pages}")
    print(f"Analyzing pages: {[p+1 for p in pages]}")
    print("=" * 80)
    
    all_results = []
    for p in pages:
        if p >= total_pages:
            continue
        r = analyze_page_layout(pdf_path, p)
        all_results.append(r)
        
        print(f"\n--- Page {r['page']} ({r['page_size']}) ---")
        print(f"  Text blocks: {r['text_blocks']}, Images: {r['images']}")
        if "text_width_stats" in r:
            s = r["text_width_stats"]
            print(f"  Text width: min={s['min']}, max={s['max']}, mean={s['mean']}, unique_widths={s['unique_widths']}")
        
        # Check for narrow text blocks (ghost-narrowing indicator)
        page_width = float(r['page_size'].split('x')[0])
        for span in r["text_spans"]:
            if span["char_count"] > 50 and span["width"] < page_width * 0.4:
                print(f"  ⚠ NARROW TEXT: width={span['width']}, bbox={span['bbox']}, chars={span['char_count']}")
        
        # Check image positions relative to text
        if r["image_rects"]:
            for img in r["image_rects"]:
                print(f"  📷 Image: {img['bbox']} ({img['width']}x{img['height']})")
    
    # Summary: how many pages have narrow text (ghost-narrowing)?
    narrow_pages = 0
    for r in all_results:
        page_width = float(r['page_size'].split('x')[0])
        has_narrow = any(
            s["char_count"] > 50 and s["width"] < page_width * 0.4
            for s in r["text_spans"]
        )
        if has_narrow:
            narrow_pages += 1
    
    print(f"\n{'='*80}")
    print(f"SUMMARY: {len(all_results)} pages analyzed, {narrow_pages} have narrow text (ghost-narrowing)")
    
    # Save
    out_path = "/home/z/my-project/download/pdf-pages/layout-analysis.json"
    with open(out_path, 'w') as f:
        json.dump(all_results, f, indent=2)
    print(f"Full results saved to {out_path}")

if __name__ == "__main__":
    main()
