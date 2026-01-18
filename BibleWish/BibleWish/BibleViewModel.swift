//
//  ViewModel.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import Foundation


class BibleViewModel: ObservableObject {

    @Published var books: [BibleBook] = [] {
        didSet {
            onBooksUpdated()
        }
    }

    @Published var errorMessage: String?
    @Published private(set) var verseIndex: [IndexedVerse] = []
    private var hasBuiltIndex = false
    
    struct ReadingProgress: Codable {
        var completedChapters: Set<String> // "Genesis-1", "Genesis-2"
    }



    init() {
        
        if let data = UserDefaults.standard.data(forKey: "readingProgress"),
               let decoded = try? JSONDecoder().decode(ReadingProgress.self, from: data) {
                readingProgress = decoded
            } else {
                readingProgress = ReadingProgress(completedChapters: [])
            }
        
        loadBible()
        
        buildSearchIndex()        
    }
    
    func progressForBook(_ book: BibleBook) -> Double {
        let total = book.chapters.count
        guard total > 0 else { return 0 }

        let completed = book.chapters.filter { chapter in
            readingProgress.completedChapters.contains("\(book.name)-\(chapter.number)")
        }.count

        return Double(completed) / Double(total)
    }

    
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(readingProgress) {
            UserDefaults.standard.set(data, forKey: "readingProgress")
        }
    }
    
    @Published private(set) var readingProgress: ReadingProgress {
        didSet {
            saveProgress()
        }
    }

    
    func chapterKey(book: String, chapter: Int) -> String {
        "\(book)-\(chapter)"
    }


    func loadBible() {
        guard let url = Bundle.main.url(forResource: "bible_kjv", withExtension: "json") else {
            errorMessage = "Bible JSON file not found."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(BibleData.self, from: data)

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
                    break // ⬅️ huge performance win
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
        let key = "\(book)-\(chapter)"
        return readingProgress.completedChapters.contains(key)
    }

    func toggleChapterCompleted(book: String, chapter: Int) {
        let key = "\(book)-\(chapter)"
        
        var progress = readingProgress

        if progress.completedChapters.contains(key) {
            progress.completedChapters.remove(key)
        } else {
            progress.completedChapters.insert(key)
        }

        readingProgress = progress

    }



}
