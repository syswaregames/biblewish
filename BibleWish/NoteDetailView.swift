//
//  NoteDetailView.swift
//
//  A note as you read it: light Markdown, and verse references that open the passage.
//  Same syntax as the website: # heading, ## smaller heading, **bold**, *italic* or _italic_,
//  - bullet, 1. numbered, > quote, [text](https://...) and bare links.
//

import SwiftUI

// MARK: - Blocks

private enum NoteBlock {
    case heading(level: Int, text: String)
    case bullet(String)
    case numbered(Int, String)
    case quote(String)
    case paragraph(String)
    case gap

    static func parse(_ text: String) -> [NoteBlock] {
        text.components(separatedBy: "\n").map { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return .gap }

            if line.hasPrefix("#") {
                let hashes = line.prefix { $0 == "#" }.count
                let rest = line.dropFirst(hashes)
                if hashes <= 6, rest.first == " " {
                    return .heading(level: min(hashes, 2), text: rest.trimmingCharacters(in: .whitespaces))
                }
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                return .bullet(String(line.dropFirst(2)))
            }
            if line.hasPrefix(">") {
                return .quote(line.dropFirst().trimmingCharacters(in: .whitespaces))
            }
            if let dot = line.firstIndex(of: "."),
               let number = Int(line[..<dot]),
               line[line.index(after: dot)...].hasPrefix(" ") {
                return .numbered(number, line[line.index(dot, offsetBy: 2)...].trimmingCharacters(in: .whitespaces))
            }
            return .paragraph(line)
        }
    }
}

// MARK: - Body

struct NoteBodyView: View {

    let text: String

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette

    var body: some View {
        let blocks = NoteBlock.parse(text)

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
        }
    }

    /// Bold, italic and links from Markdown, plus links for verse references and bare web addresses.
    private func inline(_ line: String) -> AttributedString {
        var attributed = (try? AttributedString(
            markdown: line,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(line)

        let plain = String(attributed.characters)

        func characterOffsets(_ range: Range<String.Index>) -> (Int, Int) {
            (plain.distance(from: plain.startIndex, to: range.lowerBound),
             plain.distance(from: plain.startIndex, to: range.upperBound))
        }

        func link(_ range: Range<String.Index>, to url: URL) {
            let (start, end) = characterOffsets(range)
            let lower = attributed.index(attributed.startIndex, offsetByCharacters: start)
            let upper = attributed.index(attributed.startIndex, offsetByCharacters: end)
            // Leave text that is already a Markdown link alone.
            guard attributed[lower..<upper].runs.allSatisfy({ $0.link == nil }) else { return }
            attributed[lower..<upper].link = url
        }

        for match in PassageReference.references(in: plain, books: viewModel.books) {
            if let url = Self.passageURL(match.reference) { link(match.range, to: url) }
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for found in detector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
                if let range = Range(found.range, in: plain), let url = found.url, url.scheme?.hasPrefix("http") == true {
                    link(range, to: url)
                }
            }
        }
        return attributed
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
