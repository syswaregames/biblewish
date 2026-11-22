//
//  SendVerse.swift
//
//  "Send to someone": what the website's send form posts to api/verses.php (a private link to a
//  verse, optionally delivered to a member by email). Port of js/send-verse.js.
//

import Foundation

enum SendVerse {

    /// The server's cap on verses in one message.
    static let maxVerses = 30

    static let messageLimit = 500
    static let nameLimit = 60

    /// The verses a message covers: from the first selected to the last, at most `maxVerses`.
    static func range(of selection: [Int]) -> ClosedRange<Int>? {
        guard let first = selection.min(), let last = selection.max() else { return nil }
        return first...min(last, first + maxVerses - 1)
    }

    /// The reference as the website writes it for a message: "John 3:16-18".
    static func reference(chapter: String, range: ClosedRange<Int>) -> String {
        "\(chapter):" + (range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)-\(range.upperBound)")
    }

    /// The JSON body. Empty text fields are sent as null, as the website does.
    static func payload(translation: String, bookIndex: Int, chapter: Int, range: ClosedRange<Int>, message: String, style: String, toName: String, toEmail: String, fromName: String) -> [String: Any] {
        func clean(_ text: String, _ limit: Int) -> Any {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? NSNull() : String(trimmed.prefix(limit))
        }
        return [
            "translation": translation,
            "book_index": bookIndex,
            "chapter": chapter,
            "verse_start": range.lowerBound,
            "verse_end": range.upperBound,
            "message": clean(message, messageLimit),
            "style": style,
            "to_name": clean(toName, nameLimit),
            "to_email": clean(toEmail, 254),
            "from_name": clean(fromName, nameLimit),
        ]
    }

    /// The line sent along with the link: "💌 Ana, I sent you a verse: John 3:16".
    static func shareLine(toName: String, reference: String) -> String {
        let name = toName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\u{1F48C} \(name.isEmpty ? "" : "\(name), ")I sent you a verse: \(reference)"
    }

    /// A WhatsApp link that prefills the message.
    static func whatsAppURL(line: String, link: String) -> URL? {
        var components = URLComponents(string: "https://wa.me/")
        components?.queryItems = [URLQueryItem(name: "text", value: "\(line)\n\(link)")]
        return components?.url
    }

    /// Only a plausible address is worth sending along (the server checks it again).
    static func looksLikeEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".") && !domain.hasSuffix(".") && !domain.hasPrefix(".") && !trimmed.contains(" ")
    }
}
