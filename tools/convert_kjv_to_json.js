const fs = require("fs");

const inputPath = "kjv.txt";
const outputPath = "bible_kjv.json";

const lines = fs.readFileSync(inputPath, "utf8").split("\n");

const bible = { books: [] };

let currentBook = null;
let currentChapter = null;

for (const rawLine of lines) {
  const line = rawLine.trim();
  if (!line) continue;

  // BookName Chapter:Verse Text
  // Handles: Genesis, 1 Samuel, 2 Corinthians, Song of Solomon
  const match = line.match(/^([1-3]?\s?[A-Za-z ]+?) (\d+):(\d+)\s+(.+)$/);
  if (!match) continue;

  const [, bookName, chapterStr, verseStr, verseText] = match;
  const chapterNumber = Number(chapterStr);
  const verseNumber = Number(verseStr);

  if (!currentBook || currentBook.name !== bookName) {
    currentBook = {
      name: bookName.trim(),
      chapters: []
    };
    bible.books.push(currentBook);
    currentChapter = null;
  }

  if (!currentChapter || currentChapter.number !== chapterNumber) {
    currentChapter = {
      number: chapterNumber,
      verses: []
    };
    currentBook.chapters.push(currentChapter);
  }

  currentChapter.verses.push({
    number: verseNumber,
    text: verseText
  });
}

fs.writeFileSync(outputPath, JSON.stringify(bible, null, 2), "utf8");

console.log(`KJV Bible JSON generated: ${outputPath}`);
console.log(`Books: ${bible.books.length}`);

