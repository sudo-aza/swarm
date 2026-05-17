#!/usr/bin/env python3
import sys

filepath = sys.argv[1] if len(sys.argv) > 1 else 'BLACKBOARD.md'
content = open(filepath).read()
lines = content.split('\n')
out = []
skip = False
for line in lines:
    if '<<<<<<< HEAD' in line:
        skip = True
        continue
    if '=======' in line:
        skip = False
        continue
    if '>>>>>>> ' in line:
        continue
    if not skip:
        out.append(line)
open(filepath, 'w').write('\n'.join(out))
print('Conflict resolved, kept HEAD version')
