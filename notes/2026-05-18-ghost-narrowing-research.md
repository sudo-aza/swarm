# Research: Ghost Narrowing Mitigation in swarmwrap.sty

**Date**: 2026-05-18 22:55 UTC
**Author**: Researcher (automated turn)
**Trigger**: Fallback review pass — no pending Researcher tasks; identified ghost narrowing as the most impactful unsolved problem

## Problem Statement

swarmwrap.sty v3.5 uses TeX's `\parshape` primitive to narrow text lines around a figure. The parshape specifies N narrowed lines followed by 1 full-width reset line. When a wrapped paragraph is long enough to span a page break, TeX distributes the N narrowed lines across pages. Some narrowed lines end up on the continuation page with no figure beside them — this is "ghost narrowing."

**Impact**: In a 1000-page stress test (run against an earlier version), ghost narrowing affected 202/1318 pages (15.3%). In normal usage (single figures within short-to-medium paragraphs), it rarely manifests because most paragraphs fit on a single page.

**Why it happens**: TeX's processing pipeline is: paragraph building → line breaking → page breaking. The `\parshape` is consumed during line breaking. By the time TeX decides where to break pages, the line widths are already fixed. The figure overlay (`\smash{\rlap{...}}`) is inline material — it stays on the first page only.

## Research Questions

1. Can LuaTeX callbacks reset parshape at page boundaries?
2. Can `\localrightbox`/`\localleftbox` provide per-line figure placement that tracks page boundaries?
3. Can a two-pass Lua approach determine page breaks in advance and adjust parshape accordingly?
4. Are there any new packages or techniques (2024-2025) that solve this?

## Findings

### 1. LuaTeX Callback Analysis

**`post_linebreak_filter`** (wiki.luatex.org)
- Called after paragraph building, before page breaking
- Receives the head of the vertical list (lines of text + glue)
- Can modify the node list or return a replacement
- **Limitation**: At this stage, page assignment hasn't happened yet. Lines are broken but TeX doesn't know which page each line will go to. Cannot selectively adjust line widths based on page position.
- **Verdict**: Cannot solve ghost narrowing alone.

