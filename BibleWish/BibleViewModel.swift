//
//  ViewModel.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation

enum BibleTranslation: String, CaseIterable, Identifiable {
    case kjv
    case bliv
    case webu
    case heb

    var id: String { rawValue }

    var resourceName: String {
        switch self {
        case .kjv:
            return "bible_kjv"
        case .bliv:
            return "bible_pt_bliv"
        case .webu:
            return "bible_en_webu"
        case .heb:
            return "bible_he_heb"
        }
    }

    var language: String {
        switch self {
        case .kjv:
            return "English"
        case .bliv:
            return "Portuguese"
        case .webu:
            return "English"
        case .heb:
            return "Hebrew"
        }
    }

    var version: String {
        switch self {
        case .kjv:
            return "KJV"
        case .bliv:
            return "BLIV"
        case .webu:
            return "WEBU"
        case .heb:
            return "HEB"
        }
    }

    var displayName: String {
        "\(language) - \(version)"
    }

    var shortDescription: String {
        switch self {
        case .kjv:
            return "Classic language (King James Version)"
        case .bliv:
            return "Modern Portuguese (BLIV)"
        case .webu:
            return "Modern English (WEBU)"
        case .heb:
            return "Hebrew text (HEB)"
        }
    }
}

class BibleViewModel: ObservableObject {

    @Published var books: [BibleBook] = [] {
        didSet {
            onBooksUpdated()
        }
    }

    @Published var errorMessage: String?
    @Published private(set) var verseIndex: [IndexedVerse] = []
    @Published var selectedTranslation: BibleTranslation {
        didSet {
            guard oldValue != selectedTranslation else { return }
            UserDefaults.standard.set(selectedTranslation.rawValue, forKey: selectedTranslationKey)
            loadBible()
        }
    }

    private var hasBuiltIndex = false
    private let selectedTranslationKey = "selected_bible_translation"

    struct ReadingProgress: Codable {
        var completedChapters: Set<String>
    }

    @Published private(set) var readingProgress: ReadingProgress {
        didSet {
            saveProgress()
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: selectedTranslationKey),
           let translation = BibleTranslation(rawValue: saved) {
            selectedTranslation = translation
        } else {
            selectedTranslation = .kjv
        }

        if let data = UserDefaults.standard.data(forKey: "readingProgress"),
           let decoded = try? JSONDecoder().decode(ReadingProgress.self, from: data) {
            readingProgress = decoded
        } else {
            readingProgress = ReadingProgress(completedChapters: [])
        }

        loadBible()
    }

    func progressForBook(_ book: BibleBook) -> Double {
        let total = book.chapters.count
        guard total > 0 else { return 0 }

        let completed = book.chapters.filter { chapter in
            readingProgress.completedChapters.contains(chapterKey(book: book.name, chapter: chapter.number))
        }.count

        return Double(completed) / Double(total)
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(readingProgress) {
            UserDefaults.standard.set(data, forKey: "readingProgress")
        }
    }

    func chapterKey(book: String, chapter: Int) -> String {
        "\(selectedTranslation.rawValue)|\(book)-\(chapter)"
    }

    func loadBible() {
        guard let url = Bundle.main.url(forResource: selectedTranslation.resourceName, withExtension: "json") else {
            errorMessage = "Bible JSON file not found."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(BibleData.self, from: data)

            hasBuiltIndex = false
            verseIndex = []
            errorMessage = nil

            DispatchQueue.main.async {
                self.books = decoded.books
            }
        } catch {
            errorMessage = "Failed to load Bible: \(error.localizedDescription)"
            print(error)
        }
    }

    func search(query: String, limit: Int = 100) -> [SearchResult] {
        let q = query
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard q.count >= 2 else { return [] }

        var results: [SearchResult] = []

        for verse in verseIndex {
            if verse.searchableText.contains(q) {
                results.append(
                    SearchResult(
                        bookName: verse.book,
                        chapterNumber: verse.chapter,
                        verseNumber: verse.verse,
                        verseText: verse.text
                    )
                )

                if results.count >= limit {
                    break
                }
            }
        }

        return results
    }

    func onBooksUpdated() {
        guard !hasBuiltIndex else { return }
        guard !books.isEmpty else { return }

        hasBuiltIndex = true
        buildSearchIndex()
    }

    private func buildSearchIndex() {
        var index: [IndexedVerse] = []

        for book in books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    index.append(
                        IndexedVerse(
                            book: book.name,
                            chapter: chapter.number,
                            verse: verse.number,
                            text: verse.text,
                            searchableText: verse.text.lowercased()
                        )
                    )
                }
            }
        }

        verseIndex = index
        print("🔍 Search index built: \(index.count) verses")
    }

    func chapterFor(
        bookName: String,
        chapterNumber: Int
    ) -> Chapter? {
        books
            .first { $0.name == bookName }?
            .chapters
            .first { $0.number == chapterNumber }
    }

    func book(named name: String) -> BibleBook? {
        books.first { $0.name == name }
    }

    func isChapterCompleted(book: String, chapter: Int) -> Bool {
        let key = chapterKey(book: book, chapter: chapter)
        return readingProgress.completedChapters.contains(key)
    }

    func toggleChapterCompleted(book: String, chapter: Int) {
        let key = chapterKey(book: book, chapter: chapter)

        var progress = readingProgress

        if progress.completedChapters.contains(key) {
            progress.completedChapters.remove(key)
        } else {
            progress.completedChapters.insert(key)
        }

        readingProgress = progress
    }

    func resetReadingProgress() {
        var progress = readingProgress
        progress.completedChapters.removeAll()
        readingProgress = progress
    }
}
