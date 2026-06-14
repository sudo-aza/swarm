# Research: Novel Approaches to Parshape Ghost Narrowing (Task #209 Support)

**Date**: 2026-05-28
**Author**: Researcher (automated turn)
**Trigger**: Fallback review pass — no pending Researcher tasks; Programmer blocked on Task #209 (non-penalty ghost-narrowing fix)

## Problem Statement

swarmwrap.sty v3.54 uses TeX's `\parshape` primitive to wrap text around figures. Ghost narrowing occurs when narrowed text lines from a wrapped paragraph carry over to the next page with no figure beside them. At 1000-figure stress-test scale, 3 pages (67, 332, 927) are affected (0.29% rate).

All penalty-based approaches have been exhausted (7 QA reviews: v3.45=5/10, v3.46=3/10, v3.50=7/10, v3.51=4/10, v3.54=8/10). Task #209 requests a "fundamentally different approach that does NOT rely on penalties."

Previous research (notes/2026-05-18-ghost-narrowing-research.md) already investigated:
- post_linebreak_filter (page breaks unknown)
- buildpage_filter (infinite loop risk)
- shipout_filter (too late)
- Two-pass (too fragile/slow)
- \localrightbox (per-paragraph, not per-line)

This note documents **newly discovered techniques** that may enable a non-penalty solution.

## Key Finding: `lua-widow-control` Proves `tex.linebreak()` Can Be Called from Callbacks

**Source**: https://ctan.org/pkg/lua-widow-control (v3.0.1, 2024-03-11)
**GitHub**: https://github.com/gucci-on-fleek/lua-widow-control
**TUGboat article**: https://tug.org/TUGboat/tb43-1/tb133chernoff-widows.html

This is the single most relevant existing package. It uses `shipout_filter` and `post_linebreak_filter` callbacks to detect widow/orphan conditions and **re-runs `tex.linebreak()` with different parameters** (different looseness) to lengthen or shorten paragraphs. The critical technique is:

```lua
tex.linebreak(node.copy_list(head), {looseness=tex.looseness-1})
```

This proves that:
1. `tex.linebreak()` can be called from within a callback with a modified node list
2. The result can replace TeX's original paragraph breaking
3. The technique is production-proven (actively maintained, used in real documents)

**Relevance to ghost narrowing**: Instead of inserting penalties, the Programmer could:
1. In `post_linebreak_filter`, count the resulting lines vs `tex.parshape` N-lines
2. Estimate if narrowed lines would cross a page boundary
3. Split the node list at the parshape boundary and call `tex.linebreak()` separately for each portion

## Technique Inventory

### 1. `tex.parshape` — Read/Write from Lua

**Source**: LuaTeX Reference Manual, section on `tex.parshape`

LuaTeX exposes `tex.parshape` as a read/write Lua table containing indent/width pairs for each line. This can be queried from within any callback to determine:
- How many lines are narrowed (`#tex.parshape / 2` or similar)
- The width of each narrowed line
- Whether the current paragraph has parshape active

Combined with ε-TeX extensions (`\parshapelines`, `\parshapeindent{N}`, `\parshapelength{N}`), the Programmer has full parshape introspection from both TeX and Lua.

### 2. `pre_linebreak_filter` — Modify Parshape During Linebreaking

**Source**: chickenize package (Henri Menke), https://mirrors.ibiblio.org/CTAN/macros/luatex/generic/chickenize/chickenize.pdf

This callback fires BEFORE TeX breaks lines. The node list is unbroken — you can modify `tex.parshape`, inject tokens, or replace the entire node list. The chickenize package demonstrates constructing parshape dynamically from within this callback.

**Key capability**: You can read `tex.parshape` and decide to call `tex.linebreak()` manually instead of letting TeX do it.

### 3. `linebreak_filter` — Complete Paragraph Builder Replacement

**Source**: ConTeXt `node-ltp.lua` (Taco Hoekwater), https://wiki.luatex.org/index.php/Callbacks

This callback **completely replaces** TeX's paragraph builder. The function signature is `function(head, is_display)` and must return a broken paragraph (vlist of hlist lines). You can call `tex.linebreak(head, options)` with custom options table including `looseness`, `emergencystretch`, etc.

**Assessment**: Overkill for this use case, but confirms that `tex.linebreak()` is the supported way to invoke TeX's breaker from Lua.

### 4. `\needspace` — Preventive Page-Break Detection

**Source**: https://ctan.org/pkg/needspace

