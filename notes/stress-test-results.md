# Stress Test Results — swarmwrap.sty v3.11 (current)

> **Compiled**: 2026-05-21 02:30 UTC+8 (v3.11, LuaHBTeX)
> **Test file**: `tests/test-stress-50.tex` (50 consecutive figures, merged paragraphs, no section breaks)
> **Detection script**: `scripts/detect-layout-issues.py --quality`

---

## QUALITY SCORE: 0/35 (0.0%) — FAIL

**The package STILL fails on the stress test.** v3.11 (baselineskip subtraction) halved body-text overlaps from v3.10 but introduced a caption overlap regression and a figure misalignment bug. The Programmer's crafted test files (test-customwrap.tex, test-pagebreak-variations.tex) all pass with 0 overlaps because they use section breaks or carefully chosen content. The stress test uses **consecutive swarmwrap blocks with merged paragraphs and no section breaks** — this pattern still produces visible text overlap with figures.

**Task #164 is outdated** (references v3.31's 90 overlaps). Current version is v3.11 with 37 body-text overlaps + 25 caption overlaps + 1 misaligned = 42 real bugs.

---

## Current Problem Counts (v3.11 build, 36 pages, 35 figures)

| # | Category | Count | Severity |
|---|----------|-------|----------|
| 1 | **TEXT-FIGURE OVERLAP (body text)** | **37** | CRITICAL |
| 2 | **FIGURE BESIDE TEXT (no wrapping)** | **4** | CRITICAL |
| 3 | **FIGURE MISALIGNED** | **1** | CRITICAL (regression) |
| 4 | TEXT-FIGURE OVERLAP (caption, expected) | 25 | INFO (regression) |
| 5 | GHOST NARROWING | 0 | FIXED |
| 6 | HOLLOW CARRY-OVER | 0 | FIXED |
| 7 | NEAR-EMPTY PAGES (page-eject) | 0 | FIXED |
| 8 | EXTRA VSPACE | 0 | FIXED |
| | **TOTAL REAL BUGS** | **42** | **FAIL** |
| | **TOTAL (incl. acceptable)** | **67** | |

**74.3% of figures (26/35) have text wrapping beside them.**

---

## Per-Page Issue Breakdown (v3.11)

| Page | Figs | Body Overlaps | Fig-Beside-Text | Misaligned | Notes |
|------|------|---------------|-----------------|------------|-------|
| 1 | 2 | 0 | 0 | 1 | Figure at x=235, 184pt from right margin |
| 2 | 2 | 11 | 0 | 0 | Worst page — all text through fig[1] |
| 7 | 2 | 0 | 1 | 0 | Only 1 narrow line beside fig[0] |
| 11 | 1 | 17 | 0 | 0 | Second-worst — all text through figure |
| 20 | 1 | 5 | 1 | 0 | Multicol page |
| 28 | 2 | 3 | 0 | 0 | |
| 33 | 1 | 0 | 1 | 0 | Only 1 narrow line beside figure |
| 36 | 1 | 1 | 1 | 0 | 25 caption overlaps (label repetition) |

**28 out of 36 pages are clean.** The 37 body-text overlaps are concentrated on just 5 pages (2, 11, 20, 28, 36). The remaining counter exhaustion bug affects multi-paragraph content where the figure extends beyond the first paragraph.

---

## Progress Tracking

| Version | 50-Figure Issues | Pages | Notes |
|---------|-----------------|-------|-------|
| v3.10 (stale shadow) | ~4,700 | — | Stale v3.10 was shadowing real version |
| v3.27 | ~1,420 | — | Task #161 (everypar chain) |
| v3.28 | ~1,625 | — | Task #162 (everypar re-injection) |
| v3.29 | ~1,625 | — | No change (ghost narrowing only) |
| v3.30 | 202 | — | Task #163 (consecutive figure tw clamping) |
| v3.31 | 105 (96 real) | 43 | 48% reduction from v3.30 |
| v3.10 (revert) | 85 | 37 | Programmer reverted from v3.31 |
| **v3.11** | **67 (42 real)** | **36** | **Current — baselineskip subtraction** |
| **Target** | **0** | — | **PASS** |

### What Changed: v3.10 Revert → v3.11
- **Body-text overlaps**: 74 → 37 (50% reduction — baselineskip subtraction works)
- **Caption overlaps**: 8 → 25 (regression — 3x increase)
- **Pages**: 37 → 36 (minor)
- **New bug**: FIGURE MISALIGNED on page 1 (figure 184pt from right margin)
- **Fixed**: Ghost narrowing, hollow carry-over, near-empty pages, extra vspace (all 0)

### What the Programmer Must Fix Next
1. **37 body-text overlaps**: Remaining counter exhaustion. The everypar remaining counter is consumed by the first paragraph but the figure extends beyond. Need to track figure bottom position in Lua.
2. **25 caption overlaps (regression)**: v3.11's baselineskip change disrupted caption positioning. Captions now overlap figure rectangles.
3. **1 figure misalignment (regression)**: Page 1 figure placed at x=235 instead of flush right. Tw clamping or placement issue.
4. **4 FIGURE BESIDE TEXT**: Figures with only 1 narrow line beside them (pages 7, 20, 33, 36).

---

## Detection Script Reliability Note (2026-05-21)

**The detection script (v7) is validated as correct.** In the 03:30 turn, QA performed deep PyMuPDF analysis of page 2 (11 reported overlaps) and confirmed all 11 are real: fig[1] at x=414-555 has 11 full-width text lines (359pt each) with 63pt horizontal penetration into the figure. VLM rated this page as "PASS" — the VLM was **wrong**. It only noticed fig[0] (which wraps correctly) and missed fig[1].

**Methodological lesson**: On multi-figure pages, VLM tends to focus on the first/prominent figure and miss others. The detection script catches all overlaps regardless of figure count. For QA going forward: **trust the detection script's overlap counts over VLM assessments**. VLM is still useful for ghost narrowing and structural layout confirmation.

---

## Historical Context (preserved for reference)

The 4,676 body-text overlaps reported in previous sessions were from a build where a stale v3.10 was shadowing the actual v3.23. The Programmer discovered this at 05:38 UTC+8 on 2026-05-20 — a stale `swarmwrap.sty` at the repo root was found by LuaLaTeX's kpathsea before the actual version at `src/themes/swarmwrap.sty`. With correct TEXINPUTS, v3.23 showed only 197 total issues (58 in multicol/itemize — within spec). The stress test file was also redesigned (merged paragraphs) in Task #156 to use single-paragraph `\lipsum[1]\lipsum[2]\lipsum[3]` blocks instead of separate `\lipsum[N]` calls, fixing a test design issue where TeX's parshape only applied to the first paragraph.
