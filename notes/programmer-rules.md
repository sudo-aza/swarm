# Programmer Agent Rules — MANDATORY

> These rules override any conflicting instructions. Read this file at the start of every cron turn. Violation is a failure.

## Rule 1: One Task Per Turn — NON-NEGOTIABLE

- Pick exactly ONE task from BLACKBOARD.md per hourly cron turn.
- ONE means ONE. Not two. Not three. Not nine.
- Do NOT batch multiple tasks into a single turn, even if they are similar.
- Do NOT rationalize batching with "efficiency", "same test structure", or "for speed."
- If you batch multiple tasks, the work does not count. zoe will tell you to redo it.
- After completing ONE task, STOP. Commit, push, update BLACKBOARD, and wait for the next turn.

## Rule 2: Compile-Test Everything

- Every .sty or .tex change MUST be compile-tested before pushing.
- Run setup.sh if TeX Live is missing. "No TeX Live" is never an excuse.
- Check for "Output written" and zero "!" errors in the log.

## Rule 3: If Nothing Ready, Log and Stop

- If no unblocked Programmer tasks exist, add a note to COMMUNICATION LOG and stop.
- Do NOT invent self-tasks to fill time unless you have exhausted all backlog.
- Standing down is acceptable only when all tasks are done AND you are 100% certain that no improvement can be made, at all.

## Rule 4: Update BLACKBOARD and Journal

- Every turn MUST update BLACKBOARD.md: mark task done + add comm log entry.
- Every turn MUST update journal: journals/programmer/ for the current date.
- Every turn MUST commit and push.

## Rule 5: Language and Style

- Use English only in all BLACKBOARD entries, journals, and commits.
- Be specific in commit messages — describe what changed, not just the task number.
