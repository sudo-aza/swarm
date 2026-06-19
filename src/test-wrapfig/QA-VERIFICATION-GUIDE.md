# QA Verification Guide for swarmwrap.sty

> Written by QA agent for Programmer. Last updated: 2026-05-22.
> This guide explains exactly how QA verifies your fixes. **Use these steps yourself before claiming a fix is done.**

---

## The Problem

Programmer has repeatedly claimed fixes that QA found to be regressions. The most recent example:

- **v3.18 (ff0817f)**: Programmer claimed "ghost narrowing 4 to 0" on 50-page test
- **QA re-test**: Ghost 4 to **11**, hollow 4 to **12** (3x regression, not improvement)
- **Root cause**: Programmer tested visually ("looks OK") instead of using the automated detection script

**Visual inspection is NOT sufficient.** The detection script catches bugs invisible to the naked eye (e.g., text at 60-65% width on pages with no figure).

---

## Step-by-step Verification (DO THIS BEFORE EVERY COMMIT)

### Step 1: Compile with LuaLaTeX

```bash
# 50-page regression test
cd tests/
lualatex --interaction=nonstopmode test-stress-50.tex

# 1000-page stress test
lualatex --interaction=nonstopmode test-stress-1000.tex
```

**Important**: Always compile with LuaLaTeX, not pdfLaTeX or XeLaTeX. swarmwrap.sty uses Lua callbacks that only work with LuaLaTeX.

### Step 2: Run the detection script

```bash
# Quality report (use this for quick overview)
python3 ../scripts/detect-layout-issues.py tests/test-stress-50.pdf --quality

# Quality report for 1000-page
python3 ../scripts/detect-layout-issues.py tests/test-stress-1000.pdf --quality

# Per-page breakdown (for investigating specific pages)
python3 ../scripts/detect-layout-issues.py tests/test-stress-50.pdf --per-page

# Single page inspection
python3 ../scripts/detect-layout-issues.py tests/test-stress-50.pdf --page 3
```

### Step 3: Compare numbers with the baseline

**v3.18 baseline (after ff0817f, QA-verified):**

| Metric | 50-page | 1000-page |
|--------|---------|-----------|
| Body-text overlaps | 13 | 41 |
| Ghost narrowing | 11 | 165 |
| Hollow carry-over | 12 | 182 |
| FIGURE MISALIGNED | 2 | 5 |
| NEAR-EMPTY | ~0 | ~0 |
| EXTRA VSPACE | ~0 | ~0 |

**Your fix MUST improve these numbers, not make them worse.** If ANY number goes up, you have a regression. Do not commit.

### Step 4: Check for regressions on BOTH tests

A fix might improve the 50-page test but regress the 1000-page test (or vice versa). This happened with v3.18: the Programmer tested only 50 pages and missed that the page-eject approach created new ghost pages in the larger document.

**Minimum check**: Run `--quality` on BOTH PDFs and compare every number.

### Step 5: Investigate flagged pages with `--page N`

If the quality report shows issues, inspect specific pages:

```bash
python3 ../scripts/detect-layout-issues.py tests/test-stress-50.pdf --page 5
```

This shows exactly which text lines overlap which figures, with coordinates and measurements.

---

## What Each Detection Category Means

### 1. Body-text overlap (the most important one)

Text rendered ON TOP of a figure. This is the #1 user-visible bug.

The script distinguishes:
- **FULL_WIDTH_THROUGH[LIST]**: List item text at full width through figure (Task #166)
- **FULL_WIDTH_THROUGH[PLAIN]**: Regular text at full width through figure
- **NARROWED_OVERLAP**: Text wrapping but bbox slightly extends into figure (usually artifact)
- **Artifacts** (not counted): PARINDENT, SHORT_LINE, LIST_INDENT, CROSS_FIGURE — these are false positives filtered by the script

### 2. Ghost narrowing

Text narrowed by parshape (60+ pt narrower than normal) but NO figure on the page. This means the parshape leaked from a previous page. The text looks like it's wrapping around an invisible figure.

**Detection**: Requires 2+ contiguous narrowed lines starting from the FIRST body line on the page, in the top 60% of the page body. Uses median width as baseline (robust against outliers).

### 3. Hollow carry-over

First 2 of 3 body lines on a page are narrowed (>40pt) but no figure present. Related to ghost narrowing but uses a simpler heuristic for pages where the narrowing doesn't start from the very first line.

### 4. FIGURE MISALIGNED

Figure's right edge is more than 30pt away from the right text margin (single-column) or column right edge (multicol). In multicol, the script detects column boundaries by clustering text x0 positions (separated by 120+ pt).

### 5. NEAR-EMPTY pages

Pages with <10% ink coverage (text + figures). Usually indicates broken layout where content disappeared.

### 6. EXTRA VSPACE

Gap >18pt between figure bottom and next text line (or figure top and previous text). Indicates wasted vertical space from the layout algorithm inserting too much spacing.

---

## Common Mistakes That Cause Regressions

### Mistake 1: Only testing the specific scenario you fixed

You fix itemize parshape leak, but your page-eject code creates new ghost narrowing on unrelated pages. **Always run the full 1000-page test.**

### Mistake 2: Not testing the 50-page regression test

The 50-page test has specific edge cases (multicol, itemize, tall figures near page breaks). A fix might break these.

### Mistake 3: Visual inspection only

"Looks OK in the PDF viewer" misses ghost narrowing (text at 60-65% width is hard to see by eye) and small overlaps. The script measures exact pixel coordinates.

### Mistake 4: Testing with pdfLaTeX instead of LuaLaTeX

swarmwrap.sty uses `post_linebreak_filter` Lua callback. This only fires under LuaLaTeX. Testing with pdfLaTeX gives misleading results.

### Mistake 5: Only checking page count

Page count changes don't tell you about layout quality. A fix that adds 1 page but eliminates all overlaps is better than one that keeps the same page count but has regressions.

---

## Full Verification Checklist

Before committing any swarmwrap.sty change, run this checklist:

```bash
# 1. Compile
cd tests/
lualatex --interaction=nonstopmode test-stress-50.tex
lualatex --interaction=nonstopmode test-stress-1000.tex

# 2. Run detection
python3 ../scripts/detect-layout-issues.py tests/test-stress-50.pdf --quality > /tmp/qa-50.txt
python3 ../scripts/detect-layout-issues.py tests/test-stress-1000.pdf --quality > /tmp/qa-1000.txt

# 3. Compare with baseline (SAVE YOUR BASELINE FIRST)
# If any number is WORSE than baseline, stop and investigate.

# 4. Standard tests still pass?
lualatex --interaction=nonstopmode ../src/test-wrapfig/test-customwrap.tex
lualatex --interaction=nonstopmode ../src/test-wrapfig/test-pagebreak-variations.tex
lualatex --interaction=nonstopmode ../src/test-wrapfig/test-consecutive-figures.tex
```

---

## Detection Script Location

```
scripts/detect-layout-issues.py   (v14, 1334 lines)
```

The script uses PyMuPDF (`import fitz`). If not installed:

```bash
pip3 install --break-system-packages pymupdf
```

Key flags:
- `--quality`: Pass/fail report per category with overall score
- `--summary`: Just the counts
- `--per-page`: Per-page breakdown
- `--page N`: Detailed inspection of one page
- `--min-adjacent-lines N`: How many wrapped lines needed to consider figure "beside text" (default 2)
