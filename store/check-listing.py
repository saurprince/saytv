#!/usr/bin/env python3
"""Checks the store listing text against the stores' length limits. Run: python store/check-listing.py"""
import re
import sys
from pathlib import Path

text = (Path(__file__).resolve().parent / "listing.md").read_text(encoding="utf-8")
bad = 0

# **Heading [limit]** followed by the text, up to the next blank line (single-line fields)
for m in re.finditer(r"\*\*([^*\[\]]+?) \[(\d+)[^\]]*\]\*\*\n(.+?)\n\n", text, re.S):
    name, limit, body = m.group(1), int(m.group(2)), m.group(3).strip()
    if "\n" in body:  # multi-line fields are checked below
        continue
    n = len(body)
    ok = n <= limit
    bad += not ok
    print(f"{'ok ' if ok else 'BAD'} {name}: {n}/{limit}")

# the Play full description: from its heading to the next ## heading
m = re.search(r"\*\*Full description \[(\d+)\]\*\*\n(.+?)\n## ", text, re.S)
if m:
    n = len(m.group(2).strip())
    ok = n <= int(m.group(1))
    bad += not ok
    print(f"{'ok ' if ok else 'BAD'} Play full description: {n}/{m.group(1)}")

# the title in the shared table
m = re.search(r"App name / title \[(\d+)\] \| (.+?) \|", text)
if m:
    n = len(m.group(2))
    ok = n <= int(m.group(1))
    bad += not ok
    print(f"{'ok ' if ok else 'BAD'} Title: {n}/{m.group(1)}")

sys.exit(1 if bad else 0)
