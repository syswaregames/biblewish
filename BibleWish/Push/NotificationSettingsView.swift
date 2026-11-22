//
//  NotificationSettingsView.swift
//
//  Settings \u{2192} Notifications: turn on push for this phone, choose what to be told about, and
//  send yourself a test. The reading reminder and the weekly recap are the same settings as on
//  biblewish.com (they follow you between the site and the app).
//

import SwiftUI

struct NotificationSettingsView: View {

    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var push: PushManager
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    @State private var community = true
    @State private var recap = true
    @State private var reminderOn = false
    @State private var reminderHour = 8
    @State private var loaded = false
    @State private var testResult: String?
    @State private var testing = false
    @State private var problem: String?
    @State private var showSignIn = false

    var body: some View {
        List {
            phoneSection
            if auth.isSignedIn {
                chooseSection
                testSection
            } else {
                Section {
                    Button { showSignIn = true } label: {
                        Label("Sign in to choose what you are told about", systemImage: "person.crop.circle.badge.plus")
                    }
                } footer: {
                    Text("Notifications about prayers, encouragement and verses need an account, so BibleWish knows who to tell.")
                }
                .themedRows()
            }
            if let problem {
                Section { Text(problem).font(.footnote).foregroundStyle(palette.roseInk) }.themedRows()
            }
        }
        .themedList()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignIn) { SignInView() }
        .task {
            await push.refreshAuthorization()
            if auth.isSignedIn { await push.refreshServerStatus() }
            copyFromAccount()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await push.refreshAuthorization() } }
        }
    }

    // MARK: Sections

    private var phoneSection: some View {
        Section {
            HStack {
                Label("Push notifications", systemImage: "bell.badge")
                Spacer()
                Text(statusText).foregroundStyle(palette.inkMuted)
            }
            switch push.authorization {
            case .notDetermined:
                Button { Task { await turnOn() } } label: {
                    Text("Turn on push notifications").font(.body.weight(.semibold)).foregroundStyle(palette.gold)
                }
            case .denied:
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Allow in iOS Settings", destination: url)
                }
            default:
                EmptyView()
            }
            if push.isAllowed, push.serverAvailable == false {
                Text("Push is not switched on at biblewish.com yet. Your choices below are saved and will start working as soon as it is.")
                    .font(.footnote).foregroundStyle(palette.inkMuted)
            }
        } footer: {
            Text("A banner on this phone when someone prays for you or encourages you, when a verse you sent is opened, for your reading reminder and your weekly recap, even when the app is closed.")
        }
        .themedRows()
    }

    private var statusText: String {
        switch push.authorization {
        case .notDetermined: return "Off"
        case .denied: return "Blocked"
        default: return auth.isSignedIn ? (push.isRegistered ? "On" : "Starting\u{2026}") : "Allowed"
        }
    }

    private var chooseSection: some View {
        Section {
            Toggle("Prayers, encouragement and verses", isOn: $community)
                .tint(palette.gold)
                .onChange(of: community) {
                    guard loaded, community != (auth.user?.pushCommunity ?? true) else { return }
                    save(["push_community": community])
                }
            Toggle("Weekly recap", isOn: $recap)
                .tint(palette.gold)
                .onChange(of: recap) {
                    guard loaded, recap != (auth.user?.weeklyRecap ?? true) else { return }
                    save(["weekly_recap": recap])
                }
            Toggle("Daily reading reminder", isOn: $reminderOn)
                .tint(palette.gold)
                .onChange(of: reminderOn) {
                    guard loaded, reminderOn != (auth.user?.reminderHour != nil) else { return }
                    saveReminder()
                }
            if reminderOn {
                Picker("Time", selection: $reminderHour) {
                    ForEach(0..<24, id: \.self) { Text(Self.hourLabel($0)).tag($0) }
                }
                .onChange(of: reminderHour) {
                    guard loaded, reminderHour != auth.user?.reminderHour else { return }
                    saveReminder()
                }
            }
        } header: {
            Text("Tell me about")
        } footer: {
            Text("The reminder and the recap are the ones biblewish.com emails. On a phone with push on, the reminder comes as a notification instead of an email; the recap comes as both, since the email has the whole week. Not the Verse of the Day reminder in Settings, which the phone makes itself.")
        }
        .themedRows()
    }

    private var testSection: some View {
        Section {
            Button {
                Task {
                    testing = true
                    testResult = await push.sendTest()
                    testing = false
                }
            } label: {
                HStack {
                    Label(testing ? "Sending\u{2026}" : "Send me a test notification", systemImage: "paperplane")
                    if testing { Spacer(); ProgressView() }
                }
            }
            .disabled(testing || !push.isAllowed)
            if let testResult { Text(testResult).font(.footnote).foregroundStyle(palette.inkSoft) }
        } footer: {
            Text("Checks that this phone can be reached. Use it after turning push on.")
        }
        .themedRows()
    }

    // MARK: Actions

    private func turnOn() async {
        await push.enable()
        if auth.isSignedIn { await push.syncRegistration() }
    }

    private func copyFromAccount() {
        loaded = false
        community = auth.user?.pushCommunity ?? true
        recap = auth.user?.weeklyRecap ?? true
        reminderOn = auth.user?.reminderHour != nil
        reminderHour = auth.user?.reminderHour ?? 8
        Task { @MainActor in loaded = true }
    }

    /// The reminder follows the member's own clock, so the phone's time zone goes with it.
    private func saveReminder() {
        var fields: [String: Any] = ["reminder_hour": reminderOn ? reminderHour : NSNull()]
        if reminderOn { fields["timezone"] = TimeZone.current.identifier }
        save(fields)
    }

    private func save(_ fields: [String: Any]) {
        problem = nil
        Task {
            if !(await auth.updateProfile(fields)) { problem = auth.errorMessage }
            copyFromAccount()
        }
    }

    static func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}
