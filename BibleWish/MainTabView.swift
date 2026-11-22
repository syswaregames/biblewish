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



#Preview {
    MainTabView()
}

