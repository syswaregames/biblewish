//
//  BibleBook.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

struct BibleBook: Codable, Identifiable {
    let id = UUID()
    let name: String
    let chapters: [Chapter]
}

extension BibleBook {
    var isOldTestament: Bool {
        let oldTestamentNames: Set<String> = [
            "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
            "Joshua","Judges","Ruth","1 Samuel","2 Samuel",
            "1 Kings","2 Kings","1 Chronicles","2 Chronicles",
            "Ezra","Nehemiah","Esther","Job","Psalm","Proverbs",
            "Ecclesiastes","Song of Solomon","Isaiah","Jeremiah",
            "Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos",
            "Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah",
            "Haggai","Zechariah","Malachi"
        ]
        return oldTestamentNames.contains(name)
    }
}

