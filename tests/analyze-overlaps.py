#!/usr/bin/env python3
"""Analyze swarmwrap.sty PDF for body-text overlaps with figures.

Detects overlaps between full-width text blocks and figure rectangles
(\smash{\rlap} content). Reports page number, overlap area, and text content.
"""

import sys
import fitz  # PyMuPDF

def analyze_pdf(path):
    doc = fitz.open(path)
    full_width = None  # text width for A4 with default margins
    
    overlaps = []
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        blocks = page.get_text("blocks")
        
        # Get figure rectangles from drawings (rule commands in the minipages)
        drawings = page.get_drawings()
        
        # Find figure regions: rectangles that are likely \rule{}{} inside minipages
        # These appear as filled rectangles in the right portion of the page
        figure_rects = []
        for d in drawings:
            r = d["rect"]
            fill = d.get("fill", None)
            if fill and fill != (1, 1, 1):  # non-white fill = likely a rule
                # Check if it's in the right portion of the page (figures are right-aligned)
                page_w = page.rect.width
                if r.x0 > page_w * 0.4:  # right 60% of page
                    figure_rects.append(r)
        
        # Also look for text blocks that contain "Fig" labels to find figure captions
        caption_rects = []
        for b in blocks:
            text = b[4].strip()
            if text.startswith("Fig ") and "(" in text and ")." in text:
                caption_rects.append(fitz.Rect(b[0], b[1], b[2], b[3]))
        
        # Get full-width text blocks (potential overlap candidates)
        text_blocks = []
        for b in blocks:
            text = b[4].strip()
            if not text:
                continue
            # Skip caption-like text
            if text.startswith("Fig ") and "(" in text:
                continue
            text_blocks.append({
                "rect": fitz.Rect(b[0], b[1], b[2], b[3]),
                "text": text,
                "x0": b[0],
                "width": b[2] - b[0],
            })
        
        # Determine full-width threshold from the widest text blocks
        if text_blocks:
            widths = [tb["width"] for tb in text_blocks]
            page_full_width = max(widths)
            if full_width is None or page_full_width > full_width:
                full_width = page_full_width
        
        # Detect overlaps: full-width text that intersects with figure regions
        # Combine figure rects and caption rects into overall figure zones
        fig_zones = figure_rects + caption_rects
        
        for tb in text_blocks:
            tr = tb["rect"]
            tw = tb["width"]
            
            # Only check "full-width" text (within 20pt of max width)
            if full_width and tw >= full_width - 20:
                for fz in fig_zones:
                    if tr.intersects(fz):
                        overlap_rect = tr & fz
                        overlap_area = overlap_rect.get_area()
                        if overlap_area > 10:  # threshold to ignore tiny overlaps
                            overlaps.append({
                                "page": page_num + 1,
                                "text": tb["text"][:60],
                                "text_rect": tr,
                                "fig_rect": fz,
                                "overlap_area": overlap_area,
                                "overlap_rect": overlap_rect,
                                "text_width": tw,
                            })
    
    doc.close()
    return overlaps, full_width

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "test-stress-50.pdf"
    overlaps, fw = analyze_pdf(path)
    
    print(f"Full-width threshold: {fw:.1f}pt" if fw else "No full-width threshold found")
    print(f"Overlaps found: {len(overlaps)}")
    print()
    
    for o in overlaps:
        print(f"  Page {o['page']}: area={o['overlap_area']:.0f} sqpt")
        print(f"    Text (w={o['text_width']:.1f}pt): \"{o['text']}\"")
        print(f"    Text rect:  y={o['text_rect'].y0:.1f}..{o['text_rect'].y1:.1f}, x={o['text_rect'].x0:.1f}..{o['text_rect'].x1:.1f}")
        print(f"    Fig  rect:  y={o['fig_rect'].y0:.1f}..{o['fig_rect'].y1:.1f}, x={o['fig_rect'].x0:.1f}..{o['fig_rect'].x1:.1f}")
        print()
