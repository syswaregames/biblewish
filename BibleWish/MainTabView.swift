//
//  MainTabView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var bibleVM: BibleViewModel
    @StateObject private var bookmarkManager = BookmarkManager()
    @StateObject private var highlightManager = HighlightManager()
    @StateObject private var readerSettings = ReaderSettings()
    @StateObject private var versionStore = VersionStore()
    @StateObject private var plansStore = PlansStore()
    @StateObject private var noteStore = NoteStore()
    @StateObject private var prayerStore = PrayerStore()
    @StateObject private var achievements = AchievementsStore()
    @StateObject private var reminder = DailyVerseReminder()
    @StateObject private var auth = AuthStore()
    @StateObject private var sync = SyncEngine()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.palette) private var palette


    // The body is built in stages: one long modifier chain is too much for the compiler.

    var body: some View {
        withTranslationSync
    }

    private var tabs: some View {
        TabView {

            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                BookListView()
                    .environmentObject(bibleVM)
            }
            .tabItem { Label("Bible", systemImage: "book") }

            NavigationStack {
                PlansView()
            }
            .tabItem { Label("Plans", systemImage: "checklist") }

            NavigationStack {
                StudyView()
                    .environmentObject(bookmarkManager)
            }
            .tabItem { Label("Study", systemImage: "text.book.closed") }

            NavigationStack {
                SettingsView()
                    .environmentObject(bibleVM)
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }

    /// Everything the screens read from the environment.
    private var withEnvironment: some View {
        tabs
            .environmentObject(bookmarkManager) // makes it available everywhere
            .environmentObject(highlightManager)
            .environmentObject(readerSettings)
            .environmentObject(versionStore)
            .environmentObject(plansStore)
            .environmentObject(noteStore)
            .environmentObject(prayerStore)
            .environmentObject(achievements)
            .environmentObject(reminder)
            .environmentObject(auth)
            .environmentObject(sync)
    }

    /// Signing in, syncing, and the Debug-only self-tests.
    private var withSync: some View {
        withEnvironment
            .task {
                highlightManager.migrateLegacy(currentTranslation: bibleVM.selectedTranslation.widgetId)
                sync.attach(auth: auth, viewModel: bibleVM, bookmarks: bookmarkManager, highlights: highlightManager, notes: noteStore, plans: plansStore, prayers: prayerStore)
                await auth.restore()
                await sync.signedIn()
            }
            .onChange(of: auth.user?.id) {
                guard auth.isSignedIn else { return }
                Task { await sync.signedIn() }
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                Task { await sync.syncNow() }
            }
            #if DEBUG
            .task {
                guard ProcessInfo.processInfo.environment["BW_SELFTEST"] != nil else { return }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let test = SelfTest(auth: auth, sync: sync, bibleVM: bibleVM, bookmarks: bookmarkManager, highlights: highlightManager, notes: noteStore, plans: plansStore, prayers: prayerStore)
                await test.run()
            }
            #endif
    }

    /// The daily verse reminder and the widget.
    private var withReminder: some View {
        withSync
            .task(id: bibleVM.books.count) { await reminder.reschedule(books: bibleVM.books) }
            .task(id: bibleVM.selectedTranslation) {
                WidgetSync.publish(bibleVM.selectedTranslation)
                await reminder.reschedule(books: bibleVM.books)
            }
            .onChange(of: reminder.time) { Task { await reminder.reschedule(books: bibleVM.books) } }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                Task {
                    await reminder.refreshPermission()
                    await reminder.reschedule(books: bibleVM.books)
                }
            }
    }

    /// Badges: the unlock toast and re-checking after anything that could earn one.
    private var withAchievements: some View {
        withReminder
            .overlay(alignment: .top) {
                if let badge = achievements.toast {
                    BadgeToast(badge: badge) { achievements.dismissToast() }
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: achievements.toast)
            .onAppear { refreshAchievements() }
            .onChange(of: bibleVM.books.count) { refreshAchievements() }
            .onChange(of: bibleVM.readingProgress.completedChapters) { refreshAchievements() }
            .onChange(of: bibleVM.readingLog) { refreshAchievements() }
            .onChange(of: plansStore.userPlans) { refreshAchievements() }
            .onChange(of: noteStore.notes) { refreshAchievements() }
            .onChange(of: bookmarkManager.bookmarks) { refreshAchievements() }
            .onChange(of: highlightManager.highlights) { refreshAchievements() }
            .onChange(of: prayerStore.prayers) { refreshAchievements() }
            .tint(palette.gold)
    }

    /// Keeps the translation picker, the version library and the view model in agreement.
    private var withTranslationSync: some View {
        withAchievements
            .onAppear {
                // Sync BibleViewModel with VersionStore on launch
                if let selected = versionStore.selectedBibleTranslation(),
                   selected != bibleVM.selectedTranslation {
                    bibleVM.selectedTranslation = selected
                }
            }
            .onChange(of: versionStore.selectedVersionID) { _, newID in
                // When VersionStore changes, reflect in BibleViewModel
                if let t = BibleTranslation(rawValue: newID), t != bibleVM.selectedTranslation {
                    bibleVM.selectedTranslation = t
                }
            }
            .onChange(of: bibleVM.selectedTranslation) { _, t in
                // When BibleViewModel changes, reflect in VersionStore
                if versionStore.selectedVersionID != t.rawValue {
                    versionStore.selectedVersionID = t.rawValue
                }
                // Also align languageCode with the version's language if known
                if let lang = versionStore.versionsByLanguage.first(where: { entry in
                    entry.value.contains(where: { $0.id == t.rawValue })
                })?.key, lang != versionStore.selectedLanguageCode {
                    versionStore.selectedLanguageCode = lang
                }
            }
    }
}

extension MainTabView {

    /// Gathers what the badge metrics need and lets the achievements store re-check.
    func refreshAchievements() {
        var input = AchievementInput()
        input.completed = AchievementMetrics.chapterRefs(fromKeys: bibleVM.readingProgress.completedChapters)
        input.chaptersPerBook = bibleVM.books.map { $0.chapters.count }
        input.log = bibleVM.readingLog
        input.readDates = bibleVM.readingLog.map(\.date)
            + plansStore.userPlans.flatMap { $0.progress.map(\.completedAt) }
        input.completedPlans = plansStore.catalog.filter { plansStore.summary(for: $0.id)?.status == .complete }.count
        input.favorites = bookmarkManager.bookmarks.count
        input.notes = noteStore.notes.count
        input.marginNotes = noteStore.notes.filter { !$0.reference.isEmpty }.count
        input.highlights = highlightManager.highlights.count
        input.prayerItems = prayerStore.prayers.count
        input.answeredPrayers = prayerStore.answeredCount
        achievements.update(with: input)
    }
}

#Preview {
    MainTabView()
}

