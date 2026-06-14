"""Detect ghost narrowing: lines narrower than linewidth without a figure beside them."""
import fitz, sys

pdf_path = sys.argv[1]
doc = fitz.open(pdf_path)
PAGE_W = 595.28  # A4 width in points
MARGIN = 85.0   # approximate left+right margin for article class

full_text_width = PAGE_W - 2 * MARGIN  # expected linewidth (~425pt)
ghost_threshold = full_text_width - 20  # lines narrower than this might be ghost-narrowed
ghost_instances = []

for page_num in range(len(doc)):
    page = doc[page_num]
    blocks = page.get_text("blocks")
    for b in blocks:
        x0, y0, x1, y1, text, block_no, block_type = b
        line_width = x1 - x0
        # Skip empty, very short, or non-text blocks
        if block_type != 0 or len(text.strip()) < 20:
            continue
        # Check if this is a narrow line in the body text area
        if x0 < MARGIN + 5 and line_width < ghost_threshold and line_width > 50:
            # This line starts at the left margin but is narrower than full width
            # Could be ghost narrowing or a list item
            text_preview = text.strip()[:80]
            ghost_instances.append({
                'page': page_num + 1,
                'y': y0,
                'width': line_width,
                'text': text_preview
            })

print(f"PDF: {pdf_path}")
print(f"Pages: {len(doc)}")
print(f"Potentially ghost-narrowed lines: {len(ghost_instances)}")
for g in ghost_instances:
    print(f"  p{g['page']:2d} y={g['y']:6.1f} w={g['width']:6.1f}pt: {g['text']}")
doc.close()
