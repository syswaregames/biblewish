//
//  SyncEngine.swift
//
//  Keeps this device and biblewish.com in step, when the reader is signed in.
//
//  The device is the source of truth and everything works offline. Changes are queued as
//  operations (SyncOp); a sync pass sends the queue first, and only when it is empty pulls the
//  server's state, so a pull can never overwrite a change that hasn't been sent yet.
//

import Foundation

@MainActor
final class SyncEngine: ObservableObject {

    enum Status: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSynced: Date?

    /// Changes waiting to be sent.
    var pendingCount: Int { outbox.ops.count }

    private var outbox = SyncOutbox()
    private var running = false
    private var pending: Task<Void, Never>?

    private let api = APIClient.shared
    private weak var auth: AuthStore?
    private weak var viewModel: BibleViewModel?
    private weak var bookmarks: BookmarkManager?

    private let accountKey = "sync_account_id"
    private let initialKey = "sync_initial_done_account"
    private let lastSyncedKey = "sync_last_synced"

    init() {
        let saved = UserDefaults.standard.double(forKey: lastSyncedKey)
        if saved > 0 { lastSynced = Date(timeIntervalSince1970: saved) }
    }

    // MARK: - Wiring

    func attach(auth: AuthStore, viewModel: BibleViewModel, bookmarks: BookmarkManager) {
        self.auth = auth
        self.viewModel = viewModel
        self.bookmarks = bookmarks

        bookmarks.onChange = { [weak self] op in self?.enqueue(op) }
        viewModel.onReadChange = { [weak self] op in self?.enqueue(op) }
        auth.onSignedOut = { [weak self] in self?.signedOut() }
        auth.onAccountDeleted = { [weak self] in self?.accountDeleted() }
    }

    /// Called when someone signs in (or the app starts already signed in).
    func signedIn() async {
        guard let user = auth?.user else { return }
        let account = UserDefaults.standard.integer(forKey: accountKey)
        if account != user.id {
            // A different account: the links to the old one mean nothing here.
            bookmarks?.clearServerIds()
            outbox.removeAll()
            UserDefaults.standard.set(user.id, forKey: accountKey)
            UserDefaults.standard.removeObject(forKey: initialKey)
        }
        if UserDefaults.standard.integer(forKey: initialKey) != user.id {
            queueEverythingOnThisDevice()
            UserDefaults.standard.set(user.id, forKey: initialKey)
        }
        await syncNow()
    }

    private func signedOut() {
        pending?.cancel()
        outbox.removeAll()
        status = .idle
        // Server links are kept: signing back in to the same account picks up where it left off.
        // Deleting the account is handled by clearing them (see accountDeleted()).
    }

    /// The account is gone from the server; nothing on this device points at it any more.
    func accountDeleted() {
        bookmarks?.clearServerIds()
        outbox.removeAll()
        UserDefaults.standard.removeObject(forKey: accountKey)
        UserDefaults.standard.removeObject(forKey: initialKey)
    }

    // MARK: - Queue

    func enqueue(_ op: SyncOp) {
        guard auth?.isSignedIn == true else { return }
        outbox.add(op)
        scheduleSync()
    }

    /// Everything already on the device goes up once after signing in.
    private func queueEverythingOnThisDevice() {
        outbox.add(.importReading)
        for bookmark in bookmarks?.bookmarks ?? [] {
            outbox.add(.pushFavorite(bookmark.id))
        }
    }

    private func scheduleSync() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    // MARK: - Sync

    func syncNow() async {
        guard auth?.isSignedIn == true, !running else { return }
        running = true
        status = .syncing
        defer { running = false }

        do {
            try await flush()
            try await pull()
            lastSynced = Date()
            UserDefaults.standard.set(lastSynced?.timeIntervalSince1970, forKey: lastSyncedKey)
            status = .idle
        } catch APIError.unauthorized {
            auth?.clearLocalSession()
        } catch {
            status = .failed((error as? LocalizedError)?.errorDescription ?? "Couldn\u{2019}t sync.")
        }
    }

