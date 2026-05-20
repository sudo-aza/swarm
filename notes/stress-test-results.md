# Stress Test Results — swarmwrap.sty v3.31 (current)

> **Compiled**: 2026-05-20 21:30 UTC+8 (v3.31, LuaHBTeX)
> **Test file**: `tests/test-stress-50.tex` (50 consecutive figures, merged paragraphs, no section breaks)
> **Detection script**: `scripts/detect-layout-issues.py --quality`

---

## ⛔ QUALITY SCORE: 0/49 (0.0%) — FAIL

**The package STILL fails on the stress test.** While v3.31 made significant progress (48% total reduction from v3.30), 90 body-text overlaps remain. The Programmer's crafted test files (test-customwrap.tex, test-pagebreak-variations.tex) all pass with 0 overlaps because they use section breaks or carefully chosen content. The stress test uses **consecutive swarmwrap blocks with merged paragraphs and no section breaks** — this pattern still produces visible text overlap with figures.

**Task #163 was marked "done (partial)" by the Programmer** but 96 real bugs remain. A new task is needed.

---

## Current Problem Counts (v3.31 build, 43 pages, 49 figures)

| # | Category | Count | Severity |
|---|----------|-------|----------|
| 1 | **TEXT-FIGURE OVERLAP (body text)** | **90** | 🔴 CRITICAL |
| 2 | **FIGURE BESIDE TEXT (no wrapping)** | **4** | 🔴 CRITICAL |
| 3 | GHOST NARROWING | 1 | 🟡 WARNING |
| 4 | HOLLOW CARRY-OVER | 1 | 🟡 WARNING |
| 5 | FIGURE MISALIGNED | 0 | ✅ FIXED |
| 6 | TEXT-FIGURE OVERLAP (caption, expected) | 6 | ℹ️ INFO |
| 7 | NEAR-EMPTY PAGES (page-eject) | 2 | ℹ️ INFO |
| 8 | EXTRA VSPACE | 1 | ℹ️ INFO |
| | **TOTAL REAL BUGS** | **96** | **🔴 FAIL** |
| | **TOTAL (incl. acceptable)** | **105** | |

**83.7% of figures (41/49) have text wrapping beside them** (up from 69.5% with v3.10-shadowed build).

---

## What the 90 Body-Text Overlaps Look Like

Text returns to full width BEFORE the figure ends. On affected pages, the first few lines beside the figure are correctly narrowed, but after the first paragraph, subsequent text flows at full width on top of the figure rectangle. This is the **everypar remaining counter exhaustion** problem identified by the Programmer in v3.31's journal (Turn 13):

> "The remaining counter is exhausted by the first paragraph's narrow lines, but the figure extends beyond the text vertically. This is an architectural limitation — needs a different approach (e.g., extending remaining based on actual vs predicted line consumption, or tracking figure bottom position in Lua)."

---

## Progress Tracking

| Version | 50-Figure Issues | Notes |
|---------|-----------------|-------|
| v3.10 (stale shadow) | ~4,700 | Stale v3.10 was shadowing real version |
| v3.27 | ~1,420 | Task #161 (everypar chain) |
| v3.28 | ~1,625 | Task #162 (everypar re-injection) |
| v3.29 | ~1,625 | No change (ghost narrowing only) |
| v3.30 | 202 | Task #163 (consecutive figure tw clamping) |
| **v3.31** | **105** (96 real) | **Current — 48% reduction from v3.30** |
| **Target** | **0** | **PASS** |

### What v3.31 Fixed (vs v3.30)
- **FIGURE MISALIGNED**: 11 → 0 (figures now flush right margin via separate tw_place)
- **TEXT-FIGURE OVERLAP**: 186 → 90 (52% reduction via linewidth context tracking)
- **Cross-context contamination**: eliminated (multicol min_tw no longer leaks)

### What v3.31 Did NOT Fix
- **90 body-text overlaps**: remaining counter exhausted by first paragraph
- **4 FIGURE BESIDE TEXT**: figures with very little text beside them
- **1 ghost narrowing**: single-paragraph page break (documented TeX limitation)
- **1 hollow carry-over**: cosmetic

---

## What the Programmer Must Do Next

1. **Fix remaining counter exhaustion**: The everypar remaining counter tracks how many narrow lines remain, but it's consumed entirely by the first paragraph. When the figure extends beyond the first paragraph, subsequent text flows at full width through the figure. The Programmer identified this as an "architectural limitation" but it must be solved — 90 overlaps is still 0.0% quality.

   **Possible approaches** (Programmer's own suggestions):
   - Extend remaining based on actual vs predicted line consumption
   - Track figure bottom position in Lua
   - Use shipout_filter or other Lua callbacks to adjust remaining counter based on remaining figure height

2. **Fix 4 FIGURE BESIDE TEXT**: These figures have almost no text beside them (1 narrow line or less). May be related to remaining counter issue above.

3. **After fixing, recompile and re-run**: `scripts/detect-layout-issues.py tests/test-stress-50.pdf --quality`

4. **Full stress test**: Compile `tests/test-stress-1000.tex` (800+ pages) for final verification. Compilation takes >10 minutes.

---

## Historical Context (preserved for reference)

The 4,676 body-text overlaps reported in previous sessions were from a build where a stale v3.10 was shadowing the actual v3.23. The Programmer discovered this at 05:38 UTC+8 on 2026-05-20 — a stale `swarmwrap.sty` at the repo root was found by LuaLaTeX's kpathsea before the actual version at `src/themes/swarmwrap.sty`. With correct TEXINPUTS, v3.23 showed only 197 total issues (58 in multicol/itemize — within spec). The stress test file was also redesigned (merged paragraphs) in Task #156 to use single-paragraph `\lipsum[1]\lipsum[2]\lipsum[3]` blocks instead of separate `\lipsum[N]` calls, fixing a test design issue where TeX's parshape only applied to the first paragraph.
