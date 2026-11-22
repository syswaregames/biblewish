//
//  SelfTest.swift
//
//  Debug-only checks that run inside the real app against the local biblewish.com server (the
//  Docker stack in the website repo, with Mailpit catching the sign-in emails). Not in Release.
//
//  Run:  docker compose up -d   (in the website repo)
//        SIMCTL_CHILD_BW_SELFTEST=1 SIMCTL_CHILD_BW_API_BASE=http://localhost:8088 \
//          xcrun simctl launch --console <device> Sysware.BibleWish
//  Results are printed to stderr as PASS / FAIL lines, ending with SELFTEST DONE.
//

#if DEBUG
import Foundation

@MainActor
final class SelfTest {

    let auth: AuthStore
    let sync: SyncEngine
    let bibleVM: BibleViewModel
    let bookmarks: BookmarkManager
    let highlights: HighlightManager
    let notes: NoteStore

    private(set) var failures = 0

    init(auth: AuthStore, sync: SyncEngine, bibleVM: BibleViewModel, bookmarks: BookmarkManager, highlights: HighlightManager, notes: NoteStore) {
        self.auth = auth
        self.sync = sync
        self.bibleVM = bibleVM
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.notes = notes
    }

    /// Reads from the server as the signed-in test account.
    func get<T: Decodable>(_ type: T.Type, _ path: String, query: [String: String] = [:]) async -> T? {
        try? await APIClient.shared.request(type, "GET", path, query: query)
    }

    // MARK: - Helpers

    private func emit(_ text: String) { fputs(text + "\n", stderr) }

