#!/usr/bin/env python3
"""Controleert de tekenlimieten van AppStore/METADATA.md."""
import re, sys, pathlib
text = pathlib.Path(__file__).resolve().parent.parent.joinpath("AppStore/METADATA.md").read_text()
limits = {"Subtitel": 30, "Subtitle": 30, "Promotietekst": 170, "Promotional text": 170,
          "Trefwoorden": 100, "Keywords": 100, "Beschrijving": 4000, "Description": 4000}
ok = True
for label, limit in limits.items():
    m = re.search(rf"\*\*{label}\*\* \(max \d+\):\s*(?:```\n(.*?)\n```|`([^`]*)`)", text, re.S)
    if not m:
        print(f"? {label}: niet gevonden"); ok = False; continue
    value = m.group(1) if m.group(1) is not None else m.group(2)
    n = len(value)
    flag = "OK " if n <= limit else "TE LANG"
    if n > limit: ok = False
    print(f"{flag} {label:17} {n:>4}/{limit}")
sys.exit(0 if ok else 1)
