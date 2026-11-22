//
//  NoteInline.swift
//
//  Inside a line of a note: **bold**, *italic*, _italic_, [links](https://...), web addresses,
//  {red|colored words} and {=gold|highlighted words}. A faithful port of the website's own pattern
//  (INLINE_PATTERN in js/note-format.js), so a note reads the same in the app and on biblewish.com.
//  Debug builds check it against the website's real regex (tools/gen_note_fixtures.mjs).
//

import Foundation

enum NoteInline {

    indirect enum Node: Equatable {
        case text(String)
        case bold([Node])
        case italic([Node])
        case link(label: String, url: URL)
        case color(NoteColor, [Node])
        case mark(NoteColor, [Node])
    }

    /// The website's alternatives, in its order. Capture groups: 1 bold, 2 *italic*, 3 _italic_,
    /// 4 link text, 5 link address, 6 bare address, 7 and 8 {color|text}, 9 and 10 {=color|text}.
    private static let regex: NSRegularExpression = {
        let colors = NoteColor.pattern
        let pattern = [
            #"\*\*(?=\S)(.+?)(?<=\S)\*\*"#,
            #"(?<![\p{L}\p{N}*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\p{L}\p{N}*])"#,
            #"(?<![\p{L}\p{N}_])_(?=\S)(.+?)(?<=\S)_(?![\p{L}\p{N}_])"#,
            #"\[([^\]\n]+)\]\((https?:\/\/[^\s()]+)\)"#,
            #"(https?:\/\/[^\s<>()]*[^\s<>().,;:!?'"])"#,
            "\\{(\(colors))\\|(.+?)\\}",
            "\\{=(\(colors))\\|(.+?)\\}",
        ].joined(separator: "|")
        return try! NSRegularExpression(pattern: pattern)
    }()

    static func parse(_ text: String) -> [Node] {
        var nodes: [Node] = []
        var last = text.startIndex

        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text) else { continue }
            func group(_ index: Int) -> String? {
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }

            if whole.lowerBound > last { nodes.append(.text(String(text[last..<whole.lowerBound]))) }
            last = whole.upperBound

            if let id = group(9), let inner = group(10), let color = NoteColor(rawValue: id) {
                nodes.append(.mark(color, parse(inner)))
            } else if let id = group(7), let inner = group(8), let color = NoteColor(rawValue: id) {
                nodes.append(.color(color, parse(inner)))
            } else if let inner = group(1) {
                nodes.append(.bold(parse(inner)))
            } else if let inner = group(2) ?? group(3) {
                nodes.append(.italic(parse(inner)))
            } else if let address = group(5) ?? group(6), let url = webURL(address) {
                nodes.append(.link(label: group(4) ?? address, url: url))
            } else {
                // Not a usable link: keep the text as written.
                nodes.append(.text(String(text[whole])))
            }
        }
        if last < text.endIndex { nodes.append(.text(String(text[last...]))) }
        return nodes
    }

    /// Only http and https addresses become links.
    private static func webURL(_ address: String) -> URL? {
        guard let url = URL(string: address), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host != nil else { return nil }
        return url
    }

    // MARK: - Plain text

    /// The words with all the markup taken away (for previews and titles).
    static func plain(_ text: String) -> String {
        plain(parse(text))
    }

    static func plain(_ nodes: [Node]) -> String {
        nodes.map { node -> String in
            switch node {
            case .text(let text): return text
            case .bold(let inner), .italic(let inner), .color(_, let inner), .mark(_, let inner): return plain(inner)
            case .link(let label, _): return label
            }
        }.joined()
    }

    // MARK: - Comparing with the website

    /// A compact description of the structure, in the same format tools/gen_note_fixtures.mjs writes.
    static func describe(_ nodes: [Node]) -> String {
        var merged: [Node] = []
        for node in nodes {
            if case .text(let text) = node, case .text(let before)? = merged.last {
                merged[merged.count - 1] = .text(before + text)
            } else {
                merged.append(node)
            }
        }
        return merged.compactMap { node -> String? in
            switch node {
            case .text(let text): return text.isEmpty ? nil : "t\(quote(text))"
            case .link(let label, _): return "l\(quote(label))"
            case .bold(let inner): return "b[\(describe(inner))]"
            case .italic(let inner): return "i[\(describe(inner))]"
            case .color(let color, let inner): return "c:\(color.rawValue)[\(describe(inner))]"
            case .mark(let color, let inner): return "m:\(color.rawValue)[\(describe(inner))]"
            }
        }.joined(separator: ",")
    }

    /// Like JavaScript's JSON.stringify for a string.
    private static func quote(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 { out += String(format: "\\u%04x", scalar.value) } else { out.unicodeScalars.append(scalar) }
            }
        }
        return out + "\""
    }
}

// MARK: - Plain text for whole notes

extension NoteBlock {

    /// The lines of a note as plain words, without any markup or empty lines.
    static func plainLines(_ blocks: [NoteBlock]) -> [String] {
        var lines: [String] = []
        for block in blocks {
            switch block {
            case .heading(_, let text), .paragraph(let text), .quote(let text):
                lines.append(NoteInline.plain(text))
            case .bullet(let text):
                lines.append(NoteInline.plain(text))
            case .numbered(_, let text):
                lines.append(NoteInline.plain(text))
            case .gap:
                break
            case .box(_, let title, let body):
                if let title { lines.append(NoteInline.plain(title)) }
                lines += plainLines(body)
            case .verse(let cite, let body):
                lines += plainLines(body)
                if !cite.isEmpty { lines.append(NoteInline.plain(cite)) }
            }
        }
        return lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
