# swarmwrap.sty

A LaTeX package for wrapping text around right-side figures. Built from scratch after all 9 existing LaTeX wrapping packages failed QA testing.

## Requirements

- **LuaLaTeX** (falls back to centered float with pdfLaTeX/XeLaTeX)

## Installation

1. Place `swarmwrap.sty` in your project directory (or in your TeX tree)
2. Add `\usepackage{swarmwrap}` to your preamble

## Usage

### Basic figure (single element)

```latex
\begin{swarmwrap}%
  \includegraphics[width=3cm]{photo}%
\end{swarmwrap}%
\swarmwrapnext
Paragraph text wraps around the figure.
```

### Figure with caption

```latex
\begin{swarmwrap}%
  \begin{minipage}[t]{3cm}
    \centering
    \includegraphics[width=\linewidth]{photo}
    \captionof{figure}{Caption.}
  \end{minipage}%
\end{swarmwrap}%
\swarmwrapnext
Paragraph text wraps around the figure.
```

## How It Works

1. `\begin{swarmwrap}...\end{swarmwrap}` captures content into an `lrbox` (zero-width savebox)
2. Width and height are auto-detected from the rendered box — no arguments needed
3. `\swarmwrapnext` computes a `\parshape` that narrows the text, then overlays the figure on the right via `\smash{\rlap{...}}`
4. Page break detection: if insufficient space remains on the current page, `\newpage` is inserted automatically

## Limitations

- **Right-side only** — left-wrap removed in v3.0
- **One wrap per paragraph**
- **Cannot span page breaks** (fundamental `\parshape` limitation)
- **Figure width is set by content** — use `\includegraphics[width=3cm]` or `\begin{minipage}[t]{3cm}` to control size

## API Reference

| Command | Description |
|---------|-------------|
| `\begin{swarmwrap}...\end{swarmwrap}` | Captures content into a savebox (zero arguments) |
| `\swarmwrapnext` | Applies parshape to the following paragraph and places the figure |

## Changelog

### v3.0 (2026-05-18)
- Zero-argument API: width and height auto-detected from content
- Right-side wrapping only (left-wrap code removed)
- Gap increased to 14pt (0.5cm)
- Parshape computation moved to `\swarmwrapnext` (correct `\linewidth` capture in multicol/itemize)
- Page break detection (from v2.2)
- Trailing full-width parshape reset line (from v2.0)
- `\emergencystretch` for overfull hbox absorption (from v2.4)

### v2.5 (2026-05-17)
- Fixed left-wrap figure placement (6pt overlap)

### v2.2 (2026-05-17)
- Page break detection via `\pagegoal` / `\pagetotal`

### v2.0 (2026-05-17)
- Height auto-detected from actual box dimensions
- `\smash{\rlap}` figure overlay (zero interference with line layout)
