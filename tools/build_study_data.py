#!/usr/bin/env python3
"""Copies the website's cross-reference and place data into the app.

Usage: python3 -I tools/build_study_data.py [path/to/BibleWish_Website]

  data/crossrefs/*.json                      -> BibleWish/Data/crossrefs/   (per book: chapter -> verse -> [[book, chapter, first, last]])
  data/places/{places,journeys}.json         -> BibleWish/Data/places/
  data/places/books/*.json                   -> BibleWish/Data/places/books/ (per book: chapter -> [[place index, [verses]]])

Both folders are added to the Xcode project as folder references. Files are named by book slug
(see BibleBooks.slugs in BibleStudyData.swift); this script checks that every slug has its files.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "BibleWish_Website")
DATA = os.path.join(ROOT, "BibleWish", "Data")


def slug(name):
    # The website's files say "psalms"; the KJV file names the book "Psalm".
    return {"psalm": "psalms"}.get(name.lower(), name.lower().replace(" ", "-"))


def copy_tree(src, dst):
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    os.makedirs(dst)
    for name in sorted(os.listdir(src)):
        if name.endswith(".json"):
            shutil.copy2(os.path.join(src, name), os.path.join(dst, name))


with open(os.path.join(SITE, "translations", "bible_kjv.json"), encoding="utf-8") as f:
    slugs = [slug(book["name"]) for book in json.load(f)["books"]]
assert len(slugs) == 66

copy_tree(os.path.join(SITE, "data", "crossrefs"), os.path.join(DATA, "crossrefs"))
os.makedirs(os.path.join(DATA, "places"), exist_ok=True)
for name in ("places.json", "journeys.json"):
    shutil.copy2(os.path.join(SITE, "data", "places", name), os.path.join(DATA, "places", name))
copy_tree(os.path.join(SITE, "data", "places", "books"), os.path.join(DATA, "places", "books"))

for s in slugs:
    for folder in ("crossrefs", os.path.join("places", "books")):
        assert os.path.exists(os.path.join(DATA, folder, s + ".json")), (folder, s)

print("slugs:", json.dumps(slugs))
for folder in ("crossrefs", "places"):
    total = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(os.path.join(DATA, folder)) for f in fs)
    print(folder, total, "bytes")
