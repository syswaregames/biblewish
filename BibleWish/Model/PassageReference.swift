//
//  PassageReference.swift
//  BibleWish
//
//  Turns text like "John 3:16", "1 Jn 2" or "gen 1" into a chapter (and verse) to open.
//

import Foundation

struct PassageReference: Hashable {
    let bookName: String
    let chapterIndex: Int
    let verse: Int?

    static func parse(_ input: String, in books: [BibleBook]) -> PassageReference? {
        let pattern = #"^\s*(.+?)\s+(\d+)(?:\s*[:.]\s*(\d+))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let nameRange = Range(match.range(at: 1), in: input),
              let chapterRange = Range(match.range(at: 2), in: input),
              let chapterNumber = Int(input[chapterRange]),
              let book = book(matching: String(input[nameRange]), in: books),
              let chapterIndex = book.chapters.firstIndex(where: { $0.number == chapterNumber })
        else { return nil }

        var verse: Int?
        if let verseRange = Range(match.range(at: 3), in: input) {
            verse = Int(input[verseRange])
        }
        return PassageReference(bookName: book.name, chapterIndex: chapterIndex, verse: verse)
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    /// Book names and abbreviations in English and Portuguese, in Bible order ("name|alias|alias"),
    /// from the website's note-format.js. A leading "1 " also matches "1Cor" and "I Cor".
    private static let aliasTable = [
        "Genesis|Gen|Gn|Ge|Gênesis",
        "Exodus|Exod|Ex|Êxodo",
        "Leviticus|Lev|Lv|Levítico",
        "Numbers|Num|Nm|Números",
        "Deuteronomy|Deut|Dt|Deuteronômio",
        "Joshua|Josh|Js|Josué",
        "Judges|Judg|Jdg|Juízes|Jz",
        "Ruth|Rt|Rute",
        "1 Samuel|Sam|Sm",
        "2 Samuel|Sam|Sm",
        "1 Kings|Kgs|Ki|Reis|Rs",
        "2 Kings|Kgs|Ki|Reis|Rs",
        "1 Chronicles|Chron|Chr|Ch|Crônicas|Cr",
        "2 Chronicles|Chron|Chr|Ch|Crônicas|Cr",
        "Ezra|Ezr|Esdras",
        "Nehemiah|Neh|Ne|Neemias",
        "Esther|Esth|Est|Ester",
        "Job|Jb|Jó",
        "Psalms|Psalm|Psa|Pss|Ps|Salmos|Salmo|Sl",
        "Proverbs|Prov|Prv|Pr|Provérbios|Pv",
        "Ecclesiastes|Eccl|Ecc|Ec",
        "Song of Solomon|Song of Songs|Song|Cantares|Cânticos|Ct",
        "Isaiah|Isa|Isaías",
        "Jeremiah|Jer|Jr|Jeremias",
        "Lamentations|Lam|Lm|Lamentações",
        "Ezekiel|Ezek|Ez|Ezequiel",
        "Daniel|Dan|Dn",
        "Hosea|Hos|Oséias|Oseias",
        "Joel|Jl",
        "Amos|Amós",
        "Obadiah|Obad|Ob|Obadias",
        "Jonah|Jon|Jnh|Jonas",
        "Micah|Mic|Mq|Miquéias|Miqueias",
        "Nahum|Nah|Naum",
        "Habakkuk|Hab|Hc|Habacuque",
        "Zephaniah|Zeph|Zep|Sf|Sofonias",
        "Haggai|Hag|Hg|Ag|Ageu",
        "Zechariah|Zech|Zec|Zc|Zacarias",
        "Malachi|Mal|Ml|Malaquias",
        "Matthew|Matt|Mt|Mateus",
        "Mark|Mk|Mrk|Marcos|Mc",
        "Luke|Luk|Lk|Lucas|Lc",
        "John|Jhn|Jn|João|Jo",
        "Acts|Atos",
        "Romans|Rom|Rm|Romanos",
        "1 Corinthians|Cor|Co|Coríntios",
        "2 Corinthians|Cor|Co|Coríntios",
        "Galatians|Gal|Gl|Gálatas",
        "Ephesians|Eph|Ef|Efésios",
        "Philippians|Phil|Php|Fp|Filipenses",
        "Colossians|Col|Cl|Colossenses",
        "1 Thessalonians|Thess|Thes|Th|Tessalonicenses|Ts",
        "2 Thessalonians|Thess|Thes|Th|Tessalonicenses|Ts",
        "1 Timothy|Tim|Tm|Timóteo",
        "2 Timothy|Tim|Tm|Timóteo",
        "Titus|Tit|Tt|Tito",
        "Philemon|Philem|Phlm|Phm|Filemom|Filemon|Fm",
        "Hebrews|Heb|Hb|Hebreus",
        "James|Jas|Jm|Tiago|Tg",
        "1 Peter|Pet|Pt|Pedro|Pe",
        "2 Peter|Pet|Pt|Pedro|Pe",
        "1 John|Jhn|Jn|João|Jo",
        "2 John|Jhn|Jn|João|Jo",
        "3 John|Jhn|Jn|João|Jo",
        "Jude|Jd|Judas",
        "Revelation|Revelations|Rev|Rv|Apocalipse|Ap",
    ]

    private static let romanPrefixes = ["", "i", "ii", "iii"]

    /// Normalized alias → canonical book index.
    private static let bookIndexByAlias: [String: Int] = {
        var map: [String: Int] = [:]
        for (index, row) in aliasTable.enumerated() {
            let parts = row.split(separator: "|", omittingEmptySubsequences: true).map(String.init)
            guard let name = parts.first else { continue }
            let number = name.first.flatMap { $0.isNumber ? Int(String($0)) : nil } ?? 0
            let base = number > 0 ? String(name.dropFirst(2)) : name
            for alias in [base] + parts.dropFirst() {
                let key = normalize(alias)
                if number > 0 {
                    map["\(number)\(key)"] = index
                    map["\(romanPrefixes[number])\(key)"] = index
                } else {
                    map[key] = index
                }
            }
        }
        return map
    }()

    // MARK: - References inside text

    /// One alternation of every book name and abbreviation, longest first, followed by a chapter and
    /// an optional verse or verse range. Same shape as the website's note-format.js.
    private static let scanner: NSRegularExpression? = {
        var patterns = Set<String>()
        for row in aliasTable {
            let parts = row.split(separator: "|", omittingEmptySubsequences: true).map(String.init)
            guard let name = parts.first else { continue }
            let number = name.first.flatMap { $0.isNumber ? Int(String($0)) : nil } ?? 0
            let base = number > 0 ? String(name.dropFirst(2)) : name

            for alias in [base] + parts.dropFirst() {
                for variant in Set([alias, alias.folding(options: .diacriticInsensitive, locale: nil)]) {
                    let body = variant.split(separator: " ")
                        .map { NSRegularExpression.escapedPattern(for: String($0)) }
                        .joined(separator: "\\s+")
                    patterns.insert(number > 0 ? "(?:\(number)\\s*|\(romanPrefixes[number])\\s+)\(body)" : body)
                }
            }
        }
        let names = patterns.sorted { $0.count > $1.count }.joined(separator: "|")
        let pattern = "(?<![\\p{L}\\p{N}])(\(names))\\.?\\s*(\\d{1,3})(?:\\s?(?::\\s*|\\.(?=\\d)|,(?=\\d))(\\d{1,3})(?:\\s*[-\u{2013}]\\s*(\\d{1,3}))?)?(?![\\p{N}])"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// Passages named in `text` ("John 3:16", "Rom 8:28-30", "Sl 23"), with where they appear. Only
    /// references to a chapter that exists are returned.
    static func references(in text: String, books: [BibleBook]) -> [(range: Range<String.Index>, reference: PassageReference)] {
        guard let scanner else { return [] }
        let whole = NSRange(text.startIndex..., in: text)

        return scanner.matches(in: text, range: whole).compactMap { match in
            guard let full = Range(match.range, in: text),
                  let nameRange = Range(match.range(at: 1), in: text),
                  let chapterRange = Range(match.range(at: 2), in: text),
                  let chapter = Int(text[chapterRange]),
                  let index = bookIndexByAlias[normalize(String(text[nameRange]))],
                  index < books.count,
                  let chapterIndex = books[index].chapters.firstIndex(where: { $0.number == chapter })
            else { return nil }

            var verse: Int?
            if let verseRange = Range(match.range(at: 3), in: text) { verse = Int(text[verseRange]) }
            return (full, PassageReference(bookName: books[index].name, chapterIndex: chapterIndex, verse: verse))
        }
    }

    /// Alias first, then the exact name, the same book by id (other languages), then a unique prefix.
    private static func book(matching name: String, in books: [BibleBook]) -> BibleBook? {
        let key = normalize(name)
        guard !key.isEmpty else { return nil }

        if let index = bookIndexByAlias[key], index < books.count {
            return books[index]
        }
        if let exact = books.first(where: { normalize($0.name) == key }) {
            return exact
        }
        if let id = BookNameMapper.bookId(for: name),
           let byId = books.first(where: { BookNameMapper.bookId(for: $0.name) == id }) {
            return byId
        }
        let prefixed = books.filter { normalize($0.name).hasPrefix(key) }
        return prefixed.count == 1 ? prefixed[0] : nil
    }
}
