# Spellcheck in LaTeX — Research Findings — 2026-05-16

## Source
Searched: CTAN, TeX StackExchange, GitHub, aspell.net, languagetool.org, hunspell.github.io, tex.stackexchange.com, Overleaf docs

---

## TIER 1: Internal Packages (Compile-Time, PDF-Visible)

### 1. `spelling` (CTAN) — BEST OFF-THE-SHELF MATCH
- **Type**: Internal LuaTeX package
- **How**: Calls aspell/hunspell during LuaLaTeX compilation, uses Lua callbacks to insert red underlines in PDF for misspelled words — "similar to WYSIWYG word processors"
- **Red squiggly in PDF**: YES
- **Custom dictionary**: YES (via external spellchecker)
- **Multilingual**: YES (depends on spellchecker: aspell ~70 langs, hunspell ~100+)
- **LuaLaTeX**: YES — designed for LuaTeX
- **Maintenance**: On CTAN since 2012, infrequent but functional updates
- **URL**: https://ctan.org/pkg/spelling · https://github.com/sh2d/spelling

### 2. ConTeXt MkIV `\usemodule[spelling]`
- Same concept as `spelling` but ConTeXt-only, not usable with LaTeX.
- Actively maintained by Pragma ADE.

### 3. TikZ `zigzag` Decoration — RENDERING TECHNIQUE
- Authentic-looking red squiggly (zigzag) underline using TikZ's `zigzag` decoration
- Most visually authentic squiggly achievable in LaTeX PDF
- Works with LuaLaTeX
- Needs a spellchecker to drive it (not standalone)
- Source: https://tex.stackexchange.com/questions/80378/red-squiggly-imitation

### 4. `ulem` package — `\uwave{}`
- Provides wavy (not zigzag/squiggly) underline
- Can be colored red with `\renewcommand{\uwave}[1]{\bgroup\markoverwith{\textcolor{red}{\tiny\dothighlight}}\ULon{#1}}`
- Works with LuaLaTeX
- URL: https://ctan.org/pkg/ulem

### 5. `soul` / `lua-ul` packages
- Hyphenation-aware underlining
- `lua-ul` is the modern LuaLaTeX successor to `soul`
- URL: https://ctan.org/pkg/soul · https://github.com/pgf-tikz/lua-ul

---

## TIER 2: External CLI Tools (No PDF Output, Script Integration)

### 6. GNU Aspell — MOST MATURE CLI SPELLCHECKER
- Native `--mode=tex` filter: strips LaTeX commands, ignores math mode
- Usage: `aspell --mode=tex --lang=en check file.tex`
- Custom dict: YES (`.pws` personal word lists)
- Multilingual: YES (~70 languages)
- Development slowed (last release 0.60.8, 2020) but stable
- URL: http://aspell.net

### 7. Hunspell — MOST WIDELY USED
- Used by LibreOffice, Firefox, Chrome, macOS, InDesign
- TeX filter: `hunspell -t -d en_US file.tex`
- Best multilingual coverage (100+ dictionaries)
- Easiest custom dictionary creation (`.dic`/`.aff` files)
- Actively maintained
- URL: https://hunspell.github.io

### 8. LanguageTool (CLI/Server)
- Rule-based grammar + spell checker
- Does NOT natively parse LaTeX — needs detex or YaLafi preprocessing
- 30+ languages, actively maintained
- URL: https://languagetool.org

### 9. TeXtidote — BEST GRAMMAR+SPELL FOR LATEX
- Purpose-built for LaTeX: strips markup, runs LanguageTool, maps errors back to original line/columns
- Annotated HTML output
- Actively maintained (Java)
- Usage: `textidote --check en --read file.tex`
- URL: https://github.com/sylvainhalle/textidote

### 10. YaLafi (Yet Another LaTeX Filter) + YaLafi-LS
- Python LaTeX-to-plain-text extractor with position mapping
- Integrates with LanguageTool
- Has an LSP server (YaLafi-LS) for editor integration
- URL: https://github.com/torik42/YaLafi

### 11. Vale — prose linter (Go)
- NO native LaTeX support
- Custom rule sets (styles)
- URL: https://vale.sh

