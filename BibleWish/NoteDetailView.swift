//
//  NoteDetailView.swift
//
//  A note as you read it: light Markdown, and verse references that open the passage.
//  Same syntax as the website: # heading, ## smaller heading, **bold**, *italic* or _italic_,
//  - bullet, 1. numbered, > quote, [text](https://...) and bare links.
//

import SwiftUI

// MARK: - Colors

/// The five note colors, as on the website: {red|text}, {=gold|text}, ::: green … :::
enum NoteColor: String, CaseIterable {
    case red, gold, green, teal, violet

    func color(in palette: ThemePalette) -> Color {
        switch self {
        case .red: return palette.roseInk
        case .gold: return palette.goldBright
        case .green: return palette.greenInk
        case .teal: return palette.tealInk
        case .violet: return palette.violetInk
        }
    }

    static var pattern: String { allCases.map(\.rawValue).joined(separator: "|") }
}

// MARK: - Blocks

/// A note body split into blocks. The syntax matches the website's (js/note-format.js):
///   # Heading  ## Smaller  ### Smaller   - or * or • bullet   1. or 1) numbered   > quote
///   ::: gold Optional title … :::   a colored box (red, gold, green, teal, violet)
///   ::: verse John 3:16 · KJV … :::   a verse card
indirect enum NoteBlock: Equatable {
    case heading(level: Int, text: String)
    case bullet(String)
    case numbered(Int, String)
    case quote(String)
    case paragraph(String)
    case gap
    case box(color: NoteColor, title: String?, body: [NoteBlock])
    case verse(cite: String, body: [NoteBlock])

    static func parse(_ text: String) -> [NoteBlock] {
        parse(lines: text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n"))
    }

    private static func parse(lines: [String]) -> [NoteBlock] {
        var blocks: [NoteBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]

            // A box or verse card needs its closing ":::" line; without one the line stays plain text.
            if let open = groups(line, #"^:::\s*(verse|\#(NoteColor.pattern))(?:\s+(.*?))?\s*$"#),
               let close = lines[(index + 1)...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == ":::" }) {
                let body = parse(lines: Array(lines[(index + 1)..<close]))
                let title = open[2].map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
                if open[1] == "verse" {
                    blocks.append(.verse(cite: title ?? "", body: body))
                } else if let color = NoteColor(rawValue: open[1] ?? "") {
                    blocks.append(.box(color: color, title: title, body: body))
                }
                index = close + 1
                continue
            }

            blocks.append(single(line))
            index += 1
        }
        return blocks
    }

    private static func single(_ line: String) -> NoteBlock {
        if line.trimmingCharacters(in: .whitespaces).isEmpty { return .gap }
        if let m = groups(line, #"^\s{0,3}(#{1,3})\s+(.+)$"#), let hashes = m[1], let text = m[2] {
            return .heading(level: hashes.count == 1 ? 1 : 2, text: text.trimmingCharacters(in: .whitespaces))
        }
        if let m = groups(line, #"^\s*(?:([-*\x{2022}])|(\d{1,3})[.)])\s+(.*)$"#) {
            let text = (m[3] ?? "").trimmingCharacters(in: .whitespaces)
            if let number = m[2].flatMap(Int.init) { return .numbered(number, text) }
            return .bullet(text)
        }
        if let m = groups(line, #"^\s*>\s?(.*)$"#) {
            return .quote((m[1] ?? "").trimmingCharacters(in: .whitespaces))
        }
        return .paragraph(line.trimmingCharacters(in: .whitespaces))
    }

    /// The capture groups of the first match (index 0 is the whole match), or nil.
    private static func groups(_ text: String, _ pattern: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).map { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
    }
}

// MARK: - Body

struct NoteBodyView: View {

    let text: String

    var body: some View {
        NoteBlocksView(blocks: NoteBlock.parse(text))
    }

    // MARK: - Passage links

    static func passageURL(_ reference: PassageReference) -> URL? {
        var components = URLComponents()
        components.scheme = "bwpassage"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "book", value: reference.bookName),
            URLQueryItem(name: "chapter", value: String(reference.chapterIndex)),
            URLQueryItem(name: "verse", value: reference.verse.map(String.init)),
        ]
        return components.url
    }

    static func passage(from url: URL) -> PassageReference? {
        guard url.scheme == "bwpassage",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let book = items.first(where: { $0.name == "book" })?.value,
              let chapter = items.first(where: { $0.name == "chapter" })?.value.flatMap(Int.init) else { return nil }
        let verse = items.first(where: { $0.name == "verse" })?.value.flatMap(Int.init)
        return PassageReference(bookName: book, chapterIndex: chapter, verse: verse)
    }
}

/// A list of blocks. Boxes and verse cards hold blocks of their own, so this view contains itself.
struct NoteBlocksView: View {

