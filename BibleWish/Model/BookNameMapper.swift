//
//  BookNameMapper.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-02-25.
//

import Foundation

enum BookNameMapper {

    private static let nameToId: [String: String] = {
        var map: [String: String] = [:]

        func add(_ id: String, _ names: [String]) {
            for name in names {
                let key = normalize(name)
                map[key] = id
            }
        }

        // English
        add("GEN", ["Genesis"])
        add("EXO", ["Exodus"])
        add("LEV", ["Leviticus"])
        add("NUM", ["Numbers"])
        add("DEU", ["Deuteronomy"])

        add("JOS", ["Joshua"])
        add("JDG", ["Judges"])
        add("RUT", ["Ruth"])
        add("1SA", ["1 Samuel"])
        add("2SA", ["2 Samuel"])
        add("1KI", ["1 Kings"])
        add("2KI", ["2 Kings"])
        add("1CH", ["1 Chronicles"])
        add("2CH", ["2 Chronicles"])
        add("EZR", ["Ezra"])
        add("NEH", ["Nehemiah"])
        add("EST", ["Esther"])

        add("JOB", ["Job"])
        add("PSA", ["Psalm", "Psalms"])
        add("PRO", ["Proverbs"])
        add("ECC", ["Ecclesiastes"])
        add("SNG", ["Song of Solomon", "Song of Songs"])

        add("ISA", ["Isaiah"])
        add("JER", ["Jeremiah"])
        add("LAM", ["Lamentations"])
        add("EZK", ["Ezekiel"])
        add("DAN", ["Daniel"])

        add("HOS", ["Hosea"])
        add("JOL", ["Joel"])
        add("AMO", ["Amos"])
        add("OBA", ["Obadiah"])
        add("JON", ["Jonah"])
        add("MIC", ["Micah"])
        add("NAM", ["Nahum"])
        add("HAB", ["Habakkuk"])
        add("ZEP", ["Zephaniah"])
        add("HAG", ["Haggai"])
        add("ZEC", ["Zechariah"])
        add("MAL", ["Malachi"])

        add("MAT", ["Matthew"])
        add("MRK", ["Mark"])
        add("LUK", ["Luke"])
        add("JHN", ["John"])

        add("ACT", ["Acts"])

        add("ROM", ["Romans"])
        add("1CO", ["1 Corinthians"])
        add("2CO", ["2 Corinthians"])
        add("GAL", ["Galatians"])
        add("EPH", ["Ephesians"])
        add("PHP", ["Philippians"])
        add("COL", ["Colossians"])
        add("1TH", ["1 Thessalonians"])
        add("2TH", ["2 Thessalonians"])
        add("1TI", ["1 Timothy"])
        add("2TI", ["2 Timothy"])
        add("TIT", ["Titus"])
        add("PHM", ["Philemon"])

        add("HEB", ["Hebrews"])
        add("JAS", ["James"])
        add("1PE", ["1 Peter"])
        add("2PE", ["2 Peter"])
        add("1JN", ["1 John"])
        add("2JN", ["2 John"])
        add("3JN", ["3 John"])
        add("JUD", ["Jude"])

        add("REV", ["Revelation"])

        // Portuguese (Brazil)
        add("GEN", ["Gênesis"])
        add("EXO", ["Êxodo"])
        add("LEV", ["Levítico"])
        add("NUM", ["Números"])
        add("DEU", ["Deuteronômio"])

        add("JOS", ["Josué"])
        add("JDG", ["Juízes"])
        add("RUT", ["Rute"])
        add("1SA", ["1 Samuel"])
        add("2SA", ["2 Samuel"])
        add("1KI", ["1 Reis"])
        add("2KI", ["2 Reis"])
        add("1CH", ["1 Crônicas"])
        add("2CH", ["2 Crônicas"])
        add("EZR", ["Esdras"])
        add("NEH", ["Neemias"])
        add("EST", ["Ester"])

        add("JOB", ["Jó"])
        add("PSA", ["Salmos"])
        add("PRO", ["Provérbios"])
        add("ECC", ["Eclesiastes"])
        add("SNG", ["Cântico dos Cânticos", "Cantares"])

        add("ISA", ["Isaías"])
        add("JER", ["Jeremias"])
        add("LAM", ["Lamentações"])
        add("EZK", ["Ezequiel"])
        add("DAN", ["Daniel"])

        add("HOS", ["Oséias"])
        add("JOL", ["Joel"])
        add("AMO", ["Amós"])
        add("OBA", ["Obadias"])
        add("JON", ["Jonas"])
        add("MIC", ["Miquéias"])
        add("NAM", ["Naum"])
        add("HAB", ["Habacuque"])
        add("ZEP", ["Sofonias"])
        add("HAG", ["Ageu"])
        add("ZEC", ["Zacarias"])
        add("MAL", ["Malaquias"])

        add("MAT", ["Mateus"])
        add("MRK", ["Marcos"])
        add("LUK", ["Lucas"])
        add("JHN", ["João"])

        add("ACT", ["Atos"])

        add("ROM", ["Romanos"])
        add("1CO", ["1 Coríntios"])
        add("2CO", ["2 Coríntios"])
        add("GAL", ["Gálatas"])
        add("EPH", ["Efésios"])
        add("PHP", ["Filipenses"])
        add("COL", ["Colossenses"])
        add("1TH", ["1 Tessalonicenses"])
        add("2TH", ["2 Tessalonicenses"])
        add("1TI", ["1 Timóteo"])
        add("2TI", ["2 Timóteo"])
        add("TIT", ["Tito"])
        add("PHM", ["Filemom"])

        add("HEB", ["Hebreus"])
        add("JAS", ["Tiago"])
        add("1PE", ["1 Pedro"])
        add("2PE", ["2 Pedro"])
        add("1JN", ["1 João"])
        add("2JN", ["2 João"])
        add("3JN", ["3 João"])
        add("JUD", ["Judas"])

        add("REV", ["Apocalipse"])

        // Hebrew
        add("GEN", ["בראשית"])
        add("EXO", ["שמות"])
        add("LEV", ["ויקרא"])
        add("NUM", ["במדבר"])
        add("DEU", ["דברים"])

        add("JOS", ["יהושע"])
        add("JDG", ["שופטים"])
        add("RUT", ["רות"])
        add("1SA", ["שמואל א"])
        add("2SA", ["שמואל ב"])
        add("1KI", ["מלכים א"])
        add("2KI", ["מלכים ב"])
        add("1CH", ["דברי הימים א"])
        add("2CH", ["דברי הימים ב"])
        add("EZR", ["עזרא"])
        add("NEH", ["נחמיה"])
        add("EST", ["אסתר"])

        add("JOB", ["איוב"])
        add("PSA", ["תהילים"])
        add("PRO", ["משלי"])
        add("ECC", ["קהלת"])
        add("SNG", ["שיר השירים"])

        add("ISA", ["ישעיהו"])
        add("JER", ["ירמיהו"])
        add("LAM", ["איכה"])
        add("EZK", ["יחזקאל"])
        add("DAN", ["דניאל"])

        add("HOS", ["הושע"])
        add("JOL", ["יואל"])
        add("AMO", ["עמוס"])
        add("OBA", ["עובדיה"])
        add("JON", ["יונה"])
        add("MIC", ["מיכה"])
        add("NAM", ["נחום"])
        add("HAB", ["חבקוק"])
        add("ZEP", ["צפניה"])
        add("HAG", ["חגי"])
        add("ZEC", ["זכריה"])
        add("MAL", ["מלאכי"])

        add("MAT", ["מתי"])
        add("MRK", ["מרקוס"])
        add("LUK", ["לוקס"])
        add("JHN", ["יוחנן"])

        add("ACT", ["מעשי השליחים"])

        add("ROM", ["אל הרומים"])
        add("1CO", ["אל הקורינתים א"])
        add("2CO", ["אל הקורינתים ב"])
        add("GAL", ["אל הגלטים"])
        add("EPH", ["אל האפסים"])
        add("PHP", ["אל הפיליפים"])
        add("COL", ["אל הקולוסים"])
        add("1TH", ["אל התסלוניקים א"])
        add("2TH", ["אל התסלוניקים ב"])
        add("1TI", ["אל טימותיאוס א"])
        add("2TI", ["אל טימותיאוס ב"])
        add("TIT", ["אל טיטוס"])
        add("PHM", ["אל פילימון"])

        add("HEB", ["אל העברים"])
        add("JAS", ["יעקב"])
        add("1PE", ["פטרוס א"])
        add("2PE", ["פטרוס ב"])
        add("1JN", ["יוחנן א"])
        add("2JN", ["יוחנן ב"])
        add("3JN", ["יוחנן ג"])
        add("JUD", ["יהודה"])

        add("REV", ["התגלות יוחנן"])

        return map
    }()

    static func bookId(for name: String) -> String? {
        nameToId[normalize(name)]
    }

    private static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}
