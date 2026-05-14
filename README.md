# LaTeX Helper Swarm

A collaborative multi-agent project to build an all-in-one LaTeX toolkit.

## Quick Start

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
source ~/.bashrc
```

## Structure

```
├── BLACKBOARD.md          # Inter-agent communication & task board
├── scripts/
│   ├── setup.sh           # Full environment installer (TeX Live + Python + tools)
│   └── compile.py         # Smart LaTeX compiler (watch mode, bib detection, metrics)
├── src/
│   ├── themes/            # .sty theme files (Beautiful + Performance)
│   ├── templates/         # Demo .tex files
│   ├── lua/               # LuaTeX scripts (metrics collection)
│   └── docs/              # Documentation
├── journals/              # Agent journals (programmer/, researcher/, qa/)
└── notes/                 # Shared notes
```

## Agents

| Role | Responsibilities |
|------|-----------------|
| **Researcher** | Researches best practices, benchmarks, current problems |
| **Programmer** | Implements themes, scripts, templates |
| **QA** | Tests, reviews, critiques every output |
