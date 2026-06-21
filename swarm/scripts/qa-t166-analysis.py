#!/usr/bin/env python3
"""Comprehensive layout analysis for customwrap and pagebreak-variations test PDFs."""
import fitz
import os

def analyze(pdf_path, name):
    doc = fitz.open(pdf_path)
    npages = len(doc)
    fsize = os.path.getsize(pdf_path)
    page_w = page_h = None

    issues = {"near_empty": [], "ghost_narrow": [], "no_wrap": [], "hollow_carry": [], "overlap": []}
    fig_counts = []
    all_stats = []

    for pg_i in range(npages):
        page = doc[pg_i]
        pg_num = pg_i + 1
        if page_w is None:
            page_w = page.rect.width
            page_h = page.rect.height

        # Get figures
        drawings = page.get_drawings()
        figs = [d for d in drawings if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect') and d['rect'].width > 10 and d['rect'].height > 10]
        fig_counts.append(len(figs))

        # Get text spans
        spans = []
        for blk in page.get_text("dict")["blocks"]:
            if blk["type"] == 0:
                for line in blk.get("lines", []):
                    for span in line.get("spans", []):
                        if len(span["text"].strip()) > 2:
                            spans.append({
                                "text": span["text"].strip()[:50],
                                "x0": span["bbox"][0],
                                "x1": span["bbox"][2],
                                "y0": span["bbox"][1],
                                "y1": span["bbox"][3],
                                "w": span["bbox"][2] - span["bbox"][0],
                                "size": span["size"]
                            })

        ink = len(page.get_text().strip())

        # Near-empty check (< 100 chars and 0 figs)
        if ink < 100 and len(figs) == 0:
            issues["near_empty"].append(pg_num)

        narrow_threshold = page_w * 0.85

        # Ghost narrowing: narrow lines without figures
        has_narrow = any(s["w"] < narrow_threshold and s["w"] > 20 for s in spans)
        if has_narrow and len(figs) == 0:
            issues["ghost_narrow"].append(pg_num)

        # No-wrap: figures but no narrow lines
        if len(figs) > 0:
            has_narrow_for_fig = any(s["w"] < narrow_threshold and s["w"] > 20 for s in spans)
            if not has_narrow_for_fig:
                issues["no_wrap"].append(pg_num)

        # Hollow carry-over: first line narrow, no fig on page
        if spans and len(figs) == 0:
            first = min(spans, key=lambda x: (x["y0"], x["x0"]))
            if first["w"] < narrow_threshold and first["w"] > 20:
                issues["hollow_carry"].append(pg_num)

        # Overlap check: text rect intersects figure rect
        for fig_d in [d for d in drawings if d.get('fill') and d['fill'] != (1,1,1) and d.get('rect') and d['rect'].width > 10 and d['rect'].height > 10]:
            fr = fig_d['rect']
            for s in spans:
                # Check if span text area overlaps figure area (y overlap)
                if s["y1"] > fr.y0 + 5 and s["y0"] < fr.y1 - 5:
                    # Text at same y-level as figure — check if x ranges overlap
                    # Figure should be on right side, text on left
                    if s["x1"] > fr.x0 - 2:
                        # Potential overlap
                        issues["overlap"].append((pg_num, s["text"][:30]))

        all_stats.append({
            "pg": pg_num, "figs": len(figs), "ink": ink, "spans": len(spans)
        })

    # Figure distribution
    fig_dist = {}
    for fc in fig_counts:
        fig_dist[fc] = fig_dist.get(fc, 0) + 1

    print(f"\n{'='*60}")
    print(f"  {name}: {npages} pages, {fsize} bytes")
    print(f"  Page: {page_w:.1f}pt x {page_h:.1f}pt")
    print(f"{'='*60}")

    print(f"\n  Figure distribution:")
    for k in sorted(fig_dist.keys()):
        pct = 100 * fig_dist[k] / npages
        print(f"    {k} figs/page: {fig_dist[k]} pages ({pct:.1f}%)")

    print(f"\n  Layout issues:")
    print(f"    Near-empty pages:  {len(issues['near_empty'])} {issues['near_empty']}")
    print(f"    Ghost narrowing:   {len(issues['ghost_narrow'])} {issues['ghost_narrow']}")
    print(f"    No-wrap figures:   {len(issues['no_wrap'])} {issues['no_wrap']}")
    print(f"    Hollow carry-over: {len(issues['hollow_carry'])} {issues['hollow_carry']}")
    print(f"    Text-fig overlaps: {len(issues['overlap'])} {' '.join(str(x[0]) for x in issues['overlap'][:10])}")

    # Log file analysis
    log_path = pdf_path.replace(".pdf", ".log")
    overfull = underfull = errors = 0
    try:
        with open(log_path) as f:
            for line in f:
                if "Overfull" in line:
                    overfull += 1
                if "Underfull" in line:
                    underfull += 1
                if "! " in line and "LaTeX" not in line and "Emergency" not in line:
                    errors += 1
    except:
        pass
    print(f"\n  Log: {overfull} overfull, {underfull} underfull, {errors} errors")

    # Per-page detail
    print(f"\n  Per-page:")
    for st in all_stats:
        print(f"    pg{st['pg']:2d}: {st['figs']} figs, {st['ink']:5d} chars, {st['spans']} spans")

    doc.close()
    return issues

if __name__ == "__main__":
    analyze("/home/z/my-project/swarm/src/test-wrapfig/test-customwrap.pdf", "v3.53 customwrap")
    analyze("/home/z/my-project/swarm/src/test-wrapfig/test-pagebreak-variations.pdf", "v3.53 pagebreak-variations")
