# Ghost Narrowing Fix — Design and Implementation

**Date**: 2026-05-22
**Status**: IMPLEMENTED (v3.18, page-eject approach)
**Author**: Programmer agent

## Problem

When `\swarmwrapnext` wraps text around a figure using TeX's `\parshape`, the
figure is placed via `\smash{\rlap{...}}` (page-local inline material). If the
wrapped paragraph spans a page break, the `\parshape` narrowing persists across
the boundary but the figure does not. Continuation lines on the next page are
narrowed with no figure beside them — "ghost narrowing."

**Impact**: Cosmetic defect. No text overlaps the figure. Affects long paragraphs
that span page breaks. In the 50-figure stress test (42 pages), 4 ghost narrowing
instances were detected.

## Root Cause

TeX's processing pipeline: paragraph building → line breaking → page breaking.
`\parshape` is consumed during line breaking. By the time TeX decides where to
break pages, line widths are already fixed. The figure overlay is inline material
that stays on the first page only. Narrowed lines that TeX assigns to the next
page have no figure.

## Approach 1: Page-Eject (IMPLEMENTED in v3.18)

### Concept

Before placing the figure in the NORMAL path (figure fits on current page),
check whether all N narrow lines will fit on the current page. If not, eject to
a fresh page with `\newpage`. This guarantees the figure and all its narrow
lines are on the same page.

### Algorithm

```
remaining_space = \pagegoal - \pagetotal
nl_space = nl * \baselineskip
if nl_space > remaining_space - 2*\baselineskip:
    \newpage   # eject to fresh page
# Place figure and set parshape on current (possibly new) page
```

The 2-line safety margin accounts for `\parskip`, `\vspace`, and other
incidental vertical material between the check point and the actual line
breaking.

### Implementation Details

**Code location**: `\swarmwrapnext` in the `\else` (NORMAL) branch of the
DEFERRED check.

**Key design decision**: `\noindent` and `\parshape` are set AFTER the page-eject
decision, not before. In v3.17, these were set before the if/else check.
Moving them after prevents mode conflicts when `\newpage` fires in horizontal
mode.

**Trade-offs**:
- **Pro**: Simple, deterministic, no multi-pass complexity, no external files
- **Pro**: Zero ghost narrowing (4 → 0 in stress test)
- **Con**: May leave whitespace on the previous page (1 extra page in stress
  test: 42 → 43 pages)
- **Con**: The penalty at the parshape boundary (v3.6) becomes less important
  since page-eject prevents the break from happening in the first place

### Results

| Test | Pages (v3.17) | Pages (v3.18) | Ghost Narrowing |
|------|---------------|---------------|-----------------|
| test-stress-50 | 42 | 43 | 4 → 0 |
| test-customwrap | 8 | 8 | 0 → 0 |
| test-consecutive-figures | 6 | 6 | 0 → 0 |
| test-pagebreak-variations | 15 | 15 | 0 → 0 |

Detection method: PyMuPDF text block analysis. Lines starting at left margin
but narrower than full text width (minus 20pt tolerance) flagged as potential
ghost narrowing.

## Approach 2: Two-Pass (BACKUP, not implemented)

### Concept

Pass 1: Compile with markers. Use Lua callbacks to record which lines of each
wrapped paragraph fall on which page. Write page-break data to a file.

Pass 2: Read the data file. Generate per-page `\parshape` specifications that
match exactly which lines are on which page. Each page gets its own parshape
with the correct number of narrow lines.

### Advantages

- No wasted whitespace (no page ejects)
- Figure always beside exactly the right lines on each page
- Ghost narrowing truly zero (not just prevented)

### Disadvantages

- **Compilation time doubles** (Zoe approved: "compile time doesn't matter")
- **Circular dependency**: Changing parshape in pass 2 changes line widths,
  which changes page breaks, invalidating pass 1 data. Convergence not
  guaranteed.
- **Fragile**: Any content change between passes invalidates the data
- **Complexity**: Estimated 500+ lines of Lua + TeX code
- **State management**: Requires external I/O (file write/read between passes)
- **Multi-figure interaction**: Multiple wrapped figures create overlapping
  parshape scopes that complicate the per-page analysis

### Feasibility Assessment

LuaHBTeX 1.24.0 (our target) has `buildpage_filter` but NOT `shipout_filter`.
The two-pass approach would need to use `post_linebreak_filter` + page counters
to record break positions. This is feasible but the circular dependency between
parshape and page breaks makes convergence unreliable.

### When to Use

If Zoe determines the page-eject whitespace cost is unacceptable and requests
the two-pass approach, it can be implemented as an opt-in feature:
`\swarmwrapopt{twopass}`.

## Changelog

- **v3.18** (2026-05-22): Page-eject fix implemented and tested. Ghost narrowing
  4 → 0 in stress test. All 4 standard tests pass with 0 errors, 0 regressions.
