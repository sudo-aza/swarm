#!/usr/bin/env python3
"""
detect-baseline-grid.py — QA tool for swarmwrap.sty
Analyzes baseline grid consistency in compiled PDFs.

Checks:
  1. Whether body text baselines follow a consistent vertical grid (multiples of baselineskip)
  2. Whether narrow (parshape) lines have different baseline spacing than full-width lines
  3. Whether page transitions cause baseline grid disruptions
  4. Inter-line spacing statistics (median, std, outliers)

Uses PyMuPDF. Pages are A4 (595.276 x 841.890 pt).
"""

import sys
from collections import defaultdict
import fitz

PAGE_W, PAGE_H = 595.276, 841.890
# Standard baselineskip for 10pt text is ~12pt, for 11pt ~13.6pt
EXPECTED_BASELINE_RANGES = {
    10: (11.0, 13.5),   # 10pt body
    11: (12.5, 15.0),   # 11pt body
    12: (13.5, 16.0),   # 12pt body
}


def get_text_lines(page):
    """Extract text line positions, grouped by line (y0)."""
    lines = []
    for b in page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]:
        if b["type"] != 0:
            continue
        for line in b["lines"]:
            # Use the line-level bbox for y-position
            text = " ".join(span["text"] for span in line["spans"]).strip()
            if not text:
                continue
            spans = line["spans"]
            # Use the dominant font size
            sizes = [s["size"] for s in spans]
            dominant_size = max(set(round(s, 1) for s in sizes), key=sizes.count)
            # Use x0 of leftmost span
            x0 = min(s["bbox"][0] for s in spans)
            x1 = max(s["bbox"][2] for s in spans)
            lines.append({
                "text": text[:80],
                "y0": line["bbox"][1],  # bottom of line = baseline area
                "y1": line["bbox"][3],  # top of line
                "x0": x0,
                "x1": x1,
                "size": dominant_size,
                "height": line["bbox"][3] - line["bbox"][1],
            })
    return lines


def classify_line(line, page_right_edge=476.5):
    """Classify a line as full-width or narrow (parshape-wrapped)."""
    # Narrow lines have x1 significantly less than page right edge
    # and are body-text sized
    if line["size"] < 9 or line["size"] > 13:
        return "other"
    if line["x1"] < page_right_edge - 30:
        return "narrow"
    return "full"


