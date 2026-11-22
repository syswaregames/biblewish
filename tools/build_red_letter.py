#!/usr/bin/env python3
"""Builds BibleWish/Data/red_letter_ranges.json from the website's data/redletter files.

Usage: python3 -I tools/build_red_letter.py [path/to/BibleWish_Website]

Output: { "kjv": { "MAT": { "5": { "3": [[0, 70]] } } }, "web": ..., "bliv": ... }
Offsets are UTF-16 code units into the verse text, exactly as the website uses them. A range is
dropped when the app's verse text differs from the website's, so it can never mis-slice a verse.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")
DATA = os.path.join(ROOT, "BibleWish", "Data")

# website translation id -> (translation file, redletter folder)
TRANSLATIONS = {
    "kjv": "bible_kjv.json",
    "web": "bible_en_webu.json",
    "bliv": "bible_pt_bliv.json",
}

BOOK_IDS = [
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH",
    "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK",
    "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
    "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH",
    "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD",
    "REV",
]


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def verse_texts(bible, book_index):
    book = bible["books"][book_index]
    return {c["number"]: {v["number"]: v["text"] for v in c["verses"]} for c in book["chapters"]}


def slug(name):
    return name.lower().replace(" ", "-")


def main():
    index = load(os.path.join(SITE, "data", "redletter", "index.json"))
    result = {}
    dropped = 0
    for tr, filename in TRANSLATIONS.items():
        site_bible = load(os.path.join(SITE, "translations", filename))
        app_bible = load(os.path.join(DATA, filename))
        books = {}
        for book_index in index.get(tr, []):
            # The website names files after the English book name, whatever the translation.
            english = load(os.path.join(SITE, "translations", "bible_kjv.json"))["books"][book_index]["name"]
            ranges = load(os.path.join(SITE, "data", "redletter", tr, slug(english) + ".json"))
            site_text = verse_texts(site_bible, book_index)
            app_text = verse_texts(app_bible, book_index)
            chapters = {}
            for chapter, verses in ranges.items():
                kept = {}
                for verse, spans in verses.items():
                    site_v = site_text.get(int(chapter), {}).get(int(verse))
                    if site_v is None or site_v != app_text.get(int(chapter), {}).get(int(verse)):
                        dropped += 1
                        continue
                    kept[verse] = spans
                if kept:
                    chapters[chapter] = kept
            if chapters:
                books[BOOK_IDS[book_index]] = chapters
        result[tr] = books

    out = os.path.join(DATA, "red_letter_ranges.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, separators=(",", ":"), sort_keys=True)
    print(f"wrote {out} ({os.path.getsize(out)} bytes), dropped {dropped} verses with differing text")
    for tr, books in result.items():
        print(tr, sorted(books))


main()
