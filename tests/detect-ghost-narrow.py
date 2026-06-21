#!/usr/bin/env python3
"""Detect ghost-narrowed lines in swarmwrap PDFs.

Strategy:
1. Find figure labels ("Fig N") and their positions to locate figures
2. For each page, determine figure zones (vertical ranges with active figures)
3. Lines that are narrow (< threshold of full width) AND outside all figure zones
   are ghost-narrowed
"""
import sys
import re
import fitz

def analyze_pdf(pdf_path, verbose=False):
    doc = fitz.open(pdf_path)
    
    total_ghost = 0
    ghost_pages = []
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        pnum = page_num + 1
        
        # Get all text blocks
        blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
        
        # Get all drawings (filled rectangles = figure rules)
        drawings = page.get_drawings()
        fig_rects = []
        for d in drawings:
            rect = d.get("rect")
            if rect and rect.width > 30 and rect.height > 30:
                rtype = d.get("type")
                if rtype in ("f", "fs", "s"):  # filled or stroked
                    fig_rects.append(rect)
        
        # Also find figure labels in text
        fig_labels = []
        all_lines = []
        for block in blocks:
            if block["type"] != 0:
                continue
            for line in block.get("lines", []):
                spans = line.get("spans", [])
                if not spans:
                    continue
                text = "".join(s["text"] for s in spans).strip()
                if not text:
                    continue
                
                x0 = min(s["bbox"][0] for s in spans)
                y0 = min(s["bbox"][1] for s in spans)
                x1 = max(s["bbox"][2] for s in spans)
                y1 = max(s["bbox"][3] for s in spans)
                
                all_lines.append({
                    "text": text,
                    "x0": x0, "y0": y0,
                    "x1": x1, "y1": y1,
                    "width": x1 - x0,
                })
                
                m = re.match(r'Fig\s+(\d+)\s+\((\d+)cm\s*x\s*(\d+)cm\)', text)
                if m:
                    fig_num = int(m.group(1))
                    fig_w_cm = int(m.group(2))
                    fig_h_cm = int(m.group(3))
                    fig_labels.append({
                        "num": fig_num,
                        "x0": x0, "y0": y0, "x1": x1, "y1": y1,
                        "w_cm": fig_w_cm, "h_cm": fig_h_cm,
                    })
        
        # Determine full page text width
        # Use lines that are likely full-width (widest lines)
        text_widths = [l["width"] for l in all_lines if l["width"] > 100]
        if not text_widths:
            continue
        full_width = max(text_widths)
        
        # Determine figure zones on this page
        # Each figure zone extends from the figure rect's top to its bottom
        # The narrow zone extends a few lines below the figure bottom
        # For simplicity, use the figure rect + some padding below
        fig_zones = []
        for fr in fig_rects:
            fig_zones.append((fr.y0 - 20, fr.y1 + 40))  # generous zone
        
        # Also add zones from figure labels (label is at bottom of figure)
        for fl in fig_labels:
            # Figure extends upward from label
            # Approximate: fig height in points (1cm ≈ 28.35pt)
            fig_h_pt = fl["h_cm"] * 28.35
            fig_top = fl["y1"]  # label bottom is fig bottom
            fig_bottom = fl["y1"] + fig_h_pt
            # Narrow zone extends from fig_top upward to fig_bottom
            fig_zones.append((fig_top - 20, fig_bottom + 60))
        
        # Find ghost-narrowed lines
        page_ghosts = []
        for line in all_lines:
            lw = line["width"]
            
            # Skip if line is close to full width (>85%)
            if lw > 0.85 * full_width:
                continue
            
            # Skip short lines (likely captions or labels)
            if lw < 50:
                continue
            
            # Skip figure labels themselves
            if re.match(r'Fig\s+\d+', line["text"]):
                continue
            
            # Check if line is in any figure zone
            in_fig_zone = False
            for ztop, zbot in fig_zones:
                if line["y0"] < zbot and line["y1"] > ztop:
                    in_fig_zone = True
                    break
            
            if not in_fig_zone:
                total_ghost += 1
                page_ghosts.append(line)
        
        if page_ghosts and verbose:
            print(f"\n--- Page {pnum} ({len(page_ghosts)} ghost lines) ---")
            print(f"  Full width: {full_width:.1f}pt")
            for g in page_ghosts:
                print(f"  y={g['y1']:.1f} w={g['width']:.1f} x=[{g['x0']:.1f},{g['x1']:.1f}] \"{g['text'][:60]}\"")
        
        if page_ghosts:
            ghost_pages.append((pnum, len(page_ghosts)))
    
    print(f"Total ghost-narrowed lines: {total_ghost}")
    if ghost_pages:
        print(f"Affected pages: {len(ghost_pages)}")
        for pnum, count in ghost_pages[:20]:
            print(f"  Page {pnum}: {count} ghost lines")
    
    doc.close()
    return total_ghost


if __name__ == "__main__":
    pdf = sys.argv[1] if len(sys.argv) > 1 else "/home/z/swarm/tests/test-stress-1000.pdf"
    verbose = "--verbose" in sys.argv or "-v" in sys.argv
    analyze_pdf(pdf, verbose=verbose)
