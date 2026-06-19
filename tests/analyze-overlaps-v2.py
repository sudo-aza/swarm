#!/usr/bin/env python3
"""Analyze swarmwrap.sty PDF for body-text overlaps at LINE level.

Checks individual text lines (not blocks) against figure rectangles.
Only reports overlaps where the line is FULL WIDTH and intersects a figure.
"""

import sys
import fitz

def analyze_pdf(path):
    doc = fitz.open(path)
    
    # First pass: determine full-width threshold from the widest individual lines
    all_line_widths = []
    for page_num in range(len(doc)):
        page = doc[page_num]
        blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
        for b in blocks:
            if b["type"] != 0:  # skip image blocks
                continue
            for line in b["lines"]:
                lw = line["bbox"][2] - line["bbox"][0]
                all_line_widths.append(lw)
    
    if not all_line_widths:
        return []
    
    # Full-width = 95th percentile of line widths
    all_line_widths.sort()
    fw_idx = int(len(all_line_widths) * 0.95)
    full_width = all_line_widths[min(fw_idx, len(all_line_widths)-1)]
    narrow_threshold = full_width * 0.85  # lines narrower than this are "narrow"
    
    print(f"Full-width threshold (95th pct): {full_width:.1f}pt")
    print(f"Narrow threshold (<85%): {narrow_threshold:.1f}pt")
    print()
    
    overlaps = []
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        
        # Get figure rectangles from drawings
        drawings = page.get_drawings()
        fig_rects = []
        for d in drawings:
            r = d["rect"]
            fill = d.get("fill", None)
            if fill and fill != (1, 1, 1):
                page_w = page.rect.width
                if r.x0 > page_w * 0.3:
                    fig_rects.append(r)
        
        # Get text lines
        blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
        
        page_overlaps = []
        for b in blocks:
            if b["type"] != 0:
                continue
            for line in b["lines"]:
                bbox = line["bbox"]
                lw = bbox[2] - bbox[0]
                text = "".join(span["text"] for span in line["spans"]).strip()
                
                if not text:
                    continue
                # Skip figure captions
                if text.startswith("Fig ") and "(" in text and ")." in text:
                    continue
                
                # Only check lines that are approximately full-width
                if lw < narrow_threshold:
                    continue
                
                line_rect = fitz.Rect(bbox)
                for fr in fig_rects:
                    if line_rect.intersects(fr):
                        overlap_area = (line_rect & fr).get_area()
                        if overlap_area > 5:
                            page_overlaps.append({
                                "page": page_num + 1,
                                "text": text[:80],
                                "y": bbox[1],
                                "line_width": lw,
                                "overlap_area": overlap_area,
                                "fig_rect": fr,
                                "line_rect": line_rect,
                            })
        
        if page_overlaps:
            overlaps.extend(page_overlaps)
    
    doc.close()
    return overlaps

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "test-stress-50.pdf"
    overlaps = analyze_pdf(path)
    
    # Deduplicate by page + y position (within 2pt)
    seen = set()
    unique = []
    for o in overlaps:
        key = (o["page"], round(o["y"] / 2) * 2)
        if key not in seen:
            seen.add(key)
            unique.append(o)
    
    print(f"Overlapping lines found: {len(unique)}")
    print()
    for o in unique:
        print(f"  Page {o['page']}, y={o['y']:.1f}: w={o['line_width']:.1f}pt, "
              f"overlap={o['overlap_area']:.0f}sqpt")
        print(f"    \"{o['text']}\"")
        print()
