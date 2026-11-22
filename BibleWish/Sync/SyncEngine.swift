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
    private weak var highlights: HighlightManager?
    private weak var notes: NoteStore?

    private let accountKey = "sync_account_id"
    private let initialKey = "sync_initial_done_account"
    private let lastSyncedKey = "sync_last_synced"

    init() {
        let saved = UserDefaults.standard.double(forKey: lastSyncedKey)
        if saved > 0 { lastSynced = Date(timeIntervalSince1970: saved) }
    }

    // MARK: - Wiring

    func attach(
        auth: AuthStore,
        viewModel: BibleViewModel,
        bookmarks: BookmarkManager,
        highlights: HighlightManager,
        notes: NoteStore
    ) {
        self.auth = auth
        self.viewModel = viewModel
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.notes = notes

        bookmarks.onChange = { [weak self] op in self?.enqueue(op) }
        highlights.onChange = { [weak self] op in self?.enqueue(op) }
        notes.onChange = { [weak self] op in self?.enqueue(op) }
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
            notes?.clearServerIds()
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
        notes?.clearServerIds()
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
        if !(highlights?.highlights.isEmpty ?? true) {
            outbox.add(.mergeHighlights)
        }
        for note in notes?.notes ?? [] {
            outbox.add(.pushNote(note.id))
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

        case .pushHighlightChapter(let translation, let bookIndex, let chapter):
            guard let highlights else { return }
            let state = highlights.state(of: HighlightChapter(translation: translation, bookIndex: bookIndex, chapter: chapter))
            try await api.send("PUT", "api/highlights.php", json: [
                "translation": translation,
                "book_index": bookIndex,
                "chapter": chapter,
                "verses": state.verses,
                "colors": Dictionary(uniqueKeysWithValues: state.colors.map { (String($0.key), $0.value.rawValue) }),
            ])

        case .mergeHighlights:
            try await mergeHighlights()

        case .pushNote(let id):
            guard let note = notes?.note(id: id) else { return }
            let payload = notePayload(note)
            if let serverId = note.serverId {
                try await api.send("PUT", "api/notes.php", query: ["id": String(serverId)], json: payload)
            } else {
                let response = try await api.request(NoteResponse.self, "POST", "api/notes.php", json: payload)
                notes?.setServerId(response.note.id, for: id)
            }

        case .deleteNote(let serverId):
            try await api.send("DELETE", "api/notes.php", query: ["id": String(serverId)])
        }
    }

    private func pull() async throws {
        guard outbox.isEmpty, let viewModel, !viewModel.books.isEmpty else { return }

        let favorites = try await api.request(FavoritesResponse.self, "GET", "api/favorites.php")
        bookmarks?.apply(serverFavorites: favorites.favorites.compactMap { bookmark(from: $0, books: viewModel.books) })

        let reading = try await api.request(ReadingResponse.self, "GET", "api/reading.php")
        viewModel.applyServerChapters(reading.chapters)

        let serverHighlights = try await api.request(HighlightsResponse.self, "GET", "api/highlights.php")
        highlights?.apply(server: serverHighlights.asChapters, bookName: { index in
            index < viewModel.books.count ? viewModel.books[index].name : nil
        })

        let serverNotes = try await api.request(NotesResponse.self, "GET", "api/notes.php")
        notes?.apply(serverNotes: serverNotes.notes.map(\.asNote))
    }

    // MARK: - Highlights mapping

    /// The server answers `[]` instead of `{}` for an empty map, so these are read leniently.
    private struct HighlightsResponse: Decodable {
        let highlights: [String: [Int]]
        let colors: [String: [String: String]]

        enum CodingKeys: String, CodingKey { case highlights, colors }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            highlights = (try? container.decode([String: [Int]].self, forKey: .highlights)) ?? [:]
            colors = (try? container.decode([String: [String: String]].self, forKey: .colors)) ?? [:]
        }

        var asChapters: [HighlightChapter: [Int: HighlightColor]] {
            var result: [HighlightChapter: [Int: HighlightColor]] = [:]
            for (key, verses) in highlights {
                guard let chapter = HighlightChapter(key: key) else { continue }
                var byVerse: [Int: HighlightColor] = [:]
                for verse in verses {
                    let name = colors[key]?[String(verse)]
                    byVerse[verse] = name.flatMap(HighlightColor.init(rawValue:)) ?? .yellow
                }
                result[chapter] = byVerse
            }
            return result
        }
    }

    /// Sends every highlight on the device once (the server keeps the union), in batches that fit its size limit.
    private func mergeHighlights() async throws {
        guard let highlights else { return }
        var chapters = highlights.chapters
        chapters.sort { $0.key < $1.key }
        let batchSize = 400
        for start in stride(from: 0, to: chapters.count, by: batchSize) {
            var verses: [String: [Int]] = [:]
            var colors: [String: [String: String]] = [:]
            for chapter in chapters[start..<min(start + batchSize, chapters.count)] {
                let state = highlights.state(of: chapter)
                verses[chapter.key] = state.verses
                if !state.colors.isEmpty {
                    colors[chapter.key] = Dictionary(uniqueKeysWithValues: state.colors.map { (String($0.key), $0.value.rawValue) })
                }
            }
            try await api.send("POST", "api/highlights.php", query: ["action": "merge"], json: ["highlights": verses, "colors": colors])
        }
    }

    // MARK: - Notes mapping

    private struct NoteResponse: Decodable { let note: ServerNote }
    private struct NotesResponse: Decodable { let notes: [ServerNote] }

    private struct ServerNote: Decodable {
        let id: Int
        let title: String
        let body: String
        let reference: String?
        let tags: [String]
        let createdAt: Date
        let updatedAt: Date

        var asNote: Note {
            Note(
                title: title, body: body, reference: reference ?? "",
                tags: tags.compactMap(NoteTag.init(rawValue:)),
                createdAt: createdAt, updatedAt: updatedAt, serverId: id
            )
        }
    }

    private func notePayload(_ note: Note) -> [String: Any] {
        // The server needs a title; a note without one gets its first line, as the list shows it.
        var payload: [String: Any] = [
            "title": String(note.displayTitle.prefix(200)),
            "body": String(note.body.prefix(20000)),
            "reference": String(note.reference.prefix(80)),
            "tags": note.tags.map(\.rawValue),
        ]
        // A note about one verse is shown beside it in the website's reader.
        if let viewModel, let passage = PassageReference.parse(note.reference, in: viewModel.books),
           let verse = passage.verse, let book = BookIndex.of(name: passage.bookName),
           let source = viewModel.book(named: passage.bookName), passage.chapterIndex < source.chapters.count {
            payload["book_index"] = book
            payload["chapter"] = source.chapters[passage.chapterIndex].number
            payload["verse_start"] = verse
            payload["verse_end"] = verse
        }
        return payload
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
