//
//  RedLetterRanges.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-02-25.
//

import Foundation

final class RedLetterRanges {

    static let shared = RedLetterRanges()

    private var rangesByBook: [String: [Int: [ClosedRange<Int>]]] = [:]

    private init() {
        loadRanges()
    }

    func isRedLetter(
        bookName: String,
        chapter: Int,
        verse: Int,
        includeActsRevelation: Bool
    ) -> Bool {
        guard let bookId = BookNameMapper.bookId(for: bookName) else { return false }
        if !includeActsRevelation && (bookId == "ACT" || bookId == "REV") {
            return false
        }
        guard let chapterRanges = rangesByBook[bookId]?[chapter] else { return false }
        return chapterRanges.contains { $0.contains(verse) }
    }

    private func loadRanges() {
        guard let url = Bundle.main.url(forResource: "red_letter_ranges", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(RedLetterRangePayload.self, from: data)
            rangesByBook = decoded.toRanges()
        } catch {
            rangesByBook = [:]
        }
    }
}

private struct RedLetterRangePayload: Decodable {
    let books: [String: [String: [[Int]]]]

    func toRanges() -> [String: [Int: [ClosedRange<Int>]]] {
        var result: [String: [Int: [ClosedRange<Int>]]] = [:]
        for (bookId, chapters) in books {
            var chapterMap: [Int: [ClosedRange<Int>]] = [:]
            for (chapterKey, ranges) in chapters {
                guard let chapterNumber = Int(chapterKey) else { continue }
                let converted: [ClosedRange<Int>] = ranges.compactMap { raw in
                    guard let first = raw.first else { return nil }
                    let last = raw.count > 1 ? raw[1] : first
                    return first...last
                }
                if !converted.isEmpty {
                    chapterMap[chapterNumber] = converted
                }
            }
            if !chapterMap.isEmpty {
                result[bookId] = chapterMap
            }
        }
        return result
    }
}