def analyze_baselines(pdf_path):
    """Main analysis function."""
    doc = fitz.open(pdf_path)
    issues = []
    all_gaps = []
    narrow_gaps = []
    full_gaps = []
    page_stats = []

    # Determine the dominant body text size
    body_sizes = []
    for pg_num in range(len(doc)):
        page = doc[pg_num]
        lines = get_text_lines(page)
        for line in lines:
            if line["size"] >= 9 and line["size"] <= 13:
                body_sizes.append(round(line["size"], 1))

    if body_sizes:
        from collections import Counter
        size_counts = Counter(body_sizes)
        dominant_size = size_counts.most_common(1)[0][0]
    else:
        dominant_size = 10.0

    expected_range = EXPECTED_BASELINE_RANGES.get(int(round(dominant_size)), (11.0, 15.0))

    for pg_num in range(len(doc)):
        page = doc[pg_num]
        lines = get_text_lines(page)

        # Filter to body text lines only
        body_lines = [l for l in lines if l["size"] >= 9 and l["size"] <= 13]
        if len(body_lines) < 3:
            page_stats.append({"page": pg_num + 1, "lines": len(body_lines), "note": "too few lines"})
            continue

        # Sort by y0 (top to bottom on page)
        body_lines.sort(key=lambda l: l["y0"])

        # Compute inter-line gaps
        gaps = []
        classifications = []
        for i in range(1, len(body_lines)):
            gap = body_lines[i]["y0"] - body_lines[i - 1]["y0"]
            # Skip negative gaps (superscripts, etc.) and very large gaps (page breaks, section breaks)
            if gap < 2 or gap > 40:
                continue
            cls = classify_line(body_lines[i])
            cls_prev = classify_line(body_lines[i - 1])
            gaps.append({
                "gap": gap,
                "page": pg_num + 1,
                "line_idx": i,
                "cls": cls,
                "cls_prev": cls_prev,
                "text": body_lines[i]["text"][:50],
                "text_prev": body_lines[i - 1]["text"][:50],
                "x1": body_lines[i]["x1"],
                "x1_prev": body_lines[i - 1]["x1"],
            })
            all_gaps.append(gap)
            if cls == "narrow" or cls_prev == "narrow":
                narrow_gaps.append(gap)
            else:
                full_gaps.append(gap)

        if not gaps:
            page_stats.append({"page": pg_num + 1, "lines": len(body_lines), "gaps": 0})
            continue

        gap_values = [g["gap"] for g in gaps]
        median_gap = sorted(gap_values)[len(gap_values) // 2]
        mean_gap = sum(gap_values) / len(gap_values)
        gap_std = (sum((g - mean_gap) ** 2 for g in gap_values) / len(gap_values)) ** 0.5

        # Check for grid violations (gaps outside 2*std of mean)
        for g in gaps:
            z_score = (g["gap"] - mean_gap) / gap_std if gap_std > 0.1 else 0
            if abs(z_score) > 2.5 and g["gap"] < expected_range[1] * 1.5:
                issues.append({
                    "type": "baseline_grid_violation",
                    "page": g["page"],
                    "gap": g["gap"],
                    "mean_gap": mean_gap,
                    "std": gap_std,
                    "z_score": z_score,
                    "cls": g["cls"],
                    "cls_prev": g["cls_prev"],
                    "text": g["text"],
                    "text_prev": g["text_prev"],
                    "severity": "MILD" if abs(z_score) < 4 else "MODERATE",
                    "detail": (f"pg{g['page']}: gap={g['gap']:.1f}pt (mean={mean_gap:.1f}, "
                              f"z={z_score:.1f}), {g['cls_prev']}→{g['cls']}. "
                              f'"{g["text_prev"][:30]}" → "{g["text"][:30]}"'),
                })

        # Check if the page starts on-grid
        # First line y0 should be close to a multiple of baselineskip from page top
        page_text_top = body_lines[0]["y0"]
        page_stats.append({
            "page": pg_num + 1,
            "lines": len(body_lines),
            "gaps": len(gaps),
            "median_gap": median_gap,
            "mean_gap": mean_gap,
            "std": gap_std,
            "text_top": page_text_top,
            "text_bottom": body_lines[-1]["y1"],
        })

    # Compute overall statistics
    if all_gaps:
        overall_median = sorted(all_gaps)[len(all_gaps) // 2]
        overall_mean = sum(all_gaps) / len(all_gaps)
        overall_std = (sum((g - overall_mean) ** 2 for g in all_gaps) / len(all_gaps)) ** 0.5
    else:
        overall_median = overall_mean = overall_std = 0

    if full_gaps:
        full_median = sorted(full_gaps)[len(full_gaps) // 2]
        full_mean = sum(full_gaps) / len(full_gaps)
    else:
        full_median = full_mean = 0

    if narrow_gaps:
        narrow_median = sorted(narrow_gaps)[len(narrow_gaps) // 2]
        narrow_mean = sum(narrow_gaps) / len(narrow_gaps)
    else:
        narrow_median = narrow_mean = 0

    doc.close()

    return issues, {
        "dominant_size": dominant_size,
        "expected_range": expected_range,
        "total_gaps": len(all_gaps),
        "full_gaps": len(full_gaps),
        "narrow_gaps": len(narrow_gaps),
        "overall_median": overall_median,
        "overall_mean": overall_mean,
        "overall_std": overall_std,
        "full_median": full_median,
        "full_mean": full_mean,
        "narrow_median": narrow_median,
        "narrow_mean": narrow_mean,
        "page_stats": page_stats,
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: detect-baseline-grid.py <pdf_path>")
        sys.exit(1)

    pdf_path = sys.argv[1]
    issues, stats = analyze_baselines(pdf_path)

    print(f"=== Baseline Grid Analysis: {pdf_path} ===")
    print(f"Dominant body text size: {stats['dominant_size']:.1f}pt")
    print(f"Expected baseline range: {stats['expected_range'][0]:.1f}-{stats['expected_range'][1]:.1f}pt")
    print(f"Total inter-line gaps measured: {stats['total_gaps']}")
    print(f"  Full-width line gaps: {stats['full_gaps']}")
    print(f"  Narrow line gaps: {stats['narrow_gaps']}")
    print(f"Overall: median={stats['overall_median']:.2f}pt, mean={stats['overall_mean']:.2f}pt, std={stats['overall_std']:.2f}pt")
    print(f"Full-width: median={stats['full_median']:.2f}pt, mean={stats['full_mean']:.2f}pt")
    print(f"Narrow: median={stats['narrow_median']:.2f}pt, mean={stats['narrow_mean']:.2f}pt")

    # Page text top alignment
    print(f"\nPage text-top positions (first body line y0):")
    tops = [ps["text_top"] for ps in stats["page_stats"] if "text_top" in ps]
    if tops:
        unique_tops = sorted(set(round(t, 1) for t in tops))
        print(f"  Unique values: {unique_tops}")
        if len(unique_tops) > 3:
            print(f"  WARNING: {len(unique_tops)} different text-top positions across {len(tops)} pages")

    critical = [i for i in issues if i["severity"] in ("CRITICAL", "MODERATE")]
    mild = [i for i in issues if i["severity"] == "MILD"]

    print(f"\nBaseline grid violations: {len(issues)} total ({len(critical)} MODERATE+, {len(mild)} MILD)")
    # Show first 20
    for issue in issues[:20]:
        print(f"  [{issue['severity']}] {issue['detail']}")
    if len(issues) > 20:
        print(f"  ... and {len(issues) - 20} more")

    return len(critical)


if __name__ == "__main__":
    sys.exit(main())