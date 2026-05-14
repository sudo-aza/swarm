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
