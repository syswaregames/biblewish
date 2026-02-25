const fs = require("fs");

const inputPath = "heb_vpl.txt";
const outputPath = "heb_vpl.json";

/* =======================
   🔧 DEBUG CONFIG
======================= */
const DEBUG = true; // ← turn ON / OFF here

const seenBooks = new Set();       // raw book names found
const acceptedBooks = new Set();   // normalized book IDs
const rejectedBooks = new Set();   // raw book names not recognized
/* ======================= */

const lines = fs.readFileSync(inputPath, "utf8").split("\n");

const bible = { books: [] };

const BOOK_ALIASES = {
  // 📜 Pentateuch
  GEN: ["Genesis", "Gênesis", "GEN", "Gn", "Gen"],
  EXO: ["Exodus", "Êxodo", "EXO", "Ex"],
  LEV: ["Leviticus", "Levítico", "LEV", "Lv"],
  NUM: ["Numbers", "Números", "NUM", "Nm"],
  DEU: ["Deuteronomy", "Deuteronômio", "DEU", "Dt"],

  // 📜 Historical Books
  JOS: ["Joshua", "Josué", "JOS", "Js"],
  JDG: ["Judges", "Juízes", "JDG", "Jz"],
  RUT: ["Ruth", "Rute", "RUT", "Rt"],
  "1SA": ["1 Samuel", "1SA", "1Sm"],
  "2SA": ["2 Samuel", "2SA", "2Sm"],
  "1KI": ["1 Kings", "1 Reis", "1KI", "1Rs"],
  "2KI": ["2 Kings", "2 Reis", "2KI", "2Rs"],
  "1CH": ["1 Chronicles", "1 Crônicas", "1CH", "1Cr"],
  "2CH": ["2 Chronicles", "2 Crônicas", "2CH", "2Cr"],
  EZR: ["Ezra", "Esdras", "EZR", "Ed"],
  NEH: ["Nehemiah", "Neemias", "NEH", "Ne"],
  EST: ["Esther", "Ester", "EST", "Et"],

  // 📜 Wisdom / Poetry
  JOB: ["Job", "Jó", "JOB"],
  PSA: ["Psalms", "Salmos", "PSA", "Sl", "Ps"],
  PRO: ["Proverbs", "Provérbios", "PRO", "Pv"],
  ECC: ["Ecclesiastes", "Eclesiastes", "ECC", "Ec"],
  SNG: ["Song of Solomon", "Song of Songs", "Cântico dos Cânticos", "Cantares", "SNG", "Ct", "SOL"],

  // 📜 Major Prophets
  ISA: ["Isaiah", "Isaías", "ISA", "Is"],
  JER: ["Jeremiah", "Jeremias", "JER", "Jr"],
  LAM: ["Lamentations", "Lamentações", "LAM", "Lm"],
  EZK: ["Ezekiel", "Ezequiel", "EZK", "Ez", "EZE"],
  DAN: ["Daniel", "DAN", "Dn"],

  // 📜 Minor Prophets
  HOS: ["Hosea", "Oséias", "HOS", "Os"],
  JOL: ["Joel", "JOEL", "Jl", "JOE"],
  AMO: ["Amos", "Amós", "AMO", "Am"],
  OBA: ["Obadiah", "Obadias", "OBA", "Ob"],
  JON: ["Jonah", "Jonas", "JON", "Jn"],
  MIC: ["Micah", "Miquéias", "MIC", "Mq"],
  NAM: ["Nahum", "Naum", "NAM", "Na", "NAH"],
  HAB: ["Habakkuk", "Habacuque", "HAB", "Hc"],
  ZEP: ["Zephaniah", "Sofonias", "ZEP", "Sf"],
  HAG: ["Haggai", "Ageu", "HAG", "Ag"],
  ZEC: ["Zechariah", "Zacarias", "ZEC", "Zc"],
  MAL: ["Malachi", "Malaquias", "MAL", "Ml"],

  // 📜 Gospels
  MAT: ["Matthew", "Mateus", "MAT", "Mt"],
  MRK: ["Mark", "Marcos", "MRK", "Mc", "MAR"],
  LUK: ["Luke", "Lucas", "LUK", "Lc"],
  JHN: ["John", "João", "JHN", "Jo", "JOH"],

  // 📜 Acts
  ACT: ["Acts", "Atos", "ACT", "At"],

  // 📜 Pauline Epistles
  ROM: ["Romans", "Romanos", "ROM", "Rm"],
  "1CO": ["1 Corinthians", "1 Coríntios", "1CO", "1Co"],
  "2CO": ["2 Corinthians", "2 Coríntios", "2CO", "2Co"],
  GAL: ["Galatians", "Gálatas", "GAL", "Gl"],
  EPH: ["Ephesians", "Efésios", "EPH", "Ef"],
  PHP: ["Philippians", "Filipenses", "PHP", "Fp", "PHI"],
  COL: ["Colossians", "Colossenses", "COL", "Cl"],
  "1TH": ["1 Thessalonians", "1 Tessalonicenses", "1TH", "1Ts"],
  "2TH": ["2 Thessalonians", "2 Tessalonicenses", "2TH", "2Ts"],
  "1TI": ["1 Timothy", "1 Timóteo", "1TI", "1Tm"],
  "2TI": ["2 Timothy", "2 Timóteo", "2TI", "2Tm"],
  TIT: ["Titus", "Tito", "TIT", "Tt"],
  PHM: ["Philemon", "Filemom", "PHM", "Fm"],

  // 📜 General Epistles
  HEB: ["Hebrews", "Hebreus", "HEB", "Hb"],
  JAS: ["James", "Tiago", "JAS", "Tg", "JAM"],
  "1PE": ["1 Peter", "1 Pedro", "1PE", "1Pe"],
  "2PE": ["2 Peter", "2 Pedro", "2PE", "2Pe"],
  "1JN": ["1 John", "1 João", "1JN", "1Jo"],
  "2JN": ["2 John", "2 João", "2JN", "2Jo"],
  "3JN": ["3 John", "3 João", "3JN", "3Jo"],
  JUD: ["Jude", "Judas", "JUD", "Jd"],

  // 📜 Apocalypse
  REV: ["Revelation", "Apocalipse", "REV", "Ap"]
};

