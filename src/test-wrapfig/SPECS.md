# swarmwrap.sty — Test Acceptance Criteria

> Authoritative specs: `notes/wrapping-specs.md`
> Full spec summary in: `BLACKBOARD.md` (top, ⋮ SWARMWRAP AUTHORITATIVE SPECS)

## MUST pass (all of these)

1. **Right-side wrap** — figure on right, text on left, correct gap (~14pt)
2. **Auto-detected sizes** — width from `\includegraphics[width=...]` or `\begin{minipage}{...}`, height auto-measured
3. **No breakage on newpages** — wrapping must survive page boundaries
4. **Near newpage → right-wrap on next page** — figure moves to top-right of next page, continuation text wraps around it there (NOT centered)
5. **Zero overlaps** — no text-figure overlap on any page

## Acceptable failures

- Inside itemize/enumerate — wrapping may not work perfectly
- Centered or left wrapping — not required

## Current status (v3.12)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Right-side wrap | PASS | NORMAL path works |
| Auto-detect sizes | PASS | width+height from savebox |
| No breakage | PARTIAL | NORMAL path OK; deferred path centers (WRONG per spec) |
| Near newpage → right-wrap | **FAIL** | Currently centers; spec requires right-wrap on next page |
| Zero overlaps | PASS | v3.11 fixed all overlaps |

## Key test files

- `test-customwrap.tex` — 6 tests: standard wrapping, left wrap (removed), page break, tall figure, near-bottom, narrow
- `test-pagebreak-variations.tex` — 8 scenarios: 300pt down to 30pt remaining space
- `test-stress-1000.tex` — dense stress test: 1000 figures, catches edge cases
