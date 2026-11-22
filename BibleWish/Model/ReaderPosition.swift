//
//  ReaderPosition.swift
//
//  Finds the same place in another translation, for the reader's quick version switch. Books are
//  matched by their place in the 66-book order (the Hebrew text lists them differently and names
//  them in Hebrew); if a name can't be placed, the book's position in the old list is used.
//

import Foundation

enum ReaderPosition {

    /// The book and chapter positions in `books` for a book (by canonical index, else by `position`) and chapter number.
    static func locate(canonical: Int?, position: Int, chapter: Int, in books: [BibleBook]) -> (book: Int, chapter: Int)? {
        let book = canonical.flatMap { wanted in books.firstIndex { BookIndex.of(name: $0.name) == wanted } } ?? position
        guard book >= 0, book < books.count, !books[book].chapters.isEmpty else { return nil }
        let chapters = books[book].chapters
        let index = chapters.firstIndex { $0.number == chapter } ?? min(max(chapter - 1, 0), chapters.count - 1)
        return (book, index)
    }
}
