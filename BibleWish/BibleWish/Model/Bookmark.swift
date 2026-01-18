//
//  Bookmark.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String

    init(bookName: String, chapterNumber: Int, verseNumber: Int, verseText: String) {
        self.id = UUID()
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.verseText = verseText
    }
}
