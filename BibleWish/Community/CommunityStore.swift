//
//  CommunityStore.swift
//
//  The prayer wall and the bell, over biblewish.com's API. Reading is open to everyone; anything
//  that writes needs an account, and says so (`APIError.unauthorized`) so the screen can offer to
//  sign in. Reactions update at once and are put right if the server says otherwise.
//

import Foundation

@MainActor
final class CommunityStore: ObservableObject {

    enum Sort: String, CaseIterable, Identifiable {
        case new
        case needs

        var id: String { rawValue }
        var title: String { self == .new ? "Newest" : "Needs prayer" }
    }

    @Published var sort: Sort = .new {
        didSet { if oldValue != sort { Task { await refresh() } } }
    }
    @Published private(set) var prayers: [CommunityPrayer] = []
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadedOnce = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var unreadNotifications = 0
    @Published private(set) var blockedCount = 0
    /// Badges the server awarded; the app shows them like its own.
    var onNewBadges: (([ServerBadge]) -> Void)?

    private let api = APIClient.shared
    private var loadGeneration = 0

    // MARK: - Feed

    func refresh() async {
        loadGeneration += 1
        let mine = loadGeneration
        isLoading = true
        errorMessage = nil
        defer { if mine == loadGeneration { isLoading = false } }
        do {
            let page = try await fetchPage(offset: 0)
            guard mine == loadGeneration else { return }
            prayers = page.prayers
            hasMore = page.hasMore
            loadedOnce = true
        } catch {
            guard mine == loadGeneration else { return }
            errorMessage = Self.message(error)
            loadedOnce = true
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await fetchPage(offset: prayers.count)
            let known = Set(prayers.map(\.id))
            prayers += page.prayers.filter { !known.contains($0.id) }
            hasMore = page.hasMore
        } catch {
            errorMessage = Self.message(error)
        }
    }

    private struct Page: Decodable {
        let prayers: [CommunityPrayer]
        let hasMore: Bool
    }

    private func fetchPage(offset: Int) async throws -> Page {
        try await api.request(Page.self, "GET", "api/community.php", query: ["sort": sort.rawValue, "offset": String(offset)])
    }

    /// One post (opened from a notification), fresh from the server.
    func prayer(id: Int) async throws -> CommunityPrayer {
        struct One: Decodable { let prayer: CommunityPrayer }
        return try await api.request(One.self, "GET", "api/community.php", query: ["id": String(id)]).prayer
    }

    // MARK: - Writing

    private struct Posted: Decodable {
        let prayer: CommunityPrayer
        let newBadges: [ServerBadge]?
    }

    func post(body: String, anonymous: Bool) async throws {
        let posted = try await api.request(Posted.self, "POST", "api/community.php", json: ["body": body, "is_anonymous": anonymous])
        if sort == .new { prayers.insert(posted.prayer, at: 0) } else { await refresh() }
        celebrate(posted.newBadges)
    }

    func delete(_ prayer: CommunityPrayer) async throws {
        try await api.send("DELETE", "api/community.php", query: ["id": String(prayer.id)])
        prayers.removeAll { $0.id == prayer.id }
    }

    func setAnswered(_ prayer: CommunityPrayer, answered: Bool, note: String) async throws {
        let json: [String: Any] = answered ? ["answered": true, "answer_note": note] : ["answered": false]
        let result = try await api.request(Posted.self, "PUT", "api/community.php", query: ["id": String(prayer.id)], json: json)
        replace(result.prayer)
        celebrate(result.newBadges)
    }

    private struct ReactionResult: Decodable {
        let prayedCount: Int
        let heartCount: Int
        let iPrayed: Bool
        let iHearted: Bool
        let newBadges: [ServerBadge]?
    }

    /// Toggles "I prayed" or the heart and returns the post as the server has it. The list shows the
    /// change at once; if the server refuses, the list goes back and the error is thrown.
    @discardableResult
    func react(_ kind: PrayerReaction, to prayer: CommunityPrayer) async throws -> CommunityPrayer {
        replace(prayer.toggled(kind))
        do {
            let result = try await api.request(ReactionResult.self, "POST", "api/reactions.php", json: ["prayer_id": prayer.id, "kind": kind.rawValue])
            var final = prayer.toggled(kind)
            final.prayedCount = result.prayedCount
            final.heartCount = result.heartCount
            final.iPrayed = result.iPrayed
            final.iHearted = result.iHearted
            replace(final)
            celebrate(result.newBadges)
            return final
        } catch {
            replace(prayer)
            throw error
        }
    }

