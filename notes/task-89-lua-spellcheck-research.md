# Pure-Lua Spellcheck: Research & Benchmark (Task #89)

## Executive Summary

**Recommendation: Keep the Python approach.** A pure-Lua spellcheck running inside LuaLaTeX is technically ~0.1-0.2s faster on a fast machine and ~0.3-1.0s faster on a Raspberry Pi, but the disadvantages (LuaLaTeX-only, 14-20 MB memory overhead, no CI output formats, no suggestions, callback complexity) far outweigh the modest speed gain.

---

## 1. Research: Existing Lua Spellcheck Solutions

### 1.1 Existing Libraries

| Library | Status | Notes |
|---------|--------|-------|
| `lua-spellcheck` | Not found on LuaRocks/CPAN | No active Lua spellcheck library exists |
| Hunspell Lua bindings (`luaffi`) | Requires LuaJIT FFI | Native C dependency, engine-specific |
| `hunspell` CLI via `os.execute()` | Possible but slow | Process spawn overhead defeats the purpose |

**Finding**: There is no mature, pure-Lua spellcheck library. Any implementation would need to be built from scratch using a word list file and hash table lookups.

### 1.2 Dictionary Options

| Source | Format | Size | Words |
|--------|--------|------|-------|
| pyspellchecker `en.json.gz` | JSON (gzip) | 651 KB / 2.8 MB uncompressed | 160,572 |
| `/usr/share/dict/words` | Plain text | Not available on VM | N/A |
| Custom plain text | One word/line | 1.5 MB | 160,572 |

The pyspellchecker English word list (160K words) is the most practical source. A plain-text extraction was created at `src/lua/en-dictionary.txt` for benchmarking.

---

## 2. Benchmark Results

### 2.1 Current Python Approach (Two-Pass)

```
Demo file          | Words | Misspellings | Python time | LuaLaTeX time | Total
demo-beautiful.tex |   533 |            2 |       0.30s |         2.96s | 3.26s
demo-performance.tex|   350 |            0 |       0.19s |         1.09s | 1.28s
demo-minimal.tex    |   419 |            1 |       0.25s |         0.96s | 1.21s
```

- Python time includes: interpreter startup (~0.06s), pyspellchecker import (~0.08s), word extraction + dictionary lookup
- LuaLaTeX time is standalone compilation (no spellcheck)

### 2.2 Proposed Lua Approach (Single-Pass)

Measured inside LuaLaTeX using `texlua` and `\directlua{dofile(...)}`:

```
Metric                      | Standalone texlua | Inside LuaLaTeX
Dictionary load (160K words)|              0.11s |           0.08s
600 word lookups            |            <0.001s |          <0.001s
Total Lua overhead          |              0.11s |           0.08s
Dictionary memory           |             14.2 MB |          20.6 MB
```

### 2.3 Comparison

| Metric | Python (two-pass) | Lua (single-pass) | Winner |
|--------|-------------------|-------------------|--------|
| Spellcheck overhead | 0.19-0.30s | 0.08-0.11s | **Lua** by ~0.1-0.2s |
| Total pipeline (minimal) | 1.21s | ~1.04s | **Lua** by ~0.2s |
| Total pipeline (beautiful) | 3.26s | ~3.04s | **Lua** by ~0.2s |
| Memory overhead | ~30 MB (Python process) | +14-20 MB (Lua table) | Python (external) |
| pdfLaTeX compatible | Yes | **No** | **Python** |
| XeLaTeX compatible | Yes | **No** | **Python** |
| JSON output for CI | Yes | **No** | **Python** |
| Spelling suggestions | Yes | **No** | **Python** |
| Custom dictionary file | Yes | Possible | Tie |
| Standalone tool | Yes | **No** | **Python** |

### 2.4 Raspberry Pi Estimate

On a Raspberry Pi 4 (ARM Cortex-A72, ~3x slower than this VM):

| Metric | Python | Lua |
|--------|--------|-----|
| Python startup | ~0.5-1.0s | N/A |
| Dictionary load | N/A | ~0.2-0.4s |
| Spellcheck (600 words) | ~0.05-0.10s | ~0.001s |
| LuaLaTeX compilation | 3-15s | 3-15s |
| **Total savings** | — | **~0.3-0.9s** |

Even on a Raspberry Pi, the savings are modest (0.3-0.9s out of 3-15s total compilation time, or ~3-6%).

---

## 3. Technical Challenges of Lua Approach

### 3.1 Word Interception

TeX processes text as tokens, not words. To intercept words during typesetting:
- `process_input_buffer`: Processes input before TeX tokenization. Can match word patterns in the raw input stream. Fragile — breaks inside macro expansions, verbatim, etc.
- `pre_linebreak_filter`: Processes node lists after line breaking. Can inspect glyph nodes, but word boundaries span multiple nodes (hyphenation, ligatures, kerning).
- `post_linebreak_filter`: Too late — pages already composed.

**Conclusion**: Accurate word interception from Lua callbacks is significantly harder than Python's line-by-line text extraction. The Python `TexExtractor` has mature handling for LaTeX constructs (math, commands, environments, comments). Replicating this in Lua would require substantial effort and would still be less accurate.

### 3.2 Callback Conflicts

LuaLaTeX already uses callbacks for:
- `luaotfload` (font processing): `pre_linebreak_filter`, `hpack_filter`, `glyph_stream_provider`
- Our `metrics.lua`: various Lua callbacks

Adding spellcheck callbacks would need to coexist with these, increasing complexity and potential for interaction bugs.

### 3.3 Dictionary File Distribution

A 1.5 MB dictionary file would need to be bundled with the toolkit, increasing package size. Alternatively, users would need to install `hunspell` or `aspell` separately.

---

## 4. Recommendation: Keep Python Approach

The Python approach (`scripts/spellcheck.py`) should remain the primary spellcheck mechanism. The speed savings from Lua (~0.1-0.2s on fast machines, ~0.3-0.9s on Raspberry Pi) do not justify the tradeoffs:

1. **LuaLaTeX-only** — swarmperf and swarmmin themes target pdfLaTeX compatibility
2. **No CI output** — JSON and terminal formats are essential for automated pipelines
3. **No suggestions** — users need "did you mean X?" for productivity
4. **Memory** — 14-20 MB is significant on a Raspberry Pi (1-4 GB RAM)
5. **Callback complexity** — fragile word interception, conflicts with existing callbacks
6. **Implementation effort** — replicating TexExtractor's LaTeX handling in Lua is ~500+ lines of fragile code

### Alternative Optimizations for Raspberry Pi

1. **Cache helper files**: Only re-run `spellcheck.py` when the `.tex` source changes (compare mtime). Avoids redundant Python runs during iterative editing.
2. **Lightweight mode**: Add a `--fast` flag that uses a smaller dictionary (top 50K words) for ~40% faster dictionary loading.
3. **Daemon mode**: Run `spellcheck.py` as a background daemon that watches files and pre-generates helper files, eliminating Python startup latency.
4. **Pre-compiled word lists**: Ship a Lua-table-format dictionary file (using `string.dump` or a binary format) for faster loading.

---

## 5. Artifacts

- `src/lua/en-dictionary.txt` — Plain-text English dictionary (160,572 words, 1.5 MB), extracted from pyspellchecker for benchmarking. Can be deleted if not needed for future work.
