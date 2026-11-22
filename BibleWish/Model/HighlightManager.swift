import Foundation

/// One chapter's highlights in one translation: the unit that is synced.
struct HighlightChapter: Hashable {
    let translation: String
    let bookIndex: Int
    let chapter: Int

    /// "kjv:42:3", the key biblewish.com uses.
    var key: String { "\(translation):\(bookIndex):\(chapter)" }

    init(translation: String, bookIndex: Int, chapter: Int) {
        self.translation = translation
        self.bookIndex = bookIndex
        self.chapter = chapter
    }

    init?(key: String) {
        let parts = key.split(separator: ":")
        guard parts.count == 3, let book = Int(parts[1]), let chapter = Int(parts[2]) else { return nil }
        self.init(translation: String(parts[0]), bookIndex: book, chapter: chapter)
    }
}

class HighlightManager: ObservableObject {

    @Published private(set) var highlights: [Highlight] = []

    /// Set by the sync engine to hear about changes made by the reader (not ones applied from the server).
    var onChange: ((SyncOp) -> Void)?

    /// Translations the app can show, as the website names them. Highlights in others stay on the server only.
    static let knownTranslations: Set<String> = ["kjv", "web", "bliv", "heb"]

    private let key = "saved_highlights"

    init() {
        load()
    }

    // MARK: - The reader

    func highlight(
        translation: String,
        bookIndex: Int,
        bookName: String,
        chapter: Int,
        verse: Int,
        color: HighlightColor
    ) {
        highlights.removeAll { matches($0, translation, bookIndex, chapter, verse) }
        highlights.append(
            Highlight(
                bookName: bookName,
                chapterNumber: chapter,
                verseNumber: verse,
                color: color,
                translation: translation,
                bookIndex: bookIndex
            )
        )
        save()
        onChange?(.pushHighlightChapter(translation: translation, bookIndex: bookIndex, chapter: chapter))
    }

    func removeHighlight(translation: String, bookIndex: Int, chapter: Int, verse: Int) {
        let before = highlights.count
        highlights.removeAll { matches($0, translation, bookIndex, chapter, verse) }
        guard highlights.count != before else { return }
        save()
        onChange?(.pushHighlightChapter(translation: translation, bookIndex: bookIndex, chapter: chapter))
    }

    /// The highlighted verses of a chapter, in order: the reader's current selection.
    func selected(translation: String, bookIndex: Int, chapter: Int) -> [Int] {
        highlights
            .filter { $0.translation == translation && $0.bookIndex == bookIndex && $0.chapterNumber == chapter }
            .map(\.verseNumber)
            .sorted()
    }

    /// Highlights the verse, or removes its highlight. Returns whether it is highlighted now.
    @discardableResult
    func toggle(translation: String, bookIndex: Int, bookName: String, chapter: Int, verse: Int, color: HighlightColor) -> Bool {
        if highlightFor(translation: translation, bookIndex: bookIndex, chapter: chapter, verse: verse) != nil {
            removeHighlight(translation: translation, bookIndex: bookIndex, chapter: chapter, verse: verse)
            return false
        }
        highlight(translation: translation, bookIndex: bookIndex, bookName: bookName, chapter: chapter, verse: verse, color: color)
        return true
    }

    /// Gives all of these verses one color (one change to sync, however many verses).
    func setColor(_ color: HighlightColor, translation: String, bookIndex: Int, bookName: String, chapter: Int, verses: [Int]) {
        let wanted = Set(verses)
        highlights.removeAll { $0.translation == translation && $0.bookIndex == bookIndex && $0.chapterNumber == chapter && wanted.contains($0.verseNumber) }
        for verse in wanted.sorted() {
            highlights.append(Highlight(bookName: bookName, chapterNumber: chapter, verseNumber: verse, color: color, translation: translation, bookIndex: bookIndex))
        }
        save()
        onChange?(.pushHighlightChapter(translation: translation, bookIndex: bookIndex, chapter: chapter))
    }

    /// Removes every highlight in the chapter and returns them, so the clear can be undone.
    @discardableResult
    func clear(translation: String, bookIndex: Int, chapter: Int) -> [Highlight] {
        let removed = highlights.filter { $0.translation == translation && $0.bookIndex == bookIndex && $0.chapterNumber == chapter }
        guard !removed.isEmpty else { return [] }
        highlights.removeAll { $0.translation == translation && $0.bookIndex == bookIndex && $0.chapterNumber == chapter }
        save()
        onChange?(.pushHighlightChapter(translation: translation, bookIndex: bookIndex, chapter: chapter))
        return removed
    }

