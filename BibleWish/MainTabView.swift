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
    @StateObject private var achievements = AchievementsStore()
    @StateObject private var reminder = DailyVerseReminder()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.palette) private var palette


    var body: some View {
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
        .environmentObject(bookmarkManager) // makes it available everywhere
        .environmentObject(highlightManager)
        .environmentObject(readerSettings)
        .environmentObject(versionStore)
        .environmentObject(plansStore)
        .environmentObject(noteStore)
        .environmentObject(achievements)
        .environmentObject(reminder)
        .task(id: bibleVM.books.count) { await reminder.reschedule(books: bibleVM.books) }
        .task(id: bibleVM.selectedTranslation) { await reminder.reschedule(books: bibleVM.books) }
        .onChange(of: reminder.time) { Task { await reminder.reschedule(books: bibleVM.books) } }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task {
                await reminder.refreshPermission()
                await reminder.reschedule(books: bibleVM.books)
            }
        }
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
        .tint(palette.gold)
        .onAppear {
            // Sync BibleViewModel with VersionStore on launch
            if let selected = versionStore.selectedBibleTranslation(),
               selected != bibleVM.selectedTranslation {
                bibleVM.selectedTranslation = selected
            }
        }
        .onChange(of: versionStore.selectedVersionID) { newID in
            // When VersionStore changes, reflect in BibleViewModel
            if let t = BibleTranslation(rawValue: newID), t != bibleVM.selectedTranslation {
                bibleVM.selectedTranslation = t
            }
        }
        .onChange(of: bibleVM.selectedTranslation) { t in
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
        achievements.update(with: input)
    }
}

#Preview {
    MainTabView()
}

