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
    /// The last verse when a favorite covers a range (saved from biblewish.com); nil for one verse.
    var verseEnd: Int?
    /// The translation it was saved in ("kjv", "web", "bliv", "heb"); nil for older bookmarks.
    var translation: String?
    /// The favorite's id on biblewish.com once it has been synced.
    var serverId: Int?

    init(
        id: UUID = UUID(),
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int,
        verseText: String,
        verseEnd: Int? = nil,
        translation: String? = nil,
        serverId: Int? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.verseEnd = verseEnd
        self.translation = translation
    }

    /// "John 3:16" or "John 3:16-18".
    var reference: String {
        if let verseEnd, verseEnd > verseNumber {
            return "\(bookName) \(chapterNumber):\(verseNumber)-\(verseEnd)"
        }
        return "\(bookName) \(chapterNumber):\(verseNumber)"
    }
}
