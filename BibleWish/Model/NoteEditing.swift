//
//  NoteEditing.swift
//
//  What the note editor's toolbar does to the text: bold, italic, headings, lists, links, colors,
//  boxes and verse cards. Each action takes the text and the selection and returns one edit, so it can
//  be checked without any screen. A port of the website's editor (attachNoteTools in js/note-format.js);
//  positions are UTF-16 offsets, like NSRange and JavaScript string indexes.
//

import Foundation

enum NoteEditing {

    /// Replace `range` with `text`, then select `selection` (positions in the new text).
    struct Edit: Equatable {
        var range: NSRange
        var text: String
        var selection: NSRange
    }

    /// The text after the edit.
    static func apply(_ edit: Edit, to value: String) -> String {
        (value as NSString).replacingCharacters(in: edit.range, with: edit.text)
    }

    // MARK: - Bold, italic

    /// Wraps the selection (or a placeholder) in `marker`; wraps already in place are taken off.
    static func wrap(_ value: String, _ selection: NSRange, marker: String, placeholder: String) -> Edit {
        let text = value as NSString
        let selected = text.substring(with: selection)
        let markerLength = (marker as NSString).length
        let start = selection.location
        let end = selection.location + selection.length

        if start >= markerLength, end + markerLength <= text.length,
           text.substring(with: NSRange(location: start - markerLength, length: markerLength)) == marker,
           text.substring(with: NSRange(location: end, length: markerLength)) == marker {
            return Edit(
                range: NSRange(location: start - markerLength, length: selection.length + 2 * markerLength),
                text: selected,
                selection: NSRange(location: start - markerLength, length: selection.length)
            )
        }
        return wrapped(selection, selected, open: marker, close: marker, placeholder: placeholder)
    }

    /// `lead open core close trail`, keeping the selection's own spaces outside the markers (a double
    /// tap selects a word plus its space).
    private static func wrapped(_ range: NSRange, _ selected: String, open: String, close: String, placeholder: String) -> Edit {
        let lead = String(selected.prefix { $0.isWhitespace })
        let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        let core = trimmed.isEmpty ? placeholder : trimmed
        let trail = trimmed.isEmpty ? "" : String(selected.reversed().prefix { $0.isWhitespace }.reversed())
        let leadLength = (lead as NSString).length
        let openLength = (open as NSString).length
        return Edit(
            range: range,
            text: lead + open + core + close + trail,
            selection: NSRange(location: range.location + leadLength + openLength, length: (core as NSString).length)
        )
    }

    // MARK: - Colors

    /// Wraps the selection in {color|…} (`mark` false) or {=color|…} (`mark` true). A different color
    /// replaces the old one; the same color takes it off.
    static func color(_ value: String, _ selection: NSRange, id: String, mark: Bool) -> Edit {
        let text = value as NSString
        let marker = mark ? "=" : ""
        let start = selection.location
        let end = start + selection.length
        let selected = text.substring(with: selection)

        let before = text.substring(to: start)
        if let regex = try? NSRegularExpression(pattern: #"\{(=?)([a-z]+)\|$"#),
           let match = regex.firstMatch(in: before, range: NSRange(location: 0, length: (before as NSString).length)),
           (before as NSString).substring(with: match.range(at: 1)) == marker,
           let known = NoteColor(rawValue: (before as NSString).substring(with: match.range(at: 2))),
           end < text.length, text.substring(with: NSRange(location: end, length: 1)) == "}" {
            let openLength = match.range.length
            let range = NSRange(location: start - openLength, length: selection.length + openLength + 1)
            if known.rawValue == id {
                return Edit(range: range, text: selected, selection: NSRange(location: range.location, length: selection.length))
            }
            let open = "{\(marker)\(id)|"
            return Edit(
                range: range,
                text: open + selected + "}",
                selection: NSRange(location: range.location + (open as NSString).length, length: selection.length)
            )
        }

        let open = "{\(marker)\(id)|"
        return wrapped(selection, selected, open: open, close: "}", placeholder: mark ? "highlighted text" : "colored text")
    }

    // MARK: - Boxes and verse cards

    /// Puts the selection (or a placeholder) in its own "::: color" box.
    static func box(_ value: String, _ selection: NSRange, id: String) -> Edit {
        let text = value as NSString
        let selected = text.substring(with: selection).trimmingCharacters(in: .whitespacesAndNewlines)
        let core = selected.isEmpty ? "Your text" : selected
        let head = gap(before: selection.location, in: text) + "::: \(id)\n"
        let headLength = (head as NSString).length
        return Edit(
            range: selection,
            text: head + core + "\n:::\n",
            selection: NSRange(location: selection.location + headLength, length: (core as NSString).length)
        )
    }

    /// A verse card with its reference underneath: "::: verse John 3:16 · KJV".
    static func verseCard(_ value: String, _ selection: NSRange, reference: String, translation: String, text verse: String) -> Edit {
        let block = gap(before: selection.location, in: value as NSString) + "::: verse \(reference) \u{00B7} \(translation)\n\(verse)\n:::\n"
        return Edit(
            range: selection,
            text: block,
            selection: NSRange(location: selection.location + (block as NSString).length, length: 0)
        )
    }

    /// A line break when the caret isn't already at the start of a line.
    private static func gap(before location: Int, in text: NSString) -> String {
        guard location > 0, text.substring(with: NSRange(location: location - 1, length: 1)) != "\n" else { return "" }
        return "\n"
    }

    // MARK: - Lines: headings, lists, quotes

    enum LineStyle {
        case heading, bullet, numbered, quote

        fileprivate var pattern: String {
            switch self {
            case .heading: return #"^#{1,3}\s+"#
            case .bullet: return #"^\s*[-*\x{2022}]\s+"#
            case .numbered: return #"^\s*\d{1,3}[.)]\s+"#
            case .quote: return #"^\s*>\s?"#
            }
        }

        fileprivate func prefix(_ index: Int) -> String {
            switch self {
            case .heading: return "## "
            case .bullet: return "- "
            case .numbered: return "\(index + 1). "
            case .quote: return "> "
            }
        }
    }

    private static let anyPrefix = #"^\s*(?:[-*\x{2022}]\s+|\d{1,3}[.)]\s+|>\s?|#{1,3}\s+)"#

    /// Gives every selected line the style, or takes it off when all of them already have it.
    static func lines(_ value: String, _ selection: NSRange, style: LineStyle) -> Edit {
        let text = value as NSString
        let start = selection.location
        let end = start + selection.length

        let lineStart = start == 0 ? 0 : text.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: start)).upperBound(or: 0)
        let trailingBreak = end > 0 && text.substring(with: NSRange(location: end - 1, length: 1)) == "\n"
        let selectionEnd = max(start, end - (trailingBreak ? 1 : 0))
        let nextBreak = text.range(of: "\n", options: [], range: NSRange(location: selectionEnd, length: text.length - selectionEnd))
        let lineEnd = nextBreak.location == NSNotFound ? text.length : nextBreak.location

