# Research: Ghost Narrowing Measurement Methodology & Caption Clipping Alternatives

**Date**: 2026-06-08
**Author**: Researcher (automated turn)
**Trigger**: Fallback review pass — no pending Researcher tasks; identified
QA Task #176 (measurement methodology discrepancy) as the most impactful research item

## 1. Ghost Narrowing Measurement Discrepancy (Task #176)

### Problem
Programmer (ST-009, v3.33) claims: **"18 lines → 1 line (-94%)"** on test-ghost-narrowing.tex
QA (Turn T25) finds: **56 ghost narrowing lines across 10 of 11 pages**

This is not a bug in either analysis — it is a **measurement scope mismatch**.

### Root Cause Analysis

The analyze-wrapping.py detection script (`tests/analyze-wrapping.py`) detects ghost narrowing using this logic (lines 271-292):

```python
elif classification == "below":
    # Check for ghost narrowing: narrow body text below the figure
    effective_bottom = compute_effective_fig_bottom(fig, lines)
    is_body_text = line["x0"] < fig.x0 - CAPTION_X_TOLERANCE
    expected_narrow_x1 = fig.x0 - FIGURE_GAP_PT
    is_parshape_narrow = abs(line["x1"] - expected_narrow_x1) <= GHOST_PARSHAPE_TOLERANCE
    if (is_body_text and is_parshape_narrow
            and line["y0"] > effective_bottom + GHOST_MARGIN):
        result["ghost_lines"].append(...)
```

**Critical limitation**: This ONLY detects ghost narrowing on pages that CONTAIN figure rectangles. It looks at narrow lines BELOW a figure's effective bottom on the SAME page. It does NOT detect:

1. **Page-break ghost**: Narrow lines on a page where NO figure exists at all (the paragraph spanned a page break, leaving narrow lines on the continuation page with nothing beside them). This is exactly what v3.33's penalty fence addresses.
2. **Cross-page parshape leak**: Narrow parshape lines that persist on the page AFTER a figure page — there is no figure rectangle on that page, so the script never checks it.

### Two Distinct Metrics

| Metric | What it Counts | Programmer's v3.33 Target | QA's Measurement |
|--------|---------------|--------------------------|-----------------|
| **Same-page ghost** | Narrow lines below figure on same page | 18 → 1 (the penalty fence prevents mid-zone page breaks) | Not directly measured |
| **Cross-page ghost** | Narrow lines on pages with NO figure at all | 1 remaining (overfull page bypass) | 56 lines across 10 pages |
| **All ghost** | Both categories combined | Not measured | 56 lines |

The Programmer's "94% reduction" refers specifically to **same-page ghost lines on page 10** of the focused test (the only page where the original penalty approach left ghost lines). The penalty fence successfully prevents TeX from breaking WITHIN the narrow zone on the same page — it either keeps all narrow lines together or pushes them all to the next page.

However, the penalty fence does NOT prevent the cross-page parshape leak (narrow lines on the continuation page after a page break). This is the 56-line issue QA found. These are fundamentally different problems requiring different solutions.

### Recommendation: Unified Ghost Narrowing Metric

The analysis script should be extended to also detect cross-page ghost narrowing. The detection logic for pages WITHOUT figures:

```python
# On pages with NO figure rectangles:
# Count narrow lines whose x1 ≈ expected_parshape_narrow_width
# AND whose x0 ≈ page_margin (not indented paragraphs, list items, etc.)
# These are leaked parshape lines from the previous page's wrapping session

def detect_cross_page_ghost(page, full_text_width):
    fig_rects = get_figure_rects(page)
    if fig_rects:  # Only on pages WITHOUT figures
        return []

    lines = get_text_lines(page)
    narrow_cutoff = full_text_width - NARROW_THRESHOLD
    ghost_lines = []

    for line in lines:
        # Narrow line starting at page margin = leaked parshape
        if (line["x0"] < 130  # At page margin (~117.8pt)
            and line["width"] < narrow_cutoff
            and line["width"] > 50  # Not a short last line
            and line["y0"] < FOOTER_Y_MIN):  # Not footer
            ghost_lines.append(line)

    return ghost_lines
```

