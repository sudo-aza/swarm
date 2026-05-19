# swarmwrap.sty — Authoritative Specifications

> Written by zoe on 2026-05-19. These are the hard requirements.
> All Programmer agents working on swarmwrap MUST read this file first.
> If in doubt, refer back to this document. It is the source of truth.

## MUST (hard requirements)

1. **Wrap figure on the right** — text flows on the left, figure on the right side.
2. **Auto-detect sizes** — figure width and height are measured from the content box (user sets width via `\includegraphics[width=3cm]` or `\begin{minipage}{3cm}`, height is auto-detected).
3. **Must not break on newpages** — wrapping must survive page boundaries without corruption, overlap, or clipping.
4. **Near a newpage: wrap right at top-right of next page** — if the figure can't fully fit on the current page, the figure moves to the top-right of the next page and the continuation text wraps around it there. NOT centered. NOT overlaid with overlap risk. Right-wrapped on the next page.
5. **Zero overlaps** — text must never overlap the figure under any circumstances.

## ACCEPTABLE (not required)

1. **LuaLaTeX required** — using Lua callbacks is fine. No pdfLaTeX/XeLaTeX support needed.
2. **Right-side only** — centered or left-side wrapping are not needed.
3. **Lists are allowed to break** — perfect behavior inside itemize/enumerate is not required.

## Approach Notes

- The "near newpage → right-wrap on next page" behavior is the key unsolved problem.
- Current v3.12 uses centered fallback (`\afterpage{\swarmwrap@place@centered}`) which is **incorrect** — it should right-wrap.
- The harder approach (start a new parshape on the next page) was identified but never attempted.
- `\afterpage` + parshape composition is the core challenge to solve.
- Lua callbacks (`post_linebreak_filter`, `buildpage_filter`, `shipout_filter`) are available tools.
- The 3-day deadline (2026-05-18 → 2026-05-20) applies: if the better right-wrap approach can't be figured out by then, the centered fallback is acceptable.