### 12. ChkTeX — LaTeX syntax linter (NOT spellchecker)
- Checks LaTeX syntax, not spelling
- URL: https://www.nongnu.org/chktex/

### 13. lacheck — legacy LaTeX linter
- Unmaintained, not recommended
- URL: https://www.ctan.org/pkg/lacheck

### 14. Proselint — English prose style linter only
- No LaTeX awareness
- URL: https://proselint.com

### 15. `detex` + any spellchecker
- Simple pipeline: strip TeX commands, pipe to spellchecker
- Loses position/line mapping
- URL: https://ctan.org/pkg/detex

### 16. TeXCheckR — R package
- Uses hunspell with LaTeX-aware vocabulary filtering
- URL: https://cran.r-project.org/package=TeXCheckR

---

## TIER 3: Editor Integration (Underlines in Editor, NOT PDF)

| Tool | Platform | Custom Dict | Multi-lang | URL |
|------|----------|:-----------:|:----------:|-----|
| LTeX+ | VS Code | YES | YES | https://valentjn.github.io/ltex |
| CSpell | VS Code | YES | YES | https://cspell.org |
| VimTeX + vim spell | Vim/Neovim | YES | YES | https://github.com/lervag/vimtex |
| Emacs flyspell-babel | Emacs | YES | YES | built-in |
| TeXstudio | Standalone | YES | YES | https://www.texstudio.org |
| Overleaf | Web | YES | YES | https://www.overleaf.com |
| Writefull | Overleaf ext | PARTIAL | PARTIAL | https://www.writefull.com |

---

## TIER 4: CI/CD

| Tool | Description | URL |
|------|-------------|-----|
| pre-commit-latex-hooks | Git pre-commit hooks for LaTeX (includes spellcheck) | https://github.com/jonasbb/pre-commit-latex-hooks |
| textidote-action | GitHub Actions for TeXtidote | https://github.com/ChiefGokhlayeh/textidote-action |

---

## Red Squiggly Underline Capability Summary

| Approach | Red Squiggly in PDF? | Mechanism |
|----------|:--------------------:|-----------|
| `spelling` (CTAN) | YES | LuaTeX callbacks + external spellchecker |
| ConTeXt MkIV | YES | Built-in module (ConTeXt only) |
| TikZ zigzag + soul | YES | Custom rendering (needs spellchecker driver) |
| `ulem` `\uwave` | PARTIAL (wavy, not zigzag) | `\uwave{}` with red color |
| `soul`/`lua-ul` | PARTIAL (straight/wavy underline) | `\ul{}` with color |
| Everything else | NO | CLI/editor only, no PDF feedback |

---

## Recommended Approach for the Swarm Toolkit

### Option A: Use `spelling` CTAN package directly
- Pros: off-the-shelf, compile-time, red underlines in PDF, LuaLaTeX-native
- Cons: depends on external aspell/hunspell, may be fragile, infrequent updates
- Integration: add `\usepackage{spelling}` to theme, document aspell/hunspell install

### Option B: Build hybrid pipeline (RECOMMENDED)
```
[Hunspell/Aspell] → extract misspelled words + line/col from .tex
  → generate TikZ zigzag markup (\MarkSpelling{} commands)
  → compile with LuaLaTeX
  → PDF with authentic red squiggly underlines
```
- Pros: full control, most authentic visual, works with any spellchecker backend
- Cons: more work to implement, needs Python script
- Components needed:
  1. Python script: `scripts/spellcheck.py` — runs hunspell, parses output, generates TeX markup
  2. Lua module: `src/lua/spellcheck.lua` — optional, for compile-time integration
  3. Theme support: toggle in both swarmbeauty and swarmperf

### Option C: External-only (no PDF marks)
- Add aspell/hunspell integration to `scripts/compile.py` as `--spellcheck` flag
- Output misspellings to terminal or HTML report
- No PDF underlines, but zero compilation overhead

### Key Dependencies
- hunspell: `sudo apt install hunspell hunspell-en-us` (or portable via conda)
- aspell: `sudo apt install aspell aspell-en` (or from source)
- For the toolkit, hunspell is preferred (wider language support, actively maintained)
