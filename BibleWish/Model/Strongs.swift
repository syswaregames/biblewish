//
//  Strongs.swift
//
//  Original words: each word of the KJV with the Hebrew or Greek word behind it (Strong's numbers),
//  and the Strong's dictionaries. Copied in from biblewish.com by tools/build_strongs.py; a port of
//  the website's "Original words" (read.html). Books are addressed by canonical index (0 = Genesis).
//

import Foundation

struct StrongsWord: Hashable, Identifiable {
    let id: Int
    /// The English word in the KJV.
    let english: String
    /// "H430" or "G3056".
    let number: String

    var isHebrew: Bool { number.hasPrefix("H") }
}

/// A dictionary entry. Every field but the lemma can be empty.
struct StrongsEntry: Decodable, Equatable {
    let lemma: String
    let xlit: String
    let pron: String?
    let def: String?
    let kjv: String?
    let derivation: String?
    let count: Int?
}

final class StrongsStore {

    static let shared = StrongsStore()

    /// The website shows at most this many verses at once.
    static let maxVerses = 5

    // book -> chapter -> verse -> [[english, number]]
    private var books: [Int: [String: [String: [[String]]]]] = [:]
    private var lexicon: [String: [String: StrongsEntry]] = [:]
    private let lock = NSLock()

    private init() {}

    /// The words of a verse, in order. Empty when the verse has no data.
    func words(book: Int, chapter: Int, verse: Int) -> [StrongsWord] {
        guard book >= 0, book < BibleBooks.slugs.count else { return [] }
        lock.lock(); defer { lock.unlock() }
        if books[book] == nil {
            books[book] = BundledJSON.load([String: [String: [[String]]]].self, name: BibleBooks.slugs[book], subdirectory: "strongs/books") ?? [:]
        }
        let pairs = books[book]?[String(chapter)]?[String(verse)] ?? []
        return pairs.enumerated().compactMap { index, pair in
            pair.count == 2 ? StrongsWord(id: index, english: pair[0], number: pair[1]) : nil
        }
    }

    /// The dictionary entry for a Strong's number ("H430").
    func entry(for number: String) -> StrongsEntry? {
        guard let letter = number.first, letter == "H" || letter == "G", let value = Int(number.dropFirst()) else { return nil }
        let chunk = "\(letter)-\(value / 1000)"
        lock.lock(); defer { lock.unlock() }
        if lexicon[chunk] == nil {
            lexicon[chunk] = BundledJSON.load([String: StrongsEntry].self, name: chunk, subdirectory: "strongs/lexicon") ?? [:]
        }
        return lexicon[chunk]?[number]
    }

    /// A short form of a definition for a list row: cut at a word, with an ellipsis.
    static func shorten(_ text: String, to length: Int = 90) -> String {
        guard text.count > length else { return text }
        var cut = String(text.prefix(length))
        // Drop the half word and any trailing punctuation, as the website does.
        if let space = cut.lastIndex(where: { $0.isWhitespace }) { cut = String(cut[..<space]) }
        while let last = cut.last, " ,;:".contains(last) { cut.removeLast() }
        return cut + "\u{2026}"
    }
}
