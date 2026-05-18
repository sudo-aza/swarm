# LaTeX Helper Swarm

A multi-agent collaborative project building an **all-in-one LaTeX toolkit** — four document themes, smart compilation scripts, LuaTeX metrics, and an integrated spell checker.

## Quick Start

```bash
git clone https://github.com/sudo-aza/swarm.git
cd swarm
chmod +x scripts/setup.sh
./scripts/setup.sh          # installs TeX Live + Python deps
source ~/.bashrc
python3 scripts/compile.py src/templates/demo-beautiful.tex
```

If TeX Live is already installed elsewhere, skip it with `./scripts/setup.sh --skip-texlive`.

## Themes

Four themes with a **unified API** — swap one `\usepackage` line and your document still compiles.

| Theme | Package | Engines | Description |
|-------|---------|---------|-------------|
| **Beautiful** | `swarmbeauty` (v0.5.0) | LuaLaTeX, XeLaTeX | Full-featured: TikZ title page, minted code blocks, tcolorbox environments, styled TOC, custom color palette |
| **Performance** | `swarmperf` (v1.2) | pdfLaTeX, XeLaTeX, LuaLaTeX | Fast compilation (3-9x), zero external deps, uses `listings` instead of `minted` |
| **Minimal** | `swarmmin` (v2.0) | pdfLaTeX, XeLaTeX, LuaLaTeX | Ultra-minimal: lazy-load only what you need, no colors, no decorations, maximum speed |
| **Wrap** | `swarmwrap` (v3.6) | LuaLaTeX only | Right-side text wrapping around figures via `\parshape` — built after all 9 existing packages failed QA |

### Usage

```latex
\documentclass[11pt, a4paper]{scrartcl}
\usepackage{swarmbeauty}   % swap to swarmperf, swarmmin, or swarmwrap

\title{My Document}
\author{Author Name}

\begin{document}
\swarmtitlepage

\begin{noteblock}{Tip}{}
  Block environments work across all themes.
\end{noteblock}

\begin{theorem}{Euler}{euler}
  $e^{i\pi} + 1 = 0$
\end{theorem}
\end{document}
```

Compile with:
```bash
python3 scripts/compile.py myfile.tex
```

## Scripts

### `compile.py` — Smart Compiler (v2.5)

Handles engine detection, multi-pass compilation, bibliography reruns, cleanup, and benchmarking.

```bash
python3 scripts/compile.py doc.tex                    # auto-detect engine
python3 scripts/compile.py doc.tex --engine lualatex   # force engine
python3 scripts/compile.py doc.tex --watch              # recompile on save
python3 scripts/compile.py doc.tex --clean              # remove aux files
python3 scripts/compile.py doc.tex --benchmark 5        # 5-run benchmark
```

### `spellcheck.py` — LaTeX Spell Checker (v1.0)

Spell checks `.tex` files while ignoring math, code blocks, and commands.

```bash
python3 scripts/spellcheck.py doc.tex                   # print misspellings
python3 scripts/spellcheck.py doc.tex --format json     # JSON output
python3 scripts/spellcheck.py doc.tex --format tex      # generate helper .tex
python3 scripts/spellcheck.py doc.tex --dict custom.txt # custom dictionary
```

A project-local `.swarm-dictionary` file (one word per line) is loaded automatically.

### `metrics.lua` — Document Metrics (v3.1)

Collects compilation time, page count, word count, included files, PDF size, and structure counters. Requires LuaLaTeX.

```latex
\documentclass{scrartcl}
\directlua{dofile("src/lua/metrics.lua")}
% ... compile with lualatex, then check metrics-output.json
```

The `finalize_metrics()` step in `compile.py` post-processes the JSON after compilation.

### `setup.sh` — Environment Installer

Installs TeX Live (portable, scheme-small), Python dependencies, and bash aliases.

```bash
./scripts/setup.sh              # full install
./scripts/setup.sh --skip-system # skip apt-get
./scripts/setup.sh --skip-texlive # skip TeX Live
```

## Project Structure

```
swarm/
├── BLACKBOARD.md            # Inter-agent task board
├── README.md
├── scripts/
│   ├── setup.sh             # Environment installer
│   ├── compile.py           # Smart LaTeX compiler
│   ├── spellcheck.py        # LaTeX-aware spell checker
│   ├── analyze-wrapping.py  # Wrap test analysis helper
│   └── test-wrapping.sh     # Wrap test runner
├── src/
│   ├── themes/
│   │   ├── swarmbeauty.sty  # Beautiful theme (v0.5.0)
│   │   ├── swarmperf.sty    # Performance theme (v1.2)
│   │   ├── swarmmin.sty     # Minimal theme (v2.0)
│   │   ├── swarmwrap.sty    # Float wrapper (v3.6)
│   │   └── spellcheck.sty   # Spellcheck styling
│   ├── templates/
│   │   ├── demo-beautiful.tex
│   │   ├── demo-performance.tex
│   │   ├── demo-minimal.tex
│   │   └── metrics-test.tex
│   ├── lua/
│   │   └── metrics.lua      # Document metrics collector
│   └── test-wrapfig/        # Wrap package test suite
├── journals/                # Agent work journals
└── notes/                   # Shared research notes
```

## Agents

| Role | Directory | Responsibilities |
|------|-----------|-----------------|
| **Researcher** | `journals/researcher/` | Researches packages, benchmarks, best practices |
| **Programmer** | `journals/programmer/` | Implements themes, scripts, fixes bugs |
| **QA** | `journals/qa/` | Tests, reviews, rates every output |

Task board and status are tracked in `BLACKBOARD.md`.
