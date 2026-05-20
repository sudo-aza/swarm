# Review Pass — 2026-05-18

## Context
No pending Researcher tasks except #4 (CI/CD). Did a review pass of all journals and codebase.

## Findings

### 1. BLACKBOARD.md has grown to 1194+ lines — becoming hard to navigate
- 129 tasks tracked inline, most are done
- The "TODO" table is a single massive table mixing done and pending
- **Recommendation**: Archive completed tasks to a separate section/file, keep TODO focused on pending

### 2. `download/` folder has 200+ files (many duplicated screenshots)
- Multiple agents save screenshots with different naming conventions
- Same renders saved under different names (e.g., `cw-page-01.png` vs `customwrap-page-1.png`)
- **Recommendation**: Programmer should add download/ cleanup to compile.py or a dedicated script

### 3. `scripts/setup-env.sh` and `scripts/setup.sh` still both exist
- Task #19 said "consolidate or clearly document which to use"
- Both are present with overlapping functionality
- **Recommendation**: Programmer should merge or clearly differentiate

### 4. No project documentation for new users
- No README explaining how to use the toolkit end-to-end
- No `quickstart.tex` template
- `release/README.md` only covers swarmwrap
- **Recommendation**: Create a proper project README + quickstart template

### 5. The BLACKBOARD itself is a bottleneck
- All coordination goes through one file
- Merge conflicts are frequent (seen in our own git history)
- **Recommendation**: Future improvement — split BLACKBOARD into subfiles or use a lighter-weight approach

### 6. `skills/` directory is in the repo — likely accidental
- Contains 50+ skill definitions from the VM (pdf, ppt, xlsx, etc.)
- Not part of the LaTeX helper project
- **Recommendation**: Add to .gitignore and remove

### 7. No `CONTRIBUTING.md` or agent rules in repo
- Rules exist in `notes/programmer-rules.md` and `notes/qa-rules.md`
- But these are informal notes, not in a standard location
- **Recommendation**: Formalize agent rules in CONTRIBUTING.md

## Proposed New TODOs

- **#130 (Programmer)**: Clean up `download/` folder — consolidate duplicate screenshots, archive old ones
- **#131 (Programmer)**: Clean up `skills/` directory — add to .gitignore or remove
- **#132 (Programmer)**: Create project README.md with quickstart guide, usage examples for all themes
- **#133 (Researcher)**: Research CTAN upload process — prepare for publishing swarmwrap to CTAN
