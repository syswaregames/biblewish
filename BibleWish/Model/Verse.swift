//
//  Verse.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

struct Verse: Codable, Identifiable {
    let id = UUID()
    let number: Int
    let text: String
    /// A verse the translation leaves out (Biblia Livre, which follows the oldest manuscripts) that
    /// BibleWish supplies from the KJV, as biblewish.com does: shown with a * and a footnote.
    var omitted: Bool? = nil
}
