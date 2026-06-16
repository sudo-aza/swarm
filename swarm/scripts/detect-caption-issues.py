#!/usr/bin/env python3
"""
detect-caption-issues.py — QA tool for swarmwrap.sty (v2)
Detects caption positioning anomalies in compiled PDFs:
  1. Caption-to-figure vertical gap consistency
  2. Caption font size anomalies (compared to median)
  3. Caption horizontal alignment (checks if caption extends outside figure bounds)
  4. Missing captions (figures without associated text below them)
  5. Caption overlap with body text below the figure

Uses PyMuPDF. Pages are A4 (595.276 x 841.890 pt).
Figures are vector rects from \rule{}{} commands.

v2 changes (QA T116):
  - Fixed multi-line caption grouping: find_caption_for_figure now returns all
    spans belonging to a caption (consecutive lines below figure), eliminating
    false-positive caption_text_overlap from continuation lines of the same caption.
  - Fixed centering-aware alignment: caption_misaligned now checks if the caption
    bounding box extends OUTSIDE the figure's horizontal extent, rather than
    comparing caption x0 to figure x0 (which flagged centering as misalignment).
"""

import sys
import fitz  # PyMuPDF

PAGE_W, PAGE_H = 595.276, 841.890
TEXT_AREA_BOTTOM = 720.5  # approximate text area bottom in these docs
CAPTION_SIZE_TOLERANCE = 0.5  # pt — allowed deviation from median caption size
MIN_FIG_WIDTH = 50
MIN_FIG_HEIGHT = 25


def get_figures(page):
    """Extract filled rectangles (vector-rect figures from \\rule)."""
    figs = []
    for d in page.get_drawings():
        if d.get("fill") is None:
            continue
        r = d["rect"]
        # Skip tiny artifacts
        if r.width < MIN_FIG_WIDTH or r.height < MIN_FIG_HEIGHT:
            continue
        figs.append(r)
    return figs


def get_text_blocks(page):
    """Get text blocks with position and font size info."""
    blocks = []
    for b in page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]:
        if b["type"] != 0:  # text only
            continue
        for line in b["lines"]:
            for span in line["spans"]:
                blocks.append({
                    "text": span["text"].strip(),
                    "x0": span["bbox"][0],
                    "y0": span["bbox"][1],
                    "x1": span["bbox"][2],
                    "y1": span["bbox"][3],
                    "size": span["size"],
                    "font": span["font"],
                    "line_y0": line["bbox"][1],
                    "line_y1": line["bbox"][3],
                })
    return blocks