const BOOK_LOOKUP = {};
for (const [id, names] of Object.entries(BOOK_ALIASES)) {
  for (const name of names) {
    BOOK_LOOKUP[name.toLowerCase()] = id;
  }
}

function normalizeBook(bookRaw) {
  return BOOK_LOOKUP[bookRaw.toLowerCase().trim()] || null;
}

const LANGUAGE = "he";

const BOOK_NAMES = {
  pt: {
    GEN: "Gênesis",
    EXO: "Êxodo",
    LEV: "Levítico",
    NUM: "Números",
    DEU: "Deuteronômio",

    JOS: "Josué",
    JDG: "Juízes",
    RUT: "Rute",
    "1SA": "1 Samuel",
    "2SA": "2 Samuel",
    "1KI": "1 Reis",
    "2KI": "2 Reis",
    "1CH": "1 Crônicas",
    "2CH": "2 Crônicas",
    EZR: "Esdras",
    NEH: "Neemias",
    EST: "Ester",

    JOB: "Jó",
    PSA: "Salmos",
    PRO: "Provérbios",
    ECC: "Eclesiastes",
    SNG: "Cântico dos Cânticos",

    ISA: "Isaías",
    JER: "Jeremias",
    LAM: "Lamentações",
    EZK: "Ezequiel",
    DAN: "Daniel",

    HOS: "Oséias",
    JOL: "Joel",
    AMO: "Amós",
    OBA: "Obadias",
    JON: "Jonas",
    MIC: "Miquéias",
    NAM: "Naum",
    HAB: "Habacuque",
    ZEP: "Sofonias",
    HAG: "Ageu",
    ZEC: "Zacarias",
    MAL: "Malaquias",

    MAT: "Mateus",
    MRK: "Marcos",
    LUK: "Lucas",
    JHN: "João",

    ACT: "Atos",

    ROM: "Romanos",
    "1CO": "1 Coríntios",
    "2CO": "2 Coríntios",
    GAL: "Gálatas",
    EPH: "Efésios",
    PHP: "Filipenses",
    COL: "Colossenses",
    "1TH": "1 Tessalonicenses",
    "2TH": "2 Tessalonicenses",
    "1TI": "1 Timóteo",
    "2TI": "2 Timóteo",
    TIT: "Tito",
    PHM: "Filemom",

    HEB: "Hebreus",
    JAS: "Tiago",
    "1PE": "1 Pedro",
    "2PE": "2 Pedro",
    "1JN": "1 João",
    "2JN": "2 João",
    "3JN": "3 João",
    JUD: "Judas",

    REV: "Apocalipse"
  },

  en: {
    GEN: "Genesis",
    EXO: "Exodus",
    LEV: "Leviticus",
    NUM: "Numbers",
    DEU: "Deuteronomy",

    JOS: "Joshua",
    JDG: "Judges",
    RUT: "Ruth",
    "1SA": "1 Samuel",
    "2SA": "2 Samuel",
    "1KI": "1 Kings",
    "2KI": "2 Kings",
    "1CH": "1 Chronicles",
    "2CH": "2 Chronicles",
    EZR: "Ezra",
    NEH: "Nehemiah",
    EST: "Esther",

    JOB: "Job",
    PSA: "Psalms",
    PRO: "Proverbs",
    ECC: "Ecclesiastes",
    SNG: "Song of Solomon",

    ISA: "Isaiah",
    JER: "Jeremiah",
    LAM: "Lamentations",
    EZK: "Ezekiel",
    DAN: "Daniel",

    HOS: "Hosea",
    JOL: "Joel",
    AMO: "Amos",
    OBA: "Obadiah",
    JON: "Jonah",
    MIC: "Micah",
    NAM: "Nahum",
    HAB: "Habakkuk",
    ZEP: "Zephaniah",
    HAG: "Haggai",
    ZEC: "Zechariah",
    MAL: "Malachi",

    MAT: "Matthew",
    MRK: "Mark",
    LUK: "Luke",
    JHN: "John",

    ACT: "Acts",

    ROM: "Romans",
    "1CO": "1 Corinthians",
    "2CO": "2 Corinthians",
    GAL: "Galatians",
    EPH: "Ephesians",
    PHP: "Philippians",
    COL: "Colossians",
    "1TH": "1 Thessalonians",
    "2TH": "2 Thessalonians",
    "1TI": "1 Timothy",
    "2TI": "2 Timothy",
    TIT: "Titus",
    PHM: "Philemon",

    HEB: "Hebrews",
    JAS: "James",
    "1PE": "1 Peter",
    "2PE": "2 Peter",
    "1JN": "1 John",
    "2JN": "2 John",
    "3JN": "3 John",
    JUD: "Jude",

    REV: "Revelation"
  },

  he: {
    GEN: "בראשית",
    EXO: "שמות",
    LEV: "ויקרא",
    NUM: "במדבר",
    DEU: "דברים",

    JOS: "יהושע",
    JDG: "שופטים",
    RUT: "רות",
    "1SA": "שמואל א",
    "2SA": "שמואל ב",
    "1KI": "מלכים א",
    "2KI": "מלכים ב",
    "1CH": "דברי הימים א",
    "2CH": "דברי הימים ב",
    EZR: "עזרא",
    NEH: "נחמיה",
    EST: "אסתר",

    JOB: "איוב",
    PSA: "תהילים",
    PRO: "משלי",
    ECC: "קהלת",
    SNG: "שיר השירים",

    ISA: "ישעיהו",
    JER: "ירמיהו",
    LAM: "איכה",
    EZK: "יחזקאל",
    DAN: "דניאל",

    HOS: "הושע",
    JOL: "יואל",
    AMO: "עמוס",
    OBA: "עובדיה",
    JON: "יונה",
    MIC: "מיכה",
    NAM: "נחום",
    HAB: "חבקוק",
    ZEP: "צפניה",
    HAG: "חגי",
    ZEC: "זכריה",
    MAL: "מלאכי",

    MAT: "מתי",
    MRK: "מרקוס",
    LUK: "לוקס",
    JHN: "יוחנן",

    ACT: "מעשי השליחים",

    ROM: "אל הרומים",
    "1CO": "אל הקורינתים א",
    "2CO": "אל הקורינתים ב",
    GAL: "אל הגלטים",
    EPH: "אל האפסים",
    PHP: "אל הפיליפים",
    COL: "אל הקולוסים",
    "1TH": "אל התסלוניקים א",
    "2TH": "אל התסלוניקים ב",
    "1TI": "אל טימותיאוס א",
    "2TI": "אל טימותיאוס ב",
    TIT: "אל טיטוס",
    PHM: "אל פילימון",

    HEB: "אל העברים",
    JAS: "יעקב",
    "1PE": "פטרוס א",
    "2PE": "פטרוס ב",
    "1JN": "יוחנן א",
    "2JN": "יוחנן ב",
    "3JN": "יוחנן ג",
    JUD: "יהודה",

    REV: "התגלות יוחנן"
  }
};


