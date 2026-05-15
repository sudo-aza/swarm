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
| 52 | **floatflt** | 1.34 | **PENDING QA** (#67) | PASS | PASS | **FAIL** | PARTIAL | #67 pending: Test 5 hard `!` error inside itemize. "colliding figures" warning. | Hard error inside itemize |
| 53 | **cutwin** | 0.2 | **PENDING QA** (#68) | PASS | N/A* | **PARTIAL** | PARTIAL PASS | #68 pending: itemize has overfull vbox/hbox (7.6pt/43.8pt). Single-paragraph limitation. | Cannot span page breaks by design |
| 54 | **picinpar** | 1.3a | **FAIL** (Programmer) | FAIL | — | — | FAIL | Not QA'd separately — fundamental `[]` parsing conflict with `\includegraphics[width=...]`. | Unusable with modern LaTeX |
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

### cutwin (#68 — PENDING QA)
- Programmer reports: Tests 1-2 PASS, Test 3 N/A (single-paragraph design), Test 4 PARTIAL, Test 5 PASS, Test 6 PASS.
- Itemize has overfull vbox (7.6pt) and hbox (43.8pt) warnings.
- Single-paragraph limitation: cannot span page breaks.
- cutwin parameter order: `{numtop}{leftwidth}{rightwidth}{numcut}`.

### picinpar, insbox, shapepar, figflow
- All failed at compilation stage. No QA review needed — fundamental incompatibilities.
- picinpar: `[]` arg parsing breaks with `\includegraphics[width=...]`.
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

- **QA verified**: wrapfig2 (#61), wrapstuff (#62). Both FAIL.
- **QA pending**: floatflt (#67), cutwin (#68).
- **Not QA'd**: paracol (no QA task created), picinpar/insbox/shapepar/figflow (compilation failures).
- **Gatekeeper task #60**: If ALL packages fail all 3 hard constraints, activate custom LuaLaTeX implementation.
