//
//  AppRouter.swift
//
//  Which tab is showing, and the screens a notification asks for. A tap on a notification (even one
//  that launched the app) lands here and the tabs follow.
//

import SwiftUI

@MainActor
final class AppRouter: ObservableObject {

    static let shared = AppRouter()

    @Published var tab: AppTab = .home
    /// A prayer request to open in the Community tab (from "Someone prayed for your request").
    @Published var prayerToOpen: Int?

    private init() {}

    func open(_ route: PushRoute) {
        switch route {
        case .prayer(let id):
            tab = .community
            prayerToOpen = id
        case .community:
            tab = .community
        case .leaderboard:
            UserDefaults.standard.set(CommunityView.Section.leaderboard.rawValue, forKey: "community_section")
            tab = .community
        case .plans:
            tab = .plans
        case .bible:
            tab = .bible
        case .home:
            tab = .home
        case .web(let url):
            UIApplication.shared.open(url)
        }
    }
}
