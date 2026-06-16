#!/usr/bin/env python3
"""
detect-figure-ordering.py — QA T106
Verifies that figures appear in correct numerical order across pages.
A deferred-NEWPAGE or stacking bug could potentially reorder figures.

Also checks:
1. Figure caption text matches expected "Fig N" pattern
2. No duplicate figure numbers
3. No missing figure numbers in sequence
4. Vertical ordering within each page (figures don't overlap vertically)
"""

import sys
import re
import fitz

A4_W, A4_H = 595.276, 841.890


def get_figures_and_captions(page, page_num):
    """Extract figure rectangles and caption text from a page."""
    # Get vector-rect figures (filled rects)
    drawings = page.get_drawings()
    figures = []
    for d in drawings:
        if d["type"] in ("f", "fs", "re"):
            r = d["rect"]
            if r.width > 50 and r.height > 25:
                figures.append(r)

    # Get text to find captions
    blocks = page.get_text("dict")["blocks"]
    captions = []
    for b in blocks:
        if b["type"] != 0:
            continue
        for line in b["lines"]:
            spans = line["spans"]
            if not spans:
                continue
            text = "".join(s["text"] for s in spans).strip()
            y0 = min(s["bbox"][1] for s in spans)
            x0 = min(s["bbox"][0] for s in spans)
            # Look for "Fig N" or "Figure N:" pattern in caption text
            m = re.match(r'(?:Fig|Figure)\s+(\d+)\s*[:.]?\s', text)
            if m:
                fig_num = int(m.group(1))
                captions.append({
                    "num": fig_num,
                    "text": text,
                    "y": y0,
                    "x": x0,
                })

    # Also check for figure captions that might be formatted differently
    # (e.g., inside minipages, multi-line)
    full_text = page.get_text()
    all_fig_nums = set()
    for m in re.finditer(r'Fig\s+(\d+)', full_text):
        all_fig_nums.add(int(m.group(1)))

    # Match captions to figures by proximity (caption y ≈ figure bottom y)
    fig_entries = []
    for fig in figures:
        # Find the closest caption below or overlapping this figure
        best_cap = None
        best_dist = float("inf")
        for cap in captions:
            # Caption should be near the figure (within 30pt below or overlapping)
            dist = abs(cap["y"] - fig.y1)
            if cap["y"] >= fig.y0 - 5 and dist < best_dist:
                best_dist = dist
                best_cap = cap
        fig_entries.append({
            "page": page_num,
            "rect": fig,
            "caption": best_cap,
        })

    return fig_entries, captions, all_fig_nums


def analyze_ordering(pdf_path, expected_count=None):
    doc = fitz.open(pdf_path)
    findings = []
    all_fig_entries = []
    all_captions_by_page = {}
    seen_nums = []
    duplicate_nums = []

    for pg_idx in range(len(doc)):
        page = doc[pg_idx]
        entries, caps, text_nums = get_figures_and_captions(page, pg_idx + 1)
        all_fig_entries.extend(entries)
        all_captions_by_page[pg_idx + 1] = caps

        # Check for duplicates within page
        page_nums = [e["caption"]["num"] for e in entries if e["caption"]]
        for n in page_nums:
            if n in seen_nums:
                duplicate_nums.append((n, pg_idx + 1))
            seen_nums.append(n)

        # Check vertical ordering within page (no fig overlaps)
        sorted_by_y = sorted(entries, key=lambda e: e["rect"].y0)
        for i in range(len(sorted_by_y) - 1):
            top = sorted_by_y[i]
            bot = sorted_by_y[i + 1]
            if top["rect"].y1 > bot["rect"].y0 + 2:  # allow 2pt tolerance
                findings.append(f"  pg{pg_idx+1}: Fig {top['caption']['num'] if top['caption'] else '?'} "
                              f"OVERLAPS Fig {bot['caption']['num'] if bot['caption'] else '?'} "
                              f"(top.y1={top['rect'].y1:.1f} > bot.y0={bot['rect'].y0:.1f})")

    # Check global ordering (figure N should appear before figure N+1)
    # Use page number as primary sort, then y-position within page
    ordered = sorted(all_fig_entries, key=lambda e: (e["page"], e["rect"].y0))
    caption_order = [e["caption"]["num"] for e in ordered if e["caption"]]

    ordering_violations = []
    for i in range(len(caption_order) - 1):
        if caption_order[i + 1] < caption_order[i]:
            ordering_violations.append({
                "fig_a": caption_order[i],
                "fig_b": caption_order[i + 1],
                "page_a": ordered[i]["page"],
                "page_b": ordered[i + 1]["page"],
            })

    # Check for missing numbers
    if caption_order:
        expected = set(range(1, max(caption_order) + 1))
        actual = set(caption_order)
        missing = sorted(expected - actual)
    else:
        missing = []

    return {
        "total_figures": len(all_fig_entries),
        "total_captions": sum(len(c) for c in all_captions_by_page.values()),
        "caption_order": caption_order,
        "ordering_violations": ordering_violations,
        "duplicate_nums": duplicate_nums,
        "missing_nums": missing,
        "overlap_findings": findings,
        "pages": len(doc),
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: detect-figure-ordering.py <pdf> [<pdf2> ...]")
        sys.exit(1)

    for pdf_path in sys.argv[1:]:
        print(f"\n{'='*70}")
        print(f"Figure Ordering Analysis: {pdf_path}")
        print(f"{'='*70}")

        r = analyze_ordering(pdf_path)

        print(f"Pages: {r['pages']}, Vector-rect figures: {r['total_figures']}, "
              f"Captions found: {r['total_captions']}")
        print(f"Caption order: {r['caption_order']}")

        if r['ordering_violations']:
            print(f"\n❌ ORDERING VIOLATIONS ({len(r['ordering_violations'])}):")
            for v in r['ordering_violations']:
                print(f"  Fig {v['fig_a']} (pg{v['page_a']}) appears BEFORE "
                      f"Fig {v['fig_b']} (pg{v['page_b']}) — REVERSED ORDER")
        else:
            print(f"\n✓ Figure ordering correct (monotonically increasing).")

        if r['duplicate_nums']:
            print(f"\n❌ DUPLICATE FIGURE NUMBERS ({len(r['duplicate_nums'])}):")
            for n, pg in r['duplicate_nums']:
                print(f"  Fig {n} duplicated on page {pg}")
        else:
            print(f"✓ No duplicate figure numbers.")

        if r['missing_nums']:
            print(f"\n⚠ MISSING FIGURE NUMBERS: {r['missing_nums']}")
        else:
            print(f"✓ No missing figure numbers in sequence.")

        if r['overlap_findings']:
            print(f"\n❌ VERTICAL OVERLAPS ({len(r['overlap_findings'])}):")
            for f in r['overlap_findings']:
                print(f"  {f}")
        else:
            print(f"✓ No vertical figure overlaps.")


if __name__ == "__main__":
    main()