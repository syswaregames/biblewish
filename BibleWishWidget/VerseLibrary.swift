//
//  VerseLibrary.swift
//
//  The Verse of the Day for a date, from the widget's own copy of the website's verse files
//  (Data/votd). Same verse list and day numbering as the app and the website.
//

import Foundation

enum VerseLibrary {

    private struct Index: Decodable {
        struct Day: Decodable {
            let book: Int
            let chapter: Int
            let verses: [Int]
        }
        let days: [Day]
    }

    private struct Texts: Decodable {
        let books: [String]
        let texts: [String?]
    }

    /// Days before each month, counting February as 29 days (same as the app and the website).
    private static let monthStart = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

    private static func load<T: Decodable>(_ type: T.Type, _ name: String, _ bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "votd"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func verse(on date: Date, translation: String, bundle: Bundle = .main) -> WidgetVerse {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        let day = monthStart[(parts.month ?? 1) - 1] + (parts.day ?? 1) - 1

        guard let index = load(Index.self, "index", bundle), day < index.days.count else { return .sample }
        let reference = index.days[day]

        let id = ["kjv", "web", "bliv", "heb"].contains(translation) ? translation : "kjv"
        var texts = load(Texts.self, id, bundle)
        if texts.flatMap({ $0.texts.indices.contains(day) ? $0.texts[day] : nil }) == nil {
            texts = load(Texts.self, "kjv", bundle)
        }
        guard let texts, day < texts.texts.count, let text = texts.texts[day],
              reference.book < texts.books.count, let first = reference.verses.first, let last = reference.verses.last
        else { return .sample }

        let range = first == last ? "\(first)" : "\(first)-\(last)"
        return WidgetVerse(
            label: "\(texts.books[reference.book]) \(reference.chapter):\(range)",
            text: text,
            isRightToLeft: id == "heb"
        )
    }
}
