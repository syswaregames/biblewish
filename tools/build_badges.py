#!/usr/bin/env python3
"""Builds BibleWish/Data/badges.json from the website's api/lib/badges.php.

Usage: python3 -I tools/build_badges.py [path/to/BibleWish_Website]

Only badges whose metric the app can work out on the device are kept (reading, progress through the
Bible, study and the seasonal ones); community and leaderboard badges need an account.
Never change a badge id: earned badges are stored by id.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")

SUPPORTED_METRICS = {
    "chapters", "streak", "morning", "evening", "plans", "sections", "books", "proverbs", "gospels",
    "paul", "psalms", "law", "nt", "ot", "favorites", "notes", "margin_notes", "highlights",
    "season_christmas", "season_easter",
}

# Website wording that doesn't fit the app.
DESCRIPTION_OVERRIDES = {
    "in-the-margin": "Write your first note about a verse (long-press a verse in the reader, then Add Note).",
}

STRING = r"'((?:\\'|[^'])*)'"


def field(line, key):
    match = re.search(rf"'{key}' => {STRING}", line)
    return match.group(1).replace("\\'", "'") if match else None


with open(os.path.join(SITE, "api", "lib", "badges.php"), encoding="utf-8") as f:
    source = f.read()

block = source[source.index("const BADGES = ["):source.index("// Metric groups")]
badges = []
for line in block.splitlines():
    line = line.strip()
    if not line.startswith("['id' =>"):
        continue
    target = re.search(r"'target' => (\d+)", line)
    badge = {key: field(line, key) for key in ("id", "group", "icon", "name", "description", "metric")}
    badge["target"] = int(target.group(1))
    badge["description"] = DESCRIPTION_OVERRIDES.get(badge["id"], badge["description"])
    if badge["metric"] in SUPPORTED_METRICS:
        badges.append(badge)

out = os.path.join(ROOT, "BibleWish", "Data", "badges.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(badges, f, ensure_ascii=False, separators=(",", ":"))
groups = {}
for b in badges:
    groups[b["group"]] = groups.get(b["group"], 0) + 1
print(f"wrote {out}: {len(badges)} badges {groups}")