function getBookName(bookId) {
  return BOOK_NAMES[LANGUAGE]?.[bookId] || bookId;
}

let currentBook = null;
let currentChapter = null;

for (const rawLine of lines) {
  const line = rawLine.trim();
  if (!line) continue;

  const match = line.match(
    /^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+):(\d+)\s+(.+)$/
  );

  if (!match) continue;

  const [, bookRaw, chapterStr, verseStr, verseText] = match;

  seenBooks.add(bookRaw);

  const bookId = normalizeBook(bookRaw);
  if (!bookId) {
    rejectedBooks.add(bookRaw);
    if (DEBUG) {
      console.warn(`❌ Unrecognized book: "${bookRaw}"`);
    }
    continue;
  }

  acceptedBooks.add(bookId);

  const chapterNumber = Number(chapterStr);
  const verseNumber = Number(verseStr);

  if (!currentBook || currentBook.id !== bookId) {
    currentBook = {
      id: bookId,
      name: getBookName(bookId),
      chapters: []
    };
    bible.books.push(currentBook);
    currentChapter = null;
  }

  if (!currentChapter || currentChapter.number !== chapterNumber) {
    currentChapter = { number: chapterNumber, verses: [] };
    currentBook.chapters.push(currentChapter);
  }

  currentChapter.verses.push({
    number: verseNumber,
    text: verseText
  });
}

fs.writeFileSync(outputPath, JSON.stringify(bible, null, 2), "utf8");

console.log(`✅ Bible JSON generated: ${outputPath}`);
console.log(`📘 Books parsed: ${bible.books.length}`);

if (DEBUG) {
  console.log("\n📊 DEBUG SUMMARY");
  console.log("Seen books:", [...seenBooks].sort());
  console.log("Accepted book IDs:", [...acceptedBooks].sort());
  console.log("Rejected book names:", [...rejectedBooks].sort());
}
