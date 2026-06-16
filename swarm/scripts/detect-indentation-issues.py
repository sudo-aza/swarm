#!/usr/bin/env python3
"""
detect-indentation-issues.py v2 — QA T104
Improved: removes false "page start indent" heuristic (not valid for
documents without section headings). Focuses on:
1. Indentation distribution analysis
2. Anomalous high-indent lines (could indicate parshape corruption)
3. Missing indent after figure-wrapped paragraphs
4. Page-by-page indent consistency
"""

import sys
import fitz
from collections import defaultdict

A4_W, A4_H = 595.276, 841.890
TEXT_LEFT = 72.0
TEXT_RIGHT = 523.276
FIG_LEFT_APPROX = 380.0  # conservative threshold

def get_text_lines(page):
    blocks = page.get_text("dict")["blocks"]
    lines = []
    for b in blocks:
        if b["type"] != 0:
            continue
        for line in b["lines"]:
            spans = line["spans"]
            if not spans:
                continue
            text = "".join(s["text"] for s in spans).strip()
            if not text or len(text) < 10:
                continue
            x0 = min(s["bbox"][0] for s in spans)
            y0 = min(s["bbox"][1] for s in spans)
            x1 = max(s["bbox"][2] for s in spans)
            y1 = max(s["bbox"][3] for s in spans)
            font_size = spans[0]["size"]
            lines.append({
                "text": text, "x0": x0, "y0": y0,
                "x1": x1, "y1": y1, "font_size": font_size,
            })
    # Sort by vertical position
    lines.sort(key=lambda l: l["y0"])
    return lines


def get_figures(page):
    """Get figure rectangles from vector drawings (filled rects)."""
    drawings = page.get_drawings()
    figures = []
    for d in drawings:
        if d["type"] in ("f", "fs", "re"):
            r = d["rect"]
            if r.width > 50 and r.height > 25:
                figures.append(r)
    return figures


def classify_line(line, figures):
    """Classify a line as: 'fullwidth', 'narrow', 'figure_zone', 'header', 'body'."""
    x0, x1 = line["x0"], line["x1"]
    fs = line["font_size"]
    
    # Check if inside any figure
    for fig in figures:
        if (x0 >= fig.x0 - 5 and x1 <= fig.x1 + 5 and
            line["y0"] >= fig.y0 - 5 and line["y1"] <= fig.y1 + 5):
            return "figure_zone"
    
    # Check font size (body text is typically 10-12pt)
    if fs < 8 or fs > 14:
        return "header"
    
    # Check if narrow (wrapped text)
    # Narrow text: x0 significantly > TEXT_LEFT AND x1 significantly < TEXT_RIGHT
    if x0 > TEXT_LEFT + 30 and x1 < TEXT_RIGHT - 50:
        return "narrow"
    
    # Check if starts in figure zone (parshape leak candidate)
    if x0 > FIG_LEFT_APPROX:
        return "narrow"  # treat same as narrow
    
    return "fullwidth"


def analyze_pdf(pdf_path):
    doc = fitz.open(pdf_path)
    
    all_indents = defaultdict(list)  # by category
    page_details = []
    anomalous_lines = []
    missing_indent_cases = []
    
    for pg_idx in range(len(doc)):
        page = doc[pg_idx]
        lines = get_text_lines(page)
        figures = get_figures(page)
        
        prev_line = None
        prev_was_narrow = False
        
        for ln in lines:
            cat = classify_line(ln, figures)
            if cat in ("header", "figure_zone"):
                prev_line = ln
                continue
            
            indent = ln["x0"] - TEXT_LEFT
            
            if cat == "narrow":
                prev_was_narrow = True
                all_indents["narrow"].append(indent)
                prev_line = ln
                continue
            
            # Full-width body text
            all_indents["fullwidth"].append(indent)
            
            # Check for anomalous indent on full-width lines
            # Expected parindent is typically 15-25pt in LaTeX
            # But document might use larger indent — let's check distribution
            if indent > 100:
                anomalous_lines.append({
                    "page": pg_idx + 1, "indent": indent,
                    "text": ln["text"][:80],
                    "x0": ln["x0"], "x1": ln["x1"],
                })
            
            # Check for missing indent after transition from narrow to full-width
            # This would indicate \parindent was lost
            if prev_was_narrow and indent < 5:
                # Check if there's a vertical gap (new paragraph)
                if prev_line and (ln["y0"] - prev_line["y1"]) > 3:
                    missing_indent_cases.append({
                        "page": pg_idx + 1, "indent": indent,
                        "prev_text": prev_line["text"][:40],
                        "text": ln["text"][:60],
                        "gap": ln["y0"] - prev_line["y1"],
                    })
            
            prev_was_narrow = False
            prev_line = ln
    
    return all_indents, anomalous_lines, missing_indent_cases


def print_stats(label, values):
    if not values:
        print(f"  {label}: (none)")
        return
    import statistics
    print(f"  {label}: n={len(values)}, "
          f"mean={statistics.mean(values):.1f}, "
          f"median={statistics.median(values):.1f}, "
          f"stdev={statistics.stdev(values):.1f}, "
          f"min={min(values):.1f}, max={max(values):.1f}")


def main():
    if len(sys.argv) < 2:
        print("Usage: detect-indentation-issues.py <pdf> [<pdf2> ...]")
        sys.exit(1)

    for pdf_path in sys.argv[1:]:
        print(f"\n{'='*70}")
        print(f"Indentation Analysis: {pdf_path}")
        print(f"{'='*70}")
        
        all_indents, anomalous, missing = analyze_pdf(pdf_path)
        
        print("\nIndent distributions:")
        print_stats("Full-width body text", all_indents["fullwidth"])
        print_stats("Narrow (wrapped) text", all_indents["narrow"])
        
        # Count unique indent values for full-width
        if all_indents["fullwidth"]:
            from collections import Counter
            fw_counts = Counter(round(v, 1) for v in all_indents["fullwidth"])
            print(f"\n  Full-width indent value distribution (top 5):")
            for val, cnt in fw_counts.most_common(5):
                pct = 100 * cnt / len(all_indents["fullwidth"])
                print(f"    {val:7.1f}pt: {cnt:4d} lines ({pct:.1f}%)")
        
        if anomalous:
            print(f"\n⚠ ANOMALOUS HIGH INDENT on full-width lines ({len(anomalous)}):")
            for a in anomalous[:20]:
                print(f"  pg{a['page']}: indent={a['indent']:.1f}pt, "
                      f"x=[{a['x0']:.0f},{a['x1']:.0f}], "
                      f"text=\"{a['text']}\"")
            if len(anomalous) > 20:
                print(f"  ... and {len(anomalous) - 20} more")
        else:
            print(f"\n✓ No anomalous indentation on full-width body text.")
        
        if missing:
            print(f"\n⚠ MISSING INDENT after narrow→fullwidth transition ({len(missing)}):")
            for m in missing[:10]:
                print(f"  pg{m['page']}: indent={m['indent']:.1f}pt, gap={m['gap']:.1f}pt, "
                      f"prev=\"{m['prev_text']}\" → text=\"{m['text']}\"")
        else:
            print(f"\n✓ No missing indentation after narrow→fullwidth transitions.")


if __name__ == "__main__":
    main()