#!/usr/bin/env python3
"""Copies the website's list of country codes (the ones its API accepts) into the app.

Usage: python3 -I tools/build_countries.py [path/to/BibleWish_Website]

  data/countries.json -> BibleWish/Data/countries.json   (["AD", "AE", ...])

Used by Settings -> Account -> Community to choose the country whose flag shows beside your name.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")
src = os.path.join(SITE, "data", "countries.json")
dst = os.path.join(ROOT, "BibleWish", "Data", "countries.json")
with open(src, encoding="utf-8") as f:
    codes = json.load(f)
assert isinstance(codes, list) and all(isinstance(c, str) and len(c) == 2 for c in codes)
shutil.copy2(src, dst)
print(f"copied {len(codes)} country codes")
