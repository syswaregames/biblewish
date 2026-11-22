//
//  NotificationsView.swift
//
//  The bell: people who prayed for you, encouraged you, opened a verse you sent, and so on. The
//  same list as the website's 🔔.
//

import SwiftUI

struct NotificationsView: View {

    @EnvironmentObject var store: CommunityStore
    @EnvironmentObject var auth: AuthStore
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    @State private var items: [MemberNotification] = []
    @State private var loaded = false
    @State private var failure: String?
    @State private var prayerRoute: PrayerRoute?
    @State private var showSignIn = false

    struct PrayerRoute: Identifiable, Hashable { let id: Int }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                signedOut
            } else if !loaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let failure, items.isEmpty {
                Text(failure).font(.subheadline).foregroundStyle(palette.inkMuted).multilineTextAlignment(.center).padding()
            } else if items.isEmpty {
                Text("Nothing yet. When someone prays for you, encourages you or opens a verse you sent, it appears here.")
                    .font(.subheadline).foregroundStyle(palette.inkMuted).multilineTextAlignment(.center).padding(30)
            } else {
                List(items) { item in
                    Button { open(item) } label: { row(item) }
                        .themedRows()
                }
                .themedList()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedScreen()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if auth.isSignedIn && items.contains(where: { !$0.read }) {
                ToolbarItem(placement: .primaryAction) {
                    Button("Mark all read") {
                        Task {
                            await store.markRead()
                            for index in items.indices { items[index].read = true }
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $prayerRoute) { PrayerLoadingView(id: $0.id) }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .task(id: auth.user?.id ?? 0) { await load() }
    }

    private var signedOut: some View {
        VStack(spacing: 12) {
            Text("Sign in to see who prayed for you.").font(.subheadline).foregroundStyle(palette.inkMuted)
            Button("Sign in") { showSignIn = true }.font(.headline)
        }
    }

    private func row(_ item: MemberNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.icon).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.body).font(.subheadline).foregroundStyle(palette.ink).multilineTextAlignment(.leading)
                Text(CommunityFormat.ago(item.createdAt)).font(.caption).foregroundStyle(palette.inkMuted)
            }
            Spacer(minLength: 0)
            if !item.read { Circle().fill(palette.gold).frame(width: 9, height: 9).accessibilityLabel("Unread") }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard auth.isSignedIn else { return }
        do {
            items = try await store.notifications()
            failure = nil
        } catch {
            failure = CommunityStore.message(error)
        }
        loaded = true
    }

    /// A prayer opens in the app; a verse link or anything else opens on the website.
    private func open(_ item: MemberNotification) {
        if let index = items.firstIndex(where: { $0.id == item.id }), !items[index].read {
            items[index].read = true
            Task { await store.markRead(id: item.id) }
        }
        guard let url = item.url else { return }
        if let id = Self.prayerId(in: url) {
            prayerRoute = PrayerRoute(id: id)
        } else if let full = URL(string: url, relativeTo: APIConfig.baseURL)?.absoluteURL {
            openURL(full)
        }
    }

    /// 12 from "/community/?prayer=12".
    static func prayerId(in url: String) -> Int? {
        guard url.contains("/community"), let components = URLComponents(string: url),
              let value = components.queryItems?.first(where: { $0.name == "prayer" })?.value else { return nil }
        return Int(value)
    }
}
