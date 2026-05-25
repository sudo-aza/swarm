# Programmer Verification Guide — swarmwrap.sty

> **CRITICAL**: Read this before marking ANY task as `done`. Every claim of a fix MUST be backed by the verification commands below.

## 1. Detection Script (Automated)

```bash
export PATH="/home/z/my-project/swarm/texlive/bin/x86_64-linux:$PATH"
cd /home/z/my-project/swarm
python3 scripts/detect-layout-issues.py tests/test-stress-50.pdf --quality
```

### Expected output for a PASSING version:
```
  PASS GHOST NARROWING: 0
  PASS HOLLOW CARRY-OVER: 0
  QUALITY SCORE: 49/50 (98.0%) [PASS]
```

### What was wrong before (v3.25/v3.26/v3.28/v3.29):
```
  FAIL GHOST NARROWING: 9       ← text stuck at 43.6% width on every page
  FAIL HOLLOW CARRY-OVER: 9
  QUALITY SCORE: 31/50 (62.0%) [FAIL]
```

## 2. PyMuPDF Width Check (Independent — MANDATORY)

**This is the check that catches the `hbox.width` vs `span.bbox` mistake from v3.29.**

The v3.29 Lua callback changed `hbox.width` to `linewidth`, which made PyMuPDF report 359pt per line. But the actual TEXT GLYPHS were still at 259.7pt — the callback only changed the reference width, not the content.

```python
import fitz

doc = fitz.open("tests/test-stress-50.pdf")
narrow_pages = 0
full_pages = 0
for pn in range(len(doc)):
    page = doc[pn]
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]
    max_span = 0
    for block in blocks:
        if block["type"] != 0:
            continue
        for line in block["lines"]:
            for span in line["spans"]:
                text = span["text"].strip()
                if not text or span["size"] < 9:
                    continue
                # SPAN width = actual visual extent of text glyphs
                span_width = span["bbox"][2] - span["bbox"][0]
                if span_width > max_span:
                    max_span = span_width
    # A4 page is 595.3pt. Normal text spans 350-360pt.
    # Ghost-narrowed text spans ~260pt (43.6%).
    if max_span < 300:
        narrow_pages += 1
        print(f"  p{pn+1}: NARROW — max text span = {max_span:.1f}pt (< 300pt)")
    else:
        full_pages += 1

print(f"\nResult: {full_pages} full-width pages, {narrow_pages} narrow pages out of {len(doc)}")
doc.close()
```

### Expected output for a PASSING version:
```
Result: 50 full-width pages, 0 narrow pages out of 50
```

### What v3.29 reported (WRONG — measured hbox width, not text span):
```
Result: 37 full-width pages, 0 narrow pages out of 50
```

### What v3.25/v3.26/v3.28/v3.29 actually produced (CORRECT measurement):
```
  p1: NARROW — max text span = 259.7pt (< 300pt)
  p2: NARROW — max text span = 259.7pt (< 300pt)
  ... (all 50 pages)
Result: 0 full-width pages, 50 narrow pages out of 50
```

## 3. Key Difference: `hbox.width` vs `span.bbox`

When using Lua's `post_linebreak_filter` to modify line widths:

- `hbox.width` = the TeX hbox reference width. Changing this via `current.width = tex.dimen["linewidth"]` DOES change what PyMuPDF reports as the line width when you iterate over `page.get_text("blocks")` and measure `line["bbox"]`.
- `span["bbox"][2] - span["bbox"][0]` = the actual visual extent of text glyphs. This is NOT affected by changing `hbox.width` in the callback. The glyphs remain at their original narrow positions.

**To verify text is ACTUALLY wide, always measure span widths, not line/hbox widths.**

## 4. Common Mistakes

1. **Measuring line width instead of span width**: `line["bbox"][2] - line["bbox"][0]` measures the hbox width (can be spoofed by Lua callback). Always drill down to `span["bbox"]`.
2. **Using the broken detection script without cross-validation**: The old `detect-layout-issues.py` v7 had a relative baseline that reported "0 ghost-narrowing" on a 100% narrow page. Always run the PyMuPDF span check alongside.
3. **Marking a task done based on detection script output alone**: The detection script is one data point. Always include the PyMuPDF span check output in the comm log.
4. **Self-closing tasks without QA review**: Per qa-rules.md Rule 9, tasks must not be marked `done` until QA has reviewed and approved. Create a QA review task after committing the fix.
