//
//  Chapter.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

struct Chapter: Codable, Identifiable {
    let id = UUID()
    let number: Int
    let verses: [Verse]
}
