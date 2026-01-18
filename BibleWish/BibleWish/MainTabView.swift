//
//  MainTabView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct MainTabView: View {

    @StateObject private var bibleVM = BibleViewModel()
    @StateObject private var bookmarkManager = BookmarkManager()
    @StateObject private var highlightManager = HighlightManager()
    @StateObject private var readerSettings = ReaderSettings()


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
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(bookmarkManager) // makes it available everywhere
        .environmentObject(highlightManager)
        .environmentObject(readerSettings)


    }
}



#Preview {
    MainTabView()
}