    let blocks: [NoteBlock]

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: NoteBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(.system(level == 1 ? .title2 : .headline, design: .serif, weight: .semibold))
                .foregroundStyle(palette.ink)
                .padding(.top, 6)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}").foregroundStyle(palette.gold)
                Text(inline(text)).foregroundStyle(palette.ink)
            }
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).").foregroundStyle(palette.gold)
                Text(inline(text)).foregroundStyle(palette.ink)
            }
        case .quote(let text):
            HStack(spacing: 10) {
                Rectangle().fill(palette.gold.opacity(0.6)).frame(width: 3)
                Text(inline(text)).italic().foregroundStyle(palette.inkSoft)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .paragraph(let text):
            Text(inline(text)).foregroundStyle(palette.ink)
        case .gap:
            Color.clear.frame(height: 6)
        case .box(let color, let title, let body):
            box(color: color.color(in: palette), title: title, body: body)
        case .verse(let cite, let body):
            verseCard(cite: cite, body: body)
        }
    }

    /// A tinted callout with a colored edge and an optional title.
    private func box(color: Color, title: String?, body: [NoteBlock]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(inline(title))
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(color)
            }
            NoteBlocksView(blocks: body)
        }
        .padding(.vertical, 10)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.45)))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4).padding(.vertical, 1)
        }
        .padding(.vertical, 4)
    }

    /// A verse with its reference underneath, on a gold-washed card.
    private func verseCard(cite: String, body: [NoteBlock]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NoteBlocksView(blocks: body)
                .font(.system(.body, design: .serif))
            if !cite.isEmpty {
                Text(inline(cite))
                    .font(.system(.footnote, design: .serif, weight: .semibold))
                    .foregroundStyle(palette.goldBright)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.gold.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.gold.opacity(0.45)))
        .padding(.vertical, 4)
    }

    // MARK: - Inline formatting

    /// What a piece of text looks like: the formatting wrapped around it so far.
    private struct Style {
        var bold = false
        var italic = false
        var color: Color?
        var background: Color?
    }

    /// A line as styled text, built from the website's grammar (see NoteInline).
    private func inline(_ line: String) -> AttributedString {
        attributed(NoteInline.parse(line), style: Style())
    }

    private func attributed(_ nodes: [NoteInline.Node], style: Style) -> AttributedString {
        var result = AttributedString()
        for node in nodes {
            switch node {
            case .text(let text):
                result += styled(withReferences(text), style)
            case .bold(let inner):
                var next = style
                next.bold = true
                result += attributed(inner, style: next)
            case .italic(let inner):
                var next = style
                next.italic = true
                result += attributed(inner, style: next)
            case .color(let color, let inner):
                var next = style
                next.color = color.color(in: palette)
                result += attributed(inner, style: next)
            case .mark(let color, let inner):
                var next = style
                next.background = color.color(in: palette).opacity(0.30)
                result += attributed(inner, style: next)
            case .link(let label, let url):
                var part = AttributedString(label)
                part.link = url
                result += styled(part, style)
            }
        }
        return result
    }

    private func styled(_ text: AttributedString, _ style: Style) -> AttributedString {
        var text = text
        var intent: InlinePresentationIntent = []
        if style.bold { intent.insert(.stronglyEmphasized) }
        if style.italic { intent.insert(.emphasized) }
        if !intent.isEmpty { text.inlinePresentationIntent = intent }
        if let color = style.color { text.foregroundColor = color }
        if let background = style.background { text.backgroundColor = background }
        return text
    }

    /// Plain text with verse references ("John 3:16", "Rom 8:28-30") turned into links.
    private func withReferences(_ plain: String) -> AttributedString {
        var attributed = AttributedString(plain)
        for match in PassageReference.references(in: plain, books: viewModel.books) {
            guard let url = NoteBodyView.passageURL(match.reference) else { continue }
            let start = plain.distance(from: plain.startIndex, to: match.range.lowerBound)
            let end = plain.distance(from: plain.startIndex, to: match.range.upperBound)
            let lower = attributed.index(attributed.startIndex, offsetByCharacters: start)
            let upper = attributed.index(attributed.startIndex, offsetByCharacters: end)
            attributed[lower..<upper].link = url
        }
        return attributed
    }
}

// MARK: - Screen

struct NoteDetailView: View {

    let noteID: UUID

    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var editing: Note?
    @State private var target: PassageReference?

    var body: some View {
        Group {
            if let note = noteStore.note(id: noteID) {
                content(note)
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .themedScreen()
        .navigationTitle("Note")
        .toolbar {
            if let note = noteStore.note(id: noteID) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editing = note }
                }
            }
        }
        .sheet(item: $editing) { note in
            NoteEditorView(note: note)
        }
        .navigationDestination(item: $target) { reference in
            if let book = viewModel.book(named: reference.bookName) {
                VerseListView(book: book, chapterIndex: reference.chapterIndex, scrollToVerse: reference.verse)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if let reference = NoteBodyView.passage(from: url) {
                target = reference
                return .handled
            }
            return .systemAction
        })
    }

    private func content(_ note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !note.title.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(note.title)
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(palette.ink)
                }

                if !note.reference.isEmpty {
                    if let reference = PassageReference.parse(note.reference, in: viewModel.books) {
                        Button {
                            target = reference
                        } label: {
                            Label(note.reference, systemImage: "book")
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .foregroundStyle(palette.goldBright)
                        }
                    } else {
                        Text(note.reference)
                            .font(.system(.subheadline, design: .serif, weight: .semibold))
                            .foregroundStyle(palette.goldBright)
                    }
                }

                if !note.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(note.tags) { tag in
                            Text(tag.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tag.color(in: palette))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .overlay(Capsule().stroke(tag.color(in: palette).opacity(0.7)))
                        }
                    }
                }

                NoteBodyView(text: note.body)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(4)

                Text("Written \(note.createdAt.formatted(date: .abbreviated, time: .omitted)) \u{00B7} edited \(note.updatedAt.formatted(.relative(presentation: .named))) \u{00B7} \(note.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(palette.inkMuted)
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableWidth()
        }
    }
}
