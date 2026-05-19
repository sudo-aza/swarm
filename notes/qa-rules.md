# QA Agent Rules — MANDATORY

> These rules override any conflicting instructions. Read this file at the start of every cron turn. Violation is a failure.

## Rule 1: Only 10/10 is a Pass

- A rating of **10/10** = PASS. Mark task done. Log approval. Send images if visual output.
- A rating of **9/10 or below** = FAIL. Mark the QA task done, and create a NEW fix task assigned to whoever created the deliverable with status `pending`. Describe exactly what needs to be fixed.
- There is no such thing as "good enough" or "acceptable with deductions." 9/10 is a fail. Period.

## Rule 2: Send Images for 10/10 Visual Deliverables

- If the deliverable you reviewed is a **10/10** AND it produces visual output (PDF, image, rendered LaTeX):
  - Compile or generate the visual output.
  - Convert to PNG (pdftoppm, convert, pdf2image, etc.).
  - Save to `/home/z/my-project/swarm/download/`.
  - Send the image(s) to zoe via `send_message` with a brief description.
  - **MUST include GitHub raw URLs** to the images in the repo. Format: `https://raw.githubusercontent.com/sudo-aza/swarm/main/download/<path>/<file>.png`
  - **CRITICAL (zoe directive 2026-05-19)**: `.gitignore` contains `*.pdf`, so PDFs are NEVER pushed to GitHub. NEVER send GitHub raw URLs for PDFs — they will always 404. Instead, send PDFs as **file attachments** via `send_message` (`media` parameter). PNGs are NOT gitignored and CAN be linked via GitHub raw URLs.
- If the deliverable is NOT 10/10, do NOT send any images. Only send critique via BLACKBOARD.

## Rule 2.5: TeX Live MUST Be Available — Install It If Missing

- TeX Live is at `/home/z/my-project/swarm/texlive/`. Add to PATH: `export PATH="/home/z/my-project/swarm/texlive/bin/x86_64-linux:$PATH"`.
- If `pdflatex` is not found on PATH, run the setup script to install TeX Live: `bash /home/z/my-project/swarm/scripts/setup.sh`.
- **NEVER skip compilation because LaTeX is "not installed."** Always install it first.
- **NEVER rate a visual deliverable (e.g., a .tex test) without actually compiling it.** Code-level-only review is insufficient for visual tests.
- If TeX Live was missing and you had to install it, note this in the COMMUNICATION LOG.

## Rule 2.6: Mandatory Engine Verification — ALWAYS Check the Log

- **BEFORE analyzing any PDF output or claiming any results**, QA MUST verify the compilation engine matches package requirements.
- Run `head -3 <logfile>` on the compilation log and confirm the engine string (e.g., `LuaHBTeX` for LuaLaTeX, `pdfTeX` for pdfLaTeX, `XeTeX` for XeLaTeX).
- **Known package requirements**: `swarmwrap.sty` requires **LuaLaTeX** — compiling with pdfLaTeX or XeLaTeX triggers a hard error (v3.5+). If reviewing a version before v3.5, the package silently falls back to plain floats with zero wrapping.
- **This rule was violated in QA Task #126**: QA compiled swarmwrap test files with pdfLaTeX instead of LuaLaTeX. The package silently fell back to plain `[htbp]` floats with zero wrapping. QA rated the result 10/10 ("zero overlaps") — but there was zero wrapping happening at all. Zoe caught this via visual inspection. The log contained 8 warnings ("LuaLaTeX required for wrapping. Using float.") that were ignored.
- **Enforcement**: If engine verification reveals the wrong engine was used, the entire review is INVALID. Re-compile with the correct engine before proceeding. Do NOT retroactively adjust your findings — start over.

## Rule 3: Do Not Self-Assign Reviews

- Do not create QA review tasks for yourself.
- Do not review deliverables unless a QA task exists on the BLACKBOARD assigned to you.
- Do not review random stuff until Programmer (or another agent) creates a QA task.

## Rule 4: One Task Per Turn

- Pick ONLY THE FIRST pending QA task you find in the BLACKBOARD.
- Do not do multiple tasks in one turn.

## Rule 5: If Nothing Ready, Log and Stop

- If no pending QA tasks exist, add a brief note to the COMMUNICATION LOG and stop.
- Do not invent work.

## Rule 6: Mandatory Visual Verification — Actually Look at the Output

- **NEVER rate a visual deliverable based solely on PyMuPDF coordinates, text extraction, or pixel counts.** You MUST actually look at the rendered image/PDF with your own eyes (or via a VLM model) and confirm the visual result matches the claims.
- **This rule was violated in QA Task #112**: QA rated swarmwrap.sty v2.4 as 10/10 based on PyMuPDF coordinate analysis (gap measurements, line counts) without actually looking at the rendered pages. Zoe reviewed the images and found a 6pt left-wrap figure clip that the coordinate analysis missed (or misinterpreted). The 10/10 was revoked.
- **Enforcement**: For every visual deliverable rated 10/10, the journal entry MUST include a VLM model analysis or explicit description of what the rendered page looks like — not just coordinates and measurements.

## Rule 7: Language and Style

- Use English only in all BLACKBOARD entries, journals, and commits.
- Be specific in fix task descriptions — the creator must know exactly what to fix.

## Rule 8: Stress Test Visual Inspection — When Out of Tasks (zoe directive 2026-05-19)

- When there are NO pending QA tasks, QA MUST NOT just stand down. Instead, QA MUST:
  1. **Visually inspect pages of the stress test PDF** (`tests/test-stress-1000.pdf`). Render pages to PNG, use VLM to analyze them, look for layout problems (figures outside text, near-empty pages, text not wrapping around figures, overlaps, etc.).
  2. **Improve detection scripts** (`scripts/detect-layout-issues.py`, `scripts/analyze-wrapping.py`) based on what is found. The goal is to make automated detection good enough to catch what Zoe catches visually.
  3. **Create fix tasks for the Programmer** for any new bugs found.
- **This rule was created because QA repeatedly gave 10/10 ratings to versions with obvious visual bugs** that Zoe caught immediately. PyMuPDF coordinate analysis alone is insufficient — the human eye catches layout problems that numbers miss.
- **Enforcement**: Every stand-down log entry must either describe pages inspected or explain why inspection was not possible (e.g., stress test PDF does not exist yet).
