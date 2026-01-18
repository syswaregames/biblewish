//
//  Highlight.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

struct Highlight: Identifiable, Codable, Equatable {
    let id: UUID
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let color: HighlightColor

    init(bookName: String, chapterNumber: Int, verseNumber: Int, color: HighlightColor) {
        self.id = UUID()
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.color = color
    }
}

