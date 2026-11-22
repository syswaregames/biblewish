import Foundation

struct Highlight: Identifiable, Codable, Equatable {
    let id: UUID
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let color: HighlightColor
    /// The translation it was made in ("kjv", "web", "bliv", "heb"). Highlights are per translation,
    /// like on biblewish.com. Nil only for highlights made before this was recorded.
    var translation: String?
    /// The book's position in the Bible (0 = Genesis); the same book has different names per translation.
    var bookIndex: Int?

    init(
        id: UUID = UUID(),
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int,
        color: HighlightColor,
        translation: String? = nil,
        bookIndex: Int? = nil
    ) {
        self.id = id
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.color = color
        self.translation = translation
        self.bookIndex = bookIndex
    }
}
