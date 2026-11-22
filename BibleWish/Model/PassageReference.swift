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

    /// Exact name first, then the same book by id (other languages), then a unique prefix.
    private static func book(matching name: String, in books: [BibleBook]) -> BibleBook? {
        let key = normalize(name)
        guard !key.isEmpty else { return nil }

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
