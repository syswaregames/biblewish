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
    @EnvironmentObject var themeStore: ThemeStore
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
                                .foregroundStyle(.secondary)
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
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: - Appearance
            Section(header: Text("Appearance")) {
                ThemePicker()
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
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
                        .foregroundStyle(.secondary)

                        Text("Proverbs 9:10")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Text("© 2026 BibleWish")

                    Text("Created and designed by Patrick Carvalho")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Link(destination: URL(string: "https://instagram.com/patricksysware")!) {
                        Label("@patricksysware", systemImage: "camera")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .themedList()
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

/// Colour swatches for Dark / Sepia / Light / Auto, like the website's theme picker.
private struct ThemePicker: View {
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ThemeChoice.allCases) { choice in
                Button {
                    themeStore.choice = choice
                } label: {
                    VStack(spacing: 6) {
                        swatch(for: choice)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(
                                    themeStore.choice == choice ? palette.gold : palette.goldLine,
                                    lineWidth: themeStore.choice == choice ? 2.5 : 1
                                )
                            )
                        Text(choice.displayName)
                            .font(.caption)
                            .foregroundStyle(themeStore.choice == choice ? palette.goldBright : palette.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(choice.displayName) theme")
                .accessibilityAddTraits(themeStore.choice == choice ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func swatch(for choice: ThemeChoice) -> some View {
        switch choice {
        case .dark: ThemePalette.dark.pageGradient
        case .sepia: ThemePalette.sepia.pageGradient
        case .light: ThemePalette.light.pageGradient
        case .auto:
            HStack(spacing: 0) {
                ThemePalette.dark.pageBottom
                ThemePalette.light.pageTop
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BibleViewModel())
        .environmentObject(VersionStore())
        .environmentObject(ReaderSettings())
        .environmentObject(ThemeStore())
}
