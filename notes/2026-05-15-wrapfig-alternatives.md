# Wrapfig Alternatives Research — 2026-05-15

## Source
Searched: CTAN, TeX StackExchange, TUG mailing lists, Overleaf, Google Groups

## Dedicated Text-Wrapping Packages (CTAN "text-flow" topic)

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 1 | **wrapfig** | https://ctan.org/pkg/wrapfig | ~2003 (v3.6) | The classic: `wrapfigure`/`wraptable` environments for text flowing around narrow floats at page edges |
| 2 | **wrapfig2** | https://ctan.org/pkg/wrapfig2 | 2025-03-01 (v7.0.2) | Fork of wrapfig by Claudio Beccari; backward-compatible; adds `wraptext` environment for framed text blocks. Requires LaTeX >= 2019. GitHub: https://github.com/claudio-beccari/wrapfig2 |
| 3 | **wrapstuff** | https://ctan.org/pkg/wrapstuff | ~2024 (v0.3) | Modern rewriting using LaTeX paragraph hooks (requires LaTeX >= 2021-06-01); can center figures in the wrap. Originally Chinese docs. GitHub: https://github.com/qinglee/wrapstuff |
| 4 | **floatflt** | https://ctan.org/pkg/floatflt | ~2006 (v1.34) | Successor to floatfig for LaTeX2e; `floatingfigure`/`floatingtable` environments; alternating left/right on even/odd pages |
| 5 | **floatfig** | https://ctan.org/pkg/floatfig | ~1995 | DEPRECATED. Original LaTeX 2.09 style option; superseded by floatflt |
| 6 | **picinpar** | https://ctan.org/pkg/picinpar | ~2021 (v1.3a) | Creates "windows" in paragraphs for inserting graphics (including dropped capitals); `\window`, `\windowpage`, `\tabwindow` |
| 7 | **picins** | https://ctan.org/pkg/picins | ~2006 | Legacy LaTeX 2.09 package; `\parpic` command to wrap text around picture |
| 8 | **figflow** | https://ctan.org/pkg/figflow | 2011-02-18 | Plain TeX macro `\figflow` that insets a figure into a paragraph; uses `\parshape` |
| 9 | **cutwin** | https://ctan.org/pkg/cutwin | 2021-10-13 (v0.2) | Cuts rectangular or arbitrary-shaped windows out of paragraphs; `\shapedcutout` for non-rectangular shapes. GitHub: https://github.com/LaTeX-Package-Repositories/cutwin |
| 10 | **insbox** | https://ctan.org/pkg/insbox | ~2006 (v2.2) | Generic `\parshape` bundling; `\insbox` commands to insert pictures/boxes into paragraphs |
| 11 | **shapepar** | https://ctan.org/pkg/shapepar | 2013 (v2.2) | Typesets paragraphs in specific shapes (heart, diamond, circle); includes `\cutout` for rectangular cutouts |
| 12 | **window** | https://ctan.org/pkg/window | ~1995 | LaTeX 2.09; `\windowbox` to insert boxed material at given position within paragraph |

## Document Classes with Built-in Margin/Wrap Figure Support

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 13 | **tufte-latex** | https://ctan.org/pkg/tufte-latex | ~2019 (v3.5.2) | `tufte-handout`/`tufte-book`; `marginfigure` places figures in wide margin with text alongside |
| 14 | **xtufte** | https://ctan.org/pkg/xtufte | ~2024 | Modified tufte-latex with LuaLaTeX support |

## Parallel Column Alternatives

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 15 | **paracol** | https://ctan.org/pkg/paracol | 2025-07-14 (v1.37) | Multiple columns with synchronized text flow; switch columns mid-page; figures in one column, text in other |
| 16 | **parcolumns** | https://ctan.org/pkg/parcolumns | ~2007 | Two or more parallel columns (e.g., translations) |

## Side Caption / Margin Content (indirect wrapping)

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 17 | **sidecap** | https://ctan.org/pkg/sidecap | 2023-01-24 (v1.7a) | Captions beside figures/tables; does NOT wrap text |
| 18 | **sidenotes** | https://ctan.org/pkg/sidenotes | ~2022 (v1.7d) | Notes, figures, citations, tables in margin (Tufte-like without Tufte class) |
| 19 | **sidenotesplus** | https://ctan.org/pkg/sidenotesplus | ~2024 | Labeled/referenced notes, figures, tables in margins |

