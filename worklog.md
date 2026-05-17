---
Task ID: 1
Agent: QA (zai-2)
Task: Fix workflow violations flagged by zoe

Work Log:
- Read BLACKBOARD.md — identified 3 violations
- Created Task #32 (FIX: compile.py minted dirs + biber rerun) assigned to Programmer
- Marked Task #31 (self-assigned RE-REVIEW) as removed/invalid
- Updated BLACKBOARD.md with both changes, committed and pushed
- Added Session 10 to QA journal documenting the lesson
- Sent summary to Discord

Stage Summary:
- Key lesson: <10/10 always means create a FIX task. No exceptions.
- Key lesson: Never create self-assigned tasks. Each agent assigns TO others.
- Key lesson: Only review tasks explicitly assigned to QA by Programmer.
- Cron prompt should be updated with these 3 rules (external config, not in repo).

---
Task ID: benchmark-swarmperf
Agent: QA
Task: Properly benchmark swarmperf.sty vs no-theme on the same document with pdfLaTeX, with real explanation

Work Log:
- Read BLACKBOARD.md for project state and context from previous session
- Read swarmperf.sty v1.1 and demo-performance.tex to understand theme structure
- Created 3 benchmark variants in /tmp: bench-with-theme.tex, bench-no-theme.tex, bench-bare.tex
- All 3 have identical content structure (title, TOC, sections, table, code listing, math, blocks)
- bench-with-theme.tex: uses \usepackage{swarmperf} — one line
- bench-no-theme.tex: manually includes equivalent packages + formatting — functionally equivalent output
- bench-bare.tex: \documentclass{article} only, no formatting packages at all
- Ran 10 iterations x 2 passes per variant with pdfLaTeX
- Analyzed package loading differences via log file comparison
- Installed KOMA-Script, csquotes, tikzfill, pdfcol, collectbox for beauty theme comparison (but beauty bench had command name issues, skipped — previous session already measured 8.7x vs beauty)

Stage Summary:
- Results (2-pass average, 10 runs): bare=196ms, no-theme=588ms, with-theme=646ms
- swarmperf overhead vs equivalent manual setup: +58ms (~10%)
- The 58ms comes from 4 extra packages: graphicx, mathtools, placeins, calc
- Previous "5x faster with theme" was wrong: the no-theme version was broken (undefined commands, expensive quote environments)
- Reported results to zoe with full explanation
---
Task ID: 84
Agent: Programmer
Task: Fix paracol test (task #58) — re-rate Test 4, document content loss, fix test file

Work Log:
- Read BLACKBOARD.md, identified #84 as only pending Programmer task
- Read test-paracol.tex — found Test 4 uses `\lipsum[3-4]` inside multicols nested in paracol
- Installed missing packages (paracol, lipsum, multicol)
- Reduced multicols content from `\lipsum[3-4]` to `\lipsum[3][1-4]` to avoid buffer overflow
- Added CAVEAT comment in test header and diagnostic comments inside test
- Compiled with pdfLaTeX: 6 pages, 71KB, zero errors, zero overfull warnings
- Compiled with LuaLaTeX: 6 pages, 35KB, zero errors
- Verified with PyMuPDF: "Left column text after multicol." now renders in PDF
- Updated BLACKBOARD.md: marked #84 done, re-rated Test 4 in original #58 comm log, added new comm log entry
- Updated journal: journals/programmer/2026-05-16.md

Stage Summary:
- Test 4 re-rated from PASS to PARTIAL PASS in comm log
- Content loss bug fixed by reducing multicols content
- Comments added to prevent future regressions
- Both engines compile clean, PyMuPDF verification passed
---
Task ID: 1
Agent: Programmer
Task: Fix swarmwrap.sty v2.1 figure positioning (task #101)

Work Log:
- Cloned repo (VM reset), ran git config and TeX format generation
- Read programmer-rules.md and BLACKBOARD.md — identified task #101 as critical (QA #100 rated 4/10)
- Read swarmwrap.sty v2.0 and test-customwrap.tex to understand figure positioning bug
- Root cause: [t]-minipage ref point at rule bottom, so \ht=108pt extends UPWARD while text flows DOWNWARD
- First attempt: \vtop{\hbox{...}} — abandoned because \vtop preserves inner box ht/dp
- Second attempt: \raise\strutht — failed, \strutht is not a valid TeX command
- Final fix: \raise\dimexpr\ht\strutbox-\ht\swarmwrap@box\relax — lowers box so figure TOP aligns with text ascender
- Also changed line count from \dp to \ht+\dp (total box height)
- Fixed brace mismatch (extra closing brace)
- Compiled: 6 pages, zero ! errors
- PyMuPDF verified: gap_above=-2.8pt, gap_below=0.9-7.1pt on all 6 tests (within QA thresholds)
- Updated BLACKBOARD.md (task #101 done, QA task #102 created, comm log)
- Updated journal, committed, pushed

Stage Summary:
- swarmwrap.sty v2.0 → v2.1: figure now extends DOWNWARD from text start
- Key change: \raise\dimexpr\ht\strutbox-\ht\swarmwrap@box\relax replaces \raise-2pt
- Line count: \ht+\dp replaces \dp-only
- All 6 tests pass PyMuPDF QA criteria
- Commit: 1dc9921, pushed to origin/main
---
Task ID: 1
Agent: Programmer (main)
Task: Task #103 — Fix test-customwrap.tex insufficient wrapped text on pages 3-5

Work Log:
- Pulled latest from main (2f4df25)
- Read programmer-rules.md and BLACKBOARD.md
- Identified two pending Programmer tasks: #99 (page break handling) and #103 (test text fix)
- Picked #103 as the ONE task (QA-requested fix)
- Read test-customwrap.tex and swarmwrap.sty
- Fixed Test 3: Replaced \lipsum[5-8] (4 paragraphs, only first wrapped) with \lipsum[1]\lipsum[2]\lipsum[3] (single merged paragraph)
- Fixed Tests 4-5: Replaced truncated \lipsum[1][1-3] and \lipsum[1][1-4] with full \lipsum[1]
- Fixed escaped \lipsum command in Test 3 comment text (was being executed as LaTeX)
- Compiled with LuaLaTeX: 6 pages, 37KB, zero ! errors
- Verified with PyMuPDF: all tests now have adequate wrapping coverage
- Updated BLACKBOARD.md: marked #103 done, added comm log, created QA task #104
- Updated journal: journals/programmer/2026-05-17.md
- Committed and pushed: f72e613

Stage Summary:
- Task #103 completed. test-customwrap.tex now uses adequate text for all figure heights.
- QA task #104 created for re-review.
- Remaining pending Programmer task: #99 (graceful page break handling).
