# BLACKBOARD — Multi-Agent Collaboration

> **Project**: All-in-One LaTeX Helper (theme + scripts + Lua tooling)
> **Repo**: https://github.com/sudo-aza/swarm
> **Agents**: Researcher, Programmer, Quality Assurance
> **Last updated**: 2026-05-14

---

## Communication Log

| Date | Agent | Message |
|------|-------|---------|
| 2026-05-14 | Researcher | Project initialized. Repo cloned, folder structure created, initial todos added. Kickoff! |

---

## TODO

### Active Tasks

| # | Task | Assigned To | Status | Priority | Notes |
|---|------|-------------|--------|----------|-------|
| 1 | Research best-in-class LaTeX themes (Beamer, article, book) and their defaults | Researcher | ✅ Done | High | See notes/2026-05-14-research.md |
| 2 | Research LuaLaTeX performance measurement libraries and techniques | Researcher | ✅ Done | High | See notes/2026-05-14-research.md |
| 3 | Research portable LaTeX distributions (TeX Live, MiKTeX portable) | Researcher | ✅ Done | High | See notes/2026-05-14-research.md |
| 4 | Create setup/install script for portable LaTeX + all needed packages | Researcher | ✅ Done | High | scripts/setup-env.sh (needs QA test on clean VM) |
| 5 | Design the "beautiful" theme — title page, typography, colors, tables | Programmer | ⬜ Pending | High | Depends on #1 research |
| 6 | Design the "performance" theme — minimal, fast compilation | Programmer | ⬜ Pending | Medium | Depends on #1 research |
| 7 | Implement syntax-highlighted code listings in both themes | Programmer | ⬜ Pending | Medium | minted vs listings vs minted+pygments |
| 8 | Create helper Python scripts (project init, compile, clean, word count) | Programmer | ⬜ Pending | Medium | |
| 9 | Create Lua scripts for doc measurement (compilation speed, size, etc.) | Programmer | ⬜ Pending | High | Depends on #2 research |
| 10 | QA review of "beautiful" theme | QA | ⬜ Pending | High | Depends on #5 |
| 11 | QA review of "performance" theme | QA | ⬜ Pending | Medium | Depends on #6 |
| 12 | QA review of all helper scripts | QA | ⬜ Pending | Medium | Depends on #8, #9 |
| 13 | QA review of setup script — test on clean VM | QA | ⬜ Pending | High | Depends on #4 |
| 14 | Create example documents showcasing both themes | Programmer | ⬜ Pending | Medium | |

### Completed Tasks

| # | Task | Assigned To | Completed | Notes |
|---|------|-------------|-----------|-------|
| — | Initialize repo structure (BLACKBOARD, journals/, notes/, scripts/) | Researcher | 2026-05-14 | Done |
| — | Create portable TeX Live setup script | Researcher | 2026-05-14 | scripts/setup-env.sh |
| — | Initial research (themes, Lua perf, portable TeX, syntax highlighting) | Researcher | 2026-05-14 | notes/2026-05-14-research.md |

---

## Research Notes (from Researcher)

### Themes
- **Beamer**: Moloch (v2.0.0+, replaces Metropolis) — actively maintained, highlighted at TUG 2024
- **Article/Book**: KOMA-Script (v3.49) — `scrartcl`, `scrbook`, `scrreprt` — replaces standard classes
- **Specialty**: Tufte-LaTeX (side notes), ModernCV (resumes)

### Key Packages (beautiful theme)
- `fontspec` + `microtype` + `unicode-math` (typography)
- `tcolorbox` (boxes, replaces mdframed) + `booktabs` (tables)
- `minted` + `tcolorbox` (code — requires `--shell-escape` + Pygments)
- `biblatex` + `biber` (bibliography), `tikz` + `pgfplots` (graphics)

### Key Packages (performance theme)
- `listings` (code — no external deps, fast)
- Minimal packages, avoid heavy TikZ, no fontspec overhead

### LuaLaTeX Performance
- Use `callback.register("stop_run", fn)` with `os.clock()` for timing
- Use `callback.register("finish_pdffile", fn)` for PDF size
- External: `texcount` for accurate word counts
- Key callbacks: start_run, stop_run, finish_pdffile, start_page_number, stop_page_number
- LuaLaTeX is ~2-5x slower than pdfLaTeX

### Portable TeX Live
- `install-tl --portable --scheme=full --no-interaction --texdir=./texlive/2025`
- Add `./texlive/2025/bin/x86_64-linux` to PATH
- See `scripts/setup-env.sh` for full automated setup

> Full details in `notes/2026-05-14-research.md`

---

## Agent Journals

- `journals/researcher/` — Researcher's daily journal
- `journals/programmer/` — Programmer's daily journal
- `journals/qa/` — QA's daily journal

---

## Shared Notes

- `notes/` — Shared notes, references, snippets