This would give a single, comparable metric that both Programmer and QA can use.

## 2. Caption Clipping Alternatives (Task #175)

### Current Problem
`\smash{\rlap{\hbox{\copy\swarmwrap@box}}}` makes the figure box zero-height for TeX's page-breaking calculations. Under specific page-break + parshape conditions, TeX's PDF output routine clips box content that extends beyond the visible baseline area. Result: 1/50 captions lost (Figure 29 in current v3.33).

### Alternative Placement Techniques

#### Option A: `\vbox to 0pt` + `\vss` (RECOMMENDED)
Replace `\smash{\rlap{\hbox{...}}}` with `\vbox to 0pt{\vss\hbox{...}}`:

```latex
\vbox to 0pt{\vss\hbox{\copy\swarmwrap@box}}%
\kern-\wd\swarmwrap@box\kern\figskip\relax
```

How it works: `\vbox to 0pt` creates a zero-height box, `\vss` vertically stretches to fill it (pushing content upward). The content is preserved in full within the box, unlike `\smash` which tells TeX the box has no height/depth. However, `\vbox to 0pt{\vss}` still makes the box zero-height for page-breaking purposes, so the same DEFER/eject logic applies.

**Risk**: May not work because TeX's output routine still clips based on the vbox's declared height (0pt). The content is physically inside the box but may still be invisible in PDF output if the clipping happens at the shipout stage.

**Feasibility**: MEDIUM — needs testing, but conceptually similar to \smash. The key difference is that \vbox actually contains the content structurally, while \smash discards height/depth information.

#### Option B: Direct PDF operator insertion (LuaTeX)
Use LuaTeX's `pdf.pagecontents()` or node manipulation to insert the figure directly into the PDF page stream without relying on TeX's box model:

```lua
local function insert_figure_at(x, y, width, height)
    -- Save current point, move to absolute position
    -- Draw the saved box content directly
end
```

**Risk**: Highly complex, fragile, version-dependent. Interacts with TeX's output routine in unpredictable ways.

**Feasibility**: LOW — overkill for this use case.

#### Option C: Redesign: Use `\llap` without `\smash` + manual position tracking
Keep the box's natural height/depth for content preservation, but manually offset it using `\llap` and negative `\kern`:

```latex
\llap{\copy\swarmwrap@box}\kern-\wd\swarmwrap@box\kern\figskip\relax
```

This places the figure at the correct position (flush right) without making it zero-height. The figure box still occupies vertical space in TeX's page model.

**Risk**: Defeats the purpose of zero-height placement — TeX would account for the figure's height in page breaking, potentially changing all DEFER/eject decisions. Would require rethinking the entire wrapping layout approach.

**Feasibility**: NOT VIABLE for current architecture.

#### Option D: Accept as Known Limitation + Document
1/50 caption loss (2%) on specific page-break edge cases. The caption is not permanently lost — it appears on a different figure when layout shifts slightly. This is a TeX engine limitation (\smash + page-break clipping), not a swarmwrap.sty logic bug.

**Feasibility**: ALREADY DONE (Known Limitation #3). Task #175 would only make sense if the loss rate increases or affects more figures.

### Recommendation
- **For Task #176**: Extend analyze-wrapping.py with cross-page ghost detection (the unified metric). This resolves the measurement methodology dispute.
- **For Task #175**: Test Option A (`\vbox to 0pt{\vss}`). If it doesn't fix the clipping, accept KL#3 as-is (2% loss rate is acceptable for a TeX engine limitation).

## 3. BLACKBOARD Bloat

The BLACKBOARD has regrown from 402 lines (after June 5 cleanup) to 4,589 lines. The cleanup was overwritten by a subsequent force-push or reset. The same issues persist: ~500 comm log entries consuming 95%+ of the file. A second cleanup is needed with the same approach (compress entries older than 2 days, archive done tasks).
