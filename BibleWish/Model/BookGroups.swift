//
//  BookGroups.swift
//
//  The Bible's ten sections, each with its own color, as in the website's reader (BOOK_GROUPS in
//  read.html): the Gospels are red, Paul's letters green... Books keep their section's color
//  everywhere so readers learn where a book lives.
//

import SwiftUI

struct BookGroup: Identifiable, Equatable {

    enum Testament: String, CaseIterable {
        case old = "Old Testament"
        case new = "New Testament"
    }

    let testament: Testament
    /// The heading over the section's books.
    let label: String
    /// The short name on the jump chip.
    let short: String
    /// Book positions in the Bible (0 = Genesis).
    let books: ClosedRange<Int>
    let red: Double
    let green: Double
    let blue: Double

    var id: Int { books.lowerBound }

    /// The section's own color, for fills, borders and glows.
    var base: Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

    /// The color for text on the page. On the paper themes it is darkened (the site mixes it with
    /// black) so it stays readable on a light background.
    func ink(in palette: ThemePalette) -> Color {
        let k = palette.groupDarken
        return Color(red: red / 255 * k, green: green / 255 * k, blue: blue / 255 * k)
    }

    static let all: [BookGroup] = [
        BookGroup(testament: .old, label: "Law", short: "Law", books: 0...4, red: 232, green: 176, blue: 79),
        BookGroup(testament: .old, label: "History", short: "History", books: 5...16, red: 226, green: 138, blue: 96),
        BookGroup(testament: .old, label: "Poetry & Wisdom", short: "Poetry", books: 17...21, red: 232, green: 143, blue: 178),
        BookGroup(testament: .old, label: "Major Prophets", short: "Major Prophets", books: 22...26, red: 172, green: 148, blue: 240),
        BookGroup(testament: .old, label: "Minor Prophets", short: "Minor Prophets", books: 27...38, red: 132, green: 160, blue: 242),
        BookGroup(testament: .new, label: "Gospels", short: "Gospels", books: 39...42, red: 240, green: 118, blue: 112),
        BookGroup(testament: .new, label: "History", short: "Acts", books: 43...43, red: 92, green: 204, blue: 190),
        BookGroup(testament: .new, label: "Letters of Paul", short: "Paul", books: 44...56, red: 142, green: 208, blue: 134),
        BookGroup(testament: .new, label: "General Letters", short: "General Letters", books: 57...64, red: 204, green: 210, blue: 106),
        BookGroup(testament: .new, label: "Prophecy", short: "Revelation", books: 65...65, red: 104, green: 198, blue: 238),
    ]

    static func group(forBook index: Int) -> BookGroup? {
        all.first { $0.books.contains(index) }
    }

    static func testament(ofBook index: Int) -> Testament {
        index >= 39 ? .new : .old
    }

    static func groups(in testament: Testament) -> [BookGroup] {
        all.filter { $0.testament == testament }
    }
}

/// Finding a book by typing, like the website's navigator.
enum BookSearch {

    /// Positions of the books whose name starts with, then contains, the query (accents and spaces ignored).
    static func matches(_ query: String, in names: [String]) -> [Int] {
        let wanted = PassageReference.normalize(query)
        guard !wanted.isEmpty else { return [] }

        var starts: [Int] = []
        var contains: [Int] = []
        for (index, name) in names.enumerated() {
            let normalized = PassageReference.normalize(name)
            if normalized.hasPrefix(wanted) {
                starts.append(index)
            } else if normalized.contains(wanted) {
                contains.append(index)
            }
        }
        return starts + contains
    }
}
