//
//  SettingsView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var versionStore: VersionStore
    @EnvironmentObject var readerSettings: ReaderSettings
    @State private var showResetAlert = false
    @State private var showLibrarySheet = false

    var body: some View {
        List {

            Section(header: Text("Bible")) {
                NavigationLink {
                    TranslationSettingsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Language & Version")
                            Text("\(versionStore.languages.first(where: { $0.code == versionStore.selectedLanguageCode })?.nativeName ?? viewModel.selectedTranslation.language) - \(versionStore.selectedVersion?.name ?? viewModel.selectedTranslation.version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Button {
                    showLibrarySheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.book.closed")
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bible Library")
                            Text("Browse, download, and manage versions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // MARK: - Reading Settings
            Section(header: Text("Reading")) {
                NavigationLink {
                    FontSettingsView()
                } label: {
                    Label("Reading Font", systemImage: "textformat.size")
                }

                Toggle(isOn: $readerSettings.redLetterEnabled) {
                    Label("Words of Jesus in Red", systemImage: "text.quote")
                }

                Toggle(isOn: $readerSettings.redLetterIncludeActsRevelation) {
                    Label("Include Acts, Epistles & Revelation", systemImage: "book")
                }
                .disabled(!readerSettings.redLetterEnabled)
                .opacity(readerSettings.redLetterEnabled ? 1 : 0.5)
            }

            // MARK: - Progress
            Section(
                header: Text("Progress"),
                footer: Text("This will remove all reading completion marks.")
            ) {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Reset Reading Progress",
                          systemImage: "arrow.counterclockwise")
                }
            }

            // MARK: - About
            Section {
                VStack(spacing: 16) {

                    Image("BibleWishLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .opacity(0.9)

                    Text("BibleWish")
                        .font(.headline)

                    Divider()

                    VStack(spacing: 6) {
                        Text("""
                        “The fear of the Lord is the beginning of wisdom:
                        and the knowledge of the holy is understanding.”
                        """)
                        .font(.footnote)
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                        Text("Proverbs 9:10")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Text("© 2026 BibleWish")

                    Text("Created and designed by Patrick Carvalho")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Link(destination: URL(string: "https://instagram.com/patricksysware")!) {
                        Label("@patricksysware", systemImage: "camera")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Settings")
        .alert("Reset Reading Progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}

            Button("Reset", role: .destructive) {
                viewModel.resetReadingProgress()
            }
        } message: {
            Text("This will clear all completed chapters. This action cannot be undone.")
        }
        .sheet(isPresented: $showLibrarySheet) {
            NavigationStack {
                VersionLibraryView()
                    .environmentObject(versionStore)
                    .navigationTitle("Bible Library")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BibleViewModel())
}
