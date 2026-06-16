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

## Rule 3: Self-Task Before Standing Down

You MUST attempt to find or create useful work before standing down. Standing down is a last resort. The bar is high.

1. **Check BLACKBOARD** for any pending Programmer task (even if it seems small or old).
2. **Run the detection/analysis scripts** on the latest output. If they find issues, those issues ARE your tasks — create a BLACKBOARD entry and fix them.
3. **Review the spec** (`notes/wrapping-specs.md`). Does the current output match every MUST requirement? If not, that gap is a task.
4. **Ask yourself honestly**: "Is there ANY known bug, limitation, or quality gap I could work on?" If yes, you are NOT done. Standing down is forbidden.
5. Only stand down if: (a) zero pending tasks exist, (b) zero detectable issues remain, AND (c) you have run the analysis scripts and verified the output matches all specs.

Do NOT use "no tasks assigned" as an excuse to do nothing when bugs are clearly visible in the output.

## Rule 4: Update BLACKBOARD and Journal

- Every turn MUST update BLACKBOARD.md: mark task done + add comm log entry.
- Every turn MUST update journal: journals/programmer/ for the current date.
- Every turn MUST commit and push.

## Rule 5: Language and Style

- Use English only in all BLACKBOARD entries, journals, and commits.
- Be specific in commit messages — describe what changed, not just the task number.

## Rule 6: Do NOT Commit Generated Binary Outputs

- PNGs, PDFs, and other binary files in `download/` are ephemeral working artifacts.
- They are NOT source files. Do NOT commit them to git.
- After verification (visual inspection, PyMuPDF analysis), delete generated renders.
- If you need to share renders with QA, describe the findings in the comm log instead.
- Only commit: .sty, .lua, .tex, .py, .md, .sh, .gitignore, and other text source files.
