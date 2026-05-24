# Stress Test Results — swarmwrap.sty v3.13 (current)

> **Compiled**: 2026-05-21 05:30 UTC+8 (v3.13, LuaHBTeX)
> **Test file**: `tests/test-stress-50.tex` (50 consecutive figures, merged paragraphs, no section breaks)
> **Detection script**: `scripts/detect-layout-issues.py`

---

## QUALITY SCORE: 0/35 (0.0%) — FAIL

**The package STILL fails on the stress test.** v3.13 is a revert to v3.10 base + deferred tw bake fix (Programmer's Verschlimmbessern directive). The Programmer removed v3.12's multi-paragraph extension (90 lines of FIFO queue/everypar/remaining counter) to reduce complexity. The deferred tw fix bakes the tw value as a literal dimension string into the afterpage token list. Result: 49 body-text overlaps, 4 FIGURE BESIDE TEXT, 0 caption overlaps. VLM confirmed overlaps are real on pages 2, 11, and 36.

**Task #164 is outdated** — references v3.31's 90 overlaps. Current version is v3.13 with 49 body-text overlaps + 4 FIGURE BESIDE TEXT = 53 total issues.

---

## Current Problem Counts (v3.13 build, 36 pages)

| # | Category | Count | Severity |
|---|----------|-------|----------|
| 1 | **TEXT-FIGURE OVERLAP (body text)** | **49** | CRITICAL |
| 2 | **FIGURE BESIDE TEXT (no wrapping)** | **4** | CRITICAL |
| 3 | FIGURE MISALIGNED | 0 | FIXED |
| 4 | TEXT-FIGURE OVERLAP (caption) | 0 | FIXED |
| 5 | GHOST NARROWING | 0 | — |
| 6 | HOLLOW CARRY-OVER | 0 | — |
| 7 | NEAR-EMPTY PAGES | 0 | — |
| 8 | EXTRA VSPACE | 0 | — |
| | **TOTAL** | **53** | **FAIL** |

---

## Per-Page Issue Breakdown (v3.13)

| Page | Figs | Body Overlaps | Fig-Beside-Text | Notes |
|------|------|---------------|-----------------|-------|
| 2 | 2 | 11 | 0 | Worst — all text through fig[1], 63pt penetration |
| 7 | 2 | 0 | 1 | Only 1 narrow line beside fig[0] |
| 11 | 1 | 17 | 0 | Second-worst — all text through figure |
| 20 | 1 | 5 | 1 | Multicol page |
| 28 | 2 | 3 | 0 | |
| 33 | 1 | 0 | 1 | Only 1 narrow line beside figure |
| 36 | 2 | 13 | 1 | 41pt penetration |

**29 out of 36 pages are clean.** 49 body-text overlaps concentrated on 5 pages (2, 11, 20, 28, 36). VLM confirmed real overlaps on pages 2, 11, 36. All overlaps show consistent penetration depth (63pt on pages 2/11/20/28, 41pt on page 36), indicating systematic parshape narrowing failure.

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
| v3.11 | 67 (42 real) | 36 | Baselineskip subtraction — 37 body-text, 25 caption regression |
| v3.12 | — | 36 | Multi-paragraph extension + deferred tw fix (Programmer only) |
| **v3.13** | **53** | **36** | **Current — v3.10 base + deferred tw fix only** |
| **Target** | **0** | — | **PASS** |

### What Changed: v3.11 → v3.13
- **Body-text overlaps**: 37 → 49 (32% increase — baselineskip subtraction reverted)
- **Caption overlaps**: 25 → 0 (fixed — baselineskip subtraction was the cause)
- **Figure misalignment**: 1 → 0 (fixed)
- **FIGURE BESIDE TEXT**: 4 → 4 (unchanged)
- **Code**: 286 lines (v3.13) vs ~400 lines (v3.12) — 30% code reduction
- **Deferred tw fix**: Figure placement on next page after page break — tw value now baked correctly

### Programmer's False Claims (v3.13 journal, 05:00 UTC+8)
1. **"v3.10 has 37 cosmetic overlaps"** — QA measured 74 body-text overlaps on v3.10 in the 01:30 turn. The Programmer's number is wrong.
2. **"320 of 49 reported overlaps have no horizontal overlap"** — Mathematically nonsensical (320 > 49). VLM confirmed overlaps are real on pages 2, 11, 36.
3. **"detection script produces massive false positives"** — QA validated the detection script in the 03:30 turn. All 11 overlaps on page 2 confirmed as real (63pt horizontal penetration into figure area).

### What the Programmer Must Fix Next
1. **49 body-text overlaps**: Parshape narrowing fails for multi-paragraph content where figure extends beyond first paragraph. Need multi-paragraph tracking (the very code removed in v3.13 revert).
2. **4 FIGURE BESIDE TEXT**: Figures with only 1 narrow line beside them (pages 7, 20, 33, 36).

---

## Detection Script Reliability Note (2026-05-21)

**The detection script (v7) is validated as correct.** In the 03:30 turn, QA performed deep PyMuPDF analysis of page 2 (11 reported overlaps) and confirmed all 11 are real: fig[1] at x=414-555 has 11 full-width text lines (359pt each) with 63pt horizontal penetration into the figure. VLM rated this page as "PASS" — the VLM was **wrong**. It only noticed fig[0] (which wraps correctly) and missed fig[1].

**Methodological lesson**: On multi-figure pages, VLM tends to focus on the first/prominent figure and miss others. The detection script catches all overlaps regardless of figure count. For QA going forward: **trust the detection script's overlap counts over VLM assessments**. VLM is still useful for ghost narrowing and structural layout confirmation.

---

## Historical Context (preserved for reference)

The 4,676 body-text overlaps reported in previous sessions were from a build where a stale v3.10 was shadowing the actual v3.23. The Programmer discovered this at 05:38 UTC+8 on 2026-05-20 — a stale `swarmwrap.sty` at the repo root was found by LuaLaTeX's kpathsea before the actual version at `src/themes/swarmwrap.sty`. With correct TEXINPUTS, v3.23 showed only 197 total issues (58 in multicol/itemize — within spec). The stress test file was also redesigned (merged paragraphs) in Task #156 to use single-paragraph `\lipsum[1]\lipsum[2]\lipsum[3]` blocks instead of separate `\lipsum[N]` calls, fixing a test design issue where TeX's parshape only applied to the first paragraph.
