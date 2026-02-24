import SwiftUI

struct VersionLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var versionStore: VersionStore

    @State private var query = ""
    @State private var showDownloadedOnly = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredLanguages) { lang in
                    Section(lang.nativeName) {
                        ForEach(filteredVersions(for: lang)) { version in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(version.name)
                                    Text(lang.nativeName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if version.id == versionStore.selectedVersionID {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                } else if version.isDownloaded {
                                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "icloud.and.arrow.down").foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                versionStore.setSelected(languageCode: lang.code, versionID: version.id)
                                dismiss()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if version.isDownloaded {
                                    Button(role: .destructive) {
                                        versionStore.setDownloaded(false, for: version.id, languageCode: lang.code)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                } else {
                                    Button {
                                        versionStore.setDownloaded(true, for: version.id, languageCode: lang.code)
                                    } label: {
                                        Label("Download", systemImage: "arrow.down.circle")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $showDownloadedOnly) {
                        Image(systemName: "tray.and.arrow.down.fill")
                    }
                    .toggleStyle(.button)
                    .help("Show downloaded only")
                }
            }
            .navigationTitle("Bible Library")
        }
    }

    private var filteredLanguages: [BibleLanguage] {
        var langs = versionStore.languages
        if !query.isEmpty {
            langs = langs.filter { $0.nativeName.localizedCaseInsensitiveContains(query) || $0.localizedName.localizedCaseInsensitiveContains(query) }
        }
        return langs
    }

    private func filteredVersions(for lang: BibleLanguage) -> [BibleVersion] {
        let versions = versionStore.versionsByLanguage[lang.code] ?? []
        let searched = query.isEmpty
        ? versions
        : versions.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return showDownloadedOnly ? searched.filter { $0.isDownloaded } : searched
    }
}

#Preview {
    VersionLibraryView()
        .environmentObject(VersionStore())
}
