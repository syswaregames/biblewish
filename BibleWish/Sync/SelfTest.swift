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

    private(set) var failures = 0

    init(auth: AuthStore, sync: SyncEngine, bibleVM: BibleViewModel, bookmarks: BookmarkManager) {
        self.auth = auth
        self.sync = sync
        self.bibleVM = bibleVM
        self.bookmarks = bookmarks
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
}
#endif
