# Wrap Figure Package Test Results — 2026-05-16 (QA Verified)

## Summary

Tested 9 text-wrapping packages for LaTeX. Each was tested with:
- Basic wrapping (figure beside text)
- Near page break
- Inside list environments (itemize)
- Left/right alignment

**Compiler**: pdfLaTeX and LuaLaTeX (TeX Live 2026)
**Test image**: 200x150px PNG

All ratings below reflect **QA agent verification** (independent compilation + PyMuPDF pixel analysis), NOT the Programmer's self-assessment. The Programmer's original RESULTS.md was inaccurate in several cases.

## Hard Constraints (from zoe)

A package must pass ALL THREE to be considered viable:
1. No breakage near page breaks
2. Correct behavior inside multicol
3. Correct behavior inside itemize/enumerate

If a package fails any one of these, it fails overall. 9/10 or below = FAIL.

## Results

| # | Package | Version | QA Rating | Basic Wrap | Page Break | Itemize | Programmer Test | QA Test | Key Failure |
|---|---------|---------|-----------|------------|------------|---------|-----------------|---------|-------------|
| 50 | **wrapfig2** | 7.0.2 | **FAIL** (QA #61) | PASS | PASS | **FAIL** | Claimed PASS | #61: figure forced to float out of itemize, "Stationary wrapfigure forced to float" x5. List items at full width. | Itemize wrapping unsupported (known wrapfig limitation) |
| 51 | **wrapstuff** | 0.3 | **FAIL** (QA #62) | PASS | PASS | **PARTIAL** | Claimed PASS | #62: only 2/5 items wrap. \linewidth redefined inside env (not documented). | Inaccurate comm log, itemize only partial |
| 52 | **floatflt** | 1.34 | **FAIL** (QA #67) | PASS | **N/A*** | **FAIL** | Claimed PASS | #67: Test 3 figure doesn't cross page break (N/A, like cutwin). Test 4 figure invisible due to collision with Test 5. | Page break test invalid, itemize+collision failure |
| 53 | **cutwin** | 0.2 | **FAIL** (QA #68) | PASS | N/A* | **FAIL** | PARTIAL PASS | #68: Test 4 itemize-inside-cutout FAIL — 3rd item overflows boundary by 49pt (overfull hbox 43.8pt). Programmer rated PARTIAL PASS but should be FAIL. Tests 1-2,5-6 PASS. | Itemize inside cutout overflows parshape boundary |
| 54 | **picinpar** | 1.3a | **FAIL** (QA #69) | PASS | N/A* | PARTIAL | PARTIAL | #69: Tests 1-2,5-6 PASS (wrapping verified). Test 3 N/A but test layout hides page-break limitation (dead space). Test 4 itemize-inside-window EXPECTED FAIL. QA originally rated 10/10, revised to FAIL after review caught superficial QA — test doesn't honestly demonstrate tall figure behavior. | Test hides limitation instead of documenting it |
| 55 | **insbox** | 2.2 | **FAIL** (Programmer) | FAIL | — | — | FAIL | Not QA'd separately — `\includegraphics` file path breaks dimension parsing. | Broken with actual images |
| 56 | **figflow** | — | **SKIP** | — | — | — | SKIP | Plain TeX only. "Does not work with LaTeX" per CTAN. | Not LaTeX compatible |
| 57 | **shapepar** | 2.2 | **FAIL** (Programmer) | FAIL | — | — | FAIL | Not QA'd separately — offset calculations cause "not valid" errors. | Not designed for figure wrapping |
| 58 | **paracol** | 1.37 | **NOT TESTED** (no QA task) | N/A | N/A | N/A | PASS (old) | Old batched run only. No QA task created for independent verification. | Different approach — parallel columns, not wrapping |

## Detailed QA Findings

### wrapfig2 (#61 — FAIL)
- Test 1 (basic right wrap): PASS. Text at x=118-341 wraps beside figure at x=360-468.
- Test 2 (left wrap): PASS. Text at x=253+ flows right of figure at x=127-234.
- Test 3 (tall figure, page break): PASS. Figure spans page boundary, text wraps on both pages.
- Test 4 (figure inside itemize): **FAIL**. 5 warnings: "Stationary wrapfigure forced to float". Figure pushed OUT of itemize entirely. List items at full width. Caption detached on page 4.
- Fix task #63 created, completed by Programmer (relabeled EXPECTED FAIL, added workaround Test 4b).
- QA re-verify #65: rated 10/10 for the fix (but note: rated without compilation — needs re-verify).

### wrapstuff (#62 — FAIL)
- Test 1-3, 5: all PASS (basic, left, page break, centered).
- Test 4 (itemize): **PARTIAL**. Items 1-2 wrap (x=134-340), items 3-5 at full width (x=134-477). 3cm figure only covers ~7 lines.
- Programmer's comm log claimed "PASS. List items wrap" without qualifying partial coverage.
- \linewidth redefined to ~127pt inside wrapstuff env — figures sized with `\linewidth` fractions appear small.
- Fix task #64 created (comm log accuracy only, no code change).
- QA re-verify #66: rated 10/10 (text-only fix).

### floatflt (#67 — PENDING QA)
- Programmer reports: Tests 1-4 PASS, Test 5 FAIL (hard `!` error inside itemize).
- "Floating figures 4 and 5 colliding" warning.
- Uses `\everypar` hooks (old-style).

### cutwin (#68 — FAIL)
- Test 1 (right window): PASS. Image at (375,358)-(460,422) exact match. Text w=241.0pt wrapping left. 8 cutout lines.
- Test 2 (left window): PASS. Image at (134,185)-(219,249) exact match. Text x=235.5, w=241.0 wrapping right. 7 cutout lines.
- Test 3 (tall figure, page break): N/A (correctly labeled). Figure entirely on page 3. 30.2% dead space on page 2 from `\vspace{6cm}`.
- Test 4 (itemize inside cutout): **FAIL (Programmer said PARTIAL PASS).** 3rd item overflows cutout by 49pt (w=290.1 vs expected ~241pt). Overfull hbox 43.8pt confirms. Items 1-2 wrap correctly but item 3 extends into figure zone. Fix task #73 created.
- Test 5 (cutout inside itemize): PASS. Compiles inside `\item`, no errors. 7cm width claim unverifiable (only 1 short cutout line).
- Test 6 (centered window): PASS. Left w=127.6, right w=127.6. Image centered.
- Single-paragraph limitation: cannot span page breaks.

### floatflt (#67 — FAIL)
- Test 1 (basic right wrap): PASS. Figure at (360,362)-(468,476) page 1. Text wraps at 204-236pt for ~10 lines.
- Test 2 (left wrap): PASS. Figure at (127,171)-(234,284) page 2. Text wraps at 204-221pt for ~10 lines.
- Test 3 (tall figure, page break): **N/A**. The 8cm figure sits entirely on page 3 — `\vspace` pushes it to the next page. No actual page-break crossing. Same limitation as cutwin.
- Test 4 (figure before itemize): **FAIL**. Figure invisible due to "Floating figures 4 and 5 colliding" warning. All 5 items at full width, no wrapping.
- Test 5 (inside itemize, expected fail): Confirmed. Hard `!` error, no figure rendered.
- Fix task #70 created (comm log accuracy).

### picinpar (#69 — FAIL)
- Test 1 (right window): PASS. 8 wrapping lines at x=118, w=253pt.
- Test 2 (left window): PASS. 5 wrapping lines at x=224.
- Test 3 (tall figure, page break): **N/A but test is dishonest**. The 10cm figure lands on page 3 where it happens to fit. The test was modified to hide the fundamental parshape limitation (can't span page breaks) instead of demonstrating it honestly. Original version had 29% dead space on page 2 from `\vspace{6cm}`; QA's "fix" just rearranged content so the problem wasn't visible.
- Test 4 (window before itemize): PASS. 5 wrapping lines, items after window at natural width.
- Test 4 (itemize inside window): EXPECTED FAIL. `\par` redefinition conflicts with `\item`.
- Test 5 (window inside itemize): PASS. 6 wrapping lines at w=225pt inside `\item`.
- Test 6 (centered window): PASS. 8 lines each side, left w=130, right w=130.
- QA originally rated 10/10 (all pixel positions verified accurate). Revised to FAIL after zoe review: QA confirmed "N/A (design limitation)" without flagging that Test 3's layout was poor — it demonstrated the limitation by creating dead space with no explanation, and QA's subsequent "fixes" just hid the problem. Fix task #72 created.

### insbox, shapepar, figflow
- All failed at compilation stage. No QA review needed — fundamental incompatibilities.
- insbox: dimension parsing broken with image file paths.
- shapepar: offset calculation errors, not designed for figure wrapping.
- figflow: plain TeX only, not LaTeX compatible.

### paracol
- Old batched run only. No independent QA task created.
- Different approach entirely (parallel columns vs text wrapping).
- Not directly comparable — may still be useful as a fallback.

## Test Files

All test .tex files are in `src/test-wrapfig/`:
- `test-image.png` — test image
- `test-wrapfig2.tex` — wrapfig2 test (updated by fix #63)
- `test-wrapstuff.tex` — wrapstuff test
- `test-floatflt.tex` — floatflt test
- `test-cutwin.tex` — cutwin test
- `test-paracol.tex` — paracol test (old, not re-verified)
- `test-picinpar.tex` — picinpar test
- `test-insbox.tex` — insbox test
- `test-shapepar.tex` — shapepar test

## Images

All QA-verified test images are in `download/`:
- `wrapfig2-test-{1-4}.png` — original QA run images
- `wrapfig2-fixed-{1-5}.png` — post-fix images (Test 4b workaround)
- `wrapstuff-test-{1-5}.png` — QA run images
- `floatflt-qa-{1-4}.png` — QA run images
- `wrapfig-tests/test-cutwin-{1-4}.png` — old batched run
- `wrapfig-tests/test-paracol-{1-6}.png` — old batched run

GitHub raw URLs (verified working):
```
https://raw.githubusercontent.com/sudo-aza/swarm/main/download/wrapfig2-test-1.png
https://raw.githubusercontent.com/sudo-aza/swarm/main/download/wrapstuff-test-4.png
https://raw.githubusercontent.com/sudo-aza/swarm/main/download/floatflt-qa-1.png
https://raw.githubusercontent.com/sudo-aza/swarm/main/download/wrapfig-tests/test-cutwin-1.png
https://raw.githubusercontent.com/sudo-aza/swarm/main/download/wrapfig-tests/test-paracol-1.png
```

## Status

- **QA verified**: wrapfig2 (#61 FAIL), wrapstuff (#62 FAIL), floatflt (#67 FAIL), picinpar (#69 FAIL — test quality, not package), cutwin (#68 FAIL — itemize overflow).
- **Not QA'd**: paracol (no QA task created), insbox/shapepar/figflow (compilation failures).
- **Gatekeeper task #60**: If ALL packages fail all 3 hard constraints, activate custom LuaLaTeX implementation.
