//
//  CommunityModels.swift
//
//  What biblewish.com's community endpoints send (api/community.php, replies.php, reactions.php,
//  reports.php, leaderboard.php, notifications.php), and small helpers to show it.
//

import Foundation

struct CommunityPrayer: Decodable, Identifiable, Equatable {
    let id: Int
    let body: String
    let isAnonymous: Bool
    /// Nil for anonymous posts.
    let author: String?
    let authorAvatar: String?
    let authorCountry: String?
    let createdAt: Date
    var prayedCount: Int
    var heartCount: Int
    var replyCount: Int
    var answeredAt: Date?
    var answerNote: String?
    var iPrayed: Bool
    var iHearted: Bool
    let isMine: Bool

    var isAnswered: Bool { answeredAt != nil }

    /// This post as it looks the moment "I prayed" or the heart is tapped, before the server answers.
    func toggled(_ kind: PrayerReaction) -> CommunityPrayer {
        var copy = self
        switch kind {
        case .praying:
            copy.iPrayed.toggle()
            copy.prayedCount = max(0, prayedCount + (copy.iPrayed ? 1 : -1))
        case .heart:
            copy.iHearted.toggle()
            copy.heartCount = max(0, heartCount + (copy.iHearted ? 1 : -1))
        }
        return copy
    }
    var displayName: String { isAnonymous ? "Anonymous" : (author ?? "A BibleWish member") }
}

extension CommunityPrayer: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct CommunityReply: Decodable, Identifiable, Equatable {
    let id: Int
    let prayerId: Int
    let body: String
    let author: String
    let authorAvatar: String?
    let authorCountry: String?
    let createdAt: Date
    let isMine: Bool
}

enum PrayerReaction: String {
    case praying
    case heart
}

enum ReportReason: String, CaseIterable, Identifiable {
    case inappropriate
    case spam
    case personalInfo = "personal_info"
    case other

    var id: String { rawValue }

    /// The website's own wording.
    var title: String {
        switch self {
        case .inappropriate: return "Inappropriate or offensive"
        case .spam: return "Spam or advertising"
        case .personalInfo: return "Shares personal information"
        case .other: return "Something else"
        }
    }
}

/// A badge the server just awarded (it sends one with posts, prayers, replies and the leaderboard).
struct ServerBadge: Decodable, Identifiable {
    let id: String
    let group: String
    let icon: String
    let name: String
    let description: String
    let target: Int?

    var definition: BadgeDefinition {
        BadgeDefinition(id: id, group: group, icon: icon, name: name, description: description, metric: "server", target: target ?? 1)
    }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Decodable, Identifiable, Equatable {
    let rank: Int
    let name: String
    let avatarUrl: String?
    let country: String?
    let chapters: Int
    let isMe: Bool

    var id: String { "\(rank)-\(name)-\(chapters)-\(isMe)" }
}

struct LeaderboardMe: Decodable, Equatable {
    let chapters: Int
    let rank: Int?
    let listed: Bool
    let behindNext: Int?
}

struct LeaderboardCountry: Decodable, Identifiable, Equatable {
    let country: String
    let chapters: Int
    let readers: Int

    var id: String { country }
}

struct LeaderboardCommunity: Decodable, Equatable {
    let chapters: Int
    let readers: Int
    let goal: Int
}

struct Leaderboard: Decodable, Equatable {
    let period: String
    let start: String
    let end: String
    let leaders: [LeaderboardEntry]
    let me: LeaderboardMe?
    let countries: [LeaderboardCountry]
    let community: LeaderboardCommunity
    let newBadges: [ServerBadge]?

    static func == (lhs: Leaderboard, rhs: Leaderboard) -> Bool {
        lhs.period == rhs.period && lhs.start == rhs.start && lhs.leaders == rhs.leaders && lhs.me == rhs.me
            && lhs.countries == rhs.countries && lhs.community == rhs.community
    }
}

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case week, month, year

    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        }
    }
}

// MARK: - Notifications

struct MemberNotification: Decodable, Identifiable, Equatable {
    let id: Int
    let kind: String
    let icon: String
    let body: String
    let url: String?
    let createdAt: Date
    var read: Bool
}

// MARK: - Showing it

enum CommunityFormat {

    /// "2 hours ago" (abbreviated).
    static func ago(_ date: Date, now: Date = Date()) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// The flag emoji for a country code ("BR" -> flag), or an empty string.
    static func flag(_ code: String?) -> String {
        guard let code, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.compactMap { Unicode.Scalar(127397 + $0.value).map(String.init) }.joined()
    }

    static func countryName(_ code: String) -> String {
        Locale(identifier: "en").localizedString(forRegionCode: code) ?? code
    }

    /// An avatar path from the server ("/uploads/avatars/x.jpg") as a full address.
    static func avatarURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: path, relativeTo: APIConfig.baseURL)?.absoluteURL
    }

    /// "Jan 4 – Jan 10" for a leaderboard period ("2026-01-04" to "2026-01-10").
    static func range(start: String, end: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "UTC")
        guard let from = parser.date(from: start), let to = parser.date(from: end) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "\(formatter.string(from: from)) \u{2013} \(formatter.string(from: to))"
    }
}
