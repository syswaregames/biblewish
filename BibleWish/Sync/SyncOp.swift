//
//  SyncOp.swift
//
//  One thing to tell the server. Operations name what changed (an id, a chapter) rather than carry
//  a copy of it, so what gets sent is always the current local state when the operation runs.
//

import Foundation

enum SyncOp: Codable, Hashable {
    case pushFavorite(UUID)
    case deleteFavorite(serverId: Int)
    /// A chapter was read (or unread) on this device.
    case readChapter(book: Int, chapter: Int, read: Bool)
    /// One-time upload of the chapters read before signing in (Bible progress only).
    case importReading
    /// One chapter's highlights in one translation; the current state is sent when it runs.
    case pushHighlightChapter(translation: String, bookIndex: Int, chapter: Int)
    /// One-time merge of the highlights made before signing in.
    case mergeHighlights
    case pushNote(UUID)
    case deleteNote(serverId: Int)

    /// Operations that describe the same target replace each other, so the queue stays short.
    var supersedeKey: String? {
        switch self {
        case .readChapter(let book, let chapter, _): return "read-\(book)-\(chapter)"
        default: return nil
        }
    }
}

/// The saved queue of operations waiting to reach the server.
struct SyncOutbox {

    private(set) var ops: [SyncOp]
    private let key: String

    init(key: String = "sync_outbox_v1") {
        self.key = key
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([SyncOp].self, from: data) {
            ops = decoded
        } else {
            ops = []
        }
    }

    var isEmpty: Bool { ops.isEmpty }
    var first: SyncOp? { ops.first }

    mutating func add(_ op: SyncOp) {
        if let supersede = op.supersedeKey {
            ops.removeAll { $0.supersedeKey == supersede }
        } else if ops.contains(op) {
            return
        }
        ops.append(op)
        save()
    }

    mutating func removeFirst() {
        guard !ops.isEmpty else { return }
        ops.removeFirst()
        save()
    }

    mutating func removeAll() {
        ops.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(ops) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Book numbers: the website's data uses the position in the Bible (0 = Genesis), the app's saved
/// items use the book's name in whatever translation they were made in.
enum BookIndex {

    static func of(name: String) -> Int? {
        BookNameMapper.bookId(for: name).flatMap { AchievementMetrics.bookIds.firstIndex(of: $0) }
    }
}
