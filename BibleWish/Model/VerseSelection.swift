//
//  VerseSelection.swift
//
//  Words for the verses a reader has selected: "John 3:16-17,20", the text to copy or share, and
//  the link back. A port of the website's reader (formatVerseReference, getShareText in read.html).
//  A selection is a set of verse numbers in one chapter; the reader keeps it as highlights.
//

import Foundation

enum VerseSelection {

    /// Runs of consecutive verses: [16, 17, 20] -> 16...17, 20...20. Duplicates and order are ignored.
    static func runs(_ verses: [Int]) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        for verse in Set(verses).sorted() {
            if let last = runs.last, last.upperBound + 1 == verse {
                runs[runs.count - 1] = last.lowerBound...verse
            } else {
                runs.append(verse...verse)
            }
        }
        return runs
    }

    /// "16-17,20": ranges as the website writes them.
    static func format(_ verses: [Int]) -> String {
        runs(verses).map { $0.lowerBound == $0.upperBound ? "\($0.lowerBound)" : "\($0.lowerBound)-\($0.upperBound)" }
            .joined(separator: ",")
    }

    /// "John 3:16-17,20".
    static func label(chapter: String, verses: [Int]) -> String {
        "\(chapter):\(format(verses))"
    }

    /// "16. text 17. text": the selected verses, numbered, in order.
    static func numberedText(_ verses: [Verse], selected: [Int]) -> String {
        let wanted = Set(selected)
        return verses.filter { wanted.contains($0.number) }
            .map { "\($0.number). \($0.text)" }
            .joined(separator: " ")
    }

    /// The selected verses' words without numbers (for a picture).
    static func plainText(_ verses: [Verse], selected: [Int]) -> String {
        let wanted = Set(selected)
        return verses.filter { wanted.contains($0.number) }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
    }

    /// What Copy and Share send: reference, translation, numbered verses and a link.
    static func shareText(label: String, translation: String, text: String, link: URL) -> String {
        "\(label) (\(translation))\n\(text)\n\nRead on BibleWish:\n\(link.absoluteString)"
    }

    /// A link to the passage on the website (its reader opens a typed reference).
    static func link(forLabel label: String, firstRunOnly verses: [Int]? = nil) -> URL {
        // "John 3:16-17,20" opens as its first run, "John 3:16-17".
        var text = label
        if let comma = label.firstIndex(of: ",") { text = String(label[..<comma]) }
        var components = URLComponents(string: "https://biblewish.com/read.html")!
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        return components.url ?? URL(string: "https://biblewish.com")!
    }
}
