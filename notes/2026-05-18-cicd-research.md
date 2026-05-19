# CI/CD and Compilation Benchmarking for LaTeX Projects
## Comprehensive Research Report

---

## Table of Contents
1. [LaTeX-Specific CI/CD on GitHub Actions](#1-latex-specific-cicd-on-github-actions)
2. [LaTeX Linting and Static Analysis](#2-latex-linting-and-static-analysis)
3. [Compilation Benchmarking](#3-compilation-benchmarking)
4. [CTAN + CI Integration](#4-ctan--ci-integration)
5. [Release Automation](#5-release-automation)
6. [Recommended GitHub Actions Workflow](#6-recommended-github-actions-workflow)

---

## 1. LaTeX-Specific CI/CD on GitHub Actions

### 1.1 Overview of Approaches

There are **four main approaches** to running TeX Live in GitHub Actions:

| Approach | Tools | Pros | Cons |
|----------|-------|------|------|
| **Native install actions** | `zauguin/install-texlive`, `TeX-Live/setup-texlive-action` | Install only needed packages; fast; cacheable | First run slow (~2-5 min for package install) |
| **Docker-based actions** | `xu-cheng/texlive-action`, `xu-cheng/latex-action`, `baileythomas/texlive-action` | Full TeX Live available; no install step | Large images (3-6 GB); slower pulls; no package selection |
| **Full Docker images** | `dante-ev/docker-texlive`, `texlive/texlive` (official) | Complete TeX Live + extras (Python, pandoc) | Very large; slower; no caching |
| **Manual TeX Live install** | Custom scripts, `install-tl` | Full control | Most complex to set up; must handle caching manually |

### 1.2 Recommended TeX Live Actions (Detailed)

#### Option A: `zauguin/install-texlive` (⭐ RECOMMENDED for packages)

- **URL**: https://github.com/zauguin/install-texlive
- **How it works**: Uses the TeX Live network installer to install only the packages you specify under `~/texlive`
- **Caching**: Automatic caching of `~/texlive` — cache hit restores TeX Live in seconds
- **Features**: Cross-platform (Ubuntu, macOS, Windows); version pinning; force cache refresh
- **Used by**: `Witiko/markdown` (migrated to this from `TeX-Live/setup-texlive-action`), `latex3/l3build` ecosystem

```yaml
- uses: zauguin/install-texlive@v4
  with:
    packages: >
      scheme-basic
      koma-script
      fontawesome5
      minted
      l3build
```

#### Option B: `TeX-Live/setup-texlive-action` (Official-ish)

- **URL**: https://github.com/TeX-Live/setup-texlive-action / https://github.com/marketplace/actions/setup-tex-live
- **Maintained by**: The TeX-Live GitHub org (maintainers include active TeX Live contributors)
- **Features**: Preconfigured cache for "blazing-fast builds"; package version flexibility; `texliveonfly` integration
- **Note**: The `Witiko/markdown` package migrated FROM this TO `zauguin/install-texlive@v4` due to deprecation concerns

```yaml
- uses: TeX-Live/setup-texlive-action@v3
  with:
    packages: |
      scheme-basic
      koma-script
```

#### Option C: `xu-cheng/latex-action` (Docker, simplest for compilation-only)

- **URL**: https://github.com/xu-cheng/latex-action
- **How it works**: Runs in a Docker container with full TeX Live
- **Best for**: Simple "compile this .tex to .pdf" workflows; not suitable for custom scripts
- **Engine support**: `pdflatex`, `xelatex`, `lualatex`, `biber`, `bibtex`

```yaml
- uses: xu-cheng/latex-action@v3
  with:
    root_file: main.tex
    compiler: lualatex
    args: -interaction=nonstopmode -halt-on-error
```

#### Option D: `xu-cheng/texlive-action` (Docker, for custom commands)

- **URL**: https://github.com/xu-cheng/texlive-action
- **Best for**: Running custom scripts (Python + LaTeX) in a Docker TeX Live environment

```yaml
- uses: xu-cheng/texlive-action@v3
  with:
    run: |
      python compile.py --theme beauty
      lualatex demo-beauty.tex
```

#### Option E: `dante-ev/docker-texlive` (Official DANTE image)

- **URL**: https://github.com/dante-ev/docker-texlive
- **Maintainer**: DANTE e.V. (German TeX Users Group)
- **Features**: Full TeX Live + Python 3, pip, pandoc, GraphViz, pdftk
- **Tags**: `texlive/YYYY`, `texlive/YYYY-A/B` (e.g., `texlive/2024-B`)
- **Note**: Can be 6+ months behind current TeX Live releases

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: danteev/texlive:2024
    steps:
      - uses: actions/checkout@v4
      - run: lualatex main.tex
```

### 1.3 How Popular LaTeX Projects Set Up CI

#### `latex3/latex2e` (The LaTeX Kernel)
- **URL**: https://github.com/latex3/latex2e/blob/develop/.github/workflows/main.yaml
- **Tool**: `l3build` (LaTeX3 build system)
- **Approach**: Uses `zauguin/install-texlive` to install TeX Live, then runs `l3build check` across multiple configurations and engines
- **Matrix**: Tests across `pdflatex`, `xelatex`, `lualatex`, and `pdftex` (dev format)
- **Key features**:
  - Parallel test execution via `l3build` options (`--first`, `--last` to split large test suites)
  - Uploads test logs as artifacts on failure
  - Runs on both `ubuntu-latest` and `windows-latest`
  - Takes 17–22 minutes per workflow run (even after optimization — see Issue #1073)

#### `islandoftex/github-actions-l3build` (Template for l3build projects)
- **URL**: https://github.com/islandoftex/github-actions-l3build
- **Presented at**: TUG 2024
- **Workflow structure**:
  1. **Build job**: `l3build build` + `l3build check` with matrix (engines)
  2. **Deploy job**: Extended with `zauguin/ctan-upload` dry-run for CTAN validation
- **Best practice**: This is the gold standard template for LaTeX packages using `l3build`

#### `Witiko/markdown` (Complex LaTeX package)
- **URL**: https://github.com/Witiko/markdown
- **Migration**: Moved from `TeX-Live/setup-texlive-action@v3` to `zauguin/install-texlive@v4`
- **Tests on**: Multiple TeX Live versions
- **Features**: Disabled caching in some scenarios for reproducibility

#### `DanySK/Template-LaTeX-CI` (General LaTeX CI template)
- **URL**: https://github.com/DanySK/Template-LaTeX-CI
- **Purpose**: Template repository for LaTeX projects with CI in place
- **Features**: GitHub Actions workflow, artifact upload, release automation

#### `minted` (gpoore/minted)
- **URL**: https://github.com/gpoore/minted
- **Special requirement**: Needs Python + Pygments (`pygmentize` binary)
- **CI consideration**: Since TeX Live 2024, `latexminted` is bundled — but for older TL, you need `pip install Pygments`
- **Shell escape required**: Must compile with `-shell-escape` flag

### 1.4 Multi-Engine Testing with Matrix Strategy

```yaml
strategy:
  matrix:
    engine: [pdflatex, xelatex, lualatex]
    texlive: [2024, 2023]
  fail-fast: false

steps:
  - uses: zauguin/install-texlive@v4
    with:
    # ${{ matrix.engine }} maps to engine-specific packages
      packages: |
        scheme-basic
        koma-script
    # Set TEXMFLOCAL to use the installed version
  - run: ${{ matrix.engine }} -interaction=nonstopmode -halt-on-error main.tex
```

**Note**: For LuaLaTeX-only packages (like `swarmwrap.sty`), use a separate job or conditional:

```yaml
jobs:
  build-all-engines:
    strategy:
      matrix:
        engine: [pdflatex, xelatex, lualatex]
    steps:
      - run: ${{ matrix.engine }} demo.tex
  
  build-lua-only:
    runs-on: ubuntu-latest
    steps:
      - uses: zauguin/install-texlive@v4
      - run: lualatex swarmwrap-demo.tex
```

### 1.5 Caching TeX Live Installations

| Method | Cache Key | Typical First Run | Typical Cache Hit |
|--------|-----------|-------------------|-------------------|
| `zauguin/install-texlive` | Automatic (`~/texlive`) | 2-5 min | <30 sec |
| `TeX-Live/setup-texlive-action` | Automatic | 2-5 min | <30 sec |
| `actions/cache` (manual) | `texlive-${{ hashFiles('tex-packages.txt') }}` | Custom | Depends on setup |
| Docker image pull | N/A (image layer cache) | 30-90 sec | <10 sec |

**Best practice**: Use `zauguin/install-texlive` — its caching is built-in and battle-tested.

---

## 2. LaTeX Linting and Static Analysis

### 2.1 ChkTeX (⭐ PRIMARY LINTER)

- **URL**: https://www.nongnu.org/chktex/ (documentation), https://ctan.org/pkg/chktex
- **Purpose**: Semantic checker for LaTeX source files
- **Checks include**:
  - Missing `$` signs around math expressions
  - Incorrect use of `\hline`/`\midrule` outside tabular
  - Mismatched braces (non-trivial cases)
  - Double spaces after periods (American vs. British typography)
  - Commands that should be in math mode
  - Unused or misspelled commands
  - Incorrectly paired environments
  - Use of deprecated/primitive TeX commands in LaTeX context

- **False positive rate**: **Moderate to High** — this is the most commonly cited complaint. ChkTeX produces many warnings that are stylistic opinions rather than errors. For custom packages/themes, expect to suppress 30-60% of warnings.

- **Configuration**:
  - **Global config**: `~/.chktexrc`
  - **Per-project config**: `.chktexrc` in project root
  - **Per-file suppression**: `% chktex-file 41` (suppresses warning 41 for entire file)
  - **Per-line suppression**: `% chktex 41 42` (suppresses warnings 41 and 42 on that line)

```yaml
# .chktexrc example for a custom package project
# Suppress warnings about:
# 1: Intersentence spacing (\ )
# 6: \0 outside \textbf context
# 11: Non-breaking space before reference
# 41: Using TeX primitives in LaTeX
# 44: Wrong length of dash
-Warn = 1, 6, 11, 41, 44
# Don't abort on warnings
-Global = 1
# Skip .dtx files
-Skip = 0
-PID = 0
```

- **GitHub Actions integration**:
  - `j2kun/chktex-action`: https://github.com/j2kun/chktex-action
  - `marketplace/actions/chktex-action`: https://github.com/marketplace/actions/chktex-action
  - Manual:
    ```yaml
    - name: Install chktex
      run: sudo apt-get install -y chktex
    - name: Lint LaTeX files
      run: chktex -n 1 -n 6 -n 11 -n 41 -n 44 *.tex **/*.tex
    ```

### 2.2 LaCheck

- **URL**: Part of TeX Live (`texlive-extra`); source: https://www.ctan.org/pkg/lacheck
- **Purpose**: Syntax checker for LaTeX (simpler than ChkTeX)
- **Checks**:
  - Mismatched braces
  - Mismatched `\begin`/`\end` pairs
  - Missing `$` in math mode
  - Unused or undefined labels
  - Simple syntax errors

- **Pros**:
  - Very fast (pure syntax analysis)
  - Near-zero false positives for true errors
  - Available in all TeX Live installations
  - Good for catching actual bugs

- **Cons**:
  - Far fewer checks than ChkTeX
  - No stylistic checks
  - No customization options
  - Not actively maintained (last significant update ~2010)
  - No per-line suppression mechanism

- **Recommendation**: Run **both** chktex (configured) AND lacheck. Use lacheck for catching real errors (near-zero false positives) and chktex for style/style warnings (with aggressive suppression).

```yaml
- name: Lint with lacheck
  run: lacheck *.sty **/*.tex
```

### 2.3 latexindent.pl (Code Formatter, Not Linter)

- **URL**: https://github.com/cmhughes/latexindent.pl
- **Purpose**: Beautify/tidy/format/indent LaTeX code
- **Configuration**: `.latexindent.yaml` (per-project), `defaultSettings.yaml` (global)
- **Use in CI**: Verify that committed code is properly formatted (similar to Prettier for JS):

```yaml
- name: Check formatting
  run: |
    latexindent.pl -w -s *.sty **/*.tex
    git diff --exit-code || (echo "Files not properly formatted. Run latexindent.pl locally." && exit 1)
```

- **Note**: The `-w` flag writes formatted files. In CI, you should check if formatting differs without committing.

### 2.4 texlab (Language Server Protocol)

- **URL**: https://github.com/latex-lsp/texlab
- **CTAN**: https://ctan.org/pkg/texlab
- **Features**: Code completion, go-to-definition, find-references, diagnostics (warnings/errors), document symbols, hover info
- **Built-in linter**: Uses ChkTeX internally for diagnostics
- **CI usage**: Limited — texlab is designed for editors (VSCode, Neovim, Emacs), not headless CI. However, you can run it in check mode:
  ```bash
  texlab --check main.tex  # Not a standard feature; mainly editor-focused
  ```
- **Recommendation**: Use texlab for local development, not CI. Use chktex directly in CI.

### 2.5 MegaLinter (Meta-Linter)

- **URL**: https://megalinter.io/7.6.0/descriptors/latex_chktex
- **Includes**: chktex as one of many linters
- **Pros**: One configuration for all languages (if project also has Python, YAML, etc.)
- **Cons**: Overkill if you only have LaTeX; harder to customize chktex options
- **Recommendation**: Only if project already uses MegaLinter for other languages

### 2.6 Linting Summary & Recommendation

| Tool | Type | False Positive Rate | CI Maturity | Recommendation |
|------|------|---------------------|-------------|----------------|
| **chktex** | Semantic linter | Moderate-High | ✅ GitHub Actions available | ✅ Use with custom .chktexrc |
| **lacheck** | Syntax checker | Low | ✅ Available in TeX Live | ✅ Use alongside chktex |
| **latexindent** | Formatter | N/A | ✅ Scriptable | ⚡ Optional: format-check in CI |
| **texlab** | LSP | N/A | ❌ Editor-only | ❌ Local dev only |
| **MegaLinter** | Meta-linter | Depends | ✅ GitHub Actions | ❌ Overkill for LaTeX-only |

---

## 3. Compilation Benchmarking

### 3.1 Why Benchmark LaTeX Compilation?

- Detect performance regressions when themes/packages change
- Compare compilation speed across engines (pdfLaTeX vs XeLaTeX vs LuaLaTeX)
- Validate that Lua scripts (like `metrics.lua`) don't add unacceptable overhead
- Track improvement over time

### 3.2 Approaches to Measuring Compilation Time

#### Approach A: External Timing (Shell Level) — RECOMMENDED

```bash
# Using /usr/bin/time for wall clock + memory
/usr/bin/time -v lualatex -interaction=nonstopmode demo.tex

# Using Python timeit (from compile.py)
python3 -c "
import subprocess, timeit
def compile_doc():
    subprocess.run(['lualatex', '-interaction=nonstopmode', 'demo.tex'],
                   capture_output=True)
# 5 runs, discard first (warm-up)
times = timeit.repeat(compile_doc, number=1, repeat=6)[1:]
print(f'Mean: {sum(times)/len(times):.2f}s')
print(f'Min:  {min(times):.2f}s')
print(f'Max:  {max(times):.2f}s')
"
```

#### Approach B: latexmk with Timing

```bash
# latexmk shows elapsed time in output
latexmk -interaction=nonstopmode -lualatex demo.tex 2>&1 | tail -5

# With verbose timing:
latexmk -interaction=nonstopmode -lualatex -verbose demo.tex
```

#### Approach C: LuaLaTeX Internal Timing (for Lua code)

```lua
-- In metrics.lua or similar:
local socket = require("socket")  -- built-in with LuaTeX
local start = socket.gettime()

-- ... code to benchmark ...

local elapsed = socket.gettime() - start
print(string.format("Lua code took %.3f seconds", elapsed))
```

#### Approach D: `l3benchmark` (LaTeX3 Experimental)

- **CTAN**: `l3experimental/l3benchmark`
- **Purpose**: Benchmark LaTeX code blocks from within TeX
- **Features**: Runs code multiple times, reports time and estimated operations
- **Limitation**: Only measures internal TeX code, not full document compilation

```latex
\ExplSyntaxOn
\benchmark:n { \your_code_here }
\ExplSyntaxOff
```

### 3.3 The Stuttgart LaTeX Benchmark (Real-World Example)

- **URL**: https://web.itp3.uni-stuttgart.de/latex-benchmark
- **Method**: Compiles a complex QFT lecture note document (many packages, equations, TikZ) with pdflatex + bibtex
- **Run script**: `bash -c "$(curl -L -s itp3.info/latexbench)"`
- **Scoring**: Reports min/avg/max over multiple runs; lower is better
- **Scoreboard**: AMD Ryzen 9 9950X: 7.3s; Intel Core Ultra 7 265KF: 8.2s

### 3.4 Statistical Approach for Reliable Benchmarking

```python
import subprocess
import statistics
import time

def benchmark_compilation(command, runs=10, warmup=2):
    """Benchmark a LaTeX compilation command with statistical analysis."""
    times = []
    
    for i in range(warmup + runs):
        start = time.perf_counter()
        result = subprocess.run(command, capture_output=True)
        elapsed = time.perf_counter() - start
        
        if result.returncode != 0:
            raise RuntimeError(f"Compilation failed: {result.stderr.decode()}")
        
        if i >= warmup:
            times.append(elapsed)
    
    # Remove outliers (IQR method)
    q1 = statistics.quantiles(times, n=4)[0]
    q3 = statistics.quantiles(times, n=4)[2]
    iqr = q3 - q1
    filtered = [t for t in times if q1 - 1.5*iqr <= t <= q3 + 1.5*iqr]
    
    return {
        'mean': statistics.mean(filtered),
        'median': statistics.median(filtered),
        'stdev': statistics.stdev(filtered) if len(filtered) > 1 else 0,
        'min': min(filtered),
        'max': max(filtered),
        'runs': len(filtered),
        'all_times': times,
    }
```

### 3.5 Regression Detection Strategy

**Approach 1: Baseline Comparison (Simple)**
```yaml
- name: Benchmark compilation
  run: |
    python3 compile.py --benchmark --baseline 3.5 --theme beauty
    # Fails if compilation takes > 3.5 seconds
```

**Approach 2: Historical Tracking (Advanced)**
```yaml
- name: Benchmark and store results
  run: |
    RESULT=$(python3 compile.py --benchmark --json --theme beauty)
    echo "BENCHMARK_RESULT=$RESULT" >> $GITHUB_ENV
    echo "$RESULT" >> benchmark-results.csv

- name: Check for regression
  run: |
    python3 -c "
    import json, statistics
    # Read current and previous results from CSV/artifacts
    # Compare with 20% threshold
    # Alert if regression detected
    "
```

**Approach 3: GitHub Actions Benchmark Dashboard**
- Store results as job annotations or in a `docs/benchmark.md` file
- Use `gh api` to post benchmark comments on PRs
- Trigger only on changes to `.sty` files, not `.tex` content

### 3.6 Benchmarking Recommendations for This Project

1. **Use `compile.py --benchmark`** with Python's `time.perf_counter()` for high-resolution timing
2. **Run 10 compilations**, discard 2 warm-up runs, use IQR-based outlier removal
3. **Set a baseline threshold** per theme (e.g., beauty: <5s, perf: <8s, min: <4s)
4. **Run benchmarks only on CI for pull requests** that modify `.sty` or `.lua` files
5. **Compare across engines** but only for themes that support all engines
6. **Store historical data** in a CSV committed to the repo or as workflow artifacts

---

## 4. CTAN + CI Integration

### 4.1 CTAN Submission API Overview

CTAN provides a **versioned, documented API** for programmatic uploads:
- **Validation endpoint**: `POST https://www.ctan.org/submit/validate`
- **Upload endpoint**: `POST https://www.ctan.org/submit`
- **API version**: 1.1
- **Format**: `application/x-www-form-urlencoded` multipart
- **Archive format**: `.zip`, `.tgz`, or `.tar.gz`

**Required fields**: `pkg`, `version`, `author`, `email`, `uploader`, `ctanPath`, `description`, `summary`, `update` (boolean), `file` (archive)

**Optional fields**: `announcement`, `bugtracker`, `development`, `home`, `license`, `note`, `repository`, `support`, `topic`

### 4.2 CTAN Validation Actions

#### `paolobrasolin/ctan-submit-action` (⭐ RECOMMENDED)

- **URL**: https://github.com/paolobrasolin/ctan-submit-action
- **Marketplace**: https://github.com/marketplace/actions/ctan-submit
- **Modes**: `validate` (default) and `upload`
- **Author**: Paolo Brasolin (active LaTeX package maintainer — `commutative-diagrams` package)
- **Action inputs**:
  - `action`: `validate` or `upload` (default: `validate`)
  - `file_path`: Path to the ZIP/TGZ archive
  - `version`: Package version
  - `fields`: JSON string with CTAN metadata

```yaml
- uses: paolobrasolin/ctan-submit-action@v2
  with:
    action: validate
    file_path: ./dist/swarmbeauty.zip
    version: ${{ github.ref_name }}
    fields: |
      {
        "pkg": "swarmbeauty",
        "author": "Your Name",
        "email": "you@example.com",
        "uploader": "Your Name",
        "ctanPath": "/macros/latex/contrib/swarmbeauty",
        "description": "Beautiful presentation theme for academic talks",
        "summary": "Beautiful Beamer theme for academic presentations",
        "update": true,
        "license": "lppl1.3c",
        "repository": "https://github.com/yourname/swarmthemes",
        "bugtracker": "https://github.com/yourname/swarmthemes/issues",
        "topic": "topic:beamer-theme"
      }
  env:
    CTAN_PASSWORD: ${{ secrets.CTAN_PASSWORD }}
```

#### `zauguin/ctan-upload`

- **URL**: https://github.com/zauguin/ctan-upload
- **Maintained by**: zauguin (same person as `zauguin/install-texlive`)
- **Used in**: `islandoftex/github-actions-l3build` template
- **Features**: CTAN API upload with validation

#### `ctan-o-mat` (Desktop/CLI Tool)

- **URL**: https://github.com/ge-ne/ctan-o-mat
- **CTAN**: https://ctan.org/pkg/ctan-o-mat
- **Purpose**: Scripted upload of packages to CTAN (originally a Perl/GUI tool, now also CLI)
- **Best for**: Local packaging before CI upload; creating CTAN-ready archives
- **Configuration**: Uses a separate config file for package metadata

### 4.3 CTAN Readiness Checklist for CI

```yaml
- name: CTAN readiness checks
  run: |
    # 1. Check that all required files exist
    test -f swarmbeauty.sty
    test -f swarmbeauty.pdf  # documentation
    
    # 2. Check that README contains required fields
    grep -q "## License" README.md
    grep -q "## Installation" README.md
    
    # 3. Check CTAN archive structure
    mkdir -p dist
    # Archive should contain: .sty, .pdf, README
    zip -r dist/swarmbeauty.zip swarmbeauty.sty swarmbeauty.pdf README.md
    
    # 4. Run CTAN validation
    # (see ctan-submit-action above)
```

### 4.4 Pre-Upload Validation Steps

1. **Compile test**: All demo files compile without errors
2. **Documentation builds**: `pdflatex swarmbeauty.dtx && makeindex swarmbeauty && pdflatex swarmbeauty.dtx`
3. **File structure check**: Archive contains required files (`.sty`, `.pdf` doc, `README`)
4. **License check**: LPPL or other open-source license present and correct
5. **CTAN path correctness**: `ctanPath` follows `/macros/latex/contrib/packagename` convention
6. **Version uniqueness**: New version differs from current CTAN version
7. **API validation**: Submit to `/submit/validate` and check for 200 response

---

## 5. Release Automation

### 5.1 Semantic Versioning for LaTeX Packages

LaTeX packages on CTAN traditionally use **semantic versioning** (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes (API changes, removed features)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

**LaTeX-specific convention**:
- Many packages use date-based versions (e.g., `v2024-01-15` or `2024.0115`)
- CTAN does not enforce any versioning scheme
- The `version` field can be any string, but must differ from the current CTAN version

### 5.2 Release Automation Tools

#### `googleapis/release-please` (⭐ RECOMMENDED)

- **URL**: https://github.com/googleapis/release-please
- **Marketplace**: https://github.com/marketplace/actions/release-please-action
- **How it works**: Parses conventional commits (`feat:`, `fix:`, `BREAKING CHANGE:`) to auto-determine next version, creates release PR with CHANGELOG, and publishes GitHub release on merge
- **Supports**: Multiple release types; mono-repos; manifest mode

```yaml
jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
    steps:
      - uses: google-github-actions/release-please-action@v4
        id: release
        with:
          release-type: simple  # or use manifest mode for multi-package
          package-name: swarmbeauty
```

**Conventional Commit examples**:
```
feat(beauty): add custom block environment
fix(perf): correct font size in sidebar
docs: update README for CTAN submission
BREAKING CHANGE: rename \swarmTitle to \swarmblockTitle
```

#### Manual Tag-Based Release

```yaml
on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build documentation
        run: |
          pdflatex swarmbeauty.dtx
          makeindex swarmbeauty
          pdflatex swarmbeauty.dtx
      - name: Create release archive
        run: |
          mkdir -p dist
          cp swarmbeauty.sty swarmbeauty.pdf README.md dist/
          cd dist && zip -r ../swarmbeauty-${{ github.ref_name }}.zip .
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: swarmbeauty-*.zip
```

### 5.3 Auto-Generating PDF Documentation on Release

For packages using `.dtx` (documented TeX) format:

```yaml
- name: Build documentation from .dtx
  run: |
    pdflatex swarmbeauty.dtx
    makeindex -s gind.ist swarmbeauty
    makeindex -s gglo.ist -o swarmbeauty.gls swarmbeauty.glo
    pdflatex swarmbeauty.dtx
    pdflatex swarmbeauty.dtx  # 3rd run for cross-references
```

For packages using standalone `.tex` documentation:

```yaml
- name: Build documentation
  run: |
    lualatex -interaction=nonstopmode docs/swarmbeauty-doc.tex
```

### 5.4 Changelog Generation

| Tool | Method | Pros | Cons |
|------|--------|------|------|
| `release-please` | Conventional commits | Automated; PR-based review | Requires commit discipline |
| `conventional-changelog-cli` | Conventional commits | Flexible; npm ecosystem | Needs npm |
| `standard-version` | Conventional commits | Simple | Less maintained |
| Manual `CHANGELOG.md` | Manual editing | Full control | Manual work |
| `github-changelog-generator` | GitHub PRs/issues | Comprehensive | Can be noisy |

**Recommendation**: Use `release-please` with conventional commits — it handles versioning, changelog, and GitHub releases in one action.

### 5.5 Complete Release Pipeline

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    branches: [main]

jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
    steps:
      - uses: google-github-actions/release-please-action@v4
        id: release
        with:
          release-type: simple

  build-and-publish:
    needs: release-please
    if: needs.release-please.outputs.release_created == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: scheme-basic koma-script
      
      - name: Build documentation PDF
        run: pdflatex swarmbeauty.dtx && makeindex swarmbeauty && pdflatex swarmbeauty.dtx
      
      - name: Create CTAN archive
        run: |
          mkdir -p dist
          cp swarmbeauty.sty swarmbeauty.pdf README.md dist/
          cd dist && zip -r ../swarmbeauty.zip .
      
      - name: Upload to GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ needs.release-please.outputs.tag_name }}
          files: swarmbeauty.zip
      
      - name: Submit to CTAN
        uses: paolobrasolin/ctan-submit-action@v2
        with:
          action: upload
          file_path: ./swarmbeauty.zip
          version: ${{ needs.release-please.outputs.tag_name }}
          fields: |
            { "pkg": "swarmbeauty", ... }
        env:
          CTAN_PASSWORD: ${{ secrets.CTAN_PASSWORD }}
```

---

## 6. Recommended GitHub Actions Workflow for This Project

### 6.1 Project Context

```
swarmthemes/
├── swarmbeauty.sty      # Beamer theme (all engines)
├── swarmperf.sty        # Performance theme (all engines)
├── swarmmin.sty         # Minimal theme (all engines)
├── swarmwrap.sty        # Custom package (LuaLaTeX ONLY)
├── metrics.lua          # Lua metrics script
├── compile.py           # Python build script
├── spellcheck.py        # Python spell checker
├── demos/
│   ├── demo-beauty.tex
│   ├── demo-perf.tex
│   └── demo-min.tex
├── install-texlive.sh   # TeX Live portable installer
└── docs/
    └── *.tex            # Documentation files
```

### 6.2 Recommended Workflow File Structure

```
.github/
├── workflows/
│   ├── ci.yml                    # Main CI: compile, lint, test
│   ├── lint.yml                  # Linting (separate for fast feedback)
│   ├── benchmark.yml             # Compilation benchmarking
│   ├── ctan-validate.yml         # CTAN readiness validation
│   └── release.yml               # Release automation
└── chktexrc                      # ChkTeX configuration
```

### 6.3 Workflow 1: Main CI (`ci.yml`)

```yaml
name: CI
on:
  push:
    branches: [main, develop]
    paths:
      - '**.sty'
      - '**.tex'
      - '**.lua'
      - '**.py'
      - '.github/workflows/ci.yml'
  pull_request:
    paths:
      - '**.sty'
      - '**.tex'
      - '**.lua'
      - '**.py'

jobs:
  # ============================================================
  # JOB 1: Compile all themes with all supported engines
  # ============================================================
  compile:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        engine: [pdflatex, xelatex, lualatex]
        theme: [beauty, perf, min]
      fail-fast: false
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: |
            scheme-basic
            koma-script
            fontawesome5
            xcolor
            graphics
            hyperref
            bookmark
      
      - name: Compile ${{ matrix.theme }} with ${{ matrix.engine }}
        run: |
          ${{ matrix.engine }} \
            -interaction=nonstopmode \
            -halt-on-error \
            -file-line-error \
            demos/demo-${{ matrix.theme }}.tex
      
      - name: Upload PDF artifact
        if: matrix.engine == 'lualatex'
        uses: actions/upload-artifact@v4
        with:
          name: demo-${{ matrix.theme }}.pdf
          path: demos/demo-${{ matrix.theme }}.pdf

  # ============================================================
  # JOB 2: LuaLaTeX-only package (swarmwrap.sty + metrics.lua)
  # ============================================================
  compile-lua:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: |
            scheme-basic
            luatexbase
            luaotfload
      
      - name: Verify swarmwrap.sty loads
        run: |
          echo '\\documentclass{article}\\usepackage{swarmwrap}\\begin{document}\\end{document}' > /tmp/test_swarmwrap.tex
          lualatex -interaction=nonstopmode -halt-on-error /tmp/test_swarmwrap.tex

  # ============================================================
  # JOB 3: Python scripts
  # ============================================================
  python-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      
      - name: Install dependencies
        run: |
          pip install --upgrade pip
          pip install pytest pylint mypy
          # Install any project-specific requirements
          test -f requirements.txt && pip install -r requirements.txt || true
      
      - name: Lint Python with pylint
        run: pylint compile.py spellcheck.py --disable=C0114,C0115,C0116 || true
      
      - name: Type check with mypy
        run: mypy compile.py spellcheck.py --ignore-missing-imports || true
      
      - name: Run compile.py help (smoke test)
        run: python3 compile.py --help

  # ============================================================
  # JOB 4: Spell check
  # ============================================================
  spellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      
      - name: Run spellcheck
        run: python3 spellcheck.py || true
        # Make non-blocking initially; can be made blocking later

  # ============================================================
  # JOB 5: Summary (runs after all jobs)
  # ============================================================
  summary:
    needs: [compile, compile-lua, python-checks, spellcheck]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - run: echo "All CI jobs completed."
```

### 6.4 Workflow 2: Linting (`lint.yml`)

```yaml
name: Lint
on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  chktex:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: scheme-basic
      
      - name: Install chktex
        run: sudo apt-get install -y chktex
      
      - name: Copy project chktexrc
        run: cp .github/chktexrc .chktexrc
      
      - name: Run chktex on .sty files
        run: |
          chktex -q swarmbeauty.sty swarmperf.sty swarmmin.sty swarmwrap.sty || true
          # Note: initially non-blocking; tighten as false positives are fixed
      
      - name: Run chktex on demo .tex files
        run: |
          for f in demos/*.tex; do
            echo "Linting $f..."
            chktex -q "$f" || true
          done

  lacheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: scheme-basic
      
      - name: Run lacheck on .sty files
        run: |
          lacheck swarmbeauty.sty swarmperf.sty swarmmin.sty swarmwrap.sty || true
          # Initially non-blocking
      
      - name: Run lacheck on demo .tex files
        run: |
          for f in demos/*.tex; do
            echo "Checking $f..."
            lacheck "$f" || true
          done

  latexindent-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: scheme-basic
      
      - name: Check formatting with latexindent
        run: |
          # Check if files are formatted; don't modify
          latexindent.pl -s -w swarmbeauty.sty
          latexindent.pl -s -w swarmperf.sty
          latexindent.pl -s -w swarmmin.sty
          latexindent.pl -s -w swarmwrap.sty
          git diff --exit-code . || {
            echo "::warning::Some .sty files are not properly formatted."
            echo "Run latexindent.pl locally to fix formatting."
            exit 1
          }
```

### 6.5 Workflow 3: Benchmarking (`benchmark.yml`)

```yaml
name: Benchmark
on:
  pull_request:
    paths:
      - '**.sty'
      - '**.lua'
  workflow_dispatch:  # Manual trigger

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: |
            scheme-basic
            koma-script
            fontawesome5
            xcolor
            graphics
            hyperref
      
      - name: Benchmark compilation times
        run: |
          python3 -c "
import subprocess, time, statistics

def benchmark(cmd, name, runs=10, warmup=2):
            times = []
            for i in range(warmup + runs):
                start = time.perf_counter()
                result = subprocess.run(cmd, capture_output=True, text=True)
                elapsed = time.perf_counter() - start
                if result.returncode != 0:
                    print(f'ERROR compiling {name}: {result.stderr[:200]}')
                    return
                if i >= warmup:
                    times.append(elapsed)
            
            # IQR-based outlier removal
            q1, q3 = statistics.quantiles(times, n=4)[:2]
            iqr = q3 - q1
            filtered = [t for t in times if q1 - 1.5*iqr <= t <= q3 + 1.5*iqr]
            
            mean = statistics.mean(filtered)
            median = statistics.median(filtered)
            stdev = statistics.stdev(filtered) if len(filtered) > 1 else 0
            
            print(f'{name}: mean={mean:.2f}s median={median:.2f}s stdev={stdev:.2f}s (n={len(filtered)})')
            
            # Fail if >20% slower than baseline
            baselines = {'beauty': 5.0, 'perf': 8.0, 'min': 4.0}
            baseline = baselines.get(name, 10.0)
            if mean > baseline * 1.20:
                print(f'WARNING: {name} is >20% slower than baseline ({baseline}s)')
                # Don't fail CI, but create annotation
                # exit(1)

for theme in ['beauty', 'perf', 'min']:
            benchmark(['lualatex', '-interaction=nonstopmode', f'demos/demo-{theme}.tex'], theme)
"
```

### 6.6 Workflow 4: CTAN Validation (`ctan-validate.yml`)

```yaml
name: CTAN Validation
on:
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: |
            scheme-basic
            koma-script
            fontawesome5
      
      - name: Build documentation
        run: |
          # Build docs for each theme
          for theme in beauty perf min; do
            lualatex -interaction=nonstopmode docs/swarm${theme}-doc.tex || true
          done
      
      - name: Check required files
        run: |
          # Verify all required CTAN files exist
          for f in swarmbeauty.sty swarmperf.sty swarmmin.sty swarmwrap.sty README.md; do
            test -f "$f" || { echo "Missing required file: $f"; exit 1; }
          done
      
      - name: Create CTAN archive
        run: |
          mkdir -p dist
          # Copy all theme files
          cp swarmbeauty.sty swarmperf.sty swarmmin.sty swarmwrap.sty metrics.lua dist/
          cp README.md dist/
          # Copy any built documentation
          cp docs/*.pdf dist/ 2>/dev/null || true
          # Create archive
          cd dist && zip -r ../swarmthemes.zip .
      
      - name: Validate with CTAN API
        uses: paolobrasolin/ctan-submit-action@v2
        with:
          action: validate
          file_path: ./swarmthemes.zip
          version: "0.0.0-test"
          fields: |
            {
              "pkg": "swarmthemes",
              "author": "Your Name",
              "email": "you@example.com",
              "uploader": "Your Name",
              "ctanPath": "/macros/latex/contrib/swarmthemes",
              "description": "A collection of Beamer themes for academic presentations, including beauty, performance, and minimal variants with a custom LuaLaTeX wrapping package.",
              "summary": "Beamer themes for academic presentations",
              "update": false,
              "license": "lppl1.3c",
              "repository": "https://github.com/yourname/swarmthemes",
              "bugtracker": "https://github.com/yourname/swarmthemes/issues",
              "support": "https://github.com/yourname/swarmthemes/discussions",
              "topic": "topic:beamer-theme topic:presentation"
            }
```

### 6.7 Workflow 5: Release (`release.yml`)

```yaml
name: Release
on:
  push:
    branches: [main]

jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
    steps:
      - uses: google-github-actions/release-please-action@v4
        id: release
        with:
          release-type: simple
          package-name: swarmthemes
          changelog-path: CHANGELOG.md

  build-and-publish:
    needs: release-please
    if: needs.release-please.outputs.release_created == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: zauguin/install-texlive@v4
        with:
          packages: |
            scheme-basic
            koma-script
            fontawesome5
      
      - name: Build all documentation
        run: |
          for theme in beauty perf min; do
            echo "Building docs for $theme..."
            lualatex -interaction=nonstopmode docs/swarm${theme}-doc.tex
            lualatex -interaction=nonstopmode docs/swarm${theme}-doc.tex  # 2nd pass
          done
      
      - name: Compile all demos
        run: |
          for theme in beauty perf min; do
            lualatex -interaction=nonstopmode demos/demo-${theme}.tex
          done
      
      - name: Create CTAN archive
        run: |
          mkdir -p dist
          cp swarmbeauty.sty swarmperf.sty swarmmin.sty swarmwrap.sty metrics.lua dist/
          cp README.md dist/
          cp docs/*.pdf dist/ 2>/dev/null || true
          cd dist && zip -r ../swarmthemes.zip .
      
      - name: Upload to GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ needs.release-please.outputs.tag_name }}
          files: |
            swarmthemes.zip
            demos/demo-*.pdf
      
      - name: Submit to CTAN
        uses: paolobrasolin/ctan-submit-action@v2
        with:
          action: upload
          file_path: ./swarmthemes.zip
          version: ${{ needs.release-please.outputs.tag_name }}
          fields: |
            {
              "pkg": "swarmthemes",
              "author": "Your Name",
              "email": "you@example.com",
              "uploader": "Your Name",
              "ctanPath": "/macros/latex/contrib/swarmthemes",
              "description": "A collection of Beamer themes for academic presentations.",
              "summary": "Beamer themes for academic presentations",
              "update": true,
              "license": "lppl1.3c",
              "repository": "https://github.com/yourname/swarmthemes",
              "bugtracker": "https://github.com/yourname/swarmthemes/issues",
              "support": "https://github.com/yourname/swarmthemes/discussions",
              "topic": "topic:beamer-theme topic:presentation",
              "announcement": "New version of swarmthemes available."
            }
        env:
          CTAN_PASSWORD: ${{ secrets.CTAN_PASSWORD }}
```

### 6.8 Required GitHub Secrets

| Secret | Purpose | How to Get |
|--------|---------|------------|
| `CTAN_PASSWORD` | CTAN API authentication for uploads | Register at CTAN; password set in your CTAN profile |

### 6.9 Estimated CI Times

| Workflow | First Run | Cached Run | Trigger |
|----------|-----------|------------|---------|
| `ci.yml` (full matrix: 3×3 + Lua) | 8-12 min | 2-4 min | Push/PR |
| `lint.yml` | 3-5 min | 1-2 min | Push/PR |
| `benchmark.yml` | 5-8 min | 3-5 min | PR (.sty/.lua changes) |
| `ctan-validate.yml` | 4-6 min | 2-3 min | PR to main |
| `release.yml` | 5-8 min | 3-5 min | Push to main |

---

## Summary of Key Recommendations

### Tool Choices

| Need | Recommendation | Alternative |
|------|---------------|-------------|
| **TeX Live in CI** | `zauguin/install-texlive@v4` | `TeX-Live/setup-texlive-action@v3` |
| **LaTeX compilation** | `latexmk` or direct engine call | `xu-cheng/latex-action` (for simple cases) |
| **Linting** | `chktex` (configured) + `lacheck` | texlab (local only) |
| **Formatting** | `latexindent.pl` (check mode in CI) | N/A |
| **Python linting** | `pylint` + `mypy` | `ruff` (faster) |
| **Benchmarking** | Python `time.perf_counter()` with statistics | `l3benchmark` (internal only) |
| **CTAN validation** | `paolobrasolin/ctan-submit-action` | `zauguin/ctan-upload` |
| **Release automation** | `googleapis/release-please` | Manual tag-based |
| **CTAN upload** | `paolobrasolin/ctan-submit-action` (upload mode) | `ctan-o-mat` (CLI) |
| **Changelog** | `release-please` (automatic) | `CHANGELOG.md` (manual) |

### Implementation Priority

1. **Phase 1** (Immediate): `ci.yml` — basic compilation tests across engines
2. **Phase 2** (Week 1): `lint.yml` — chktex + lacheck with configured suppressions
3. **Phase 3** (Week 2): `benchmark.yml` — compilation timing baseline
4. **Phase 4** (Pre-CTAN): `ctan-validate.yml` — CTAN readiness checks
5. **Phase 5** (Post-CTAN): `release.yml` — automated releases and CTAN uploads

### Key URLs Referenced

- `zauguin/install-texlive`: https://github.com/zauguin/install-texlive
- `TeX-Live/setup-texlive-action`: https://github.com/TeX-Live/setup-texlive-action
- `xu-cheng/latex-action`: https://github.com/xu-cheng/latex-action
- `xu-cheng/texlive-action`: https://github.com/xu-cheng/texlive-action
- `dante-ev/docker-texlive`: https://github.com/dante-ev/docker-texlive
- `latex3/latex2e` CI: https://github.com/latex3/latex2e/blob/develop/.github/workflows/main.yaml
- `islandoftex/github-actions-l3build`: https://github.com/islandoftex/github-actions-l3build
- `DanySK/Template-LaTeX-CI`: https://github.com/DanySK/Template-LaTeX-CI
- `Witiko/markdown`: https://github.com/Witiko/markdown
- `j2kun/chktex-action`: https://github.com/j2kun/chktex-action
- `chktex documentation`: https://www.nongnu.org/chktex/ChkTeX.pdf
- `latexindent.pl`: https://github.com/cmhughes/latexindent.pl
- `texlab LSP`: https://github.com/latex-lsp/texlab
- `Stuttgart LaTeX Benchmark`: https://web.itp3.uni-stuttgart.de/latex-benchmark
- `paolobrasolin/ctan-submit-action`: https://github.com/paolobrasolin/ctan-submit-action
- `zauguin/ctan-upload`: https://github.com/zauguin/ctan-upload
- `ge-ne/ctan-o-mat`: https://github.com/ge-ne/ctan-o-mat
- `CTAN submit API`: https://ctan.org/help/submit
- `googleapis/release-please`: https://github.com/googleapis/release-please
- `latex3/l3build`: https://github.com/latex3/l3build
- `l3benchmark`: https://www.latex-project.org/news/2018/10/28/benchmarking
- `PHPirates/travis-ci-latex-pdf`: https://github.com/PHPirates/travis-ci-latex-pdf (comparison of approaches)
