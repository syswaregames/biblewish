//
//  CommunitySettingsView.swift
//
//  What the community sees of you and what you can switch off (Settings \u{2192} Account \u{2192}
//  Community): your name, your country's flag, your place on the leaderboard, emails when people
//  pray, verses sent to you, and the members you blocked.
//

import SwiftUI

struct CommunitySettingsView: View {

    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var store: CommunityStore
    @Environment(\.palette) private var palette

    @State private var name = ""
    @State private var country = ""
    @State private var showCountry = false
    @State private var onLeaderboard = true
    @State private var emailPrayers = true
    @State private var allowVerses = true
    @State private var loaded = false
    @State private var message: String?
    @State private var confirmUnblock = false
    @State private var showGuidelines = false

    /// The website's list of country codes, named in English and sorted by name.
    static let countries: [(code: String, name: String)] = {
        let codes = BundledJSON.load([String].self, name: "countries", subdirectory: "") ?? []
        return codes.map { ($0, CommunityFormat.countryName($0)) }.sorted { $0.name < $1.name }
    }()

    var body: some View {
        List {
            Section(footer: Text("Shown beside your prayers, encouragement and place on the leaderboard. Anonymous posts hide it.")) {
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                if name.trimmingCharacters(in: .whitespaces) != (auth.user?.displayName ?? "") && !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Save name") { saveName() }
                }
            }
            .themedRows()

            Section(footer: Text("Choose your country to show its flag next to your name. You can hide it at any time.")) {
                Picker("Country", selection: $country) {
                    Text("Not shown").tag("")
                    ForEach(Self.countries, id: \.code) { entry in
                        Text("\(CommunityFormat.flag(entry.code)) \(entry.name)").tag(entry.code)
                    }
                }
                .onChange(of: country) {
                    guard loaded, country != (auth.user?.country ?? "") else { return }
                    if country.isEmpty { showCountry = false }
                    save(["country": country, "show_country": country.isEmpty ? false : showCountry])
                }
                Toggle("Show my flag", isOn: $showCountry)
                    .disabled(country.isEmpty)
                    .tint(palette.gold)
                    .onChange(of: showCountry) {
                        guard loaded, showCountry != (auth.user?.showCountry ?? false) else { return }
                        save(["show_country": showCountry])
                    }
            }
            .themedRows()

            Section(footer: Text("Turn this off and you are not listed. You still see your own place.")) {
                Toggle("Show me on the leaderboard", isOn: $onLeaderboard)
                    .tint(palette.gold)
                    .onChange(of: onLeaderboard) {
                        guard loaded, onLeaderboard != (auth.user?.showOnLeaderboard ?? true) else { return }
                        save(["show_on_leaderboard": onLeaderboard])
                    }
            }
            .themedRows()

            Section(footer: Text("Prayer emails are a daily note when people have prayed for your requests. Members you blocked can never send you verses.")) {
                Toggle("Email me when people pray", isOn: $emailPrayers)
                    .tint(palette.gold)
                    .onChange(of: emailPrayers) {
                        guard loaded, emailPrayers != (auth.user?.notifyPrayers ?? true) else { return }
                        save(["notify_prayers": emailPrayers])
                    }
                Toggle("Let members send me verses", isOn: $allowVerses)
                    .tint(palette.gold)
                    .onChange(of: allowVerses) {
                        guard loaded, allowVerses != (auth.user?.allowVerses ?? true) else { return }
                        save(["allow_verses": allowVerses])
                    }
            }
            .themedRows()

            Section(footer: Text("Block a member from the \u{22EF} menu on a request or reply. You stop seeing everything they post, even when it was anonymous, and they are not told.")) {
                HStack {
                    Text("Blocked members")
                    Spacer()
                    Text("\(store.blockedCount)").foregroundStyle(palette.inkMuted)
                }
                if store.blockedCount > 0 {
                    Button("Unblock everyone", role: .destructive) { confirmUnblock = true }
                }
                Button("Community guidelines") { showGuidelines = true }
            }
            .themedRows()

            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(palette.roseInk) }.themedRows()
            }
        }
        .themedList()
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGuidelines) { CommunityGuidelinesView() }
        .confirmationDialog("Unblock everyone?", isPresented: $confirmUnblock, titleVisibility: .visible) {
            Button("Unblock everyone", role: .destructive) {
                Task {
                    do { try await store.unblockEveryone() } catch { message = CommunityStore.message(error) }
                }
            }
        } message: {
            Text("Their requests and replies will show again, and they can send you verses.")
        }
        .task {
            await store.refreshBlockedCount()
            copyFromAccount()
        }
    }

    private func copyFromAccount() {
        loaded = false
        name = auth.user?.displayName ?? ""
        country = auth.user?.country ?? ""
        showCountry = auth.user?.showCountry ?? false
        onLeaderboard = auth.user?.showOnLeaderboard ?? true
        emailPrayers = auth.user?.notifyPrayers ?? true
        allowVerses = auth.user?.allowVerses ?? true
        Task { @MainActor in loaded = true }
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != auth.user?.displayName else { return }
        save(["display_name": trimmed])
    }

    /// Saves, and puts the controls back to what the server has if it said no.
    private func save(_ fields: [String: Any]) {
        message = nil
        Task {
            if await auth.updateProfile(fields) {
                copyFromAccount()
            } else {
                message = auth.errorMessage
                copyFromAccount()
            }
        }
    }
}