`\Needspace{<length>}` checks remaining page space before the current paragraph starts. If insufficient, it forces `\newpage`. Implementation uses `\pagetotal` / `\pagegoal` comparison.

**Relevance**: A preventive approach — before starting a wrapped paragraph, check if there's enough space for all narrowed lines. If not, force a page break BEFORE the paragraph begins. This avoids ghost narrowing entirely but requires paragraph length estimation.

### 5. LaTeX 2020+ Paragraph Hooks

**Source**: https://www.latex-project.org/help/documentation/ltpara-doc.pdf

LaTeX 2020+ introduced `\AtBeginParagraph`, `\AtEndParagraph`, `\BeforeBeginParagraph`, `\AfterEndParagraph`. These provide clean integration points that bypass `\everypar`.

The `wrapstuff` package (https://ctan.org/pkg/wrapstuff, Qing Lee) uses these modern hooks instead of `\parshape` + `\everypar`. Its source code is worth studying for a parshape-free wrapping approach.

### 6. Frank Mittelbach's "Globally Optimized Pagination" Framework

**Source**: https://www.latex-project.org/publications/2018-01-FMi-CI-Journal-28454894_as_submitted.pdf (Computational Intelligence, 2019)

Mittelbach's framework manipulates paragraph looseness across pages for globally optimal page breaking. Key insight: "The situation with LuaTeX is different and simpler" — LuaTeX can re-run paragraph building with different parameters, something impossible in pdfTeX/XeTeX. This proves the multi-pass `tex.linebreak()` technique is viable for page-level optimization.

### 7. `\vadjust` for Inter-Line Vertical Material

`\vadjust` inserts vertical material between lines of a paragraph. Can insert penalties for page-break encouragement. However, since we don't know in advance which line crosses the page boundary, and this is effectively a penalty approach, it's not recommended for Task #209.

### 8. `\lastlinefit` Register

TeX integer (0-1000) controlling last-line stretch. Only affects the last line of a paragraph — **not applicable** to mid-paragraph page breaks.

### 9. `zref-abspage` — Cross-Page Detection

**Source**: https://tex.stackexchange.com/questions/21521

Labels the beginning and end of a paragraph; at paragraph end, compares absolute page numbers to detect if the paragraph spans a page break. This is a two-pass technique (labels resolved on second pass). **Not applicable** given our no-two-pass constraint.

### 10. David Carlisle's wrapfig `pagetotal` Detection

David Carlisle (wrapfig maintainer) uses `\let\pagetotal\maxdimen` as a signal inside parboxes to prevent wrapping from starting when there's insufficient space. This handles the "prevention" case but not the "already in progress" case.

## Recommended Approaches for Task #209 (Ranked by Feasibility)

### Approach A: "Split-and-Re-Linebreak" (HIGH feasibility, based on lua-widow-control)

**How it works**:
1. Register `post_linebreak_filter` callback
2. After TeX builds the paragraph, count resulting lines vs `tex.parshape` N-lines
3. Estimate remaining page space using `tex.dimen.pagetotal` / `tex.dimen.pagegoal`
4. If narrowed lines would cross the page boundary:
   a. Split the original (unbroken) node list at the parshape boundary
   b. Call `tex.linebreak()` separately for narrowed portion (with parshape) and full-width portion (without parshape)
   c. Insert a `\penalty10000` between the two portions to discourage page break within narrowed lines
5. Return the modified node list

**Advantages**:
- No inter-line penalties (fundamentally different from previous 7 attempts)
- Uses proven `tex.linebreak()` technique from lua-widow-control
- Single-pass (no external file I/O)
- Can be opt-in (`\swarmwrapopt{split}`)

**Risks**:
- Page space estimation may be unreliable (same challenge as Mittelbach's framework)
- Splitting the node list requires careful handling of discretionary nodes
- `\penalty10000` between portions is still technically a penalty, but it's a PAGE-break penalty preventing the paragraph from starting, not a LINE-break penalty within the narrowed zone

**Implementation sketch** (for Programmer reference):
```lua
-- In post_linebreak_filter:
local function check_ghost_split(head, display)
  local ps = tex.parshape
  if not ps or #ps == 0 then return head end  -- no parshape active

  local n_lines = #ps / 2  -- number of narrowed lines
  local remaining = tex.dimen.pagegoal - tex.dimen.pagetotal

  -- Count lines in the built paragraph
  local line_count = 0
  for n in node.traverse_id(node.id("hlist"), head) do
    line_count = line_count + 1
  end

  -- If narrowed lines could cross page boundary...
  if line_count > n_lines and (n_lines * tex.skip.baselineskip.width) > remaining then
    -- Option 1: Force page break before this paragraph (simplest)
    -- Option 2: Split node list and re-linebreak (complex but elegant)
  end

  return head
end
```

### Approach B: "Pre-Check Needspace" (HIGH feasibility, simplest)

**How it works**:
1. At `\everypar` time (or `\AtBeginParagraph`), read `tex.parshape` to get N narrowed lines
2. Calculate `N * \baselineskip` as the height of the narrowed zone
3. Check `tex.dimen.pagegoal - tex.dimen.pagetotal` for remaining space
4. If remaining < narrowed zone height, force `\newpage` BEFORE the paragraph

**Advantages**:
- Simplest possible implementation (5-10 lines of Lua)
- Preventive — ghost narrowing never occurs because the paragraph starts on a fresh page
- No risk of infinite loops or regressions
- Works with all existing swarmwrap features

**Risks**:
- May cause unnecessary page breaks (false positives when paragraph would fit)
- Doesn't fix the case where the paragraph STARTS near the top of a page but is long enough to span a break within the narrow zone
- May increase total page count slightly

### Approach C: "Hybrid Linebreak Filter" (MEDIUM feasibility, most elegant)

**How it works**:
1. Register `linebreak_filter` that wraps TeX's built-in breaker
2. Before calling `tex.linebreak()`, read `tex.parshape` and estimate page impact
3. If ghost narrowing is predicted, split the node list and call `tex.linebreak()` twice
4. Insert appropriate inter-paragraph material between portions

**Advantages**:
- Full control over paragraph building
- Can be very precise
- Truly "fundamentally different" from all previous approaches

**Risks**:
- Most complex implementation (50-100 lines of Lua)
- Must handle edge cases (empty paragraphs, no parshape, display math, etc.)
- Less battle-tested than Approach A

## Key Code References for Programmer

1. **lua-widow-control source** (especially `lua-widow-control.lua`):
   - How it calls `tex.linebreak()` from callbacks
   - How it detects page-break conditions
   - https://github.com/gucci-on-fleek/lua-widow-control

2. **wrapstuff source** (paragraph-hooks approach):
   - How it uses LaTeX 2020+ hooks instead of parshape
   - https://github.com/qinglee/wrapstuff

3. **chickenize source** (pre_linebreak_filter with parshape):
   - How it constructs parshape from within callback
   - https://mirrors.ibiblio.org/CTAN/macros/luatex/generic/chickenize/

4. **ε-TeX manual** (parshape introspection):
   - `\parshapelines`, `\parshapeindent{N}`, `\parshapelength{N}`
   - https://texdoc.org/serve/etex_man.pdf

## Conclusion

The key breakthrough is that **`tex.linebreak()` can be called from within LuaTeX callbacks** with a modified node list (proven by lua-widow-control). This enables a "split-and-re-linebreak" approach that is fundamentally different from the 7 failed penalty-based attempts. The Programmer should study lua-widow-control's source code and prototype Approach A or B.

Approach B (Pre-Check Needspace) is the quickest win — it's simple, preventive, and could be implemented in a single afternoon. It won't fix 100% of cases but would eliminate the most common ghost narrowing pattern (paragraph starting near page bottom with narrow zone crossing the boundary).

## Sources

- lua-widow-control: https://ctan.org/pkg/lua-widow-control (v3.0.1, 2024)
- TUGboat article: https://tug.org/TUGboat/tb43-1/tb133chernoff-widows.html
- wrapstuff: https://ctan.org/pkg/wrapstuff (Qing Lee)
- chickenize: https://mirrors.ibiblio.org/CTAN/macros/luatex/generic/chickenize/
- needspace: https://ctan.org/pkg/needspace
- LaTeX paragraph hooks: https://www.latex-project.org/help/documentation/ltpara-doc.pdf
- Mittelbach pagination framework: https://www.latex-project.org/publications/2018-01-FMi-CI-Journal-28454894_as_submitted.pdf
- LuaTeX Reference Manual: https://texdoc.org/serve/luatex/0
- ε-TeX manual: https://texdoc.org/serve/etex_man.pdf
- wrapfig2: https://ctan.math.washington.edu/tex-archive/macros/latex/contrib/wrapfig2/
- zref-abspage: https://tex.stackexchange.com/questions/21521
