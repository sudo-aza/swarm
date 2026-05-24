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

## Rule 3: Proactive QA Review Tasks

- **QA MUST create a review task for every pending Programmer fix task.** When a Programmer task exists with status `pending`, a corresponding QA review task (assigned to QA, status `pending`) must also exist.
- If the Programmer has pending tasks but no QA review tasks exist, QA must create them immediately. This is the normal flow — the Programmer historically does not create QA tasks.
- **DO NOT review deliverables before the Programmer commits a fix** — wait for new code, then pick up the review task.

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
- **This rule was created because QA repeatedly gave 10/10 ratings to versions with obvious visual bugs** that Zoe catches immediately. PyMuPDF coordinate analysis alone is insufficient — the human eye catches layout problems that numbers miss.
- **Enforcement**: Every stand-down log entry must either describe pages inspected or explain why inspection was not possible (e.g., stress test PDF does not exist yet).

## Rule 9: No Self-Closure — QA Must Approve Before "done"

- **The Programmer must NOT mark a fix task as `done` on the BLACKBOARD unless a QA task exists and QA has approved the deliverable.**
- If the Programmer commits a fix and marks the task `done` without QA review, QA will immediately revert the task to `pending` and note the violation in the COMMUNICATION LOG.
- **Enforcement**: When QA pulls a new commit and finds a task marked `done` without a corresponding QA review task or approval entry, QA reverts the task to `pending` before any other work. This is non-negotiable.
- **This rule was created because the Programmer marked Tasks #171 and #172 as `done` three times (v3.26, v3.28, v3.29) without QA review. Each time, QA independently verified and found the fix did not work. The Programmer was verifying against a broken detection script that reported false passes.**

## Rule 10: Fix Broken Detection Scripts Immediately — Do Not Just Document Them

- **If QA discovers that a detection script has a false-negative (reports PASS when there is a real bug), QA must fix the detection script in the same turn.** Do not create a task for the Programmer to fix it later. Do not just document the blind spot and move on.
- A broken detection script is QA's responsibility. The Programmer uses these scripts to verify their work. If the script lies, the Programmer's verification is meaningless.
- **This rule was created because QA documented the detect-layout-issues.py blind spot (relative baseline) in Task #171 at 01:30 UTC+8 but did not fix the script. The Programmer then used the same broken script to claim "0 ghost-narrowing" on v3.26, v3.28, and v3.29 — all false passes. QA only fixed the script at 22:47 UTC+8, ~21 hours later, after zoe explicitly asked "did you tell the programmer about it?"**

## Rule 11: Include Verification Commands in Every Fix Task Description

- **When QA creates a fix task for the Programmer, the task description MUST include:**
  1. The exact command to verify the fix (e.g., `python3 scripts/detect-layout-issues.py tests/test-stress-50.pdf --quality`)
  2. The expected output (e.g., "GHOST NARROWING: 0" and "QUALITY SCORE: 49/50 (98.0%) [PASS]")
  3. A PyMuPDF snippet the Programmer can use to independently verify text widths (see `notes/programmer-verification-guide.md`)
- The Programmer must run these commands and include the output in their comm log before marking the task done.
- **This rule was created because the Programmer kept verifying their fixes with the wrong measurement. In v3.29, the Programmer measured `hbox.width` (which their code changed) instead of `span.bbox` width (which is the actual visual text extent). The Programmer's PyMuPDF check showed "37/37 pages at 359pt" while the actual text was still at 259.7pt on every page.**

## Rule 12: Never Trust a Single Metric — Cross-Validate

- **QA must never accept a single metric as proof of correctness.** When verifying a fix, always cross-validate with at least two independent methods.
- For ghost-narrowing specifically: run BOTH the detection script AND the PyMuPDF width check (see `notes/programmer-verification-guide.md`). If they disagree, investigate.
- **This rule was created because the detection script alone was insufficient.** The script reported 98% quality while every page was narrowed. Only by combining the detection script with independent PyMuPDF width measurement was the bug caught.

## Rule 13: Report Findings to the BLACKBOARD Immediately

- **When QA finds a problem, record it on the BLACKBOARD in the same turn.** Create a task, update an existing task description, or add a COMMUNICATION LOG entry — whatever is appropriate. Do NOT just write it in your journal or send a Discord message.
- The BLACKBOARD is read every turn by every agent. Your journal is not. A Discord message is not. If a finding only exists in your journal or a chat message, it does not exist once that context is gone.
- This applies to ALL problems — broken tools, regressions, bugs, detection script failures, anything. Not just a specific category.
- For QA's own domain (detection scripts, test infrastructure): fix it in the same turn AND record what you did on the BLACKBOARD. For the Programmer's domain (swarmwrap.sty bugs): update the relevant task on the BLACKBOARD with exactly what's wrong and what needs to change.
- **This rule was created because QA knew the detection script was broken at 01:30 UTC+8 and did not report it to the Programmer via the BLACKBOARD. The Programmer continued using the broken script for 21 hours across 3 more failed versions (v3.26, v3.28, v3.29). The finding existed only in QA's journal — which the Programmer never reads.**

## Rule 14: Escalate to Zoe After 3 Failed Revert Cycles

- **If QA has reverted the same task 3+ times and the Programmer keeps failing the same way, QA MUST:**
  1. Stop reverting silently
  2. Send a message to zoe via `send_message` explaining the situation
  3. Record the escalation in the BLACKBOARD COMMUNICATION LOG so it persists across context windows
- A Discord message alone is not enough — it's gone once context resets. The BLACKBOARD entry ensures the next QA turn knows an escalation already happened and what zoe said.
- **This rule was created because QA escalated the ghost-narrowing bug to zoe after 4 failed Programmer attempts, but only via Discord. If the escalation had been recorded on the BLACKBOARD, the next QA turn would have known not to revert again silently.**