    func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        emit((ok ? "PASS " : "FAIL ") + name + (ok ? "" : " " + detail()))
        if !ok { failures += 1 }
    }

    private func clearMailbox() async {
        var request = URLRequest(url: URL(string: "http://localhost:8025/api/v1/messages")!)
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
    }

    private func latestMailCode() async -> String? {
        struct List: Decodable { struct Message: Decodable { let ID: String }; let messages: [Message] }
        struct Message: Decodable { let Text: String? }
        for _ in 0..<10 {
            if let (data, _) = try? await URLSession.shared.data(from: URL(string: "http://localhost:8025/api/v1/messages")!),
               let id = (try? JSONDecoder().decode(List.self, from: data))?.messages.first?.ID,
               let (body, _) = try? await URLSession.shared.data(from: URL(string: "http://localhost:8025/api/v1/message/\(id)")!),
               let text = (try? JSONDecoder().decode(Message.self, from: body))?.Text,
               let range = text.range(of: #"\b\d{6}\b"#, options: .regularExpression) {
                return String(text[range])
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        return nil
    }

    /// Signs in with a fresh throwaway account on the local server.
    func signInFreshAccount(_ label: String = "apptest") async -> String? {
        let email = "\(label)\(Int(Date().timeIntervalSince1970))\(Int.random(in: 100...999))@example.test"
        await clearMailbox()
        guard await auth.requestCode(email: email), let code = await latestMailCode(),
              await auth.verify(email: email, code: code) else { return nil }
        return email
    }

    // MARK: - Run

    func run() async {
        check("base url is local", APIConfig.baseURL.absoluteString == "http://localhost:8088", APIConfig.baseURL.absoluteString)
        runKeyFormat()
        await runAuth()
        await runFavoritesAndReading()
        await runHighlights()
        await runNotes()
        emit(failures == 0 ? "SELFTEST ALL PASSED" : "SELFTEST \(failures) FAILED")
        emit("SELFTEST DONE")
    }

    // MARK: - Saved chapter keys

    /// The app saves chapters as "translation|Book-Chapter"; every place that counts progress depends on reading it.
    private func runKeyFormat() {
        let real = AchievementMetrics.chapterRefs(fromKeys: ["kjv|John-3", "bliv|Mateus-5", "webu|1 John-2", "heb|Genesis-1", "kjv|Song of Solomon-2"])
        check("real keys are understood", real == [ChapterRef(book: 42, chapter: 3), ChapterRef(book: 39, chapter: 5), ChapterRef(book: 61, chapter: 2), ChapterRef(book: 0, chapter: 1), ChapterRef(book: 21, chapter: 2)], "\(real)")
        check("old keys without a translation too", AchievementMetrics.chapterRefs(fromKeys: ["Matthew-5"]) == [ChapterRef(book: 39, chapter: 5)])
        check("same chapter in two translations counts once", AchievementMetrics.chapterRefs(fromKeys: ["kjv|Matthew-5", "bliv|Mateus-5"]).count == 1)
        check("junk keys are skipped", AchievementMetrics.chapterRefs(fromKeys: ["kjv|Nonsense-1", "oops", "kjv|John-x", ""]).isEmpty)
        let model = BibleViewModel()
        check("keys the app writes are the ones we read", AchievementMetrics.chapterRefs(fromKeys: [model.chapterKey(book: "John", chapter: 3)]) == [ChapterRef(book: 42, chapter: 3)], model.chapterKey(book: "John", chapter: 3))
    }

    // MARK: - Sign-in

    private func runAuth() async {
        check("starts signed out", !auth.isSignedIn)
        let email = "apptest\(Int(Date().timeIntervalSince1970))@example.test"
        await clearMailbox()
        check("request code", await auth.requestCode(email: email), auth.errorMessage ?? "")
        let code = await latestMailCode()
        check("code arrived", code != nil)
        check("wrong code rejected", await auth.verify(email: email, code: "000000") == false && auth.errorMessage != nil)
        check("right code signs in", await auth.verify(email: email, code: code ?? "") && auth.user?.email == email, auth.errorMessage ?? "")
        let firstId = auth.user?.id
        await auth.restore()
        check("restore keeps the session", auth.isSignedIn)
        let export = try? await APIClient.shared.send("GET", "api/account.php", query: ["action": "export"])
        check("export has the email", export.flatMap { String(data: $0, encoding: .utf8) }?.contains(email) == true)
        await auth.signOut()
        check("sign out", !auth.isSignedIn)
        check("server rejects after sign out", (try? await APIClient.shared.send("GET", "api/highlights.php")) == nil)

        await clearMailbox()
        _ = await auth.requestCode(email: email)
        check("sign in again", await auth.verify(email: email, code: await latestMailCode() ?? ""))
        check("delete account", await auth.deleteAccount() && !auth.isSignedIn, auth.errorMessage ?? "")
        check("deleted session is dead", (try? await APIClient.shared.send("GET", "api/highlights.php")) == nil)

        await clearMailbox()
        _ = await auth.requestCode(email: email)
        check("same email is a new account after deleting", await auth.verify(email: email, code: await latestMailCode() ?? "") && auth.user?.id != firstId)
        await auth.signOut()
    }

    // MARK: - Favorites and reading

    private struct Fav: Decodable { let id: Int; let bookIndex: Int; let chapter: Int; let verses: [Int]; let text: String }
    private struct Favs: Decodable { let favorites: [Fav] }
    private struct Reading: Decodable { let chapters: [[Int]]; let today: [[Int]] }

    private func waitForBooks() async {
        for _ in 0..<40 where bibleVM.books.count < 66 { try? await Task.sleep(nanoseconds: 250_000_000) }
    }

    private func serverFavorites() async -> [Fav] { await get(Favs.self, "api/favorites.php")?.favorites ?? [] }
    private func serverReading() async -> Reading? { await get(Reading.self, "api/reading.php") }

    private func bookmark(_ book: String, _ chapter: Int, _ verse: Int, _ text: String) -> Bookmark {
        Bookmark(bookName: book, chapterNumber: chapter, verseNumber: verse, verseText: text, translation: "kjv")
    }

    private func runFavoritesAndReading() async {
        await waitForBooks()
        check("books loaded", bibleVM.books.count == 66, "\(bibleVM.books.count)")

        // Start clean and signed out; make some things on the device first.
        bookmarks.delete(at: IndexSet(integersIn: 0..<bookmarks.bookmarks.count))
        check("signed out for setup", !auth.isSignedIn)
        bookmarks.toggle(bookmark("John", 3, 16, "For God so loved the world"))
        if !bibleVM.isChapterCompleted(book: "John", chapter: 3) { bibleVM.toggleChapterCompleted(book: "John", chapter: 3) }
        check("nothing queued while signed out", sync.pendingCount == 0, "\(sync.pendingCount)")

        // 1. Signing in uploads what was already on the device.
        guard let email = await signInFreshAccount("sync") else { check("sign in for sync tests", false); return }
        await sync.signedIn()
        var favs = await serverFavorites()
        check("device favorite reached the server", favs.count == 1 && favs[0].bookIndex == 42 && favs[0].chapter == 3 && favs[0].verses == [16], "\(favs)")
        check("local bookmark linked to the server", bookmarks.bookmarks.first?.serverId == favs.first?.id && favs.first != nil)
        var reading = await serverReading()
        check("device reading reached the server", reading?.chapters.contains([42, 3]) == true, "\(String(describing: reading?.chapters))")
        check("import made no read event today", reading?.today.isEmpty == true, "\(String(describing: reading?.today))")
        check("queue empty after sync", sync.pendingCount == 0, "\(sync.pendingCount)")

        // 2. Add and delete on the device while signed in.
        bookmarks.toggle(bookmark("Psalm", 23, 1, "The LORD is my shepherd"))
        check("change is queued", sync.pendingCount >= 1)
        await sync.syncNow()
        favs = await serverFavorites()
        check("added bookmark synced", favs.contains { $0.bookIndex == 18 && $0.chapter == 23 && $0.verses == [1] }, "\(favs.count)")
        let john = bookmarks.bookmarks.first { $0.bookName == "John" }!
        bookmarks.toggle(john)
        await sync.syncNow()
        favs = await serverFavorites()
        check("deleted bookmark removed from server", !favs.contains { $0.bookIndex == 42 } && favs.count == 1, "\(favs.count)")

        // 3. Changes made on the server (the website) arrive.
        _ = try? await APIClient.shared.send("POST", "api/favorites.php", json: ["translation": "kjv", "book_index": 44, "chapter": 8, "verses": [28, 29], "reference_label": "Romans 8:28-29", "text": "And we know that all things work together for good"])
        await sync.syncNow()
        let romans = bookmarks.bookmarks.first { $0.bookName == "Romans" }
        check("server favorite arrived", romans != nil && romans?.verseNumber == 28 && romans?.verseEnd == 29 && romans?.reference == "Romans 8:28-29", "\(String(describing: romans))")
        check("arrived favorite is linked", romans?.serverId != nil)
        if let id = (await serverFavorites()).first(where: { $0.bookIndex == 44 })?.id {
            _ = try? await APIClient.shared.send("DELETE", "api/favorites.php", query: ["id": String(id)])
        }
        await sync.syncNow()
        check("server deletion reached the device", !bookmarks.bookmarks.contains { $0.bookName == "Romans" } && bookmarks.bookmarks.count == 1, "\(bookmarks.bookmarks.map(\.reference))")

        // 4. Reading progress.
        if !bibleVM.isChapterCompleted(book: "Mark", chapter: 1) { bibleVM.toggleChapterCompleted(book: "Mark", chapter: 1) }
        await sync.syncNow()
        reading = await serverReading()
        check("chapter read on device reached the server today", reading?.today.contains([40, 1]) == true, "\(String(describing: reading?.today))")
        bibleVM.toggleChapterCompleted(book: "Mark", chapter: 1)
        await sync.syncNow()
        reading = await serverReading()
        check("unread on device undone on the server", reading?.today.contains([40, 1]) == false && reading?.chapters.contains([40, 1]) == false, "\(String(describing: reading))")
        _ = try? await APIClient.shared.send("POST", "api/reading.php", json: ["book_index": 41, "chapter": 2, "read": true])
        await sync.syncNow()
        check("chapter read on the website arrived", bibleVM.isChapterCompleted(book: "Luke", chapter: 2))

        // 5. Offline: changes wait in the queue and are sent later.
        setenv("BW_API_BASE", "http://localhost:9", 1)
        bookmarks.toggle(bookmark("Genesis", 1, 1, "In the beginning"))
        await sync.syncNow()
        check("failed sync keeps the change queued", sync.pendingCount >= 1 && { if case .failed = sync.status { return true } else { return false } }(), "\(sync.pendingCount) \(sync.status)")
        setenv("BW_API_BASE", "http://localhost:8088", 1)
        await sync.syncNow()
        favs = await serverFavorites()
        check("queued change delivered once back online", sync.pendingCount == 0 && favs.contains { $0.bookIndex == 0 && $0.verses == [1] }, "\(sync.pendingCount) \(favs.count)")
        check("status back to idle", sync.status == .idle)

        // 6. A different account: the old links are dropped and the device's data goes up again.
        await auth.signOut()
        check("signed out again", !auth.isSignedIn)
        let before = bookmarks.bookmarks.count
        guard await signInFreshAccount("sync2") != nil else { check("second account sign in", false); return }
        await sync.signedIn()
        favs = await serverFavorites()
        check("second account got the device favorites", favs.count == before && before >= 2, "\(favs.count) vs \(before)")
        check("favorites relinked to the new account", bookmarks.bookmarks.allSatisfy { $0.serverId != nil } && Set(bookmarks.bookmarks.compactMap(\.serverId)) == Set(favs.map(\.id)))

        // Clean up both throwaway accounts.
        check("delete second account", await auth.deleteAccount())
        _ = email
    }

    // MARK: - Highlights

    private struct ServerHighlights {
        var verses: [String: [Int]] = [:]
        var colors: [String: [String: String]] = [:]
    }

    private func serverHighlights() async -> ServerHighlights {
        guard let data = try? await APIClient.shared.send("GET", "api/highlights.php"),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ServerHighlights() }
        // The server answers [] for an empty map.
        return ServerHighlights(
            verses: object["highlights"] as? [String: [Int]] ?? [:],
            colors: object["colors"] as? [String: [String: String]] ?? [:]
        )
    }

    private func putServerHighlight(_ translation: String, _ book: Int, _ chapter: Int, _ verses: [Int], colors: [String: String]? = nil) async {
        var body: [String: Any] = ["translation": translation, "book_index": book, "chapter": chapter, "verses": verses]
        if let colors { body["colors"] = colors }
        _ = try? await APIClient.shared.send("PUT", "api/highlights.php", json: body)
    }

    private func runHighlights() async {
        if auth.isSignedIn { await auth.signOut() }
        highlights.removeAllLocal()

        // Highlights made before this version only know a book name: they get its number and the open translation.
        let legacy = [Highlight(bookName: "John", chapterNumber: 3, verseNumber: 5, color: .green)]
        UserDefaults.standard.set(try? JSONEncoder().encode(legacy), forKey: "saved_highlights")
        let migrated = HighlightManager()
        migrated.migrateLegacy(currentTranslation: "bliv")
        check("legacy highlight gets its book number and translation", migrated.highlights.first?.bookIndex == 42 && migrated.highlights.first?.translation == "bliv", "\(String(describing: migrated.highlights.first))")
        UserDefaults.standard.removeObject(forKey: "saved_highlights")

        // Made on the device before signing in.
        highlights.highlight(translation: "kjv", bookIndex: 42, bookName: "John", chapter: 3, verse: 16, color: .green)
        highlights.highlight(translation: "kjv", bookIndex: 42, bookName: "John", chapter: 3, verse: 17, color: .yellow)
        highlights.highlight(translation: "kjv", bookIndex: 0, bookName: "Genesis", chapter: 1, verse: 1, color: .pink)
        check("nothing queued while signed out (highlights)", sync.pendingCount == 0, "\(sync.pendingCount)")

        guard await signInFreshAccount("hl") != nil else { check("sign in for highlight tests", false); return }
        await sync.signedIn()
        var server = await serverHighlights()
        check("device highlights merged up", server.verses["kjv:42:3"] == [16, 17] && server.verses["kjv:0:1"] == [1], "\(server.verses)")
        check("colors survived (yellow is the default)", server.colors["kjv:42:3"] == ["16": "green"] && server.colors["kjv:0:1"] == ["1": "pink"], "\(server.colors)")

        // Changes while signed in.
        highlights.removeHighlight(translation: "kjv", bookIndex: 42, chapter: 3, verse: 17)
        await sync.syncNow()
        server = await serverHighlights()
        check("removed highlight removed on the server", server.verses["kjv:42:3"] == [16], "\(server.verses)")
        highlights.highlight(translation: "kjv", bookIndex: 42, bookName: "John", chapter: 3, verse: 16, color: .blue)
        await sync.syncNow()
        server = await serverHighlights()
        check("changed color reached the server", server.colors["kjv:42:3"] == ["16": "blue"], "\(server.colors)")

        // Changes made on the website (and another translation).
        await putServerHighlight("web", 43, 1, [8], colors: ["8": "pink"])
        await putServerHighlight("heb2", 0, 1, [1])
        await sync.syncNow()
        check("website highlight arrived with its color", highlights.highlightFor(translation: "web", bookIndex: 43, chapter: 1, verse: 8)?.color == .pink)
        check("highlights are per translation", highlights.highlightFor(translation: "kjv", bookIndex: 43, chapter: 1, verse: 8) == nil)
        check("a translation the app doesn't have stays on the server", !highlights.highlights.contains { $0.translation == "heb2" })
        await putServerHighlight("kjv", 0, 1, [])
        await sync.syncNow()
        check("highlight removed on the website disappears", highlights.highlightFor(translation: "kjv", bookIndex: 0, chapter: 1, verse: 1) == nil)
        // The website sends verses only; saved colors must survive its edits.
        await putServerHighlight("kjv", 42, 3, [16, 18])
        await sync.syncNow()
        check("website edit keeps the saved color", highlights.highlightFor(translation: "kjv", bookIndex: 42, chapter: 3, verse: 16)?.color == .blue && highlights.highlightFor(translation: "kjv", bookIndex: 42, chapter: 3, verse: 18)?.color == .yellow)

        // Offline.
        setenv("BW_API_BASE", "http://localhost:9", 1)
        highlights.highlight(translation: "kjv", bookIndex: 42, bookName: "John", chapter: 3, verse: 20, color: .green)
        await sync.syncNow()
        check("offline highlight stays queued", sync.pendingCount >= 1)
        setenv("BW_API_BASE", "http://localhost:8088", 1)
        await sync.syncNow()
        server = await serverHighlights()
        check("queued highlight delivered", sync.pendingCount == 0 && server.verses["kjv:42:3"]?.contains(20) == true, "\(server.verses)")

        // Another account gets everything on the device.
        await auth.signOut()
        let chaptersOnDevice = Set(highlights.chapters.map(\.key))
        guard await signInFreshAccount("hl2") != nil else { check("second account for highlights", false); return }
        await sync.signedIn()
        server = await serverHighlights()
        check("second account received the device highlights", Set(server.verses.keys) == chaptersOnDevice && !chaptersOnDevice.isEmpty, "\(server.verses.keys) vs \(chaptersOnDevice)")
        _ = await auth.deleteAccount()
        highlights.removeAllLocal()
    }

    // MARK: - Notes

    private struct SrvNote: Decodable {
        let id: Int
        let title: String
        let body: String
        let reference: String?
        let tags: [String]
        let bookIndex: Int?
        let chapter: Int?
        let verseStart: Int?
    }
    private struct SrvNotes: Decodable { let notes: [SrvNote] }

    private func serverNotes() async -> [SrvNote] { await get(SrvNotes.self, "api/notes.php")?.notes ?? [] }

    private func runNotes() async {
        if auth.isSignedIn { await auth.signOut() }
        notes.removeAllLocal()

        var plain = Note(title: "", body: "First line of body\nmore text", reference: "", tags: [.insight])
        var verse = Note(title: "Grace", body: "**bold** and a list\n- one", reference: "John 3:16", tags: [.prayer, .promise])
        notes.save(plain)
        notes.save(verse)
        check("nothing queued while signed out (notes)", sync.pendingCount == 0, "\(sync.pendingCount)")

        guard await signInFreshAccount("notes") != nil else { check("sign in for note tests", false); return }
        await sync.signedIn()
        var server = await serverNotes()
        check("both notes reached the server", server.count == 2, "\(server.count)")
        check("untitled note was sent with its first line as the title", server.contains { $0.title == "First line of body" && $0.body.hasPrefix("First line") })
        let anchored = server.first { $0.title == "Grace" }
        check("note about a verse is anchored to it", anchored?.bookIndex == 42 && anchored?.chapter == 3 && anchored?.verseStart == 16, "\(String(describing: anchored))")
        check("tags and Markdown survived", anchored?.tags == ["prayer", "promise"] && anchored?.body.contains("**bold**") == true)
        check("notes are linked to the server", notes.notes.allSatisfy { $0.serverId != nil } && notes.notes.count == 2)

        // Edit and delete on the device.
        verse = notes.notes.first { $0.title == "Grace" }!
        verse.body = "edited on the device"
        notes.save(verse)
        await sync.syncNow()
        server = await serverNotes()
        check("edit reached the server", server.contains { $0.title == "Grace" && $0.body == "edited on the device" })
        plain = notes.notes.first { $0.body.hasPrefix("First line") }!
        notes.delete(id: plain.id)
        await sync.syncNow()
        server = await serverNotes()
        check("delete reached the server", server.count == 1, "\(server.count)")

        // Made on the website.
        _ = try? await APIClient.shared.send("POST", "api/notes.php", json: ["title": "From the web", "body": "web body", "reference": "Psalm 23", "tags": ["question"]])
        await sync.syncNow()
        let fromWeb = notes.notes.first { $0.title == "From the web" }
        check("website note arrived", fromWeb != nil && fromWeb?.tags == [.question] && fromWeb?.reference == "Psalm 23" && fromWeb?.serverId != nil)
        let graceId = server.first { $0.title == "Grace" }!.id
        _ = try? await APIClient.shared.send("PUT", "api/notes.php", query: ["id": String(graceId)], json: ["title": "Grace", "body": "edited on the web", "reference": "John 3:16"])
        let localIdBefore = notes.notes.first { $0.title == "Grace" }?.id
        await sync.syncNow()
        let graceNow = notes.notes.first { $0.title == "Grace" }
        check("website edit arrived and the note kept its local id", graceNow?.body == "edited on the web" && graceNow?.id == localIdBefore)
        check("tags kept when the website edits without them", graceNow?.tags == [.prayer, .promise], "\(String(describing: graceNow?.tags))")
        if let webId = fromWeb?.serverId { _ = try? await APIClient.shared.send("DELETE", "api/notes.php", query: ["id": String(webId)]) }
        await sync.syncNow()
        check("note deleted on the website disappears", !notes.notes.contains { $0.title == "From the web" } && notes.notes.count == 1, "\(notes.notes.map(\.title))")

        // Offline edit.
        setenv("BW_API_BASE", "http://localhost:9", 1)
        var offline = notes.notes.first!
        offline.body = "written offline"
        notes.save(offline)
        await sync.syncNow()
        check("offline edit stays on the device and queued", notes.notes.first?.body == "written offline" && sync.pendingCount >= 1)
        setenv("BW_API_BASE", "http://localhost:8088", 1)
        await sync.syncNow()
        server = await serverNotes()
        check("offline edit delivered and not overwritten by the pull", server.first?.body == "written offline" && notes.notes.first?.body == "written offline" && sync.pendingCount == 0, "\(String(describing: server.first?.body)) / \(String(describing: notes.notes.first?.body))")

        // A new note while signed in.
        notes.save(Note(title: "Made while signed in", body: "hello", reference: "", tags: []))
        await sync.syncNow()
        server = await serverNotes()
        check("new note synced", server.contains { $0.title == "Made while signed in" } && server.count == 2, "\(server.count)")

        // Another account.
        await auth.signOut()
        let onDevice = notes.notes.count
        guard await signInFreshAccount("notes2") != nil else { check("second account for notes", false); return }
        await sync.signedIn()
        server = await serverNotes()
        check("second account received the notes", server.count == onDevice && onDevice == 2, "\(server.count) vs \(onDevice)")
        check("no duplicates locally", notes.notes.count == onDevice, "\(notes.notes.count)")
        _ = await auth.deleteAccount()
        notes.removeAllLocal()
    }
}
#endif
