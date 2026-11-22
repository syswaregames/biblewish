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
    /// The note's id on biblewish.com once it has been synced.
    var serverId: Int?

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        reference: String = "",
        tags: [NoteTag] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serverId: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.reference = reference
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverId = serverId
    }

    var wordCount: Int {
        body.split(whereSeparator: \.isWhitespace).count
    }

    /// The title, or the first line of the body (as plain words, without markup) when there is none.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return NoteInline.plain(trimmed) }
        return plainBodyLines.first ?? "Untitled note"
    }

    /// A short plain-text preview for lists: the body without markup, minus the line used as the title.
    var preview: String {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasTitle ? plainBodyLines : Array(plainBodyLines.dropFirst())).joined(separator: " ")
    }

    private var plainBodyLines: [String] {
        NoteBlock.plainLines(NoteBlock.parse(body))
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class NoteStore: ObservableObject {

    /// Most recently edited first.
    @Published private(set) var notes: [Note] = []

    /// Set by the sync engine to hear about changes made by the reader (not ones applied from the server).
    var onChange: ((SyncOp) -> Void)?

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
        onChange?(.pushNote(note.id))
    }

    func delete(id: UUID) {
        let serverId = note(id: id)?.serverId
        notes.removeAll { $0.id == id }
        persist()
        if let serverId { onChange?(.deleteNote(serverId: serverId)) }
    }

    // MARK: - Sync (these never call onChange)

    func setServerId(_ serverId: Int, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].serverId = serverId
        persist()
    }

    /// Makes the notes match the server's, keeping notes that haven't been sent yet.
    func apply(serverNotes: [Note]) {
        let waiting = notes.filter { $0.serverId == nil }
        let known = Dictionary(uniqueKeysWithValues: notes.compactMap { local in local.serverId.map { ($0, local) } })

        let fromServer = serverNotes.map { incoming -> Note in
            // Keep the local id of a note we already had.
            guard let serverId = incoming.serverId, let local = known[serverId] else { return incoming }
            return Note(
                id: local.id, title: incoming.title, body: incoming.body, reference: incoming.reference,
                tags: incoming.tags, createdAt: incoming.createdAt, updatedAt: incoming.updatedAt, serverId: serverId
            )
        }
        let updated = (waiting + fromServer).sorted { $0.updatedAt > $1.updatedAt }
        if updated != notes {
            notes = updated
            persist()
        }
    }

    /// Forget the links to a server account (a different account is signing in).
    func clearServerIds() {
        for index in notes.indices { notes[index].serverId = nil }
        persist()
    }

    func removeAllLocal() {
        guard !notes.isEmpty else { return }
        notes = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
