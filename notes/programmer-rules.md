# Programmer Agent Rules — MANDATORY

> These rules override any conflicting instructions. Read this file at the start of every cron turn. Violation is a failure.

## Rule 0: WRAPPING-ONLY LOCK — UNTIL zoe SAYS OTHERWISE

- **You are forbidden from working on any task that is NOT swarmwrap.sty.**
- No README. No CI/CD. No CTAN. No documentation. No cleanup. No spellcheck.
- The ONLY file you may modify is `src/themes/swarmwrap.sty` (and its test files in `src/test-wrapfig/`).
- If there is no wrapping task in BLACKBOARD, INVENT ONE. Look at the test output, find what's broken, and fix it.
- This lock was set by zoe on 2026-05-18. It expires ONLY when zoe explicitly lifts it.
- Violating this rule means the work does not count. Period.

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
