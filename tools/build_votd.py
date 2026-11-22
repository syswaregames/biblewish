#!/usr/bin/env python3
"""Builds BibleWish/Data/votd_references.json from the website's data/votd/index.json, and copies the
verse texts into BibleWishWidget/Data/votd/ for the Verse of the Day widget.

Usage: python3 -I tools/build_votd.py [path/to/BibleWish_Website]

Output: [[book, chapter, firstVerse, lastVerse], ...] for 366 days (day 0 = 1 January, counted as in
a leap year so 29 February has its own verse), where `book` is the 0-based canonical book index.
The verse text is read from the translation selected in the app, so it works offline.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")

with open(os.path.join(SITE, "data", "votd", "index.json"), encoding="utf-8") as f:
    days = json.load(f)["days"]

rows = [[d["book"], d["chapter"], d["verses"][0], d["verses"][1]] for d in days]
out = os.path.join(ROOT, "BibleWish", "Data", "votd_references.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(rows, f, separators=(",", ":"))
print(f"wrote {out}: {len(rows)} days, {os.path.getsize(out)} bytes")

# The widget carries its own copy of the verse texts (all days, every translation the app has), so it
# works without the app's Bible files. It only needs to know which translation to show.
WIDGET_VOTD = os.path.join(ROOT, "BibleWishWidget", "Data", "votd")
os.makedirs(WIDGET_VOTD, exist_ok=True)
for name in ("index", "kjv", "web", "bliv", "heb"):
    shutil.copy2(os.path.join(SITE, "data", "votd", name + ".json"), os.path.join(WIDGET_VOTD, name + ".json"))
print(f"copied widget data to {WIDGET_VOTD}")
