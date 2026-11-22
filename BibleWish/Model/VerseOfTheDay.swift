//
//  VerseOfTheDay.swift
//  BibleWish
//
//  One verse per calendar day, from the same list as biblewish.com (data/votd).
//

import Foundation

struct VerseOfTheDay {

    let bookName: String
    let chapterNumber: Int
    /// The reference as shown to the reader, e.g. "Isaiah 9:6" or "Luke 2:10-11".
    let label: String
    let text: String

    /// Days before each month, counting February as 29 days so every date maps to the same verse
    /// each year (the website does the same).
    private static let monthStart = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

    /// [book index, chapter, first verse, last verse] per day of the year.
    private static let references: [[Int]] = {
        guard let url = Bundle.main.url(forResource: "votd_references", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([[Int]].self, from: data) else {
            assertionFailure("votd_references.json is missing or unreadable")
            return []
        }
        return rows
    }()

    static func dayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return monthStart[(parts.month ?? 1) - 1] + (parts.day ?? 1) - 1
    }

    /// The verse for `date` in the given books (the selected translation), or nil if it isn't there.
    static func load(from books: [BibleBook], date: Date = Date()) -> VerseOfTheDay? {
        let day = dayIndex(for: date)
        guard day < references.count else { return nil }

        let row = references[day]
        guard row.count == 4, row[0] < books.count else { return nil }

        let book = books[row[0]]
        guard let chapter = book.chapters.first(where: { $0.number == row[1] }) else { return nil }

        let verses = chapter.verses.filter { $0.number >= row[2] && $0.number <= row[3] }
        guard !verses.isEmpty else { return nil }

        let range = row[2] == row[3] ? "\(row[2])" : "\(row[2])-\(row[3])"
        return VerseOfTheDay(
            bookName: book.name,
            chapterNumber: row[1],
            label: "\(book.name) \(row[1]):\(range)",
            text: verses.map(\.text).joined(separator: " ")
        )
    }
}
