#!/usr/bin/env python3
"""Builds BibleWish/Data/reading_plans.json from the website's data/plans files.

Usage: python3 -I tools/build_plans.py [path/to/BibleWish_Website]

Output: { "plans": [ {id, title, description, days, chapters, minutes_per_day} ],
          "days": { "<plan id>": [ [[book, chapter], ...], ... ] } }
`book` is the 0-based canonical book index, `chapter` the chapter number. Never change the days of a
plan people have already started (progress is stored as day + item); add a new plan id instead.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")
PLANS = os.path.join(SITE, "data", "plans")

with open(os.path.join(PLANS, "index.json"), encoding="utf-8") as f:
    catalog = json.load(f)["plans"]

days = {}
for plan in catalog:
    with open(os.path.join(PLANS, plan["id"] + ".json"), encoding="utf-8") as f:
        days[plan["id"]] = json.load(f)["days"]
    assert len(days[plan["id"]]) == plan["days"], plan["id"]

out = os.path.join(ROOT, "BibleWish", "Data", "reading_plans.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump({"plans": catalog, "days": days}, f, separators=(",", ":"))
print(f"wrote {out}: {len(catalog)} plans, {os.path.getsize(out)} bytes")
