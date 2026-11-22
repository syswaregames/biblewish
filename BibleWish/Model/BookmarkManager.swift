import Foundation

class BookmarkManager: ObservableObject {

    @Published private(set) var bookmarks: [Bookmark] = []

    /// Set by the sync engine to hear about changes made by the reader (not ones applied from the server).
    var onChange: ((SyncOp) -> Void)?

    private let key = "saved_bookmarks"

    init() {
        load()
    }

    func isBookmarked(_ bookmark: Bookmark) -> Bool {
        bookmarks.contains {
            $0.bookName == bookmark.bookName &&
            $0.chapterNumber == bookmark.chapterNumber &&
            $0.verseNumber == bookmark.verseNumber
        }
    }

    func toggle(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: {
            $0.bookName == bookmark.bookName &&
            $0.chapterNumber == bookmark.chapterNumber &&
            $0.verseNumber == bookmark.verseNumber
        }) {
            let removed = bookmarks.remove(at: index)
            if let serverId = removed.serverId {
                onChange?(.deleteFavorite(serverId: serverId))
            }
        } else {
            bookmarks.append(bookmark)
            onChange?(.pushFavorite(bookmark.id))
        }
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            if let serverId = bookmarks[index].serverId {
                onChange?(.deleteFavorite(serverId: serverId))
            }
        }
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Sync (these never call onChange)

    func bookmark(id: UUID) -> Bookmark? {
        bookmarks.first { $0.id == id }
    }

    func setServerId(_ serverId: Int, for id: UUID) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        bookmarks[index].serverId = serverId
        save()
    }

    /// Makes the list match the server's favorites, keeping bookmarks that haven't been sent yet.
    func apply(serverFavorites: [Bookmark]) {
        let waiting = bookmarks.filter { $0.serverId == nil }
        let known = Dictionary(uniqueKeysWithValues: bookmarks.compactMap { local in local.serverId.map { ($0, local) } })

        let fromServer = serverFavorites.map { incoming -> Bookmark in
            // Keep the local id of a bookmark we already had, so the list doesn't flicker.
            guard let serverId = incoming.serverId, let local = known[serverId] else { return incoming }
            return Bookmark(
                id: local.id, bookName: incoming.bookName, chapterNumber: incoming.chapterNumber,
                verseNumber: incoming.verseNumber, verseText: incoming.verseText,
                verseEnd: incoming.verseEnd, translation: incoming.translation, serverId: serverId
            )
        }
        let updated = waiting + fromServer
        if updated != bookmarks {
            bookmarks = updated
            save()
        }
    }

    /// Forget the links to a server account (a different account is signing in).
    func clearServerIds() {
        for index in bookmarks.indices { bookmarks[index].serverId = nil }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return
        }
        bookmarks = decoded
    }
}
