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
                .foregroundColor(.secondary)
            +
            Text(verse.text)
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
}
