//
//  PushRoute.swift
//
//  Where a notification leads. The server sends a path of the website ("/community/?prayer=12");
//  the app opens the matching screen, or the website for anything it has no screen for.
//

import Foundation

enum AppTab: Hashable {
    case home, bible, plans, study, community
}

enum PushRoute: Equatable {
    case prayer(Int)
    case community
    case leaderboard
    case plans
    case bible
    case home
    case web(URL)

    /// A path or address from a notification. Nothing readable means Home.
    static func parse(_ text: String?, base: URL = APIConfig.baseURL) -> PushRoute {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
              let components = URLComponents(string: text) else { return .home }

        // An address on another site opens there; one on ours is read by its path.
        if let host = components.host, host != base.host {
            return components.url.map(PushRoute.web) ?? .home
        }
        let path = components.path.isEmpty ? "/" : components.path
        let query = components.queryItems ?? []

        if path.hasPrefix("/community") {
            if let id = query.first(where: { $0.name == "prayer" })?.value.flatMap(Int.init) { return .prayer(id) }
            return .community
        }
        if path.hasPrefix("/leaderboard") { return .leaderboard }
        if path.hasPrefix("/plans") { return .plans }
        if path.hasPrefix("/read") { return query.contains { $0.name == "plan" } ? .plans : .bible }
        if path == "/" { return .home }
        guard let url = URL(string: text, relativeTo: base) else { return .home }
        return .web(url.absoluteURL)
    }
}

/// Which Apple push service this build's device token belongs to. Builds run from Xcode carry a
/// development profile (sandbox tokens); TestFlight and App Store builds have none and use production.
enum PushEnvironment {

    /// "development" or "production" from the `aps-environment` entitlement inside an
    /// embedded.mobileprovision file, or nil if it cannot be read.
    static func apsEnvironment(inProfile data: Data) -> String? {
        // The profile is a signed wrapper around an XML property list; cut the list out.
        let start = Data("<?xml".utf8), end = Data("</plist>".utf8)
        guard let from = data.range(of: start), let to = data.range(of: end, in: from.lowerBound..<data.endIndex) else { return nil }
        let plistData = data[from.lowerBound..<to.upperBound]
        guard let plist = try? PropertyListSerialization.propertyList(from: Data(plistData), format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return nil }
        return entitlements["aps-environment"] as? String
    }

    /// "sandbox" or "production", as api/devices.php wants it.
    static var current: String {
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url),
           let value = apsEnvironment(inProfile: data) {
            return value == "development" ? "sandbox" : "production"
        }
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// A device token as the hex text the server stores.
    static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }
}
