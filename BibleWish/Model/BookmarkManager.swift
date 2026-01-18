//
//  BookmarkManager.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

class BookmarkManager: ObservableObject {

    @Published private(set) var bookmarks: [Bookmark] = []

    private let key = "saved_bookmarks"

    init() {
        load()
    }

    func isBookmarked(_ bookmark: Bookmark) -> Bool {
        bookmarks.contains {
            $0.bookName == bookmark.bookName &&
            $0.chapterNumber == bookmark.chapterNumber &&
            $0.verseNumber == bookmark.verseNumber
        }
    }

    func toggle(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: {
            $0.bookName == bookmark.bookName &&
            $0.chapterNumber == bookmark.chapterNumber &&
            $0.verseNumber == bookmark.verseNumber
        }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.append(bookmark)
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return
        }
        bookmarks = decoded
    }
    
    func delete(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

}