    /// Puts back highlights returned by `clear`.
    func restore(_ removed: [Highlight], translation: String, bookIndex: Int, chapter: Int) {
        guard !removed.isEmpty else { return }
        highlights.removeAll { $0.translation == translation && $0.bookIndex == bookIndex && $0.chapterNumber == chapter }
        highlights.append(contentsOf: removed)
        save()
        onChange?(.pushHighlightChapter(translation: translation, bookIndex: bookIndex, chapter: chapter))
    }

    func highlightFor(translation: String, bookIndex: Int, chapter: Int, verse: Int) -> Highlight? {
        highlights.first { matches($0, translation, bookIndex, chapter, verse) }
    }

    private func matches(_ highlight: Highlight, _ translation: String, _ bookIndex: Int, _ chapter: Int, _ verse: Int) -> Bool {
        highlight.chapterNumber == chapter && highlight.verseNumber == verse
            && highlight.bookIndex == bookIndex && highlight.translation == translation
    }

    // MARK: - Older highlights

    /// Highlights made before this version only know the book's name. Give them the book's number and
    /// assume the translation that is open now (it is the one they were almost certainly made in).
    func migrateLegacy(currentTranslation: String) {
        var changed = false
        for index in highlights.indices {
            if highlights[index].bookIndex == nil, let number = BookIndex.of(name: highlights[index].bookName) {
                highlights[index].bookIndex = number
                changed = true
            }
            if highlights[index].translation == nil {
                highlights[index].translation = currentTranslation
                changed = true
            }
        }
        if changed { save() }
    }

    // MARK: - Sync (these never call onChange)

    /// Every chapter that has a highlight.
    var chapters: [HighlightChapter] {
        var seen = Set<HighlightChapter>()
        for highlight in highlights {
            if let translation = highlight.translation, let book = highlight.bookIndex {
                seen.insert(HighlightChapter(translation: translation, bookIndex: book, chapter: highlight.chapterNumber))
            }
        }
        return Array(seen)
    }

    /// The highlighted verses of a chapter and the colors of those that aren't the default yellow.
    func state(of chapter: HighlightChapter) -> (verses: [Int], colors: [Int: HighlightColor]) {
        let inChapter = highlights.filter {
            $0.translation == chapter.translation && $0.bookIndex == chapter.bookIndex && $0.chapterNumber == chapter.chapter
        }
        var colors: [Int: HighlightColor] = [:]
        for highlight in inChapter where highlight.color != .yellow { colors[highlight.verseNumber] = highlight.color }
        return (inChapter.map(\.verseNumber).sorted(), colors)
    }

    /// Makes the highlights match the server's. `bookName` names a book in the open translation.
    func apply(server: [HighlightChapter: [Int: HighlightColor]], bookName: (Int) -> String?) {
        var updated = highlights.filter { highlight in
            // Keep what the app can't show anyway (none today) and anything that isn't tied to a translation.
            guard let translation = highlight.translation else { return true }
            return !Self.knownTranslations.contains(translation)
        }
        for (chapter, verses) in server where Self.knownTranslations.contains(chapter.translation) {
            for (verse, color) in verses {
                // Reuse the highlight we already had so nothing flickers.
                if let existing = highlights.first(where: {
                    $0.translation == chapter.translation && $0.bookIndex == chapter.bookIndex
                        && $0.chapterNumber == chapter.chapter && $0.verseNumber == verse && $0.color == color
                }) {
                    updated.append(existing)
                } else {
                    updated.append(Highlight(
                        bookName: bookName(chapter.bookIndex) ?? "",
                        chapterNumber: chapter.chapter,
                        verseNumber: verse,
                        color: color,
                        translation: chapter.translation,
                        bookIndex: chapter.bookIndex
                    ))
                }
            }
        }
        if Set(updated.map(\.id)) != Set(highlights.map(\.id)) {
            highlights = updated
            save()
        }
    }

    func removeAllLocal() {
        guard !highlights.isEmpty else { return }
        highlights = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(highlights) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Highlight].self, from: data)
        else { return }

        highlights = decoded
    }
}