def find_caption_for_figure(fig, text_blocks, all_figs):
    """
    Find ALL spans belonging to the caption associated with a figure.
    Captions are typically:
      - Below the figure (y0 > fig.y1)
      - Within a small vertical gap (0-40pt below figure bottom)
      - Smaller font size than body text
      - Horizontally overlapping with the figure
    Returns a list of caption spans (handles multi-line captions), or None.
    The first span in the list is the one closest to the figure.
    """
    fig_bottom = fig.y1
    fig_left = fig.x0
    fig_right = fig.x1

    candidates = []
    for tb in text_blocks:
        if not tb["text"]:
            continue
        # Caption must be below the figure
        if tb["y0"] < fig_bottom - 2:
            continue
        # Caption should be within reasonable distance below figure
        gap = tb["y0"] - fig_bottom
        if gap > 40:
            continue
        # Caption should be smaller font (typically <=11pt vs ~11pt body)
        if tb["size"] > 11:
            continue
        # Caption text should overlap horizontally with the figure
        h_overlap = min(tb["x1"], fig_right) - max(tb["x0"], fig_left)
        if h_overlap < 10:
            continue
        candidates.append((gap, tb))

    if not candidates:
        return None

    # Sort by gap (closest first)
    candidates.sort(key=lambda c: c[0])
    gap, first_span = candidates[0]

    # Filter out body text: if the line extends well past the figure to the left
    # (into the main text area), it's likely body text, not a caption
    if first_span["x0"] < fig_left - 20 and gap > 15:
        return None

    # Collect ALL spans belonging to this caption: consecutive lines below
    # the figure with similar font size and horizontal overlap with figure.
    # This fixes the v1 bug where multi-line captions had continuation lines
    # flagged as "body text overlapping caption."
    first_size = first_span["size"]
    line_height = first_span["y1"] - first_span["y0"]
    max_line_gap = line_height * 1.5 if line_height > 0 else 16

    caption_spans = [first_span]
    last_y1 = first_span["y1"]

    for _, tb in candidates[1:]:
        if tb is first_span:
            continue
        # Must be on a line that starts right after (or overlaps with) the
        # previous caption line
        if tb["y0"] > last_y1 + max_line_gap:
            break  # gap too large — not part of the same caption
        # Must have similar font size (within 1pt)
        if abs(tb["size"] - first_size) > 1.0:
            continue
        # Must horizontally overlap with the figure
        h_ol = min(tb["x1"], fig_right) - max(tb["x0"], fig_left)
        if h_ol < 10:
            continue
        caption_spans.append(tb)
        last_y1 = max(last_y1, tb["y1"])

    # Second pass: extend caption beyond the 40pt gap threshold.
    # The initial candidate filter (gap > 40) may exclude later lines of
    # very long multi-line captions. Scan ALL text_blocks (not just candidates)
    # for consecutive lines below the last grouped caption span.
    # Key constraint: span must START within or near the figure's horizontal
    # extent (not body text that merely extends into the figure area).
    caption_ids = set(id(s) for s in caption_spans)
    changed = True
    while changed:
        changed = False
        for tb in text_blocks:
            if id(tb) in caption_ids:
                continue
            if not tb["text"]:
                continue
            # Must be on a consecutive line below the last caption span
            if tb["y0"] > last_y1 + max_line_gap:
                continue
            if tb["y0"] < last_y1 - 2:  # skip spans above or at same pos
                continue
            # Must have similar font size
            if abs(tb["size"] - first_size) > 1.0:
                continue
            # Must start within or near the figure's horizontal extent
            # (body text starts at x~72-118, well left of figures at x~235+)
            if tb["x0"] < fig_left - 20:
                continue
            # Must horizontally overlap with the figure
            h_ol = min(tb["x1"], fig_right) - max(tb["x0"], fig_left)
            if h_ol < 10:
                continue
            caption_spans.append(tb)
            caption_ids.add(id(tb))
            last_y1 = max(last_y1, tb["y1"])
            changed = True

    return caption_spans


