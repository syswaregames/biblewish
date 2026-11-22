//
//  BibleSearch.swift
//
//  Search the Bible the way biblewish.com does (api/search.php): every word must appear, in any
//  order; "quoted words" must appear together; words match whole words plus a plural ending
//  ("bread" finds "breads", not "breadth"); a star searches word starts ("bread*"). Capitals,
//  accents and Hebrew vowel points are ignored. In Hebrew a word matches anywhere, since prefixes
//  attach to words.
//
//  Each translation gets an inverted index (word -> verses) built once, off the main thread, so
//  a search is a few lookups instead of a scan of 31,000 verses.
//

import Foundation
import SwiftUI

// MARK: - Text

enum SearchText {

    /// The website's search_normalize: lowercase, no accents, no Hebrew vowel points or cantillation,
    /// maqaf as a space, whitespace collapsed.
    static func normalize(_ text: String) -> String {
        let lowered = text.replacingOccurrences(of: "\u{05BE}", with: " ").lowercased()
        var kept = String.UnicodeScalarView()
        for scalar in lowered.decomposedStringWithCanonicalMapping.unicodeScalars {
            let value = scalar.value
            if (0x0300...0x036F).contains(value) || (0x0591...0x05C7).contains(value) { continue }
            kept.append(scalar)
        }
        return String(kept).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// A letter or a number (the website's \p{L}\p{N}).
    @inline(__always) static func isWord(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        if value < 128 { return (48...57).contains(value) || (97...122).contains(value) || (65...90).contains(value) }
        return CharacterSet.alphanumerics.contains(scalar)
    }

    /// The words and phrases to look for: `bread of life` is three terms, `"bread of life"` one,
    /// `bread*` a word start. At most 8; one-letter words are dropped (numbers are kept).
    static func terms(_ query: String) -> [String] {
        let query = String(query.prefix(100))
        guard let regex = try? NSRegularExpression(pattern: #""([^"]+)"|(\S+)"#) else { return [] }
        var terms: [String] = []
        for match in regex.matches(in: query, range: NSRange(query.startIndex..., in: query)) {
            let part = [1, 2].compactMap { Range(match.range(at: $0), in: query).map { String(query[$0]) } }.first ?? ""
            var term = normalize(part)
            let star = term.hasSuffix("*")
            var scalars = Array(term.unicodeScalars)
            while let first = scalars.first, !isWord(first) { scalars.removeFirst() }
            while let last = scalars.last, !isWord(last) { scalars.removeLast() }
            term = String(String.UnicodeScalarView(scalars))
            let hasDigit = scalars.contains { (48...57).contains($0.value) }
            guard !term.isEmpty, scalars.count >= 2 || hasDigit else { continue }
            let full = term + (star ? "*" : "")
            if !terms.contains(full) { terms.append(full) }
        }
        return Array(terms.prefix(8))
    }

    /// One character as the index would write it (lowercase, no marks), for highlighting.
    fileprivate static func fold(_ character: Character) -> String {
        normalizeKeepingSpace(String(character))
    }

    private static func normalizeKeepingSpace(_ text: String) -> String {
        let lowered = text.replacingOccurrences(of: "\u{05BE}", with: " ").lowercased()
        var kept = String.UnicodeScalarView()
        for scalar in lowered.decomposedStringWithCanonicalMapping.unicodeScalars {
            let value = scalar.value
            if (0x0300...0x036F).contains(value) || (0x0591...0x05C7).contains(value) { continue }
            kept.append(scalar)
        }
        return String(kept)
    }
}

// MARK: - Matching a term in one text

enum SearchMatch {

    /// Where a term occurs in `text` (already normalized), as scalar ranges. A whole word, with an
    /// optional "s"/"es" ending, or from the start of a word when `prefix`; in Hebrew anywhere.
    static func occurrences(of term: [Unicode.Scalar], in text: [Unicode.Scalar], prefix: Bool, anywhere: Bool) -> [Range<Int>] {
        let n = term.count
        guard n > 0, text.count >= n else { return [] }
        var found: [Range<Int>] = []
        var i = 0
        while i <= text.count - n {
            if text[i] == term[0], Array(text[i..<i + n]) == term {
                if anywhere {
                    found.append(i..<i + n)
                    i += n
                    continue
                }
                if i == 0 || !SearchText.isWord(text[i - 1]) {
                    var end = i + n
                    if prefix {
                        while end < text.count, SearchText.isWord(text[end]) { end += 1 }
                        found.append(i..<end)
                    } else if end == text.count || !SearchText.isWord(text[end]) {
                        found.append(i..<end)
                    } else if text[end] == "s", end + 1 == text.count || !SearchText.isWord(text[end + 1]) {
                        found.append(i..<end + 1)
                    } else if end + 1 < text.count, text[end] == "e", text[end + 1] == "s", end + 2 == text.count || !SearchText.isWord(text[end + 2]) {
                        found.append(i..<end + 2)
                    }
                }
            }
            i += 1
        }
        return found
    }

    static func scalars(_ text: String) -> [Unicode.Scalar] { Array(text.unicodeScalars) }
}

// MARK: - Index

/// What a search found: verse ids in Bible order, and how many per book.
struct SearchOutcome {
    let ids: [Int32]
    let bookCounts: [(book: Int, count: Int)]
}

final class SearchIndex: @unchecked Sendable {

    let isHebrew: Bool
    let books: [BibleBook]
    private(set) var verseCount = 0

    private var bookOf: [UInt16] = []
    private var chapterOf: [UInt16] = []
    private var verseOf: [UInt16] = []
    private var normalized: [String] = []
    /// Hebrew only: every verse's normalized text as UTF-8, each ended by a 0 byte, and where each starts.
    private var blob: [UInt8] = []
    private var blobStarts: [Int] = []
    private var postings: [String: [Int32]] = [:]
    private var vocabulary: [String] = []

    init(books: [BibleBook], isHebrew: Bool) {
        self.books = books
        self.isHebrew = isHebrew
        for (b, book) in books.enumerated() {
            for (c, chapter) in book.chapters.enumerated() {
                for (v, verse) in chapter.verses.enumerated() {
                    let id = Int32(bookOf.count)
                    let text = SearchText.normalize(verse.text)
                    bookOf.append(UInt16(b))
                    chapterOf.append(UInt16(c))
                    verseOf.append(UInt16(v))
                    if isHebrew {
                        blobStarts.append(blob.count)
                        blob.append(contentsOf: text.utf8)
                        blob.append(0)
                    } else {
                        normalized.append(text)
                        addWords(of: text, id: id)
                    }
                }
            }
        }
        verseCount = bookOf.count
        vocabulary = postings.keys.sorted()
    }

    private func addWords(of text: String, id: Int32) {
        var word = String.UnicodeScalarView()
        func flush() {
            guard !word.isEmpty else { return }
            let key = String(word)
            if postings[key]?.last != id { postings[key, default: []].append(id) }
            word = String.UnicodeScalarView()
        }
        for scalar in text.unicodeScalars {
            if SearchText.isWord(scalar) { word.append(scalar) } else { flush() }
        }
        flush()
    }

    /// Where a verse is: book position, chapter position and verse position (not numbers).
    func location(of id: Int32) -> (book: Int, chapter: Int, verse: Int) {
        (Int(bookOf[Int(id)]), Int(chapterOf[Int(id)]), Int(verseOf[Int(id)]))
    }

    func verse(of id: Int32) -> (bookName: String, chapterNumber: Int, verse: Verse, location: (book: Int, chapter: Int, verse: Int)) {
        let at = location(of: id)
        let book = books[at.book]
        let chapter = book.chapters[at.chapter]
        return (book.name, chapter.number, chapter.verses[at.verse], at)
    }

    // MARK: Search

    func search(_ terms: [String]) -> SearchOutcome {
        guard !terms.isEmpty else { return SearchOutcome(ids: [], bookCounts: []) }
        let ids = isHebrew ? scanHebrew(terms) : lookUp(terms)
        var counts: [Int: Int] = [:]
        for id in ids { counts[Int(bookOf[Int(id)]), default: 0] += 1 }
        return SearchOutcome(ids: ids, bookCounts: counts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
    }

    /// Hebrew: every term anywhere in the verse. Looks for the first term through all the text at
    /// once, then checks the other terms in the verses it was found in.
    private func scanHebrew(_ terms: [String]) -> [Int32] {
        let needles = terms.map { Array(($0.hasSuffix("*") ? String($0.dropLast()) : $0).utf8) }.filter { !$0.isEmpty }
        guard let first = needles.first, !blob.isEmpty else { return [] }
        return blob.withUnsafeBufferPointer { buffer -> [Int32] in
            guard let base = buffer.baseAddress else { return [] }
            func contains(_ needle: [UInt8], from start: Int, to end: Int) -> Bool {
                needle.withUnsafeBufferPointer { pattern in
                    memmem(base + start, end - start, pattern.baseAddress!, pattern.count) != nil
                }
            }
            var ids: [Int32] = []
            var offset = 0
            while offset < buffer.count {
                let hit: UnsafeMutableRawPointer? = first.withUnsafeBufferPointer { pattern in
                    memmem(base + offset, buffer.count - offset, pattern.baseAddress!, pattern.count)
                }
                guard let hit else { break }
                let position = base.distance(to: hit.assumingMemoryBound(to: UInt8.self))
                // The verse that holds this position: the last start at or before it.
                var low = 0, high = blobStarts.count
                while low < high {
                    let mid = (low + high) / 2
                    if blobStarts[mid] <= position { low = mid + 1 } else { high = mid }
                }
                let id = low - 1
                let end = id + 1 < blobStarts.count ? blobStarts[id + 1] - 1 : buffer.count - 1
                if needles.dropFirst().allSatisfy({ contains($0, from: blobStarts[id], to: end) }) { ids.append(Int32(id)) }
                offset = end + 1
            }
            return ids
        }
    }

    private func lookUp(_ terms: [String]) -> [Int32] {
        var lists: [[Int32]] = []
        for term in terms {
            let list = candidates(for: term)
            if list.isEmpty { return [] }
            lists.append(list)
        }
        lists.sort { $0.count < $1.count }
        var result = lists[0]
        for list in lists.dropFirst() {
            result = Self.intersect(result, list)
            if result.isEmpty { break }
        }
        return result
    }

    /// The verses that contain one term (sorted).
    private func candidates(for term: String) -> [Int32] {
        let prefix = term.hasSuffix("*")
        let core = prefix ? String(term.dropLast()) : term
        let words = core.unicodeScalars.split(whereSeparator: { !SearchText.isWord($0) }).map { String(String.UnicodeScalarView($0)) }

        // One plain word: its verses, and its plural forms.
        if words.count == 1, words[0] == core {
            return prefix ? startingWith(core) : Self.union([postings[core], postings[core + "s"], postings[core + "es"]])
        }

        // A phrase or a word with punctuation: verses that have all its words, then check the text.
        var lists: [[Int32]] = []
        for (position, word) in words.enumerated() {
            let last = position == words.count - 1
            lists.append(last ? (prefix ? startingWith(word) : Self.union([postings[word], postings[word + "s"], postings[word + "es"]])) : (postings[word] ?? []))
        }
        guard !lists.isEmpty, lists.allSatisfy({ !$0.isEmpty }) else { return [] }
        lists.sort { $0.count < $1.count }
        var result = lists[0]
        for list in lists.dropFirst() { result = Self.intersect(result, list) }
        let needle = Array(core.unicodeScalars)
        return result.filter { id in
            !SearchMatch.occurrences(of: needle, in: Array(normalized[Int(id)].unicodeScalars), prefix: prefix, anywhere: false).isEmpty
        }
    }

    private func startingWith(_ prefix: String) -> [Int32] {
        var low = 0, high = vocabulary.count
        while low < high {
            let mid = (low + high) / 2
            if vocabulary[mid] < prefix { low = mid + 1 } else { high = mid }
        }
        var lists: [[Int32]] = []
        var index = low
        while index < vocabulary.count, vocabulary[index].hasPrefix(prefix) {
            if let list = postings[vocabulary[index]] { lists.append(list) }
            index += 1
        }
        return Self.union(lists)
    }

    private static func union(_ lists: [[Int32]?]) -> [Int32] {
        let present = lists.compactMap { $0 }
        guard present.count > 1 else { return present.first ?? [] }
        return Array(Set(present.joined())).sorted()
    }

    private static func intersect(_ a: [Int32], _ b: [Int32]) -> [Int32] {
        var result: [Int32] = []
        var i = 0, j = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] { result.append(a[i]); i += 1; j += 1 }
            else if a[i] < b[j] { i += 1 } else { j += 1 }
        }
        return result
    }
}

// MARK: - Highlighting the matches in a verse

enum SearchHighlight {

