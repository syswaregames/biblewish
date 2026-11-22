//
//  BibleStudyData.swift
//  BibleWish
//
//  Cross-references, places and journeys from biblewish.com (copied in by tools/build_study_data.py).
//  Books are addressed by their 0-based canonical index.
//

import Foundation
import SwiftUI
import CoreLocation

enum BibleBooks {
    /// File names of the study data, in Bible order.
    static let slugs = [
        "genesis", "exodus", "leviticus", "numbers", "deuteronomy", "joshua", "judges", "ruth",
        "1-samuel", "2-samuel", "1-kings", "2-kings", "1-chronicles", "2-chronicles", "ezra",
        "nehemiah", "esther", "job", "psalms", "proverbs", "ecclesiastes", "song-of-solomon", "isaiah",
        "jeremiah", "lamentations", "ezekiel", "daniel", "hosea", "joel", "amos", "obadiah", "jonah",
        "micah", "nahum", "habakkuk", "zephaniah", "haggai", "zechariah", "malachi", "matthew", "mark",
        "luke", "john", "acts", "romans", "1-corinthians", "2-corinthians", "galatians", "ephesians",
        "philippians", "colossians", "1-thessalonians", "2-thessalonians", "1-timothy", "2-timothy",
        "titus", "philemon", "hebrews", "james", "1-peter", "2-peter", "1-john", "2-john", "3-john",
        "jude", "revelation",
    ]
}

/// A bundled JSON file, decoded once and kept.
private enum BundledJSON {
    static func load<T: Decodable>(_ type: T.Type, name: String, subdirectory: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: subdirectory),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Cross-references

struct CrossReference: Hashable, Identifiable {
    let book: Int
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int

    var id: String { "\(book).\(chapter).\(verseStart).\(verseEnd)" }
}

final class CrossReferenceStore {

    static let shared = CrossReferenceStore()

    // book index → chapter → verse → [[book, chapter, first, last]]
    private var books: [Int: [String: [String: [[Int]]]]] = [:]

    private init() {}

    func references(book: Int, chapter: Int, verse: Int) -> [CrossReference] {
        guard book >= 0, book < BibleBooks.slugs.count else { return [] }

        if books[book] == nil {
            books[book] = BundledJSON.load([String: [String: [[Int]]]].self,
                                           name: BibleBooks.slugs[book], subdirectory: "crossrefs") ?? [:]
        }

        let rows = books[book]?["\(chapter)"]?["\(verse)"] ?? []
        return rows.compactMap { row in
            row.count == 4 ? CrossReference(book: row[0], chapter: row[1], verseStart: row[2], verseEnd: row[3]) : nil
        }
    }
}

// MARK: - Places

struct Place: Identifiable, Hashable {
    let id: Int
    let name: String
    let longitude: Double
    let latitude: Double
    let kind: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlaceMention: Identifiable {
    let place: Place
    let verses: [Int]
    var id: Int { place.id }
}

struct JourneyStop: Decodable, Identifiable {
    let place: Int
    let label: String
    let reference: String
    let note: String
    let lon: Double
    let lat: Double

    var id: String { "\(place)-\(reference)" }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

struct Journey: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    /// "232, 176, 79"
    let color: String
    let stops: [JourneyStop]

    var tint: Color {
        let parts = color.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 3 else { return .orange }
        return Color(red: parts[0] / 255, green: parts[1] / 255, blue: parts[2] / 255)
    }
}

final class PlacesStore {

    static let shared = PlacesStore()

    let places: [Place]
    let journeys: [Journey]

    // book index → chapter → [place index, [verses]] pairs
    private var books: [Int: [String: [PlaceRow]]] = [:]

    private struct PlaceRow: Decodable {
        let place: Int
        let verses: [Int]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            place = try container.decode(Int.self)
            verses = try container.decode([Int].self)
        }
    }

    private init() {
        // places.json rows are [name, longitude, latitude, type, mentions].
        var places: [Place] = []
        if let url = Bundle.main.url(forResource: "places", withExtension: "json", subdirectory: "places"),
           let data = try? Data(contentsOf: url),
           let rows = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
            for (index, row) in rows.enumerated() where row.count >= 4 {
                guard let name = row[0] as? String,
                      let lon = (row[1] as? NSNumber)?.doubleValue,
                      let lat = (row[2] as? NSNumber)?.doubleValue,
                      let kind = row[3] as? String else { continue }
                places.append(Place(id: index, name: name, longitude: lon, latitude: lat, kind: kind))
            }
        }
        self.places = places
        self.journeys = BundledJSON.load([Journey].self, name: "journeys", subdirectory: "places") ?? []
    }

    /// The places named in a chapter, with the verses that name them.
    func places(book: Int, chapter: Int) -> [PlaceMention] {
        guard book >= 0, book < BibleBooks.slugs.count else { return [] }

        if books[book] == nil {
            books[book] = BundledJSON.load([String: [PlaceRow]].self,
                                           name: BibleBooks.slugs[book], subdirectory: "places/books") ?? [:]
        }
        let rows = books[book]?["\(chapter)"] ?? []
        return rows.compactMap { row in
            row.place < places.count ? PlaceMention(place: places[row.place], verses: row.verses) : nil
        }
    }
}
