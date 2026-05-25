#!/usr/bin/env python3
"""Build test-stress-1000.pdf by compiling 6 independent parts and merging."""
import subprocess, fitz, os, re, sys

BASE = '/home/z/my-project/swarm/tests'
SRC = os.path.join(BASE, 'test-stress-1000.tex')
TEXLATEX = '/home/z/my-project/swarm/texlive/bin/x86_64-linux/lualatex'
ENV = dict(os.environ, TEXINPUTS=f'.:../src/themes:', LUAINPUTS=f'.:../src/themes:')

with open(SRC) as f:
    lines = f.readlines()

# Find section boundaries
sections = []
for i, line in enumerate(lines):
    m = re.match(r'\\section\{Section (\d+)\}', line)
    if m:
        sections.append((i, int(m.group(1))))

PREAMBLE = ''.join(lines[:10])  # \documentclass .. \begin{document}
POSTAMBLE = '\n\\end{document}\n'

# Split into ~6 parts at section boundaries (target ~180 figures each)
PART_SIZE = 2  # sections per part (each section = 50 figures)
parts = []
for start_idx in range(0, len(sections), PART_SIZE):
    end_idx = min(start_idx + PART_SIZE, len(sections))
    start_line = sections[start_idx][0]
    end_line = sections[end_idx][0] if end_idx < len(sections) else len(lines)
    parts.append((start_line, end_line, start_idx // PART_SIZE + 1))

print(f'Splitting into {len(parts)} parts')

pdf_files = []
for start, end, num in parts:
    part_tex = os.path.join(BASE, f'_stress_p{num}.tex')
    part_pdf = os.path.join(BASE, f'_stress_p{num}.pdf')
    
    with open(part_tex, 'w') as f:
        f.write(PREAMBLE)
        f.writelines(lines[start:end])
        f.write(POSTAMBLE)
    
    print(f'\nCompiling part {num} ({end - start} lines)...')
    result = subprocess.run(
        [TEXLATEX, '--interaction=nonstopmode', f'_stress_p{num}.tex'],
        cwd=BASE, env=ENV, capture_output=True, text=True, timeout=300
    )
    
    if result.returncode != 0:
        # Check for fatal errors
        if 'Fatal error' in result.stdout or 'Fatal error' in result.stderr:
            print(f'  FATAL ERROR in part {num}:')
            for line in result.stdout.split('\n')[-10:]:
                print(f'    {line}')
            sys.exit(1)
    
    if os.path.exists(part_pdf):
        doc = fitz.open(part_pdf)
        print(f'  -> {doc.page_count} pages')
        doc.close()
        pdf_files.append(part_pdf)
    else:
        print(f'  ERROR: No PDF produced for part {num}')
        sys.exit(1)

# Merge
print(f'\nMerging {len(pdf_files)} PDFs...')
merged = fitz.open()
for pf in pdf_files:
    merged.insert_pdf(fitz.open(pf))
merged.save(os.path.join(BASE, 'test-stress-1000.pdf'))
merged.close()

final = fitz.open(os.path.join(BASE, 'test-stress-1000.pdf'))
print(f'Final PDF: {final.page_count} pages')
final.close()

# Cleanup temp files
for pf in pdf_files:
    os.remove(os.path.join(BASE, os.path.basename(pf).replace('.pdf', '.tex')))
    os.remove(os.path.join(BASE, os.path.basename(pf).replace('.pdf', '.log')))
    os.remove(os.path.join(BASE, os.path.basename(pf).replace('.pdf', '.aux')))
    os.remove(pf)

print('Done!')
