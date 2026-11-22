#!/usr/bin/env python3
"""Copies the verses Biblia Livre leaves out into the app's copy of the text.

Usage: python3 -I tools/sync_omitted_verses.py [path/to/BibleWish_Website]

Biblia Livre follows the oldest manuscripts and omits 15 verses (Matthew 17:21, Acts 8:37, ...);
its file has "-" there. biblewish.com supplies a BibleWish translation from the KJV for each and
flags it "omitted": the reader shows it with a * and a footnote at the end of the chapter. This
takes those verses (text and flag) from the website's translations/bible_pt_bliv.json and puts them
into BibleWish/Data/bible_pt_bliv.json, changing nothing else. Safe to run again.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")
APP_FILE = os.path.join(ROOT, "BibleWish", "Data", "bible_pt_bliv.json")

with open(os.path.join(SITE, "translations", "bible_pt_bliv.json"), encoding="utf-8") as f:
    site = json.load(f)
with open(APP_FILE, encoding="utf-8") as f:
    original = f.read()
app = json.loads(original)

changed = 0
for site_book, app_book in zip(site["books"], app["books"]):
    assert site_book["id"] == app_book["id"], (site_book["id"], app_book["id"])
    for site_chapter, app_chapter in zip(site_book["chapters"], app_book["chapters"]):
        wanted = {v["number"]: v for v in site_chapter["verses"] if v.get("omitted")}
        for verse in app_chapter["verses"]:
            supplied = wanted.get(verse["number"])
            if supplied and (verse["text"] != supplied["text"] or not verse.get("omitted")):
                verse["text"] = supplied["text"]
                verse["omitted"] = True
                changed += 1

with open(APP_FILE, "w", encoding="utf-8") as f:
    f.write(json.dumps(app, ensure_ascii=False, indent=2) + ("\n" if original.endswith("\n") else ""))
print(f"{changed} verses supplied")
