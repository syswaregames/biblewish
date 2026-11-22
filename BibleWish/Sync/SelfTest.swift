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
    let plans: PlansStore
    let prayers: PrayerStore

    private(set) var failures = 0

    init(auth: AuthStore, sync: SyncEngine, bibleVM: BibleViewModel, bookmarks: BookmarkManager, highlights: HighlightManager, notes: NoteStore, plans: PlansStore, prayers: PrayerStore) {
        self.auth = auth
        self.sync = sync
        self.bibleVM = bibleVM
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.notes = notes
        self.plans = plans
        self.prayers = prayers
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
        runNoteFormat()
        runNoteEditing()
        await runAuth()
        await runFavoritesAndReading()
        await runHighlights()
        await runNotes()
        await runPlans()
        await runPrayers()
        await runRefusingServer()
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

    // MARK: - Note editing (the toolbar)

    private func edited(_ value: String, _ selection: NSRange, _ edit: NoteEditing.Edit) -> (text: String, selected: String) {
        let text = NoteEditing.apply(edit, to: value)
        let selected = edit.selection.location + edit.selection.length <= (text as NSString).length ? (text as NSString).substring(with: edit.selection) : "<out of range>"
        return (text, selected)
    }

    private func runNoteEditing() {
        func range(_ value: String, _ word: String) -> NSRange { (value as NSString).range(of: word) }

        var r = edited("a word b", range("a word b", "word"), NoteEditing.wrap("a word b", range("a word b", "word"), marker: "**", placeholder: "bold text"))
        check("bold wraps the selection", r.text == "a **word** b" && r.selected == "word", "\(r)")
        let wrappedText = "a **word** b"
        r = edited(wrappedText, range(wrappedText, "word"), NoteEditing.wrap(wrappedText, range(wrappedText, "word"), marker: "**", placeholder: "bold text"))
        check("bold again takes it off", r.text == "a word b" && r.selected == "word", "\(r)")
        r = edited("ab", NSRange(location: 1, length: 0), NoteEditing.wrap("ab", NSRange(location: 1, length: 0), marker: "*", placeholder: "italic text"))
        check("italic with nothing selected inserts a placeholder, selected", r.text == "a*italic text*b" && r.selected == "italic text", "\(r)")
        r = edited("a word b", range("a word b", "word "), NoteEditing.wrap("a word b", range("a word b", "word "), marker: "**", placeholder: "x"))
        check("a selected trailing space stays outside the markers", r.text == "a **word** b" && r.selected == "word", "\(r)")
        r = edited("a caf\u{00E9} \u{1F600} b", range("a caf\u{00E9} \u{1F600} b", "\u{1F600}"), NoteEditing.wrap("a caf\u{00E9} \u{1F600} b", range("a caf\u{00E9} \u{1F600} b", "\u{1F600}"), marker: "**", placeholder: "x"))
        check("bold works around an emoji (UTF-16 positions)", r.text == "a caf\u{00E9} **\u{1F600}** b" && r.selected == "\u{1F600}", "\(r)")

        r = edited("hello world", range("hello world", "world"), NoteEditing.color("hello world", range("hello world", "world"), id: "red", mark: false))
        check("text color wraps the selection", r.text == "hello {red|world}" && r.selected == "world", "\(r)")
        let colored = "hello {red|world}"
        r = edited(colored, range(colored, "world"), NoteEditing.color(colored, range(colored, "world"), id: "gold", mark: false))
        check("a different color replaces the old one", r.text == "hello {gold|world}" && r.selected == "world", "\(r)")
        r = edited(colored, range(colored, "world"), NoteEditing.color(colored, range(colored, "world"), id: "red", mark: false))
        check("the same color takes it off", r.text == "hello world" && r.selected == "world", "\(r)")
        r = edited("hello world", range("hello world", "world"), NoteEditing.color("hello world", range("hello world", "world"), id: "teal", mark: true))
        check("highlighter uses {=color|…}", r.text == "hello {=teal|world}" && r.selected == "world", "\(r)")
        let marked = "hello {=teal|world}"
        r = edited(marked, range(marked, "world"), NoteEditing.color(marked, range(marked, "world"), id: "red", mark: false))
        check("a text color doesn't replace a highlight", r.text == "hello {=teal|{red|world}}", "\(r)")
        r = edited("", NSRange(location: 0, length: 0), NoteEditing.color("", NSRange(location: 0, length: 0), id: "green", mark: false))
        check("color with nothing selected inserts a placeholder", r.text == "{green|colored text}" && r.selected == "colored text", "\(r)")

        r = edited("intro", NSRange(location: 5, length: 0), NoteEditing.box("intro", NSRange(location: 5, length: 0), id: "gold"))
        check("a box starts on its own line", r.text == "intro\n::: gold\nYour text\n:::\n" && r.selected == "Your text", "\(r)")
        r = edited("see this now", range("see this now", "this"), NoteEditing.box("see this now", range("see this now", "this"), id: "red"))
        check("a box takes the selection", r.text == "see \n::: red\nthis\n:::\n now" && r.selected == "this", "\(r)")
        let card = NoteEditing.verseCard("a\n", NSRange(location: 2, length: 0), reference: "John 3:16", translation: "KJV", text: "For God so loved")
        check("a verse card with its reference", NoteEditing.apply(card, to: "a\n") == "a\n::: verse John 3:16 \u{00B7} KJV\nFor God so loved\n:::\n" && card.selection.length == 0, "\(card)")

        r = edited("one\ntwo", NSRange(location: 0, length: 7), NoteEditing.lines("one\ntwo", NSRange(location: 0, length: 7), style: .bullet))
        check("bullets on every selected line", r.text == "- one\n- two", "\(r)")
        r = edited("- one\n- two", NSRange(location: 0, length: 11), NoteEditing.lines("- one\n- two", NSRange(location: 0, length: 11), style: .bullet))
        check("bullets again take them off", r.text == "one\ntwo", "\(r)")
        r = edited("a\nb\nc", NSRange(location: 0, length: 5), NoteEditing.lines("a\nb\nc", NSRange(location: 0, length: 5), style: .numbered))
        check("numbers count up", r.text == "1. a\n2. b\n3. c", "\(r)")
        r = edited("- a\n- b", NSRange(location: 0, length: 7), NoteEditing.lines("- a\n- b", NSRange(location: 0, length: 7), style: .numbered))
        check("a different list style replaces the old one", r.text == "1. a\n2. b", "\(r)")
        r = edited("title", NSRange(location: 2, length: 0), NoteEditing.lines("title", NSRange(location: 2, length: 0), style: .heading))
        check("a heading on the caret's line", r.text == "## title", "\(r)")
        r = edited("first\nsecond", NSRange(location: 8, length: 0), NoteEditing.lines("first\nsecond", NSRange(location: 8, length: 0), style: .quote))
        check("only the caret's line is quoted", r.text == "first\n> second", "\(r)")
        r = edited("a\n\nb", NSRange(location: 0, length: 4), NoteEditing.lines("a\n\nb", NSRange(location: 0, length: 4), style: .bullet))
        check("blank lines are left alone", r.text == "- a\n\n- b", "\(r)")

        r = edited("see site", range("see site", "site"), NoteEditing.link("see site", range("see site", "site")))
        check("a link with the selection as its text", r.text == "see [site](https://)" && r.selected == "https://", "\(r)")
        r = edited("go https://x.com now", range("go https://x.com now", "https://x.com"), NoteEditing.link("go https://x.com now", range("go https://x.com now", "https://x.com")))
        check("a selected address becomes the target", r.text == "go [link text](https://x.com) now" && r.selected == "link text", "\(r)")
        r = edited("", NSRange(location: 0, length: 0), NoteEditing.link("", NSRange(location: 0, length: 0)))
        check("a link with nothing selected", r.text == "[link text](https://)" && r.selected == "https://", "\(r)")

        var key = NoteEditing.returnKey("- one", caret: 5)
        check("return continues a bullet list", key.map { NoteEditing.apply($0, to: "- one") } == "- one\n- ", "\(String(describing: key))")
        key = NoteEditing.returnKey("1. one", caret: 6)
        check("return continues a numbered list", key.map { NoteEditing.apply($0, to: "1. one") } == "1. one\n2. ", "\(String(describing: key))")
        key = NoteEditing.returnKey("3) x", caret: 4)
        check("numbering keeps its style", key.map { NoteEditing.apply($0, to: "3) x") } == "3) x\n4) ", "\(String(describing: key))")
        key = NoteEditing.returnKey("a\n- ", caret: 4)
        check("return on an empty item ends the list", key.map { NoteEditing.apply($0, to: "a\n- ") } == "a\n", "\(String(describing: key))")
        key = NoteEditing.returnKey("  - nested", caret: 10)
        check("indent is kept", key.map { NoteEditing.apply($0, to: "  - nested") } == "  - nested\n  - ", "\(String(describing: key))")
        check("return in plain text is left to the editor", NoteEditing.returnKey("just text", caret: 9) == nil)
        key = NoteEditing.returnKey("> quote", caret: 7)
        check("return continues a quote", key.map { NoteEditing.apply($0, to: "> quote") } == "> quote\n> ", "\(String(describing: key))")

        // Verse ranges for "Insert a verse".
        let books = bibleVM.books
        let single = PassageReference.parse("John 3:16", in: books)
        let range = PassageReference.parse("Psalm 23:1-3", in: books)
        let dashed = PassageReference.parse("Rom 8:28\u{2013}30", in: books)
        check("a verse reference has no range end", single?.verse == 16 && single?.verseEnd == nil, "\(String(describing: single))")
        check("a verse range is read", range?.verse == 1 && range?.verseEnd == 3 && range?.chapterIndex == 22, "\(String(describing: range))")
        check("an en dash range is read too", dashed?.verse == 28 && dashed?.verseEnd == 30, "\(String(describing: dashed))")
        check("a backwards range is not a range", PassageReference.parse("John 3:16-12", in: books)?.verseEnd == nil)
    }

    // MARK: - Note formatting

    /// The note syntax is shared with the website (js/note-format.js).
    private func runNoteFormat() {
        // The inline grammar against the website's own regex (cases generated by tools/gen_note_fixtures.mjs).
        var mismatches: [String] = []
        for (line, expected) in NoteInlineFixtures.cases {
            let ours = NoteInline.describe(NoteInline.parse(line))
            if ours != expected { mismatches.append("\(line) -> \(ours) (website: \(expected))") }
        }
        check("inline formatting matches the website on \(NoteInlineFixtures.cases.count) lines", mismatches.isEmpty, mismatches.prefix(3).joined(separator: " | "))
        check("bold with a space inside is not bold", NoteInline.parse("** spaced **") == [.text("** spaced **")])
        check("bold around colored words keeps both", NoteInline.parse("**bold {red|red} bold**") == [.bold([.text("bold "), .color(.red, [.text("red")]), .text(" bold")])], "\(NoteInline.parse("**bold {red|red} bold**"))")
        check("bold inside a colored span", NoteInline.parse("{red|**x**}") == [.color(.red, [.bold([.text("x")])])])
        check("plain text drops the markup", NoteInline.plain("**a** *b* _c_ {red|d} {=gold|e} [f](https://x.com)") == "a b c d e f", NoteInline.plain("**a** *b* _c_ {red|d} {=gold|e} [f](https://x.com)"))
        check("an untitled note is titled by its first line without markup", Note(body: "**Bold title**\nsecond").displayTitle == "Bold title" && Note(body: "# Heading\ntext").displayTitle == "Heading" && Note(body: "::: gold Remember\nbe still\n:::").displayTitle == "Remember")
        check("a preview has no markup and skips the title line", Note(body: "**Title**\nwith {red|color} and *style*").preview == "with color and style", Note(body: "**Title**\nwith {red|color} and *style*").preview)
        check("a titled note previews its whole body", Note(title: "T", body: "**a**\n- b").preview == "a b", Note(title: "T", body: "**a**\n- b").preview)
        check("a box and a verse card preview as words", Note(title: "T", body: "::: verse John 3:16\nFor God so loved\n:::").preview == "For God so loved John 3:16", Note(title: "T", body: "::: verse John 3:16\nFor God so loved\n:::").preview)
        check("a colored box with a title", NoteBlock.parse("::: gold Remember\nbe still\n:::") == [.box(color: .gold, title: "Remember", body: [.paragraph("be still")])], "\(NoteBlock.parse("::: gold Remember\nbe still\n:::"))")
        check("a box without a title", NoteBlock.parse("::: red\ntext\n:::") == [.box(color: .red, title: nil, body: [.paragraph("text")])])
        check("a verse card with its citation", NoteBlock.parse("::: verse John 3:16 \u{00B7} KJV\nFor God so loved\n:::") == [.verse(cite: "John 3:16 \u{00B7} KJV", body: [.paragraph("For God so loved")])], "\(NoteBlock.parse("::: verse John 3:16 \u{00B7} KJV\nFor God so loved\n:::"))")
        check("a box without its closing line stays text", NoteBlock.parse("::: gold Title\nbody") == [.paragraph("::: gold Title"), .paragraph("body")])
        check("an unknown box color stays text", NoteBlock.parse("::: pink\nx\n:::") == [.paragraph("::: pink"), .paragraph("x"), .paragraph(":::")])
        check("blocks around a box", NoteBlock.parse("before\n::: green\ninside\n:::\nafter") == [.paragraph("before"), .box(color: .green, title: nil, body: [.paragraph("inside")]), .paragraph("after")])
        check("a box can hold a list", NoteBlock.parse("::: teal List\n- one\n- two\n:::") == [.box(color: .teal, title: "List", body: [.bullet("one"), .bullet("two")])])
        check("headings up to three hashes", NoteBlock.parse("# A\n## B\n### C\n#### D") == [.heading(level: 1, text: "A"), .heading(level: 2, text: "B"), .heading(level: 2, text: "C"), .paragraph("#### D")])
        check("bullets and numbers as on the website", NoteBlock.parse("\u{2022} dot\n* star\n3) three\n1. one") == [.bullet("dot"), .bullet("star"), .numbered(3, "three"), .numbered(1, "one")], "\(NoteBlock.parse("\u{2022} dot\n* star\n3) three\n1. one"))")
        check("quotes and blank lines", NoteBlock.parse("> wise\n\nplain") == [.quote("wise"), .gap, .paragraph("plain")])
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

    // MARK: - Reading plans

    private struct SrvPlan: Decodable {
        let planId: String
        let startedOn: String
        let completedAt: String?
        let progress: [[PlanCell]]
        // progress items are [day, item, completed_at]; only day and item are read here
        var cells: [[Int]] { progress.map { $0.compactMap(\.number) } }
    }
    private struct PlanCell: Decodable {
        let number: Int?
        init(from decoder: Decoder) throws { number = try? decoder.singleValueContainer().decode(Int.self) }
    }
    private struct SrvPlans: Decodable { let plans: [SrvPlan] }

    private func serverPlans() async -> [SrvPlan] { await get(SrvPlans.self, "api/plans.php")?.plans ?? [] }

    private func runPlans() async {
        if auth.isSignedIn { await auth.signOut() }
        for plan in plans.userPlans { plans.stop(plan.id) }
        let calendar = Calendar.current
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date())!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date())!
        let startedOnTen = PlansStore.isoDay(tenDaysAgo)

        // Made on the device before signing in, with real dates.
        plans.start("gospels-30", on: tenDaysAgo)
        plans.toggle(planId: "gospels-30", day: 1, item: 0, at: fiveDaysAgo)
        plans.toggle(planId: "gospels-30", day: 1, item: 1, at: fiveDaysAgo)
        plans.toggle(planId: "gospels-30", day: 2, item: 0, at: fiveDaysAgo)
        plans.start("proverbs-31")
        check("nothing queued while signed out (plans)", sync.pendingCount == 0, "\(sync.pendingCount)")

        guard await signInFreshAccount("plans") != nil else { check("sign in for plan tests", false); return }
        await sync.signedIn()
        var server = await serverPlans()
        let gospels = server.first { $0.planId == "gospels-30" }
        check("both plans reached the server", Set(server.map(\.planId)) == ["gospels-30", "proverbs-31"], "\(server.map(\.planId))")
        check("the real start date was kept", gospels?.startedOn == startedOnTen, "\(String(describing: gospels?.startedOn)) vs \(startedOnTen)")
        check("ticks arrived", Set((gospels?.cells ?? []).map { "\($0[0]):\($0[1])" }) == ["1:0", "1:1", "2:0"], "\(String(describing: gospels?.cells))")
        var reading = await get(Reading.self, "api/reading.php")
        check("importing old ticks did not count as reading today", reading?.today.isEmpty == true, "\(String(describing: reading?.today))")
        check("ticked chapters are in Bible progress", reading?.chapters.contains([39, 1]) == true, "\(String(describing: reading?.chapters.prefix(6)))")
        check("and came back to the device's progress", bibleVM.isChapterCompleted(book: "Matthew", chapter: 1))

        // Ticking and unticking while signed in.
        plans.toggle(planId: "gospels-30", day: 2, item: 1)
        await sync.syncNow()
        server = await serverPlans()
        check("new tick reached the server", server.first { $0.planId == "gospels-30" }?.cells.contains([2, 1]) == true)
        reading = await get(Reading.self, "api/reading.php")
        check("a live tick counts as reading today", (reading?.today.count ?? 0) >= 1, "\(String(describing: reading?.today))")
        plans.toggle(planId: "gospels-30", day: 2, item: 1)
        await sync.syncNow()
        server = await serverPlans()
        check("untick reached the server", server.first { $0.planId == "gospels-30" }?.cells.contains([2, 1]) == false)

        // Stopping and starting.
        plans.stop("proverbs-31")
        plans.start("new-testament-90")
        await sync.syncNow()
        server = await serverPlans()
        check("stopped plan removed and new plan added", Set(server.map(\.planId)) == ["gospels-30", "new-testament-90"], "\(server.map(\.planId))")
        check("new plan starts today", server.first { $0.planId == "new-testament-90" }?.startedOn == PlansStore.isoDay(Date()))

        // Made on the website.
        _ = try? await APIClient.shared.send("POST", "api/plans.php", json: ["plan_id": "psalms-30", "start_date": PlansStore.isoDay(Date())])
        _ = try? await APIClient.shared.send("POST", "api/plans.php", query: ["action": "check"], json: ["plan_id": "psalms-30", "day": 1, "item": 0, "done": true])
        await sync.syncNow()
        check("plan started on the website arrived with its tick", plans.userPlan("psalms-30")?.progress.contains { $0.day == 1 && $0.item == 0 } == true)
        _ = try? await APIClient.shared.send("DELETE", "api/plans.php", query: ["plan_id": "gospels-30"])
        await sync.syncNow()
        check("plan stopped on the website disappears", plans.userPlan("gospels-30") == nil)

        // Offline.
        setenv("BW_API_BASE", "http://localhost:9", 1)
        plans.toggle(planId: "psalms-30", day: 1, item: 1)
        await sync.syncNow()
        check("offline tick stays queued", sync.pendingCount >= 1 && plans.isTicked(planId: "psalms-30", day: 1, item: 1))
        setenv("BW_API_BASE", "http://localhost:8088", 1)
        await sync.syncNow()
        server = await serverPlans()
        check("offline tick delivered and kept", sync.pendingCount == 0 && server.first { $0.planId == "psalms-30" }?.cells.contains([1, 1]) == true && plans.isTicked(planId: "psalms-30", day: 1, item: 1))

        // Another account gets the plans with their dates.
        await auth.signOut()
        let onDevice = Set(plans.userPlans.map(\.id))
        let psalmsStart = plans.userPlan("psalms-30")?.startedOn
        guard await signInFreshAccount("plans2") != nil else { check("second account for plans", false); return }
        await sync.signedIn()
        server = await serverPlans()
        check("second account received the plans", Set(server.map(\.planId)) == onDevice && !onDevice.isEmpty, "\(server.map(\.planId)) vs \(onDevice)")
        check("dates intact on the second account", server.first { $0.planId == "psalms-30" }?.startedOn == psalmsStart)
        _ = await auth.deleteAccount()
        for plan in plans.userPlans { plans.stop(plan.id) }
    }

    // MARK: - Prayer list

    private struct SrvPrayer: Decodable {
        let id: Int
        let title: String
        let details: String?
        let status: String
        let answeredAt: String?
        let answerNote: String?
    }
    private struct SrvPrayers: Decodable { let prayers: [SrvPrayer] }

    private func serverPrayers() async -> [SrvPrayer] { await get(SrvPrayers.self, "api/prayers.php")?.prayers ?? [] }

    private func runPrayers() async {
        if auth.isSignedIn { await auth.signOut() }
        prayers.removeAllLocal()

        // The answered date and note belong to answered prayers only.
        var oddity = Prayer(title: "Odd", status: .archived, answeredAt: Date(), answerNote: "should clear")
        prayers.save(oddity)
        oddity = prayers.prayers.first!
        check("answer details are cleared unless answered", oddity.answeredAt == nil && oddity.answerNote.isEmpty)
        prayers.removeAllLocal()

        prayers.save(Prayer(title: "Healing for a friend", details: "Please pray this week"))
        prayers.save(Prayer(title: "A job", details: "Interview on Friday", status: .answered, answerNote: "He got the job"))
        check("answered prayer gets its date", prayers.prayers.first { $0.title == "A job" }?.answeredAt != nil)
        check("nothing queued while signed out (prayers)", sync.pendingCount == 0, "\(sync.pendingCount)")

        guard await signInFreshAccount("pray") != nil else { check("sign in for prayer tests", false); return }
        await sync.signedIn()
        var server = await serverPrayers()
        check("both prayers reached the server", server.count == 2, "\(server.count)")
        let job = server.first { $0.title == "A job" }
        check("an answered prayer arrives answered, with its note", job?.status == "answered" && job?.answerNote == "He got the job" && job?.answeredAt != nil, "\(String(describing: job))")
        check("an active prayer stays active", server.first { $0.title == "Healing for a friend" }?.status == "active")
        check("prayers are linked to the server", prayers.prayers.allSatisfy { $0.serverId != nil })

        // Edits on the device.
        var healing = prayers.prayers.first { $0.title == "Healing for a friend" }!
        healing.title = "Healing for Sam"
        prayers.save(healing)
        await sync.syncNow()
        server = await serverPrayers()
        check("edit reached the server", server.contains { $0.title == "Healing for Sam" })
        healing = prayers.prayers.first { $0.title == "Healing for Sam" }!
        healing.status = .answered
        healing.answerNote = "Sam is well"
        prayers.save(healing)
        await sync.syncNow()
        server = await serverPrayers()
        let sam = server.first { $0.title == "Healing for Sam" }
        check("marking answered reached the server", sam?.status == "answered" && sam?.answerNote == "Sam is well" && sam?.answeredAt != nil, "\(String(describing: sam))")
        prayers.delete(id: prayers.prayers.first { $0.title == "A job" }!.id)
        await sync.syncNow()
        server = await serverPrayers()
        check("delete reached the server", server.count == 1, "\(server.count)")

        // Made on the website.
        if let response = try? await APIClient.shared.send("POST", "api/prayers.php", json: ["title": "From the web", "details": "web details"]),
           let object = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
           let prayer = object["prayer"] as? [String: Any], let webId = prayer["id"] as? Int {
            _ = try? await APIClient.shared.send("PUT", "api/prayers.php", query: ["id": String(webId)], json: ["title": "From the web", "details": "web details", "status": "archived"])
            await sync.syncNow()
            let fromWeb = prayers.prayers.first { $0.title == "From the web" }
            check("website prayer arrived archived", fromWeb?.status == .archived && fromWeb?.serverId == webId && fromWeb?.details == "web details", "\(String(describing: fromWeb))")
            _ = try? await APIClient.shared.send("DELETE", "api/prayers.php", query: ["id": String(webId)])
            await sync.syncNow()
            check("prayer deleted on the website disappears", !prayers.prayers.contains { $0.title == "From the web" } && prayers.prayers.count == 1, "\(prayers.prayers.map(\.title))")
        } else {
            check("create a prayer on the website", false)
        }

        // Offline.
        setenv("BW_API_BASE", "http://localhost:9", 1)
        var offline = prayers.prayers.first!
        offline.details = "added offline"
        prayers.save(offline)
        await sync.syncNow()
        check("offline edit stays queued", sync.pendingCount >= 1 && prayers.prayers.first?.details == "added offline")
        setenv("BW_API_BASE", "http://localhost:8088", 1)
        await sync.syncNow()
        server = await serverPrayers()
        check("offline edit delivered and kept", sync.pendingCount == 0 && server.first?.details == "added offline" && prayers.prayers.first?.details == "added offline")

        // Another account.
        await auth.signOut()
        let onDevice = prayers.prayers.count
        guard await signInFreshAccount("pray2") != nil else { check("second account for prayers", false); return }
        await sync.signedIn()
        server = await serverPrayers()
        check("second account received the prayer list", server.count == onDevice && onDevice == 1 && prayers.prayers.count == 1, "\(server.count) / \(prayers.prayers.count)")

        // Badges that use the prayer list.
        var input = AchievementInput()
        input.chaptersPerBook = bibleVM.books.map { $0.chapters.count }
        input.prayerItems = 10
        input.answeredPrayers = 5
        let values = AchievementMetrics.values(for: input)
        check("prayer list badge metrics", values["prayer_items"] == 10 && values["answered"] == 5)
        check("prayer badges are in the badge list", ["watchman", "testimony", "many-testimonies"].allSatisfy { id in AchievementsStore().badges.contains { $0.id == id } })

        _ = await auth.deleteAccount()
        prayers.removeAllLocal()
    }

    // MARK: - A server that refuses the uploads (not updated yet)

    /// An older website refuses the import endpoints. Nothing on the device may be deleted because of that.
    private func runRefusingServer() async {
        if auth.isSignedIn { await auth.signOut() }
        for plan in plans.userPlans { plans.stop(plan.id) }
        highlights.removeAllLocal()
        plans.clearConfirmed()

        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        plans.start("gospels-30", on: fiveDaysAgo)
        plans.toggle(planId: "gospels-30", day: 1, item: 0, at: fiveDaysAgo)
        plans.start("psalms-30", on: fiveDaysAgo)
        plans.toggle(planId: "psalms-30", day: 1, item: 1, at: fiveDaysAgo)
        highlights.highlight(translation: "kjv", bookIndex: 42, bookName: "John", chapter: 3, verse: 16, color: .green)

        APIClient.simulatedRefusals = ["POST api/plans.php?action=import", "POST api/highlights.php?action=merge"]
        guard await signInFreshAccount("refuse") != nil else { check("sign in for refusal tests", false); return }
        // psalms-30 also exists on the server (started on the website) with a different tick.
        _ = try? await APIClient.shared.send("POST", "api/plans.php", json: ["plan_id": "psalms-30", "start_date": PlansStore.isoDay(Date())])
        _ = try? await APIClient.shared.send("POST", "api/plans.php", query: ["action": "check"], json: ["plan_id": "psalms-30", "day": 1, "item": 0, "done": true])
        await sync.signedIn()
        await sync.syncNow()

        check("plan the server refused is still on the device", plans.userPlan("gospels-30")?.progress.count == 1)
        check("plan on both sides keeps ticks from both", Set(plans.userPlan("psalms-30")?.progress.map { $0.item } ?? []) == [0, 1], "\(String(describing: plans.userPlan("psalms-30")?.progress))")
        check("highlight the server refused is still on the device", highlights.highlightFor(translation: "kjv", bookIndex: 42, chapter: 3, verse: 16)?.color == .green)

        // The server catches up.
        APIClient.simulatedRefusals = []
        await sync.syncNow()
        await sync.syncNow()
        let server = await serverPlans()
        check("plan reaches the server once it accepts it", server.contains { $0.planId == "gospels-30" } && plans.userPlan("gospels-30") != nil, "\(server.map(\.planId))")
        let psalms = server.first { $0.planId == "psalms-30" }
        check("server has both ticks of the shared plan", Set((psalms?.cells ?? []).map { $0[1] }) == [0, 1], "\(String(describing: psalms?.cells))")
        let hl = await serverHighlights()
        check("highlight reaches the server once it accepts it", hl.verses["kjv:42:3"] == [16] && highlights.highlightFor(translation: "kjv", bookIndex: 42, chapter: 3, verse: 16) != nil, "\(hl.verses)")
        check("nothing left waiting", sync.pendingCount == 0, "\(sync.pendingCount)")

        // Once acknowledged, the server wins: a plan removed on the website goes from the device too.
        _ = try? await APIClient.shared.send("DELETE", "api/plans.php", query: ["plan_id": "gospels-30"])
        await sync.syncNow()
        check("acknowledged plan removed on the website goes from the device", plans.userPlan("gospels-30") == nil)

        _ = await auth.deleteAccount()
        for plan in plans.userPlans { plans.stop(plan.id) }
        highlights.removeAllLocal()
        plans.clearConfirmed()
    }
}
#endif
