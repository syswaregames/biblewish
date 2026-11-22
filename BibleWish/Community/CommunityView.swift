//
//  CommunityView.swift
//
//  The Community tab: the prayer wall and the reading leaderboard, with the bell.
//

import SwiftUI

struct CommunityView: View {

    enum Section: String, CaseIterable, Identifiable {
        case wall = "Prayer wall"
        case leaderboard = "Leaderboard"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: CommunityStore
    @EnvironmentObject var auth: AuthStore
    @Environment(\.palette) private var palette

    @AppStorage("community_section") private var sectionName = Section.wall.rawValue
    @State private var reload = 0

    private var section: Section { Section(rawValue: sectionName) ?? .wall }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Section", selection: Binding(get: { section }, set: { sectionName = $0.rawValue })) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch section {
                case .wall: PrayerWallView()
                case .leaderboard: LeaderboardView(reloadToken: reload)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .readableWidth(720)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            switch section {
            case .wall: await store.refresh()
            case .leaderboard: reload += 1; try? await Task.sleep(nanoseconds: 600_000_000)
            }
            await store.refreshUnread()
        }
        .themedScreen()
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink { NotificationsView() } label: {
                    Image(systemName: store.unreadNotifications > 0 ? "bell.badge.fill" : "bell")
                        .overlay(alignment: .topTrailing) {
                            if store.unreadNotifications > 0 {
                                Text(store.unreadNotifications > 99 ? "99+" : "\(store.unreadNotifications)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Capsule().fill(palette.roseInk))
                                    .foregroundStyle(.white)
                                    .offset(x: 10, y: -8)
                            }
                        }
                }
                .accessibilityLabel(store.unreadNotifications > 0 ? "Notifications, \(store.unreadNotifications) unread" : "Notifications")
            }
        }
        .task(id: auth.user?.id ?? 0) { if auth.isSignedIn { await store.refreshUnread() } }
    }
}
