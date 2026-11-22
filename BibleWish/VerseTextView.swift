//
//  VerseTextView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct VerseTextView: View {

    let verse: Verse
    let bookName: String
    let chapterNumber: Int
    /// Verse 1 of a book-page chapter: its first letter is drawn as a large gold initial.
    var dropCap = false

    @EnvironmentObject var bookmarkManager: BookmarkManager
    @EnvironmentObject var highlightManager: HighlightManager
    @EnvironmentObject var readerSettings: ReaderSettings
    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette

    @State private var showHighlightMenu = false
    @State private var showNoteEditor = false

    var body: some View {

        let bookmark = Bookmark(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verse.number,
            verseText: verse.text
        )

        let highlight = highlightManager.highlightFor(
            book: bookName,
            chapter: chapterNumber,
            verse: verse.number
        )

        (
            numberText
            +
            verseText
        )

        .font(
            .system(
                size: readerSettings.fontSize,
                design: readerSettings.font.fontDesign

            )
        )

        

        .lineSpacing(6)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(highlight?.color.color ?? Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            bookmarkManager.toggle(bookmark)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .onLongPressGesture {
            showHighlightMenu = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .confirmationDialog(
            "Highlight Color",
            isPresented: $showHighlightMenu,
            titleVisibility: .visible
        ) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    highlightManager.highlight(
                        book: bookName,
                        chapter: chapterNumber,
                        verse: verse.number,
                        color: color
                    )
                } label: {
                    Label(color.rawValue.capitalized, systemImage: "circle.fill")
                        .foregroundColor(color.iconColor)
                }
            }

            Button("Add Note\u{2026}") {
                showNoteEditor = true
            }

            Button("Remove Highlight", role: .destructive) {
                highlightManager.removeHighlight(
                    book: bookName,
                    chapter: chapterNumber,
                    verse: verse.number
                )
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorView(reference: "\(bookName) \(chapterNumber):\(verse.number)")
        }
    }

    /// The verse number. Hidden in focus mode, and for a drop-cap verse, where the initial stands in.
    private var numberText: Text {
        if readerSettings.focusMode || dropCap {
            return Text("")
        }
        return Text("\(verse.number) ")
            .font(.caption2)
            .foregroundColor(palette.gold)
    }

    /// The verse text, with the words of Jesus in red when the reader has turned that on.
    private var verseText: Text {
        let utf16 = Array(verse.text.utf16)

        var spans: [Range<Int>] = []
        if readerSettings.redLetterEnabled,
           let translationId = viewModel.selectedTranslation.redLetterId {
            spans = RedLetterRanges.shared.spans(
                translation: translationId,
                bookName: bookName,
                chapter: chapterNumber,
                verse: verse.number,
                includeExtras: readerSettings.redLetterIncludeActsRevelation
            )
        }

        // Cut the text into runs: plain or red, with the drop-cap letter split off the front.
        var runs: [(range: Range<Int>, red: Bool)] = []
        var position = 0
        for span in spans where span.lowerBound >= position && span.upperBound <= utf16.count {
            if span.lowerBound > position { runs.append((position..<span.lowerBound, false)) }
            runs.append((span, true))
            position = span.upperBound
        }
        if position < utf16.count { runs.append((position..<utf16.count, false)) }

        var initialEnd = 0
        if dropCap, let first = verse.text.first {
            initialEnd = min(String(first).utf16.count, utf16.count)
        }

        var result = Text("")
        for run in runs {
            var pieces: [(Range<Int>, Bool)] = []
            if run.range.lowerBound < initialEnd && initialEnd < run.range.upperBound {
                pieces = [(run.range.lowerBound..<initialEnd, true), (initialEnd..<run.range.upperBound, false)]
            } else {
                pieces = [(run.range, run.range.upperBound <= initialEnd)]
            }
            for (range, isInitial) in pieces {
                var piece = Text(String(decoding: utf16[range], as: UTF16.self))
                if isInitial {
                    piece = piece
                        .font(.system(size: readerSettings.fontSize * 1.9, weight: .semibold, design: .serif))
                        .foregroundColor(palette.goldBright)
                } else if run.red {
                    piece = piece.foregroundColor(palette.jesus)
                }
                result = result + piece
            }
        }
        return result
    }
}
