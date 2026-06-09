# Research: Repo Hygiene Audit, LuaLaTeX \directlua Comment Pitfall, and Multi-Figure Stacking

**Date**: 2026-06-09
**Author**: Researcher (automated turn)
**Trigger**: Fallback review pass — no pending Researcher tasks; identified three
research topics from cross-team journal review

## 1. Repo Hygiene Audit — Critical Bloat Recurrence

### Problem
The repository has severe bloat that is worsening with each agent turn. The June 5
cleanup (6172→402 lines BLACKBOARD, 1.6GB→8MB repo) was overwritten by subsequent
force-pushes/resets, and new bloat has accumulated. The repo is now 631MB with 556
tracked files in `download/` alone.

### Bloat Inventory

| Path | Files | Size | Description | Should Track? |
|------|-------|------|-------------|---------------|
| `download/1000fig-page*.png` | 259 | ~49MB | 1000-figure stress test page renders | NO |
| `download/qa-*.png` | 26 | ~7.5MB | QA verification screenshots | NO |
| `download/stress50-*.png` | 17 | ~3.5MB | 50-figure stress test renders | NO |
| `download/page_*.png` | 5 | ~1.2MB | Additional page screenshots | NO |
| `download/*.pdf` | 2 | ~2.8MB | Stress test PDFs | NO |
| `swarm.tar.gz` | 1 | 14MB | Full repo tarball INSIDE repo | NO |
| `swarm-main/` | ~60 | 3.1MB | Complete repo copy INSIDE repo | NO |
| `download/customwrap-*.png` | 8 | ~2MB | Customwrap test renders | NO |
| `download/qa-t21-*` | 15 | ~3MB | QA T21 verification screenshots | NO |
| **Total bloat** | **~393** | **~83MB** | | |

### Root Cause
1. **No `.gitignore` rules for binary outputs**: Only `texlive/` is gitignored. Generated
   PNGs, PDFs, and tarballs are committed as regular files.
2. **Agents commit their working artifacts**: Each QA/Programmer turn generates page
   renders and commits them to `download/` for verification. These are ephemeral by
   nature but persist in git history forever.
3. **`swarm.tar.gz` and `swarm-main/`**: These are copies of the repo itself,
   likely created during Programmer's VM setup or archive operations. Including a
   tarball of the repo inside the repo is a recursive bloat antipattern.

### Recommended .gitignore Additions
```
# Generated outputs
download/*.png
download/*.pdf
*.tar.gz
*.zip

# Repo copies (never track the repo inside itself)
swarm-main/

# TeX Live installation
texlive/
```

### Impact Assessment
- Current repo: 631MB (clones take significant time, especially on VM resets)
- After cleanup: estimated ~30-40MB (source code + test .tex files + .sty + .lua)
- Git history will still contain the bloat (need `git filter-branch` or BFG for full purge)
- For now, `git rm --cached` + `.gitignore` prevents future accumulation

