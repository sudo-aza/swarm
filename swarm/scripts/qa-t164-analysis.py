#!/usr/bin/env python3
"""Quick layout analysis for QA T164 — v3.52 verification."""
import fitz
import sys

def analyze(pdf_path, name):
    doc = fitz.open(pdf_path)
    npages = len(doc)
    total_bytes = doc.metadata.get("format", "?")
    
    # Get file size
    import os
    fsize = os.path.getsize(pdf_path)
    
    issues = {"near_empty": [], "ghost_narrow": [], "no_wrap": [], "overlap": [], "hollow_carry": []}
    fig_counts = []
    
    page_w = page_h = None
    
    for pg_i in range(npages):
        page = doc[pg_i]
        pg_num = pg_i + 1
        
        if page_w is None:
            page_w = page.rect.width
            page_h = page.rect.height
        
        # Get drawings (figures are filled rectangles)
        drawings = page.get_drawings()
        figs = []
        for d in drawings:
            if d.get('fill') and d['fill'] != (1, 1, 1):
                r = d.get('rect')
                if r and r.width > 10 and r.height > 10:
                    figs.append(r)
        fig_counts.append(len(figs))
        
        # Get text blocks
        blocks = page.get_text("blocks")
        if not blocks:
            continue
        
        # Check ink coverage
        all_text = page.get_text()
        ink = len(all_text.strip())
        
        if ink < 100 and len(figs) == 0:
            issues["near_empty"].append(pg_num)
            continue
        
        # Get text lines with positions
        text_lines = []
        for b in blocks:
            if b[6] == 0:  # text block
                for ln in page.get_text("dict")["blocks"]:
                    if abs(ln["bbox"][0] - b[0]) < 5 and abs(ln["bbox"][1] - b[1]) < 5:
                        for line in ln.get("lines", []):
                            text_lines.append(line)
        
        # Simpler: just use text spans
        spans = []
        for b in blocks:
            if b[6] == 0:
                lines = page.get_text("dict")["blocks"]
                for blk in lines:
                    if blk["type"] == 0 and abs(blk["bbox"][0] - b[0]) < 5:
                        for line in blk.get("lines", []):
                            for span in line.get("spans", []):
                                spans.append({
                                    "text": span["text"],
                                    "bbox": span["bbox"],
                                    "font": span["font"],
                                    "size": span["size"],
                                    "x0": span["bbox"][0],
                                    "x1": span["bbox"][1],
                                    "y": span["bbox"][1],
                                    "w": span["bbox"][2] - span["bbox"][0]
                                })
        
        # Check for ghost narrowing: lines narrower than 90% of page width with no fig
        narrow_threshold = page_w * 0.9
        has_narrow = False
        for s in spans:
            if s["w"] < narrow_threshold and s["w"] > 20:
                has_narrow = True
                break
        
        if has_narrow and len(figs) == 0:
            issues["ghost_narrow"].append(pg_num)
        
        # Check for no-wrap: fig present but no narrow lines
        if len(figs) > 0:
            has_narrow_lines = False
            for s in spans:
                if s["w"] < narrow_threshold and s["w"] > 20:
                    has_narrow_lines = True
                    break
            if not has_narrow_lines:
                issues["no_wrap"].append((pg_num, len(figs)))
        
        # Check hollow carry-over: first line narrow, no fig
        if len(spans) > 0:
            first_span = min(spans, key=lambda x: x["y"])
            if first_span["w"] < narrow_threshold and len(figs) == 0:
                issues["hollow_carry"].append(pg_num)
    
    # Summary
    print(f"\n{'='*60}")
    print(f"  {name}: {npages} pages, {fsize} bytes")
    print(f"{'='*60}")
    print(f"  Page width: {page_w:.1f}pt")
    
    # Figure distribution
    fig_dist = {}
    for fc in fig_counts:
        fig_dist[fc] = fig_dist.get(fc, 0) + 1
    print(f"\n  Figure distribution:")
    for k in sorted(fig_dist.keys()):
        pct = 100 * fig_dist[k] / npages
        print(f"    {k} figs/page: {fig_dist[k]} pages ({pct:.1f}%)")
    
    # Issues
    print(f"\n  Issues found:")
    print(f"    Near-empty pages: {len(issues['near_empty'])} {issues['near_empty']}")
    print(f"    Ghost narrowing: {len(issues['ghost_narrow'])} {issues['ghost_narrow']}")
    print(f"    No-wrap figures: {len(issues['no_wrap'])} {issues['no_wrap']}")
    print(f"    Hollow carry-over: {len(issues['hollow_carry'])} {issues['hollow_carry']}")
    
    # Overfull/underfull from log
    log_path = pdf_path.replace(".pdf", ".log")
    overfull = underfull = 0
    try:
        with open(log_path) as f:
            for line in f:
                if "Overfull" in line:
                    overfull += 1
                if "Underfull" in line:
                    underfull += 1
    except:
        pass
    print(f"\n  Overfull: {overfull}, Underfull: {underfull}")
    
    doc.close()
    return issues

if __name__ == "__main__":
    analyze("/home/z/my-project/swarm/src/test-wrapfig/test-stress-50.pdf", "v3.52 stress-50")
    analyze("/home/z/my-project/swarm/src/test-wrapfig/test-1000fig.pdf", "v3.52 1000-fig")
