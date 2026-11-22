//
//  BookListView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct BookListView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var versionStore: VersionStore

    @State private var showingLibrary = false

    var body: some View {
        BookNavigatorView()
            .themedScreen()
            .navigationTitle("BibleWish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search the Bible")
                }

                ToolbarItem(placement: .principal) {
                    Text("BibleWish")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Language picker
                        Picker("Language", selection: $versionStore.selectedLanguageCode) {
                            ForEach(versionStore.languages) { lang in
                                Text(lang.nativeName).tag(lang.code)
                            }
                        }

                        // Version picker for the selected language
                        Picker("Version", selection: $versionStore.selectedVersionID) {
                            ForEach(versionStore.versionsByLanguage[versionStore.selectedLanguageCode] ?? []) { version in
                                Label(version.name, systemImage: version.isDownloaded ? "checkmark.circle.fill" : "icloud.and.arrow.down")
                                    .tag(version.id)
                            }
                        }

                        Divider()
                        Button("Manage versions\u{2026}") { showingLibrary = true }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.book.closed")
                            VStack(alignment: .leading, spacing: 0) {
                                Text(versionStore.selectedVersion?.name ?? "Version")
                                    .font(.subheadline)
                                Text(versionStore.languages.first(where: { $0.code == versionStore.selectedLanguageCode })?.nativeName ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLibrary) {
                VersionLibraryView()
                    .environmentObject(versionStore)
            }
    }
}
