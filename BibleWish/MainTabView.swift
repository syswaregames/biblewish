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


    var body: some View {
        TabView {

            NavigationStack {
                BookListView()
                    .environmentObject(bibleVM)
            }
            .tabItem { Label("Bible", systemImage: "book") }

            NavigationStack {
                SearchView()
                    .environmentObject(bibleVM)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                BookmarksView()
                    .environmentObject(bookmarkManager)
            }
            .tabItem { Label("Bookmarks", systemImage: "star") }

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

