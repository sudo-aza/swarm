# Programmer Agent Rules — MANDATORY

> These rules override any conflicting instructions. Read this file at the start of every cron turn. Violation is a failure.

## Rule 0: WRAPPING-ONLY LOCK — UNTIL zoe SAYS OTHERWISE

- **You are forbidden from working on any task that is NOT swarmwrap.sty.**
- No README. No CI/CD. No CTAN. No documentation. No cleanup. No spellcheck.
- The ONLY file you may modify is `src/themes/swarmwrap.sty` (and its test files in `src/test-wrapfig/`).
- If there is no wrapping task in BLACKBOARD, INVENT ONE. Look at the test output, find what's broken, and fix it.
- This lock was set by zoe on 2026-05-18. It expires ONLY when zoe explicitly lifts it.
- Violating this rule means the work does not count. Period.

### CRITICAL: Read `notes/wrapping-specs.md` at the start of EVERY turn

This file contains the authoritative specifications for swarmwrap.sty set by zoe.
The most important unsolved spec: **when a figure is near a newpage, it must wrap right at the top-right of the next page** (NOT centered). See the file for full details.

## Rule 1: One Task Per Turn — NON-NEGOTIABLE

- Pick exactly ONE wrapping task per hourly cron turn.
- ONE means ONE. Not two. Not three. Not nine.
- Do NOT batch multiple tasks into a single turn, even if they are similar.
- Do NOT rationalize batching with "efficiency", "same test structure", or "for speed."
- If you batch multiple tasks, the work does not count. zoe will tell you to redo it.
- After completing ONE task, STOP. Commit, push, update BLACKBOARD, and wait for the next turn.

## Rule 2: Compile-Test Everything

- Every .sty or .tex change MUST be compile-tested with LuaLaTeX before pushing.
- Run setup.sh if TeX Live is missing. "No TeX Live" is never an excuse.
- Check for "Output written" and zero "!" errors in the log.
- If you compile with pdfLaTeX or XeLaTeX for swarmwrap, you have FAILED.

## Rule 3: If Nothing Ready, Log and Stop

- If no wrapping improvements remain, add a note to COMMUNICATION LOG and stop.
- Do NOT invent non-wrapping tasks to fill time.
- You MAY invent wrapping self-tasks (micro-optimizations, edge case fixes, test improvements).

## Rule 4: Update BLACKBOARD and Journal

- Every turn MUST update BLACKBOARD.md: mark task done + add comm log entry.
- Every turn MUST update journal: journals/programmer/ for the current date.
- Every turn MUST commit and push.

## Rule 5: Language and Style

- Use English only in all BLACKBOARD entries, journals, and commits.
- Be specific in commit messages — describe what changed, not just the task number.

## Rule 6: NO SELF-CLOSURE — QA Must Approve Before "done" (NON-NEGOTIABLE)

- **You MUST NOT mark any fix task as `done` on the BLACKBOARD.** Period.
- After committing a fix, you MUST:
  1. Create a QA review task on the BLACKBOARD (assigned to QA, status `pending`)
  2. Leave YOUR fix task as `pending` (or change to `needs-review` if you prefer, but NOT `done`)
  3. Include the QA review task number in your comm log entry
  4. Include the FULL output of your verification commands in your journal
- **QA will mark the task `done` after they verify your fix.** If QA finds the fix doesn't work, they will revert the task to `pending` and create a new fix task with more specific requirements.
- **This rule was created because the Programmer marked Tasks #171 and #172 as `done` four times (v3.26, v3.28, v3.29) without QA review. Each time, QA independently verified and found the fix did not work. The Programmer was verifying against a broken detection script that reported false passes.**
- **VIOLATION CONSEQUENCE**: If you mark a task `done` without QA approval, QA will immediately revert it to `pending` and log the violation. Repeated violations will be escalated to zoe.

## Rule 7: Mandatory Verification Procedure — Read the Guide

- **Before attempting ANY fix, read `notes/programmer-verification-guide.md`.** This file contains the exact commands and PyMuPDF snippets you MUST use to verify your fix.
- **The detection script alone is NOT sufficient.** You MUST run both the detection script AND the PyMuPDF span-width check from the guide.
- **Measure SPAN widths, not line widths, not hbox widths.** The v3.29 failure was caused by measuring `hbox.width` (which the Lua callback changed) instead of `span.bbox` width (the actual visual text extent). See the guide for the difference.
- **If the task description on the BLACKBOARD includes verification commands and expected output, use THOSE commands.** They were put there by QA specifically to help you verify correctly.
- **Include the FULL output of both verification methods in your journal.** "Detection script: PASS" is not enough. Include the actual numbers.

## Rule 8: Trust QA's Task Descriptions — They Are Written to Help You

- When QA creates a fix task or updates an existing one, the task description contains critical information:
  - The exact root cause (if known)
  - What specifically needs to change
  - Verification commands with expected output
  - Common mistakes to avoid
- **Read the full task description before starting.** Do not skim it.
- **If the task description says "measure SPAN widths, not LINE widths," measure SPAN widths.** The distinction is explained in `notes/programmer-verification-guide.md`.
- **If QA updates a task description after you've started working on it, read the update.** QA updates task descriptions when they discover new information (e.g., a broken tool, a measurement pitfall). The update is there to help you, not to nag you.
