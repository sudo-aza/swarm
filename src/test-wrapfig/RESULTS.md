# Wrap Figure Package Test Results — 2026-05-15

## Summary

Tested 9 text-wrapping packages for LaTeX. Each was tested with:
- Basic wrapping (figure beside text)
- Near page break
- Inside list environments (itemize)
- Left/right alignment

**Compiler**: pdfLaTeX (TeX Live 2026)
**Test image**: 200x150px PNG

## Results

| # | Package | Version | Compile | Basic | Page Break | In List | Notes |
|---|---------|---------|---------|-------|------------|---------|-------|
| 50 | **wrapfig2** | — | UNAVAILABLE | — | — | — | GitHub repo returns 404, not on CTAN. Cannot test. |
| 51 | **wrapstuff** | 0.3 | PASS | PASS | PASS | PASS* | Modern, uses paragraph hooks. API: key-value `\begin{wrapstuff}[width=0.3\textwidth, r]`. Requires LaTeX >= 2021. Centered wrapping unique feature. *Itemize: works but figure may overlap items. |
| 52 | **floatflt** | 1.34 | PASS | PASS | PASS | PASS | Simple API: `\begin{floatingfigure}[r]{width}`. Auto-alters left/right on even/odd pages. |
| 53 | **cutwin** | 0.2 | PASS | PASS | PASS | PASS* | Cuts rectangular/arbitrary-shaped windows. API unusual: `\begin{cutout}{overlap}{lines-left}{width}{text-lines}`. *In lists: works but placement less predictable. |
| 54 | **picinpar** | 1.3a | FAIL | FAIL | — | — | `\window` reads all args from `[]`, so nested `[]` from `\includegraphics[width=...]` breaks parsing. FUNDAMENTAL FLAW for modern use. |
| 55 | **insbox** | 2.2 | FAIL | FAIL | — | — | `\includegraphics` file path `(test-image.png)` breaks dimension parsing in `\@@InsertBox`. Works with plain `\fbox` text but fails with actual images. |
| 56 | **figflow** | — | SKIP | — | — | — | Plain TeX only — "does not work with LaTeX" per CTAN docs. |
| 57 | **shapepar** | 2.2 | FAIL | FAIL | — | — | `\cutout` syntax very complex. Offset calculations (`\dimexpr\linewidth-3cm\relax`) cause "not valid" errors. Designed for decorative shapes, not practical figure wrapping. |
| 58 | **paracol** | 1.37 | PASS | N/A | PASS | PASS | Different approach: parallel columns, not true wrapping. Good for side-by-side content. Supports synchronized page breaks. Well-maintained (2025). |

## Recommendations

### Best for figure wrapping: **wrapstuff** (if LaTeX >= 2021) or **wrapfig** (classic)
- wrapstuff: modern, centered figures, works in lists (mostly)
- wrapfig: most widely used, stable, good documentation

### Good alternative: **floatflt**
- Simple, well-tested, handles page breaks

### For non-wrapping alternatives: **paracol**
- Parallel columns, not wrapping, but solves similar layout problems
- Well-maintained, feature-rich

### Do NOT use: picinpar, insbox, shapepar, figflow
- picinpar: `[]` arg parsing conflicts with modern packages
- insbox: dimension parsing broken with `\includegraphics`
- shapepar: not designed for figure wrapping
- figflow: plain TeX only

## Test Files

All test files are in `src/test-wrapfig/`:
- `test-image.png` — test image
- `test-wrapfig.tex` — wrapfig test (PASS)
- `test-wrapstuff.tex` — wrapstuff test (PASS)
- `test-floatflt.tex` — floatflt test (PASS)
- `test-cutwin.tex` — cutwin test (PASS)
- `test-paracol.tex` — paracol test (PASS)
- `test-picinpar.tex` — picinpar test (FAIL)
- `test-insbox.tex` — insbox test (FAIL)
- `test-shapepar.tex` — shapepar test (FAIL)

Compiled PDFs available for PASS tests.

## Packages Installed

Added to setup.sh's tlmgr install list: wrapfig, wrapstuff, floatflt, picinpar,
insbox, figflow, cutwin, shapepar, paracol, lipsum