def detect_caption_issues(pdf_path):
    """Main detection function."""
    doc = fitz.open(pdf_path)
    issues = []
    stats = {
        "total_figures": 0,
        "figures_with_captions": 0,
        "figures_without_captions": 0,
        "caption_gaps": [],
        "caption_sizes": [],
        "caption_x_offsets": [],
    }

    for pg_num in range(len(doc)):
        page = doc[pg_num]
        figs = get_figures(page)
        text_blocks = get_text_blocks(page)

        if not figs:
            continue

        for fig_idx, fig in enumerate(figs):
            stats["total_figures"] += 1
            pg = pg_num + 1

            caption_spans = find_caption_for_figure(fig, text_blocks, figs)

            if caption_spans is None:
                stats["figures_without_captions"] += 1
                issues.append({
                    "type": "missing_caption",
                    "page": pg,
                    "fig_idx": fig_idx,
                    "fig_rect": f"({fig.x0:.1f}, {fig.y0:.1f}, {fig.x1:.1f}, {fig.y1:.1f})",
                    "fig_size": f"{fig.width:.1f}x{fig.height:.1f}pt",
                    "severity": "MILD",
                    "detail": f"Figure on page {pg} has no detectable caption below it",
                })
                continue

            # Compute caption bounding box from all spans
            cap_x0 = min(s["x0"] for s in caption_spans)
            cap_y0 = min(s["y0"] for s in caption_spans)
            cap_x1 = max(s["x1"] for s in caption_spans)
            cap_y1 = max(s["y1"] for s in caption_spans)
            cap_first = caption_spans[0]  # span closest to figure
            cap_text = " ".join(s["text"] for s in caption_spans)

            stats["figures_with_captions"] += 1
            gap = cap_first["y0"] - fig.y1
            stats["caption_gaps"].append(gap)
            stats["caption_sizes"].append(cap_first["size"])

            # Check horizontal alignment: use caption bounding box.
            # Only flag if caption EXTENDS OUTSIDE the figure's horizontal extent
            # (handles \centering, \raggedleft, and other alignment modes).
            x_overrun_left = fig.x0 - cap_x0   # positive = caption starts left of figure
            x_overrun_right = cap_x1 - fig.x1   # positive = caption ends right of figure
            x_offset = cap_x0 - fig.x0
            stats["caption_x_offsets"].append(x_offset)

            # Issue 1: Abnormal caption-to-figure gap
            if gap < 0:
                issues.append({
                    "type": "caption_overlap_figure",
                    "page": pg,
                    "fig_idx": fig_idx,
                    "gap": gap,
                    "caption_text": cap_text[:50],
                    "severity": "CRITICAL",
                    "detail": f"pg{pg} fig{fig_idx}: Caption overlaps figure by {-gap:.1f}pt. Caption: '{cap_text[:50]}'",
                })
            elif gap > 25:
                issues.append({
                    "type": "caption_gap_large",
                    "page": pg,
                    "fig_idx": fig_idx,
                    "gap": gap,
                    "caption_text": cap_text[:50],
                    "severity": "MILD",
                    "detail": f"pg{pg} fig{fig_idx}: Large caption gap ({gap:.1f}pt). Caption: '{cap_text[:50]}'",
                })

            # Issue 2: Caption horizontal misalignment
            # Only flag if caption extends OUTSIDE the figure's horizontal extent
            if x_overrun_left > 5 or x_overrun_right > 5:
                issues.append({
                    "type": "caption_misaligned",
                    "page": pg,
                    "fig_idx": fig_idx,
                    "x_overrun_left": x_overrun_left,
                    "x_overrun_right": x_overrun_right,
                    "fig_x0": fig.x0,
                    "fig_x1": fig.x1,
                    "cap_bbox": f"({cap_x0:.1f}, {cap_y0:.1f}, {cap_x1:.1f}, {cap_y1:.1f})",
                    "caption_text": cap_text[:50],
                    "severity": "MILD",
                    "detail": f"pg{pg} fig{fig_idx}: Caption extends outside figure bounds. Left overrun: {x_overrun_left:.1f}pt, Right overrun: {x_overrun_right:.1f}pt. Fig: [{fig.x0:.1f},{fig.x1:.1f}], Cap bbox: [{cap_x0:.1f},{cap_x1:.1f}]",
                })

            # Issue 3: Check if body text overlaps with caption
            # Exclude ALL caption spans from the overlap check (v2 fix)
            caption_span_ids = set(id(s) for s in caption_spans)
            for tb in text_blocks:
                if id(tb) in caption_span_ids:
                    continue
                if tb["y1"] > cap_y0 and tb["y0"] < cap_y1:
                    # Horizontal overlap check
                    h_overlap = min(tb["x1"], cap_x1) - max(tb["x0"], cap_x0)
                    if h_overlap > 20:
                        issues.append({
                            "type": "caption_text_overlap",
                            "page": pg,
                            "fig_idx": fig_idx,
                            "overlapping_text": tb["text"][:50],
                            "caption_text": cap_text[:50],
                            "severity": "CRITICAL",
                            "detail": f"pg{pg} fig{fig_idx}: Body text '{tb['text'][:40]}' overlaps caption '{cap_text[:40]}'",
                        })

    # Compute statistics
    if stats["caption_sizes"]:
        sizes = stats["caption_sizes"]
        median_size = sorted(sizes)[len(sizes) // 2]
        mean_size = sum(sizes) / len(sizes)

        # Flag font size anomalies
        for pg_num in range(len(doc)):
            page = doc[pg_num]
            figs = get_figures(page)
            text_blocks = get_text_blocks(page)
            for fig_idx, fig in enumerate(figs):
                caption_spans = find_caption_for_figure(fig, text_blocks, figs)
                if caption_spans and caption_spans[0]["size"]:
                    deviation = abs(caption_spans[0]["size"] - median_size)
                    if deviation > CAPTION_SIZE_TOLERANCE:
                        # Check if already reported
                        already = any(
                            i["type"] == "caption_font_anomaly" and
                            i["page"] == pg_num + 1 and
                            i["fig_idx"] == fig_idx
                            for i in issues
                        )
                        if not already:
                            cap_text = " ".join(s["text"] for s in caption_spans)
                            issues.append({
                                "type": "caption_font_anomaly",
                                "page": pg_num + 1,
                                "fig_idx": fig_idx,
                                "caption_size": caption_spans[0]["size"],
                                "median_size": median_size,
                                "deviation": deviation,
                                "caption_text": cap_text[:50],
                                "severity": "MODERATE",
                                "detail": f"pg{pg_num+1} fig{fig_idx}: Caption font {caption_spans[0]['size']:.2f}pt, median {median_size:.2f}pt (deviation {deviation:.2f}pt). Text: '{cap_text[:50]}'",
                            })

    if stats["caption_gaps"]:
        gaps = stats["caption_gaps"]
        median_gap = sorted(gaps)[len(gaps) // 2]
        mean_gap = sum(gaps) / len(gaps)
        gap_std = (sum((g - mean_gap) ** 2 for g in gaps) / len(gaps)) ** 0.5
        stats["gap_median"] = median_gap
        stats["gap_mean"] = mean_gap
        stats["gap_std"] = gap_std

        # Flag gap outliers (> 2 std from mean)
        for i, issue in enumerate(issues):
            if issue["type"] == "caption_gap_large":
                gap = issue["gap"]
                z_score = (gap - mean_gap) / gap_std if gap_std > 0 else 0
                issue["z_score"] = z_score
                if z_score > 3:
                    issue["severity"] = "MODERATE"

    doc.close()

    return issues, stats


def main():
    if len(sys.argv) < 2:
        print("Usage: detect-caption-issues.py <pdf_path>")
        sys.exit(1)

    pdf_path = sys.argv[1]
    issues, stats = detect_caption_issues(pdf_path)

    print(f"=== Caption Analysis: {pdf_path} ===")
    print(f"Total figures: {stats['total_figures']}")
    print(f"With captions: {stats['figures_with_captions']}")
    print(f"Without captions: {stats['figures_without_captions']}")
    print(f"(detect-caption-issues.py v2 — multi-line + centering aware)")

    if stats['caption_gaps']:
        print(f"Caption gap: median={stats['gap_median']:.1f}pt, mean={stats['gap_mean']:.1f}pt, std={stats['gap_std']:.1f}pt")

    sizes = stats.get('caption_sizes', [])
    if sizes:
        median_size = sorted(sizes)[len(sizes) // 2]
        unique_sizes = sorted(set(round(s, 2) for s in sizes))
        print(f"Caption font sizes: median={median_size:.2f}pt, unique values: {unique_sizes}")

    # Count by severity
    critical = [i for i in issues if i["severity"] == "CRITICAL"]
    moderate = [i for i in issues if i["severity"] == "MODERATE"]
    mild = [i for i in issues if i["severity"] == "MILD"]

    print(f"\nIssues found: {len(issues)} total")
    print(f"  CRITICAL: {len(critical)}")
    print(f"  MODERATE: {len(moderate)}")
    print(f"  MILD: {len(mild)}")

    for issue in issues:
        print(f"\n  [{issue['severity']}] {issue['type']}")
        print(f"    {issue['detail']}")

    return len(critical) + len(moderate)


if __name__ == "__main__":
    sys.exit(main())