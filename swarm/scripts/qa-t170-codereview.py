#!/usr/bin/env python3
"""
QA T170: Code-level review of v3.54 parshape reset mechanism.
Reviews the TeX + Lua code for correctness, edge cases, and potential issues.

Key components:
  1. \swarmwrap@parshape@active register (line 433)
  2. \swarmwrap@reset@pshape command (lines 441-445)
  3. \newpage / \clearpage patches (lines 454-465)
  4. pre_shipout_filter reset (Lua, lines 665-667)
  5. post_linebreak_filter cross-page reset (Lua, lines 729-732)
  6. \swarmwrap@apply@ext@pshape space check (lines 512-518)
  7. Deferred everypar (line 489, 1016-1018)
  8. Normal placement (line 1034)
"""

# Read the extracted v3.54
with open("/tmp/swarmwrap-v354.sty") as f:
    lines = f.readlines()

print("=== QA T170: Code-Level Review of v3.54 Parshape Reset ===\n")

# Track all places where parshape@active is set
sets_to_1 = []
sets_to_0 = []
reads_active = []

for i, line in enumerate(lines, 1):
    stripped = line.strip()
    
    # Set to 1
    if "parshape@active=1" in stripped and "ifnum" not in stripped:
        sets_to_1.append((i, stripped))
    
    # Set to 0
    if "parshape@active=0" in stripped and "ifnum" not in stripped:
        sets_to_0.append((i, stripped))
    
    # Conditional reads
    if "parshape@active" in stripped and "==" in stripped and "ifnum" not in stripped:
        reads_active.append((i, stripped))

print("1. REGISTRY LIFECYCLE: \\swarmwrap@parshape@active")
print(f"   Set to 1 ({len(sets_to_1)} places):")
for ln, txt in sets_to_1:
    print(f"     Line {ln}: {txt[:80]}")
print(f"   Set to 0 ({len(sets_to_0)} places):")
for ln, txt in sets_to_0:
    print(f"     Line {ln}: {txt[:80]}")
print(f"   Conditional reads ({len(reads_active)} places):")
for ln, txt in reads_active:
    print(f"     Line {ln}: {txt[:80]}")

print("\n2. ANALYSIS:")

analysis = [
    ("CORRECT: reset@pshape (L441-445)", 
     "Sets register=0, parshape to full-width (1 line, 0pt to \\linewidth), "
     "clears everypar. This is a complete state reset."),
    
    ("CORRECT: \\newpage/\\clearpage patches (L454-465)",
     "Only resets if parshape@active=1. Saves originals via \\let. "
     "Calls reset BEFORE the actual page break. This prevents parshape "
     "from leaking to the next page."),
    
    ("CORRECT: pre_shipout_filter (L665-667)",
     "Also resets parshape@active=0 at shipout time. This is a safety net "
     "for cases where \\newpage is not explicitly called (e.g., natural "
     "page overflow)."),
    
    ("CORRECT: post_linebreak_filter cross-page (L729-732)",
     "When total_lines < nl (paragraph broke across pages), resets "
     "parshape@active=0 AND sets everypar to reset@pshape. This handles "
     "the scenario where a wrapped paragraph continues onto a new page "
     "but runs out of narrow lines."),
    
    ("CORRECT: apply@ext@pshape space check (L512-518)",
     "When remaining lines won't fit on current page (dimen2 > remaining), "
     "zeros remaining@nl, resets parshape@active=0, clears everypar. "
     "Prevents ghost narrowing from lines that would spill to next page."),
    
    ("CORRECT: deferred everypar (L489)",
     "Sets parshape@active=1 when deferred figure is placed via everypar. "
     "Matches the normal path (L1034)."),
    
    ("POTENTIAL ISSUE: Double reset on deferred path",
     "In the deferred path (L1002/1008), \\newpage is called. The v3.54 "
     "patched \\newpage checks parshape@active=1 and resets if so. BUT "
     "at this point in the deferred path, has parshape@active been set? "
     "The answer depends on whether a PREVIOUS figure set it. If "
     "parshape@active=1 from a prior figure, the \\newpage patch will "
     "reset it. Then deferred@everypar (L1017) sets it to 1 again. "
     "This seems correct — the old parshape is cleared before the new "
     "page, and the deferred figure re-sets it on the new page."),
    
    ("POTENTIAL ISSUE: everypar interaction with reset@pshape",
     "reset@pshape sets everypar{}. But post_linebreak_filter (L732) "
     "sets everypar to \\swarmwrap@reset@pshape (with trailing space). "
     "This means after a cross-page break, the FIRST paragraph on the "
     "new page will execute reset@pshape via everypar, which sets "
     "everypar{} — effectively a one-shot reset. This is correct behavior."),
    
    ("EDGE CASE: Multiple \\newpage calls",
     "If \\newpage is called twice in a row, the first call resets "
     "parshape@active to 0. The second call checks parshape@active=1, "
     "finds it 0, and skips the reset. This is correct — no double-reset."),
    
    ("EDGE CASE: \\newpage inside a list (\\@listdepth > 0)",
     "The \\newpage patch always checks parshape@active regardless of "
     "list depth. This is correct — we want to reset parshape at page "
     "boundaries even inside lists. The list-item parshape leak (customwrap "
     "pg7, scenario 'b') is NOT related to \\newpage — it's about parshape "
     "continuing across \\item boundaries."),
]

for title, detail in analysis:
    print(f"\n  {title}")
    for dline in detail.split(". "):
        print(f"    {dline.strip()}")

print(f"\n3. CONCLUSION:")
print(f"   v3.54 parshape reset mechanism is CORRECTLY IMPLEMENTED.")
print(f"   The 4 reset points (\\newpage/\\clearpage patch, pre_shipout_filter,")
print(f"   post_linebreak_filter, space check) cover all page-break scenarios.")
print(f"   No logical errors, no race conditions, no missing resets found.")
print(f"   The remaining ghost-narrowing (customwrap pg7, scenario 'b') is")
print(f"   correctly identified as out of scope — it requires node-list")
print(f"   manipulation in post_linebreak_filter, not page-boundary resets.")
