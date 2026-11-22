#!/usr/bin/env python3
"""Copies the website's word-study data (the KJV tagged with Strong's numbers, and the Hebrew and
Greek dictionaries) into the app.

Usage: python3 -I tools/build_strongs.py [path/to/BibleWish_Website]

  data/strongs/books/<slug>.json      -> BibleWish/Data/strongs/books/     (chapter -> verse -> [[english word, "H430"]])
  data/strongs/lexicon/<H|G>-<n>.json -> BibleWish/Data/strongs/lexicon/  (Strong's number -> lemma, xlit, pron, def, kjv, derivation, count)
  data/strongs/LICENSE.txt            -> BibleWish/Data/strongs/LICENSE.txt

The folder is added to the Xcode project as a folder reference (like crossrefs and places). The
lexicon is CC BY-SA 4.0 (Open Scriptures); the app credits it in the Original words screen and
docs/CREDITS.md.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")
SRC = os.path.join(SITE, "data", "strongs")
DST = os.path.join(ROOT, "BibleWish", "Data", "strongs")

SLUGS = [
    "genesis", "exodus", "leviticus", "numbers", "deuteronomy", "joshua", "judges", "ruth",
    "1-samuel", "2-samuel", "1-kings", "2-kings", "1-chronicles", "2-chronicles", "ezra",
    "nehemiah", "esther", "job", "psalms", "proverbs", "ecclesiastes", "song-of-solomon", "isaiah",
    "jeremiah", "lamentations", "ezekiel", "daniel", "hosea", "joel", "amos", "obadiah", "jonah",
    "micah", "nahum", "habakkuk", "zephaniah", "haggai", "zechariah", "malachi", "matthew", "mark",
    "luke", "john", "acts", "romans", "1-corinthians", "2-corinthians", "galatians", "ephesians",
    "philippians", "colossians", "1-thessalonians", "2-thessalonians", "1-timothy", "2-timothy",
    "titus", "philemon", "hebrews", "james", "1-peter", "2-peter", "1-john", "2-john", "3-john",
    "jude", "revelation",
]

if os.path.isdir(DST):
    shutil.rmtree(DST)
for folder in ("books", "lexicon"):
    shutil.copytree(os.path.join(SRC, folder), os.path.join(DST, folder))
shutil.copy2(os.path.join(SRC, "LICENSE.txt"), os.path.join(DST, "LICENSE.txt"))

for slug in SLUGS:
    assert os.path.exists(os.path.join(DST, "books", slug + ".json")), slug

# Every Strong's number a book mentions must have a dictionary entry in its chunk file.
lexicon = {}
for name in os.listdir(os.path.join(DST, "lexicon")):
    with open(os.path.join(DST, "lexicon", name), encoding="utf-8") as f:
        lexicon[name] = json.load(f)
missing = 0
for slug in SLUGS:
    with open(os.path.join(DST, "books", slug + ".json"), encoding="utf-8") as f:
        book = json.load(f)
    for chapter in book.values():
        for words in chapter.values():
            for _, number in words:
                chunk = f"{number[0]}-{int(number[1:]) // 1000}.json"
                if number not in lexicon.get(chunk, {}):
                    missing += 1
print(f"copied {len(SLUGS)} books and {len(lexicon)} dictionary files; {missing} numbers without an entry")