    func replace(_ prayer: CommunityPrayer) {
        if let index = prayers.firstIndex(where: { $0.id == prayer.id }) { prayers[index] = prayer }
    }

    // MARK: - Replies

    func replies(for prayerId: Int) async throws -> [CommunityReply] {
        struct Replies: Decodable { let replies: [CommunityReply] }
        return try await api.request(Replies.self, "GET", "api/replies.php", query: ["prayer_id": String(prayerId)]).replies
    }

    func reply(to prayerId: Int, body: String) async throws -> CommunityReply {
        struct Posted: Decodable { let reply: CommunityReply; let replyCount: Int; let newBadges: [ServerBadge]? }
        let result = try await api.request(Posted.self, "POST", "api/replies.php", json: ["prayer_id": prayerId, "body": body])
        if let index = prayers.firstIndex(where: { $0.id == prayerId }) { prayers[index].replyCount = result.replyCount }
        celebrate(result.newBadges)
        return result.reply
    }

    func deleteReply(_ reply: CommunityReply) async throws {
        struct Deleted: Decodable { let replyCount: Int }
        let result = try await api.request(Deleted.self, "DELETE", "api/replies.php", query: ["id": String(reply.id)])
        if let index = prayers.firstIndex(where: { $0.id == reply.prayerId }) { prayers[index].replyCount = result.replyCount }
    }

    // MARK: - Keeping it safe

    /// Reports a post, or one reply. The server emails the moderator and hides a post reported by
    /// three different members until it is reviewed.
    func report(prayerId: Int, replyId: Int? = nil, reason: ReportReason, details: String) async throws {
        var json: [String: Any] = ["reason": reason.rawValue, "details": details.trimmingCharacters(in: .whitespacesAndNewlines)]
        if json["details"] as? String == "" { json["details"] = NSNull() }
        if let replyId { json["reply_id"] = replyId } else { json["prayer_id"] = prayerId }
        try await api.send("POST", "api/reports.php", json: json)
    }

    /// Stops showing everything by the author of a post or reply (never learning who it is).
    func block(prayerId: Int, replyId: Int? = nil) async throws {
        struct Blocked: Decodable { let blocked: Int }
        var json: [String: Any] = [:]
        if let replyId { json["reply_id"] = replyId } else { json["prayer_id"] = prayerId }
        let result = try await api.request(Blocked.self, "POST", "api/community.php", query: ["action": "block"], json: json)
        blockedCount = result.blocked
        await refresh()
    }

    func refreshBlockedCount() async {
        struct Blocked: Decodable { let blocked: Int }
        if let result = try? await api.request(Blocked.self, "GET", "api/community.php", query: ["action": "blocked"]) {
            blockedCount = result.blocked
        }
    }

    func unblockEveryone() async throws {
        try await api.send("DELETE", "api/community.php", query: ["action": "blocked"])
        blockedCount = 0
        await refresh()
    }

    // MARK: - Notifications

    func refreshUnread() async {
        struct Count: Decodable { let unread: Int }
        if let result = try? await api.request(Count.self, "GET", "api/notifications.php", query: ["count": "1"]) {
            unreadNotifications = result.unread
        }
    }

    func notifications() async throws -> [MemberNotification] {
        struct List: Decodable { let unread: Int; let notifications: [MemberNotification] }
        let list = try await api.request(List.self, "GET", "api/notifications.php")
        unreadNotifications = list.unread
        return list.notifications
    }

    func markRead(id: Int? = nil) async {
        struct Count: Decodable { let unread: Int }
        let json: [String: Any] = id.map { ["id": $0] } ?? ["all": true]
        if let result = try? await api.request(Count.self, "POST", "api/notifications.php", query: ["action": "read"], json: json) {
            unreadNotifications = result.unread
        }
    }

    /// Signed out: nothing of the member's is kept.
    func reset() {
        prayers = []
        hasMore = false
        loadedOnce = false
        unreadNotifications = 0
        blockedCount = 0
    }

    // MARK: - Leaderboard

    func leaderboard(_ period: LeaderboardPeriod) async throws -> Leaderboard {
        let board = try await api.request(Leaderboard.self, "GET", "api/leaderboard.php", query: ["period": period.rawValue])
        celebrate(board.newBadges)
        return board
    }

    // MARK: - Helpers

    private func celebrate(_ badges: [ServerBadge]?) {
        if let badges, !badges.isEmpty { onNewBadges?(badges) }
    }

    static func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
    }
}