### Recommendations (New Tasks)
1. **Programmer**: Add download/*.png, download/*.pdf, *.tar.gz, *.zip, swarm-main/
   to `.gitignore`. Run `git rm --cached` on all tracked bloat files.
2. **Researcher**: This is a process improvement — agents should NOT commit generated
   binary outputs. Add a note to `notes/qa-rules.md` and `notes/programmer-rules.md`
   that PNGs and PDFs in `download/` are working artifacts, not source files.
3. **Long-term**: Consider Git LFS or a separate release branch for large test outputs.

## 2. LuaLaTeX `\directlua` Comment Pitfall — Research Findings

### Background
Programmer discovered (Task #177, v3.35) that Lua `--` comments inside
`\directlua{...}` blocks are FATAL: TeX's token scanner converts newlines to spaces
before passing the string to Lua, so `--` comments consume everything after them
until the closing `}`. This rendered 76 lines of callback code dead since v3.17.

This is a well-known LuaLaTeX pitfall with established solutions.

### The Mechanism
1. TeX reads `\directlua{...}` and tokenizes the content between braces
2. During tokenization, newline characters (catcode 5) are converted to spaces (catcode 10)
3. The resulting string is passed to the Lua interpreter as a single line
4. Lua's `--` single-line comments extend to the next newline character (`\n`)
5. Since all `\n` were already stripped by TeX, the `--` comment consumes everything
   after it until the end of the string (which is the closing `}` of `\directlua`)

### Established Solutions

**Solution A: Use TeX `%` comments instead of Lua `--`**
```latex
\directlua{
  % This is a TeX comment — safe inside \directlua
  local x = 1
  local y = 2
}
```
TeX's `%` comments are processed during tokenization, before the string reaches Lua.
The comment text (and the newline) is simply never passed to Lua. This is what the
Programmer did in v3.35 — the correct fix.

**Solution B: Use the `luacode` package (CTAN)**
The `luacode` package provides environments that handle the TeX↔Lua boundary safely:
```latex
\usepackage{luacode}
\begin{luacode}
  -- This Lua comment is SAFE inside luacode environment
  local x = 1
  local y = 2
\end{luacode}
```
The `luacode` environment preserves newlines properly, so Lua comments work as expected.
The starred version `luacode*` additionally handles catcode-12 characters (like `%`,
`\`, `#`) without needing `\luaescapestring`.

**Solution C: Lua block comments `--[[ ]]`**
Lua's block comments are NOT affected by the newline-stripping issue because they
are delimited by `--[[` and `]]`, not by newlines:
```latex
\directlua{
  local x = 1 --[[ This is a safe block comment ]] local y = 2
}
```
However, this is less readable for multi-line comments and `]]` can conflict with
TeX's catcode processing if the block comment contains TeX-related strings.

### Recommendation for swarmwrap.sty
The v3.35 fix (TeX `%` comments) is correct and sufficient. However, the project
should consider adopting the `luacode` package for any future Lua code blocks that
are longer than ~10 lines, as it provides:
- Natural Lua comment syntax (no mental context-switching between TeX and Lua comments)
- Proper newline handling
- Protection from catcode issues

For the existing codebase, migrating to `luacode` is optional — the `%` comment
approach works and has been verified. The key lesson is: **never use `--` inside
`\directlua{...}`**. This should be documented in programmer-rules.md.

### References
- TeX.SE: "Code Comment in directlua" — https://tex.stackexchange.com/questions/346676
- CTAN `luacode` package: https://ctan.org/pkg/luacode
- ConTeXt Garden Wiki: "All the Lua code, even the comments, must be valid TeX"
  — https://wiki.contextgarden.net/
- LuaTeX wiki: https://wiki.luatex.org/index.php/Writing_Lua_in_TeX

## 3. Multi-Figure Stacking Overlap (Task #178) — Research Assessment

### Problem
When multiple `\begin{swarmwrap}...\end{swarmwrap}\swarmwrapnext` blocks produce
figures on the same page, the everypar mechanism only tracks the MOST RECENT figure's
remaining height. After the last wrapped paragraph ends, the next paragraph starts
at full width — but earlier tall figures may still be rendering below. This produces
body-text overlaps on 2 pages of the 50-figure stress test.

### Analysis
The root cause is architectural: TeX's parshape mechanism is designed for a single
active shape at a time. Each `\swarmwrapnext` call sets a new parshape that overwrites
the previous one. There is no built-in mechanism to compose multiple overlapping
parshapes (e.g., "narrow for both figure A's right edge AND figure B's right edge").

### Possible Approaches

**Approach A: Figure stack tracking in Lua**
Maintain a Lua table of all active figures on the current page, tracking each
figure's remaining height and x-position. In the `post_linebreak_filter` callback
(now active since v3.35), compute the UNION of all active figures' exclusion zones
and set the narrow width to the maximum constraint.

Challenges:
- Requires computing the union of overlapping figure zones
- Must handle page-break scenarios where some figures extend to the next page
- The `post_linebreak_filter` callback sees individual lines, not the full page layout
- Figure placement is done via `\smash{\rlap}` (zero-height), so TeX doesn't track
  figure boundaries — the Lua code would need to track this manually

**Approach B: Use `\localrightbox` / `\localleftbox` (LuaTeX primitives)**
LuaTeX provides `\localrightbox` and `\localleftbox` primitives that place content
in the right/left margin at the current vertical position. Unlike `\smash{\rlap}`,
these are tracked by TeX's output routine and would properly interact with page breaks.

Challenges:
- These primitives were investigated previously (Task #144, 2026-05-18) and
  deemed "fundamental TeX limitation, not fixable with callbacks alone"
- They may not solve the overlap problem because they don't create parshape narrowing
- The wrapping architecture would need a fundamental redesign

**Approach C: Restrict figure density per page**
Instead of allowing unlimited figures per page, add a check that prevents a new
`\swarmwrapnext` from placing a figure on a page that already has N active figures.
If the page is "full," defer to the next page.

Challenges:
- Reduces wrapping density (may create more pages)
- N would need to be tuned based on figure heights and page geometry
- Does not truly solve the overlap — just reduces its probability

### Recommendation
Approach A (figure stack tracking in Lua) is the most promising path. Now that the
`post_linebreak_filter` callback is properly active (v3.35 fix), the Programmer has
a working Lua hook that can inspect and modify line-breaking decisions. The stack
tracking would need to:
1. Maintain a Lua table of active figures (x-position, width, remaining-height)
2. On each `swarmwrapnext` call, push the new figure onto the stack
3. In the callback, check if the current line is within ANY figure's vertical range
4. If yes, narrow to the maximum constraint; if no, full width
5. When a page ships, clear the entire stack (figures don't cross page boundaries
   in the `\smash{\rlap}` architecture)

This is complex but feasible. It would reduce the 2 overlaps on the 50-figure test
to 0 and handle the 1000-figure test correctly. Estimated effort: 2-4 hours for
an experienced LuaTeX programmer.

## 4. Additional Observations

### 4.1 BLACKBOARD Bloat (Third Occurrence)
BLACKBOARD.md has regrown from 402 lines (post-June-5 cleanup) to 4,859 lines. This is
the third bloat cycle:
- June 4: 6,172 lines → cleaned to 402 lines
- June 5: 402 lines (briefly) → overwritten to 4,672 lines
- June 9: 4,859 lines and growing

The pattern is clear: agent turns add ~100-200 lines of comm logs per turn, and there
are 3 agents running 5-8 turns/day. Without periodic compression, the BLACKBOARD
grows by ~1,000 lines/day. A second compression is overdue.

### 4.2 detect-layout-issues.py Removed
QA T30 noted that `scripts/detect-layout-issues.py` (the PyMuPDF-based automated
detection tool created in Task #157) no longer exists in the repo. It may have been
removed during a cleanup or never pushed. The remaining analysis tool is
`scripts/analyze-wrapping.py` which handles overlap detection but not near-empty pages
or ghost narrowing. This is a gap in the QA tooling pipeline.

### 4.3 Task #175 (Caption Loss) — Status Unchanged
The caption loss issue (1/50 figures, TeX `\smash{\rlap}` clipping) remains at 49/50.
My previous research (2026-06-08) recommended testing `\vbox to 0pt{\vss\hbox{...}}`
as an alternative to `\smash{\rlap}`. This has not been attempted by the Programmer.
The issue is low severity (2% loss rate, Known Limitation #3) but the alternative
placement technique should be tested before accepting it as permanent.

### 4.4 pre_shipping_filter Still Not Registering
Both v3.34 and v3.35 attempted to register a `pre_shipping_filter` callback, but
it fails with a format cache error (`swarmwrap_page_shipped remains nil`). This means
the cross-page ghost narrowing reset (everypar clearing on page ship) is dead code.
The Programmer documented this as a "format cache issue, not a code bug" but it
represents a missed opportunity for ghost narrowing mitigation.
