
### 2026-06-02 20:03 UTC+8 — Programmer Turn (Task #296: v4.01 page-fill via enlargethispage)

**Task #296 (v4.01): Replace v4.00 centered page-fill placement with \enlargethispage approach.**

v4.00 stored deferred figures in a savebox and placed them centered on the next page. This caused 7 "no wrapping" regressions on 50-fig (43/50, 86%). The figures were correctly NOT wrapped — just centered images.

v4.01 uses a fundamentally different approach: `\enlargethispage` extends underfilled pages so the figure fits INLINE with wrapping. This keeps ALL figures wrapped. Two extension paths:

1. **Defer-to-inline extension**: When DEFER would fire AND page <90% filled, extend the page by the amount needed for the figure to fit (narrow_zone + safety - remaining + 1bs safety). Cap at 30% of pagegoal. After extension, the DEFER check re-evaluates — if the figure now fits, it wraps inline instead of being deferred.

2. **Inline underfill extension**: When the figure fits inline but the page would still be underfilled after wrapping (pagetotal + narrow_zone < 90% of pagegoal), extend to reach 90%. Same 30% cap.

v4.00 code fully removed (pf@box, pf@pending, centered placement — zero traces).

**Results**:
- demo-beautiful.tex: 7 pages, 136893 bytes, 0 errors
- test-stress-50.tex: 40 pages (was 48, -17%), 50/50 (100.0%) PASS, 0 real bugs, 49/50 wrapped (98%)
- test-stress-1000.tex: 1090 pages, 2995206 bytes, 1096/1100 (99.6%) PASS, 4 real (all pre-existing: 2 no-wrap multicols FP, 1 ghost, 1 hollow)

**Page-fill analysis** (50-fig): 0 pages <85% fill. 23 pages at 89.5% (normal bottom margin at y=753.4, page_h=841.9 — the 10.5% "empty" is page number area, not content gap). All content reaches within ~3pt of the bottom margin.

**Page-fill analysis** (1000-fig): 0 pages <85% fill. 1088 pages at ~89.5%. 0 pages <80%. No genuinely underfilled pages.

**Trade-off**: -8 pages on 50-fig (48→40) from extended pages. The extensions allow TeX to fit more content per page (figures + text), reducing total page count. Extensions are capped at 30% of pagegoal to prevent absurdly tall pages.

**Version**: v4.01 (header + ProvidesPackage + .lua header + .lua startup + wlog — all 5 locations consistent).

**QA review task**: #300. Task #296 status: needs-review (Rule 6).
