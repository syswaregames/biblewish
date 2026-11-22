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

    @EnvironmentObject var bookmarkManager: BookmarkManager
    @EnvironmentObject var highlightManager: HighlightManager
    @EnvironmentObject var readerSettings: ReaderSettings
    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette

    @State private var showHighlightMenu = false

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
            Text("\(verse.number) ")
                .font(.caption2)
                .foregroundColor(palette.gold)
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

            Button("Remove Highlight", role: .destructive) {
                highlightManager.removeHighlight(
                    book: bookName,
                    chapter: chapterNumber,
                    verse: verse.number
                )
            }
        }
    }

    /// The verse text, with the words of Jesus in red when the reader has turned that on.
    private var verseText: Text {
        guard readerSettings.redLetterEnabled,
              let translationId = viewModel.selectedTranslation.redLetterId else {
            return Text(verse.text)
        }

        let spans = RedLetterRanges.shared.spans(
            translation: translationId,
            bookName: bookName,
            chapter: chapterNumber,
            verse: verse.number,
            includeExtras: readerSettings.redLetterIncludeActsRevelation
        )

        let utf16 = Array(verse.text.utf16)
        var result = Text("")
        var position = 0

        func plain(_ range: Range<Int>) -> Text {
            Text(String(decoding: utf16[range], as: UTF16.self))
        }

        for span in spans where span.lowerBound >= position && span.upperBound <= utf16.count {
            if span.lowerBound > position {
                result = result + plain(position..<span.lowerBound)
            }
            result = result + plain(span).foregroundColor(palette.jesus)
            position = span.upperBound
        }
        if position < utf16.count {
            result = result + plain(position..<utf16.count)
        }
        return result
    }
}
