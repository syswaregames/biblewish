//
//  StudyNotes.swift
//  BibleWish
//
//  Study notes kept on the device: plain text, an optional passage, and colored tags (same ids as
//  NOTE_TAGS on biblewish.com).
//

import SwiftUI

enum NoteTag: String, Codable, CaseIterable, Identifiable {
    case insight
    case question
    case prayer
    case sermon
    case promise

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    func color(in palette: ThemePalette) -> Color {
        switch self {
        case .insight: return palette.goldBright
        case .question: return palette.violetInk
        case .prayer: return palette.roseInk
        case .sermon: return palette.tealInk
        case .promise: return palette.greenInk
        }
    }
}

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var body: String
    /// Free text such as "John 3:16"; opened as a passage when it can be read as one.
    var reference: String
    var tags: [NoteTag]
    let createdAt: Date
    var updatedAt: Date

    init(title: String = "", body: String = "", reference: String = "", tags: [NoteTag] = []) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.reference = reference
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var wordCount: Int {
        body.split(whereSeparator: \.isWhitespace).count
    }

    /// The title, or the first line of the body when there is none.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Untitled note" : firstLine
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class NoteStore: ObservableObject {

    /// Most recently edited first.
    @Published private(set) var notes: [Note] = []

    private let key = "study_notes_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func note(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    /// Adds a new note, or saves changes to an existing one.
    func save(_ note: Note) {
        var note = note
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            guard notes[index] != note else { return }
            note.updatedAt = Date()
            notes.remove(at: index)
        }
        notes.insert(note, at: 0)
        persist()
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
