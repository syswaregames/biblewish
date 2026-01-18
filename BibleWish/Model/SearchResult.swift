//
//  SearchResult.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

import Foundation

struct SearchResult: Identifiable {
    let id = UUID()              // id can stay let
    var bookName: String
    var chapterNumber: Int
    var verseNumber: Int
    var verseText: String
}