## Frame-based / Layout

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 20 | **flowfram** | https://ctan.org/pkg/flowfram | 2026-02-23 (v2.1) | Text frames for posters/brochures; content flows frame-to-frame; figures in dedicated frames beside text |

## Float Control Companions

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 21 | **nonfloat** | https://ctan.org/pkg/nonfloat | ~2005 | Non-floating `figure*`/`table*`; captions without floating |
| 22 | **float** | https://ctan.org/pkg/float | ~2023 (v1.4) | `[H]` placement; custom floats |
| 23 | **floatrow** | https://ctan.org/pkg/floatrow | ~2014 (v0.3b) | Custom float layouts; `ffigtable` environments |
| 24 | **placeins** | https://ctan.org/pkg/placeins | ~2010 (v2.2) | `\FloatBarrier` to prevent floats passing a point |
| 25 | **newfloat** | https://ctan.org/pkg/newfloat | ~2022 | `\DeclareFloatingEnvironment` for new float types |
| 26 | **keyfloat** | https://ctan.org/pkg/keyfloat | ~2023 | Key/value interface for figures/tables |

## Absolute Positioning / Overlay

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 27 | **textpos** | https://ctan.org/pkg/textpos | 2022-07-23 (v1.10.1) | Boxes at absolute page positions; overlay text and figures |
| 28 | **abspos** | https://ctan.org/pkg/abspos | ~2022 | Content at absolute positions |
| 29 | **overpic** | https://ctan.org/pkg/overpic | ~2022 (v1.3) | Picture environment + `\includegraphics`; place text over images |

## Shape/Path-based Text Flow

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 30 | **pst-text** | https://ctan.org/pkg/pst-text | ~2010 (v1.02) | PSTricks; plot text along arbitrary paths (PostScript/pdfLaTeX only) |
| 31 | **textpath** | https://ctan.org/pkg/textpath | ~2010 | MetaPost; text along free path |

## Primitive / Manual Techniques

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 32 | **`\parshape` primitive** | Built into TeX | N/A | Underlying primitive used by all wrapping packages; line-by-line indentation |
| 33 | **minipage/parbox** | Built into LaTeX | N/A | Side-by-side figure + text; no actual wrapping |
| 34 | **twocolumn** | Built into LaTeX | N/A | Two-column mode |

## ConTeXt Built-ins

| # | Name | Last Updated | One-liner |
|---|------|-------------|-----------|
| 35 | **`\startfiguretext`** | N/A | ConTeXt: wrap text around figure |
| 36 | **`\placefloat`** | N/A | ConTeXt: float placement with beside-text options |
| 37 | **`\starthanging`** | N/A | ConTeXt: hanging/wrapping text around figure |

## Modified / Experimental

| # | Name | Last Updated | One-liner |
|---|------|-------------|-----------|
| 38 | **pullquote** | N/A | Experimental pull quotes with wrapping; reported buggy |
| 39 | **wrapfig (modified for page breaks)** | 2013 | User-modified wrapfig.sty fixing ugly page breaks at end of page. SE: https://tex.stackexchange.com/questions/131063/wrapfig-w-non-ugly-page-breaks |

## Related: Drop Caps

| # | Name | CTAN Link | Last Updated | One-liner |
|---|------|-----------|-------------|-----------|
| 40 | **lettrine** | https://ctan.org/pkg/lettrine | ~2022 (v2.7) | Sophisticated drop caps; wraps text around large initial letter |
| 41 | **dropcaps** | https://ctan.org/pkg/dropcaps | ~2022 | Simple drop caps |

## Most Actively Maintained (as of 2025)

| Package | Last Update | Status |
|---------|------------|--------|
| flowfram | 2026-02-23 | Active |
| paracol | 2025-07-14 | Active |
| wrapfig2 | 2025-03-01 | Active |
| wrapstuff | ~2024 | Active (open bugs) |
| sidecap | 2023-01-24 | Recent |
| textpos | 2022-07-23 | Recent |
| cutwin | 2021-10-13 | Recent |

## Key Reference URLs
- CTAN "Text flow" topic: https://ctan.org/topic/text-flow
- TeX FAQ on text flow: https://texfaq.org/FAQ-textflow
- Overleaf wrapping guide: https://www.overleaf.com/learn/latex/Wrapping_text_around_figures
- StackExchange "wrap" tag: https://tex.stackexchange.com/questions/tagged/wrap
