import SwiftUI
import Foundation

// Represents a content language for Bible versions
struct BibleLanguage: Identifiable, Codable, Hashable {
    var id: String { code }
    let code: String            // e.g., "en", "pt-BR"
    let nativeName: String      // e.g., "English", "Português (Brasil)"
    let localizedName: String   // Displayed in UI language; can be same as nativeName
}

// Represents a concrete Bible version/translation in a given language
struct BibleVersion: Identifiable, Codable, Hashable {
    let id: String              // e.g., "kjv", "bliv" (match BibleTranslation rawValue when possible)
    let name: String            // e.g., "King James Version"
    let languageCode: String    // e.g., "en"
    var isDownloaded: Bool
    var sizeInMB: Double?
}

/// Stores the available languages/versions and the user's selection.
/// Persists the selected language and version in UserDefaults.
final class VersionStore: ObservableObject {

    // MARK: - Persistence Keys
    private let selectedLanguageKey = "selected_language_code"
    private let selectedVersionKey  = "selected_version_id"

    // MARK: - Published State
    @Published var languages: [BibleLanguage] = []
    @Published var versionsByLanguage: [String: [BibleVersion]] = [:] // key: languageCode

    @Published var selectedLanguageCode: String = "en" {
        didSet {
            persistSelection()
            ensureSelectionIsValid()
        }
    }

    @Published var selectedVersionID: String = "kjv" {
        didSet { persistSelection() }
    }

    // MARK: - Init
    init() {
        // Seed catalog first
        seedCatalog()

        // Load persisted selection (with sensible defaults)
        let defaults = UserDefaults.standard
        let savedLang = defaults.string(forKey: selectedLanguageKey)
        let savedVer  = defaults.string(forKey: selectedVersionKey)

        // Defaults align with the existing app content: English/KJV
        self.selectedLanguageCode = savedLang ?? "en"
        self.selectedVersionID = savedVer ?? "kjv"

        ensureSelectionIsValid()
    }

    // MARK: - Computed
    var selectedVersion: BibleVersion? {
        versionsByLanguage[selectedLanguageCode]?.first { $0.id == selectedVersionID }
    }

    /// If the project still uses BibleTranslation enum elsewhere, this maps to it.
    func selectedBibleTranslation() -> BibleTranslation? {
        BibleTranslation(rawValue: selectedVersionID)
    }

    // MARK: - Public API
    func setSelected(languageCode: String, versionID: String) {
        selectedLanguageCode = languageCode
        selectedVersionID = versionID
        ensureSelectionIsValid()
    }

    /// Marks a version as downloaded or not. In a real app, tie this to actual download logic.
    func setDownloaded(_ downloaded: Bool, for versionID: String, languageCode: String) {
        guard var versions = versionsByLanguage[languageCode],
              let idx = versions.firstIndex(where: { $0.id == versionID }) else { return }
        versions[idx].isDownloaded = downloaded
        versionsByLanguage[languageCode] = versions
    }

    // MARK: - Private
    private func persistSelection() {
        let defaults = UserDefaults.standard
        defaults.set(selectedLanguageCode, forKey: selectedLanguageKey)
        defaults.set(selectedVersionID, forKey: selectedVersionKey)
    }

    private func ensureSelectionIsValid() {
        // If selected language has no versions, fall back to first available language
        if versionsByLanguage[selectedLanguageCode]?.isEmpty ?? true {
            if let firstLang = languages.first?.code {
                selectedLanguageCode = firstLang
            }
        }

        // If selected version doesn't exist in the selected language, pick the first version
        if let versions = versionsByLanguage[selectedLanguageCode],
           !versions.contains(where: { $0.id == selectedVersionID }) {
            if let firstVersion = versions.first {
                selectedVersionID = firstVersion.id
            }
        }
    }

    private func seedCatalog() {
        // Languages
        let en = BibleLanguage(code: "en", nativeName: "English", localizedName: "English")
        let ptBR = BibleLanguage(code: "pt-BR", nativeName: "Português (Brasil)", localizedName: "Portuguese (Brazil)")
        let he = BibleLanguage(code: "he", nativeName: "עברית", localizedName: "Hebrew")
        languages = [en, ptBR, he]

        // Versions (align ids with BibleTranslation.rawValue where possible)
        let kjv = BibleVersion(id: "kjv", name: "King James Version", languageCode: "en", isDownloaded: true, sizeInMB: 5.2)
        let webu = BibleVersion(id: "webu", name: "English (WEBU)", languageCode: "en", isDownloaded: true, sizeInMB: 4.8)
        let bliv = BibleVersion(id: "bliv", name: "BLIV", languageCode: "pt-BR", isDownloaded: true, sizeInMB: 4.9)
        let heb = BibleVersion(id: "heb", name: "Hebrew Bible (HEB)", languageCode: "he", isDownloaded: true, sizeInMB: 6.1)

        // Example of additional versions you might list (not downloaded yet)
        // let niv = BibleVersion(id: "niv", name: "New International Version", languageCode: "en", isDownloaded: false, sizeInMB: 6.0)

        versionsByLanguage = [
            en.code: [kjv, webu],
            ptBR.code: [bliv],
            he.code: [heb]
        ]
    }
}