    /// Sends the queued operations in order. Stops at a temporary problem (offline, server busy) and
    /// keeps the rest; drops an operation the server will never accept so it can't block the queue.
    private func flush() async throws {
        while let op = outbox.first {
            do {
                try await perform(op)
            } catch let error as APIError {
                if case .unauthorized = error { throw error }
                if error.isTemporary { throw error }
                // Permanent refusal: forget this one and carry on.
            }
            outbox.removeFirst()
        }
    }

    private func perform(_ op: SyncOp) async throws {
        switch op {
        case .pushFavorite(let id):
            guard let bookmark = bookmarks?.bookmark(id: id), let payload = favoritePayload(bookmark) else { return }
            let response = try await api.request(FavoriteResponse.self, "POST", "api/favorites.php", json: payload)
            bookmarks?.setServerId(response.favorite.id, for: id)

        case .deleteFavorite(let serverId):
            try await api.send("DELETE", "api/favorites.php", query: ["id": String(serverId)])

        case .readChapter(let book, let chapter, let read):
            try await api.send("POST", "api/reading.php", json: ["book_index": book, "chapter": chapter, "read": read])

        case .importReading:
            guard let viewModel else { return }
            let refs = AchievementMetrics.chapterRefs(fromKeys: viewModel.readingProgress.completedChapters)
            guard !refs.isEmpty else { return }
            let pairs = refs.sorted { ($0.book, $0.chapter) < ($1.book, $1.chapter) }.map { [$0.book, $0.chapter] }
            try await api.send("POST", "api/reading.php", query: ["action": "import"], json: ["chapters": pairs])
        }
    }

    private func pull() async throws {
        guard outbox.isEmpty, let viewModel, !viewModel.books.isEmpty else { return }

        let favorites = try await api.request(FavoritesResponse.self, "GET", "api/favorites.php")
        bookmarks?.apply(serverFavorites: favorites.favorites.compactMap { bookmark(from: $0, books: viewModel.books) })

        let reading = try await api.request(ReadingResponse.self, "GET", "api/reading.php")
        viewModel.applyServerChapters(reading.chapters)
    }

    // MARK: - Favorites mapping

    private struct FavoriteResponse: Decodable { let favorite: ServerFavorite }
    private struct FavoritesResponse: Decodable { let favorites: [ServerFavorite] }
    private struct ReadingResponse: Decodable { let chapters: [[Int]] }

    private struct ServerFavorite: Decodable {
        let id: Int
        let translation: String
        let bookIndex: Int
        let chapter: Int
        let verses: [Int]
        let referenceLabel: String
        let text: String
    }

    private func favoritePayload(_ bookmark: Bookmark) -> [String: Any]? {
        guard let bookIndex = BookIndex.of(name: bookmark.bookName) else { return nil }
        let last = max(bookmark.verseEnd ?? bookmark.verseNumber, bookmark.verseNumber)
        guard last - bookmark.verseNumber < 200 else { return nil }
        return [
            "translation": bookmark.translation ?? viewModel?.selectedTranslation.widgetId ?? "kjv",
            "book_index": bookIndex,
            "chapter": bookmark.chapterNumber,
            "verses": Array(bookmark.verseNumber...last),
            "reference_label": String(bookmark.reference.prefix(120)),
            "text": String(bookmark.verseText.prefix(8000)),
        ]
    }

    private func bookmark(from favorite: ServerFavorite, books: [BibleBook]) -> Bookmark? {
        guard favorite.bookIndex < books.count, let first = favorite.verses.first else { return nil }
        let last = favorite.verses.last ?? first
        return Bookmark(
            bookName: books[favorite.bookIndex].name,
            chapterNumber: favorite.chapter,
            verseNumber: first,
            verseText: favorite.text,
            verseEnd: last > first ? last : nil,
            translation: favorite.translation,
            serverId: favorite.id
        )
    }
}