    /// The parts of `text` that matched `terms`, merged, in order.
    static func ranges(in text: String, terms: [String], isHebrew: Bool) -> [Range<String.Index>] {
        var folded: [Unicode.Scalar] = []
        var starts: [String.Index] = []
        var ends: [String.Index] = []
        for index in text.indices {
            let next = text.index(after: index)
            for scalar in SearchText.fold(text[index]).unicodeScalars {
                folded.append(scalar)
                starts.append(index)
                ends.append(next)
            }
        }

        var spans: [Range<Int>] = []
        for term in terms {
            let prefix = term.hasSuffix("*")
            let core = Array((prefix ? String(term.dropLast()) : term).unicodeScalars)
            spans += SearchMatch.occurrences(of: core, in: folded, prefix: prefix, anywhere: isHebrew)
        }

        var merged: [Range<Int>] = []
        for span in spans.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, span.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, span.upperBound)
            } else {
                merged.append(span)
            }
        }
        return merged.map { starts[$0.lowerBound]..<ends[$0.upperBound - 1] }
    }

    /// The verse text with the matches in bold and the given color.
    static func attributed(_ text: String, terms: [String], isHebrew: Bool, color: Color) -> AttributedString {
        var result = AttributedString(text)
        for range in ranges(in: text, terms: terms, isHebrew: isHebrew) {
            let lower = result.characters.index(result.characters.startIndex, offsetBy: text.distance(from: text.startIndex, to: range.lowerBound))
            let upper = result.characters.index(result.characters.startIndex, offsetBy: text.distance(from: text.startIndex, to: range.upperBound))
            result[lower..<upper].foregroundColor = color
            result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}

// MARK: - Indexes, built once per translation

actor SearchEngine {

    static let shared = SearchEngine()

    private var cached: (key: String, index: SearchIndex)?

    /// The index for a translation; builds it on first use (a second or less), then reuses it.
    func index(key: String, books: [BibleBook], isHebrew: Bool) -> SearchIndex {
        if let cached, cached.key == key, cached.index.books.count == books.count { return cached.index }
        let built = SearchIndex(books: books, isHebrew: isHebrew)
        cached = (key, built)
        return built
    }
}
