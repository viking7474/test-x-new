#!/usr/bin/env python3
"""Static audit of UI target-action/gesture wiring for the TLinkIOS Objective-C sources."""
from __future__ import annotations

from pathlib import Path
import re
from collections import Counter, defaultdict

ROOT = Path(__file__).resolve().parents[1]
EXTS = {".m", ".mm", ".x"}
SRC = [p for p in ROOT.rglob("*") if p.is_file() and p.suffix in EXTS and ".git" not in p.parts]

selector_refs: list[tuple[str, int, str, str]] = []
method_defs: defaultdict[str, list[tuple[str, int]]] = defaultdict(list)

# UI registration patterns. Keep this intentionally limited to self-targeted handlers;
# action-handler blocks do not have selector wiring to audit.
ref_patterns = [
    ("target", re.compile(r"addTarget\s*:\s*self\s+action\s*:\s*@selector\s*\(\s*([^\)]+)\s*\)")),
    ("gesture", re.compile(r"initWithTarget\s*:\s*self\s+action\s*:\s*@selector\s*\(\s*([^\)]+)\s*\)")),
    ("barButton", re.compile(r"target\s*:\s*self\s+action\s*:\s*@selector\s*\(\s*([^\)]+)\s*\)")),
]

# ObjC instance/class method declaration. We only need selector spelling + colon count.
method_head = re.compile(r"^[-+]\s*\([^\n]*?\)\s*([A-Za-z_]\w*)(?=\s*[:\s\{])", re.M)

for path in SRC:
    text = path.read_text(encoding="utf-8", errors="replace")
    # Strip comments while preserving line count enough for diagnostics.
    scrub = re.sub(r"//.*", "", text)
    scrub = re.sub(r"/\*.*?\*/", "", scrub, flags=re.S)

    for kind, pat in ref_patterns:
        for m in pat.finditer(scrub):
            line = scrub.count("\n", 0, m.start()) + 1
            selector = m.group(1).strip()
            selector_refs.append((str(path.relative_to(ROOT)), line, kind, selector))

    # Parse multi-part declarations by taking declaration head through '{' or ';'.
    for start in re.finditer(r"^[-+]\s*\(", scrub, re.M):
        end_match = re.search(r"[\{;]", scrub[start.start(): start.start() + 800])
        if not end_match:
            continue
        decl = scrub[start.start(): start.start() + end_match.start()]
        name_match = re.search(r"\)\s*([A-Za-z_]\w*)", decl)
        if not name_match:
            continue
        first = name_match.group(1)
        colon_count = decl.count(":")
        selector = first + (":" * colon_count)
        line = scrub.count("\n", 0, start.start()) + 1
        method_defs[selector].append((str(path.relative_to(ROOT)), line))

# Build exact and base selector indexes.
base_index: defaultdict[str, list[str]] = defaultdict(list)
for selector in method_defs:
    base_index[selector.split(":", 1)[0]].append(selector)

missing: list[tuple[str, int, str, str]] = []
ambiguous: list[tuple[str, int, str, str, list[str]]] = []
for ref in selector_refs:
    path, line, kind, selector = ref
    if selector in method_defs:
        continue
    candidates = base_index.get(selector.split(":", 1)[0], [])
    if candidates:
        ambiguous.append((path, line, kind, selector, sorted(set(candidates))))
    else:
        missing.append(ref)

# Focused warning patterns that are known to cause logically wrong button routing even
# when selector existence is valid.
source_text = {str(p.relative_to(ROOT)): p.read_text(encoding="utf-8", errors="replace") for p in SRC}
warnings: list[str] = []

# Re-adding targets is safe when the reuse path explicitly removes the previous
# UIControl targets first. Only flag the pattern when no corresponding removeTarget
# is present in the same source file.
for path, text in source_text.items():
    if "Re-add targets every time" in text and "addTarget:self" in text and "removeTarget:nil action:NULL" not in text:
        warnings.append(f"{path}: cell reuse path re-adds UIControl targets without a visible removeTarget reset")

# Tag-based app selection derived from NSDictionary allKeys is unstable across mutations.
for path, text in source_text.items():
    if "button.tag = [self.appSwitches.allKeys indexOfObject:" in text or "Button.tag = [self.appSwitches.allKeys indexOfObject:" in text:
        warnings.append(f"{path}: UI action tags derive from NSDictionary allKeys order; verify handlers do not map tag back to a different app")

# Print concise report.
print(f"UI selector references: {len(selector_refs)}")
print(f"Unique selectors: {len({s for _,_,_,s in selector_refs})}")
print(f"Missing exact selector implementations: {len(missing)}")
for item in missing:
    print("MISSING", item)
print(f"Arity/name mismatches with same base selector: {len(ambiguous)}")
for item in ambiguous:
    print("MISMATCH", item)
print(f"Focused logic warnings: {len(warnings)}")
for warning in warnings:
    print("WARNING", warning)

if missing or ambiguous:
    raise SystemExit(2)
print("UI wiring selector audit: PASS")
