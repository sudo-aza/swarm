---
Task ID: 1
Agent: Programmer (main)
Task: Fix v3.45 shipout filter — replace glue-stretch with node.hpack (Task #199 follow-up)

Work Log:
- Set up git credentials and pulled latest code (resolved merge conflicts)
- Read BLACKBOARD, QA journal, programmer rules, verification guide
- Analyzed QA Task #200 review: v3.45 rated 5/10 FAIL — shipout filter's glue-stretch approach doesn't reposition text glyphs
- Identified root cause: v3.45's widen_hbox() sets hbox.width + glue_set but text glyphs stay at narrow positions (same class of bug as v3.27/v3.29)
- Implemented v3.46: replaced glue-stretch with node.hpack(head, target_width, 'exactly') which actually redistributes inter-word glue and repositions glyphs
- Switched from single fig_page counter to per-page fig_pages Lua table for accurate figure detection
- Compiled 50-fig stress test: 47 pages, 0 overlaps, 0 ghost-narrowing, 1 hollow carry-over, 31 excessive narrowing
- Compiled 1000-fig stress test: 1059 pages, 0 overlaps, 3 ghost-narrowing, 3 hollow carry-over (was 27 in v3.45 — 89% reduction)
- PyMuPDF span-width check: 45/47 full-width, 2 narrow (p23 section heading, p40 active wrapping — both legitimate)
- Updated version to v3.46 in both swarmwrap.sty and swarmwrap-callback.lua

Stage Summary:
- v3.46 fixes hollow carry-over regression from 27→3 in 1000-fig test (back to v3.44 baseline)
- Ghost narrowing: 3 (same as v3.44, slight regression from v3.45's 2)
- Zero overlaps, zero caption overlaps maintained
- Per-page fig_pages table more accurate than single fig_page counter

---
Task ID: 2
Agent: QA (main)
Task: QA Turn 16 — Review v3.50 source-prevention carry-over fix (Task #205)

Work Log:
- Pulled repo: Programmer committed v3.50 (fafaba85 + cd209a1b) — three-part fix at SOURCE
- Read QA rules, BLACKBOARD, previous QA journal (Turns 4-15)
- Compiled 50-fig stress test: 46 pages, LuaHBTeX 1.24.0 confirmed
- Ran detection script on 50-fig: PERFECT (0 ghost, 0 hollow, 0 near-empty, 32 excessive narrowing artifact)
- Compiled 1000-fig stress test: 1038 pages
- Ran detection script on 1000-fig: 3 ghost narrowing (67, 332, 927), 3 hollow carry-over (same pages), 720 excessive narrowing
- PyMuPDF cross-validated ghost pages: page 67 (6 spans at 203pt), page 332 (scattered widths), page 927 (4 spans at 260pt)
- VLM visual inspection: page 41 (50-fig) has figure + carry-over narrowing (not ghost); pages 67, 332 (1000-fig) confirmed ghost; pages 67, 927 VLM false negatives
- Code review: v3.50 uses correct approach (source prevention), removed dead shipout code
- Compared all versions: v3.44 → v3.45 → v3.46 → v3.50 across 14 metrics
- Updated BLACKBOARD Tasks #204 (needs-review), #205 (done, 7/10)
- Added COMMUNICATION LOG entry
- Wrote journal entry for Turn 16

Stage Summary:
- v3.50 rated 7/10 FAIL: correct approach, regression eliminated, perfect 50-fig, but 3 ghost narrowing persist at 1000-fig scale
- v3.50 matches v3.44 quality baseline (3 ghost/hollow carry-over at 1000-fig, same root cause)
- 4th consecutive FAIL on carry-over narrowing (v3.45=5/10, v3.46=3/10, v3.50=7/10) — trend improving
- No new QA tasks created; Task #204 set to needs-review for Programmer follow-up