        let lines = text.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart)).components(separatedBy: "\n")
        let filled = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let removing = !filled.isEmpty && filled.allSatisfy { matches($0, style.pattern) }

        var count = 0
        let next = lines.map { line -> String in
            if removing { return replacingFirst(style.pattern, in: line) }
            if line.trimmingCharacters(in: .whitespaces).isEmpty && !filled.isEmpty { return line }
            defer { count += 1 }
            return style.prefix(count) + replacingFirst(anyPrefix, in: line)
        }.joined(separator: "\n")

        return Edit(
            range: NSRange(location: lineStart, length: lineEnd - lineStart),
            text: next,
            selection: NSRange(location: lineStart + (next as NSString).length, length: 0)
        )
    }

    // MARK: - Links

    /// [label](https://): a web address that is selected becomes the link's target.
    static func link(_ value: String, _ selection: NSRange) -> Edit {
        let selected = (value as NSString).substring(with: selection).trimmingCharacters(in: .whitespacesAndNewlines)
        if matches(selected, #"^https?://\S+$"#) {
            return Edit(range: selection, text: "[link text](\(selected))", selection: NSRange(location: selection.location + 1, length: 9))
        }
        let label = selected.isEmpty ? "link text" : selected
        let labelLength = (label as NSString).length
        return Edit(
            range: selection,
            text: "[\(label)](https://)",
            selection: NSRange(location: selection.location + labelLength + 3, length: 8)
        )
    }

    // MARK: - Return key in a list

    /// Return at the end of a list item starts the next one; Return on an empty item ends the list.
    /// Nil when the caret isn't in a list (the editor then inserts a plain line break).
    static func returnKey(_ value: String, caret: Int) -> Edit? {
        let text = value as NSString
        let lineStart = caret == 0 ? 0 : text.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: caret)).upperBound(or: 0)
        let line = text.substring(with: NSRange(location: lineStart, length: caret - lineStart))

        guard let regex = try? NSRegularExpression(pattern: #"^(\s*)([-*\x{2022}]|\d{1,3}[.)]|>)(\s+)(.*)$"#),
              let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else { return nil }
        func group(_ index: Int) -> String { (line as NSString).substring(with: match.range(at: index)) }

        if group(4).trimmingCharacters(in: .whitespaces).isEmpty {
            return Edit(range: NSRange(location: lineStart, length: caret - lineStart), text: "", selection: NSRange(location: lineStart, length: 0))
        }
        let marker = group(2)
        let next: String
        if let number = Int(marker.dropLast()), marker.first?.isNumber == true {
            next = "\(number + 1)\(marker.last!)"
        } else {
            next = marker
        }
        let inserted = "\n\(group(1))\(next)\(group(3))"
        return Edit(
            range: NSRange(location: caret, length: 0),
            text: inserted,
            selection: NSRange(location: caret + (inserted as NSString).length, length: 0)
        )
    }

    // MARK: - Helpers

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func replacingFirst(_ pattern: String, in text: String) -> String {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return text }
        return text.replacingCharacters(in: range, with: "")
    }
}

private extension NSRange {
    /// The end of the range, or `fallback` when nothing was found.
    func upperBound(or fallback: Int) -> Int {
        location == NSNotFound ? fallback : location + length
    }
}
