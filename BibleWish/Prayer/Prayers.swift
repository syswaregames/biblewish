//
//  Prayers.swift
//
//  Your private prayer list: things to pray for, and answers when they come. Kept on the device and,
//  when signed in, in step with the same list on biblewish.com (it is never shown to anyone else).
//

import Foundation

enum PrayerStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case answered
    case archived

    var id: String { rawValue }

    var label: String { rawValue.capitalized }
}

struct Prayer: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var details: String
    var status: PrayerStatus
    var answeredAt: Date?
    var answerNote: String
    let createdAt: Date
    /// The prayer's id on biblewish.com once it has been synced.
    var serverId: Int?

    init(
        id: UUID = UUID(),
        title: String = "",
        details: String = "",
        status: PrayerStatus = .active,
        answeredAt: Date? = nil,
        answerNote: String = "",
        createdAt: Date = Date(),
        serverId: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.status = status
        self.answeredAt = answeredAt
        self.answerNote = answerNote
        self.createdAt = createdAt
        self.serverId = serverId
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class PrayerStore: ObservableObject {

    /// Newest first.
    @Published private(set) var prayers: [Prayer] = []

    /// Set by the sync engine to hear about changes made by the reader (not ones applied from the server).
    var onChange: ((SyncOp) -> Void)?

    private let key = "prayer_list_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Prayer].self, from: data) {
            prayers = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func prayer(id: UUID) -> Prayer? {
        prayers.first { $0.id == id }
    }

    var answeredCount: Int { prayers.filter { $0.status == .answered }.count }

    /// Adds a new prayer, or saves changes to an existing one.
    func save(_ prayer: Prayer) {
        var prayer = prayer
        // The answered date is set when a prayer becomes answered and cleared when it stops being.
        if prayer.status == .answered {
            if prayer.answeredAt == nil { prayer.answeredAt = Date() }
        } else {
            prayer.answeredAt = nil
            prayer.answerNote = ""
        }

        if let index = prayers.firstIndex(where: { $0.id == prayer.id }) {
            guard prayers[index] != prayer else { return }
            prayers[index] = prayer
        } else {
            prayers.insert(prayer, at: 0)
        }
        persist()
        onChange?(.pushPrayer(prayer.id))
    }

    func delete(id: UUID) {
        let serverId = prayer(id: id)?.serverId
        prayers.removeAll { $0.id == id }
        persist()
        if let serverId { onChange?(.deletePrayer(serverId: serverId)) }
    }

    // MARK: - Sync (these never call onChange)

    func setServerId(_ serverId: Int, for id: UUID) {
        guard let index = prayers.firstIndex(where: { $0.id == id }) else { return }
        prayers[index].serverId = serverId
        persist()
    }

    /// Makes the list match the server's, keeping prayers that haven't been sent yet.
    func apply(serverPrayers: [Prayer]) {
        let waiting = prayers.filter { $0.serverId == nil }
        let known = Dictionary(uniqueKeysWithValues: prayers.compactMap { local in local.serverId.map { ($0, local) } })

        let fromServer = serverPrayers.map { incoming -> Prayer in
            guard let serverId = incoming.serverId, let local = known[serverId] else { return incoming }
            var kept = incoming
            // Keep the local id so the list doesn't flicker.
            kept = Prayer(
                id: local.id, title: incoming.title, details: incoming.details, status: incoming.status,
                answeredAt: incoming.answeredAt, answerNote: incoming.answerNote,
                createdAt: incoming.createdAt, serverId: serverId
            )
            return kept
        }
        let updated = (waiting + fromServer).sorted { $0.createdAt > $1.createdAt }
        if updated != prayers {
            prayers = updated
            persist()
        }
    }

    func clearServerIds() {
        for index in prayers.indices { prayers[index].serverId = nil }
        persist()
    }

    func removeAllLocal() {
        guard !prayers.isEmpty else { return }
        prayers = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(prayers) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