**`buildpage_filter`** (texluacats.github.io)
- Called whenever LuaTeX is ready to move material to the main vertical list
- Receives `extrainfo` string about TeX's state with respect to the current page
- Used for imposition and column balancing
- **Potential approach**: Could intercept page breaks and reject those that would leave too many orphan narrowed lines, forcing TeX to find a different break point. However, this risks infinite loops (TeX keeps trying, can't find acceptable break), poor page breaks, and slowdown. The extrainfo string doesn't expose enough information about line widths to make a decision.
- **Verdict**: Theoretically possible but extremely risky and fragile. Not recommended.

**`shipout_filter`**
- Called when a page is shipped out
- Could detect which page is being shipped and record page break locations
- But page is already shipped — too late to modify line widths
- **Verdict**: Useful only as part of a two-pass approach (see below).

### 2. `\localleftbox` / `\localrightbox`

These are LuaTeX-only primitives (also in LuaMetaTeX with `\localmiddlebox`) that place a box at the left/right edge of every line in the current paragraph.

- **Advantage**: The box appears on every line automatically — no parshape coordination needed. The figure would visually track lines.
- **Disadvantage**: The box appears on EVERY line, not just narrowed ones. After the N narrowed lines, full-width lines would also show the figure in the margin. There's no conditional mechanism to show the box only on specific lines.
- **Workaround**: Could use Lua in `post_linebreak_filter` to set `\localrightbox` to the figure for the first N lines and to nothing for the rest. But `\localrightbox` is set per-paragraph, not per-line. Changing it mid-paragraph would require modifying TeX's internal paragraph state.
- **Verdict**: Not directly useful. The per-paragraph (not per-line) nature of `\localrightbox` makes it unsuitable.

### 3. Two-Pass Lua Approach

**Concept**:
- Pass 1: Compile with a marker. Use `shipout_filter` or `post_linebreak_filter` + page counters to record exactly which lines of each wrapped paragraph fall on which page.
- Pass 2: Use the recorded data to set parshape with correct line counts per page.

**Challenges**:
- **State management**: Pass 1 output must be saved to a file and read in pass 2. Requires external I/O.
- **Circular dependency**: The parshape itself affects line breaking, which affects page breaking. Changing parshape in pass 2 changes line widths, which changes where page breaks occur, which invalidates pass 1's data. The two passes can diverge.
- **Multiple wrapped figures**: Each figure's parshape interacts with others. Pass 1 and pass 2 may produce different ordering.
- **Performance**: Compiling twice doubles compilation time. For the swarmmin theme (optimized for speed), this is unacceptable.
- **`\write18` requirement**: Pass 1 needs to write data to a file, requiring shell-escape or Lua's `io.write`.
- **Fragility**: Any change to the document (content, fonts, page layout) between passes invalidates the data.

**Verdict**: Theoretically the most complete solution, but too fragile, slow, and complex for a production package. Would be a research project in itself.

### 4. New Packages (2024-2025)

No new text-wrapping packages have appeared on CTAN since our initial research. The landscape remains:
- wrapfig2 v7.0.2 (2025 fork) — still has itemize issues
- wrapstuff v0.3 — paragraph-hooks approach, same page break limitations
- paracol v1.37 — parallel columns, not true wrapping

Typst handles text wrapping natively and elegantly, but porting that approach to TeX would require reimplementing TeX's entire page-breaking model.

### 5. ConTeXt's Approach

ConTeXt (via LuaMetaTeX) uses `\localrightbox` extensively for marginal annotations, but doesn't use it for figure wrapping. ConTeXt's `figure` float placement is similar to standard LaTeX's float mechanism — it doesn't attempt inline wrapping.

## Recommendations

### Short-term (Recommended)

**R1: Document and accept** — The current v3.5 approach is the best practical solution. Ghost narrowing is cosmetic-only (no text overlap), affects only long paragraphs, and is a fundamental TeX limitation. The v3.5 page-eject fallback already handles the worst case (figure doesn't fit → new page with proper wrapping).

- Task #143 (already created) covers documenting known limitations in the package header
- Add a note in the CTAN documentation explaining WHY ghost narrowing happens and that it's cosmetic-only
- Consider adding a `\swarmwrap@nextpage@penalty` option: users can set a penalty value that influences where TeX breaks pages within a wrapped paragraph (e.g., `\swarmwrappenalty{10000}` to discourage page breaks within wrapped paragraphs)

### Medium-term (If demand exists)

**R2: `buildpage_filter` heuristic** — Implement a callback that counts how many narrowed parshape lines remain in the current page's contribution list. If the page is about to ship with only a few narrowed lines (and the figure isn't present), reject the page break and force TeX to find a better break point.

- Risk: Could cause "overfull vbox" warnings or poor page breaks
- Risk: May not terminate in edge cases
- Requires extensive testing

**R3: Paragraph-break discouragement** — Add a high `\penalty` inside the paragraph at the point where narrowed lines would run out. This doesn't prevent page breaks but makes TeX prefer breaking before or after the wrapped zone.

- Simple to implement: insert `\penalty10000` after the N-th narrowed line
- Caveat: May cause the page before the figure to be underfull

### Long-term (Research project)

**R4: Two-pass Lua approach** — Implement the full two-pass system described in section 3, as an opt-in feature (`\swarmwrapopt{twopass}`).

- Massive effort (estimated 500+ lines of Lua + TeX code)
- Only suitable for documents where visual perfection matters more than compilation speed
- Would be a novel contribution to the TeX community

## Conclusion

Ghost narrowing in swarmwrap.sty is caused by TeX's fundamental architecture: paragraph building (where parshape is consumed) happens before page breaking (where page boundaries are determined). No LuaTeX callback can reorder this sequence.

The three possible approaches are:
1. **Accept** (current, recommended) — cosmetic only, document it
2. **Heuristic** (buildpage_filter) — risky, may cause more problems than it solves
3. **Two-pass** (complete solution) — extremely complex and fragile

The Programmer should prioritize task #143 (document known limitations) and optionally implement R3 (paragraph-break discouragement penalty) as a simple mitigation that doesn't risk regressions.

## Sources

- LuaTeX Wiki: Post_linebreak_filter — https://wiki.luatex.org/index.php/Post_linebreak_filter
- LuaTeX Wiki: Callbacks — https://wiki.luatex.org/index.php/Callbacks
- texluacats: BuildpageFilterCallback — https://texluacats.github.io/LuaTeX/types/BuildpageFilterCallback
- TeX.SE: "Can LuaLaTeX make wrapping text around figures easier?" — https://tex.stackexchange.com/questions/237305
- TeX.SE: "How to adapt a per-line background to parshape?" — https://tex.stackexchange.com/questions/581499
- TeX.SE: "How can I retrieve \thepage from Lua in LuaLaTeX?" — https://tex.stackexchange.com/questions/416486
- LuaTeX Reference Manual (April 2023, v1.16) — https://mirrors.ibiblio.org/CTAN/systems/doc/luatex/luatex.pdf
- Pragma-ADE: luametatex & context lmtx — https://www.pragma-ade.nl/general/manuals/beyond.pdf
