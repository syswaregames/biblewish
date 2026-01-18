//
//  HighlightManager.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

class HighlightManager: ObservableObject {

    @Published private(set) var highlights: [Highlight] = []

    private let key = "saved_highlights"

    init() {
        load()
    }

    func highlight(
        book: String,
        chapter: Int,
        verse: Int,
        color: HighlightColor
    ) {
        removeHighlight(book: book, chapter: chapter, verse: verse)

        highlights.append(
            Highlight(
                bookName: book,
                chapterNumber: chapter,
                verseNumber: verse,
                color: color
            )
        )
        save()
    }

    func removeHighlight(book: String, chapter: Int, verse: Int) {
        highlights.removeAll {
            $0.bookName == book &&
            $0.chapterNumber == chapter &&
            $0.verseNumber == verse
        }
        save()
    }

    func highlightFor(book: String, chapter: Int, verse: Int) -> Highlight? {
        highlights.first {
            $0.bookName == book &&
            $0.chapterNumber == chapter &&
            $0.verseNumber == verse
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(highlights) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Highlight].self, from: data)
        else { return }

        highlights = decoded
    }
}
