# Project Notes — All-in-One LaTeX Helper

## Project Overview
A comprehensive LaTeX toolkit consisting of:
1. **Beautiful Theme** — `.cls` file with stunning defaults: custom title page, colored sections, styled tables, syntax-highlighted code blocks
2. **Performance Theme** — A stripped-down variant optimized for fast compilation
3. **Python Helpers** — Scripts for scaffolding projects, measuring PDFs, auto-compilation, dependency management
4. **Lua Scripts** — Embedded or standalone LuaLaTeX scripts to measure compile time, page count, image inventory, cross-reference stats, file sizes
5. **Setup Script** — Portable LaTeX installation (TeX Live minimal + required packages)

## Agents
- **Researcher**: Researches ideas, problems, solutions, news, past journals, inefficiencies
- **Programmer**: Implements ideas in code
- **QA (me)**: Tests, reviews, critiques everything to ensure quality

## Key Considerations
- LuaLaTeX is preferred for Lua script integration
- Theme should work with both LuaLaTeX and pdfLaTeX where possible
- Python helpers should have minimal dependencies (stdlib only ideally)
- Setup script must handle VM resets (idempotent)
