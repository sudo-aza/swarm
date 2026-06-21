#!/usr/bin/env python3
"""Detailed page analysis: show all text lines and figure rects on a specific page."""

import sys
import fitz

def analyze_page(path, page_num):
    doc = fitz.open(path)
    page = doc[page_num - 1]
    
    print(f"=== Page {page_num} ===")
    print(f"Page size: {page.rect.width:.1f} x {page.rect.height:.1f} pt")
    print()
    
    # Get figure rectangles
    drawings = page.get_drawings()
    fig_rects = []
    for d in drawings:
        r = d["rect"]
        fill = d.get("fill", None)
        if fill and fill != (1, 1, 1):
            fig_rects.append(r)
    
    print(f"Figure rectangles ({len(fig_rects)}):")
    for i, r in enumerate(fig_rects):
        print(f"  #{i+1}: x={r.x0:.1f}..{r.x1:.1f}, y={r.y0:.1f}..{r.y1:.1f} "
              f"(w={r.width:.1f}, h={r.height:.1f})")
    print()
    
    # Get text lines
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
    lines = []
    for b in blocks:
        if b["type"] != 0:
            continue
        for line in b["lines"]:
            bbox = line["bbox"]
            text = "".join(span["text"] for span in line["spans"]).strip()
            if text:
                lines.append((bbox[1], bbox, text))  # sort by y
    
    lines.sort()
    
    print(f"Text lines ({len(lines)}):")
    for y, bbox, text in lines:
        lw = bbox[2] - bbox[0]
        # Check if this line overlaps with any figure
        overlaps = []
        line_rect = fitz.Rect(bbox)
        for fr in fig_rects:
            if line_rect.intersects(fr):
                overlaps.append(f"  OVERLAP with fig at y={fr.y0:.1f}..{fr.y1:.1f}")
        
        marker = " <<<< OVERLAP" if overlaps else ""
        print(f"  y={y:.1f}, w={lw:.1f}: \"{text[:70]}\"{marker}")
        for o in overlaps:
            print(o)
    
    doc.close()

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "test-stress-50.pdf"
    pages = [int(x) for x in sys.argv[2:]] if len(sys.argv) > 2 else [5]
    for p in pages:
        analyze_page(path, p)
        print()
