# Stress Test Results — swarmwrap.sty v3.30 (current)

> **Compiled**: 2026-05-20 11:30 UTC+8 (v3.30, LuaHBTeX)
> **Test file**: `tests/test-stress-1000.tex` (150 figures, consecutive blocks, NO section breaks between most figures)
> **Detection script**: `scripts/detect-layout-issues.py --quality`

---

## ⛔ QUALITY SCORE: 0/855 (0.0%) — FAIL

**The package fails on nearly every figure in the stress test.** The Programmer's crafted test files (test-customwrap.tex, test-pagebreak-variations.tex) all pass with 0 overlaps because they have section breaks or carefully chosen content. The stress test uses **consecutive swarmwrap blocks with no section breaks** — and the package completely breaks in this pattern.

---

## Problem Counts (v3.29 build, 236 pages, 855 figures)

| # | Category | Count | Severity |
|---|----------|-------|----------|
| 1 | **TEXT-FIGURE OVERLAP (body text)** | **4,676** | 🔴 CRITICAL |
| 2 | **FIGURE BESIDE TEXT (no wrapping)** | **39** | 🔴 CRITICAL |
| 3 | **FIGURE MISALIGNED** | **4** | 🟡 WARNING |
| 4 | TEXT-FIGURE OVERLAP (caption, expected) | 664 | ℹ️ INFO |
| 5 | NEAR-EMPTY PAGES (page-eject) | 5 | ℹ️ INFO |
| 6 | EXTRA VSPACE | 7 | ℹ️ INFO |
| | **TOTAL REAL BUGS** | **4,719** | **🔴 FAIL** |
| | **TOTAL (incl. acceptable)** | **5,395** | |

**Only 69.5% of figures (594/855) have any text wrapping beside them.**

---

## What These Numbers Mean

### 4,676 BODY-TEXT OVERLAPS
Text is rendered ON TOP of figures. Entire paragraphs (10-15 lines each) run at full width straight through figure rectangles. This is not a subtle pixel-level issue — it is visually catastrophic. A reader would see body text printed on top of colored figure blocks.

**Pages most affected**: 3 (30 overlaps), 25-26, 44-50, 80-85, 150-155, 200-210 — dense overlap clusters.

### 39 FIGURES WITH NO WRAPPING
On 39 pages, a figure exists but text does NOT wrap beside it at all. The figure is just a colored block with text above and below it — as if it were a centered float, not a right-wrapped figure. The MUST spec says "wrap figure on right" — these are clear violations.

### 4 FIGURES MISALIGNED
Figures placed 20-184pt left of the right text margin. The `swarmwrap_min_tw` clamping is too aggressive for small (2cm) figures.

---

## Root Cause (Task #163)

The Programmer's v3.30 fix addressed 3 bugs in parshape computation, but the fix is **INCOMPLETE**:

1. **Programmer's test file** (`test-consecutive-figures.tex`) has `\section*` breaks between figure groups. Section breaks reset parshape. The stress test has **NO section breaks** between consecutive `\begin{swarmwrap}...\end{swarmwrap}\swarmwrapnext` blocks.

2. In consecutive blocks without section breaks, the **second figure's `\swarmwrapnext` does not correctly account for the first figure's parshape still being active**. Text continues at full width through both figures.

3. The everypar chain from the first figure's narrowing leaks into subsequent paragraphs, but only partially — some lines get narrowed, others don't.

**Evidence**: VLM visual inspection confirmed severe overlaps on pages 3, 25, 30, 36, 45 of the 50-figure stress subset. Entire paragraphs at full width through figures.

---

## What the Programmer Must Do (Task #163, STILL PENDING)

1. **Create a test that replicates the actual stress test pattern**: Consecutive `\begin{swarmwrap}...\end{swarmwrap}\swarmwrapnext\lipsum[N]` blocks with NO intervening section breaks.

2. **Fix the parshape/everypar chain** so that consecutive figures WITHOUT section breaks still produce correct narrowing.

3. **Fix figure alignment**: 2cm figures placed at x=235 (87pt left of expected right margin position) — tw clamping is too aggressive.

4. **Run `scripts/detect-layout-issues.py tests/test-stress-50.pdf --quality`** after each fix attempt. The 50-figure subset compiles fast and is a reliable proxy.

---

## Progress Tracking

| Version | Stress Test Overlaps | Status |
|---------|---------------------|--------|
| v3.27 | 1,420 | Task #161 |
| v3.28 | 1,625 | Task #162 |
| v3.29 | 1,625 | No change |
| v3.30 | 186 (50-fig subset) / ~4,676 (full) | Task #163 OPEN |
| **Target** | **0** | **PASS** |
