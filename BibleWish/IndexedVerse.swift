//
//  IndexedVerse.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

struct IndexedVerse: Identifiable {
    let id = UUID()
    let book: String
    let chapter: Int
    let verse: Int
    let text: String
    let searchableText: String
}
