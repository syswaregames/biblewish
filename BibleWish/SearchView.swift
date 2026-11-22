//
//  SearchView.swift
//  BibleWish
//
//  Search like the website's search sheet: a field that also takes a reference ("John 3:16"),
//  recent searches, a count of verses and books, a colored filter chip per book, results with the
//  matched words marked, and "More verses". The search itself is BibleSearch.swift.
//

import SwiftUI

// MARK: - Model

@MainActor
final class SearchModel: ObservableObject {

    enum Phase: Equatable { case idle, preparing, searching, done }

    static let pageSize = 30
    static let suggestions = ["love", "faith", "\"bread of life\"", "shepherd", "peace", "grace"]
    private static let recentKey = "recent_searches_v1"

    @Published var query: String
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var terms: [String] = []
    @Published private(set) var total = 0
    @Published private(set) var bookCounts: [(book: Int, count: Int)] = []
    @Published private(set) var matches: [Int32] = []
    @Published var bookFilter: Int? { didSet { applyFilter() } }
    @Published private(set) var visible = SearchModel.pageSize
    @Published private(set) var recent: [String]

    private(set) var index: SearchIndex?
    private var all: [Int32] = []
    private var task: Task<Void, Never>?
    private var generation = 0

    init(query: String) {
        self.query = query
        self.recent = UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? []
    }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasQuery: Bool { trimmedQuery.count >= 2 }
    var shown: ArraySlice<Int32> { matches.prefix(visible) }
    var hasMore: Bool { visible < matches.count }

    /// Runs the search for the current text. Typing waits a moment so a word is searched once, not
    /// once per letter; Search (the keyboard key) and the chips don't wait.
    func run(books: [BibleBook], translation: String, isHebrew: Bool, immediately: Bool = false) {
        task?.cancel()
        generation += 1
        let mine = generation
        guard hasQuery else {
            terms = []; all = []; matches = []; total = 0; bookCounts = []; bookFilter = nil
            phase = .idle
            return
        }
        guard !books.isEmpty else { phase = .preparing; return }
        let text = trimmedQuery
        let hadResults = phase == .done
        if !hadResults { phase = index == nil ? .preparing : .searching }

        task = Task { [weak self] in
            if !immediately { try? await Task.sleep(nanoseconds: 250_000_000) }
            guard !Task.isCancelled else { return }
            let index = await SearchEngine.shared.index(key: translation, books: books, isHebrew: isHebrew)
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .userInitiated) { () -> ([String], SearchOutcome) in
                let terms = SearchText.terms(text)
                return (terms, index.search(terms))
            }.value
            guard !Task.isCancelled, let self, self.generation == mine else { return }
            self.index = index
            self.terms = found.0
            self.all = found.1.ids
            self.total = found.1.ids.count
            self.bookCounts = found.1.bookCounts
            if let filter = self.bookFilter, !found.1.bookCounts.contains(where: { $0.book == filter }) { self.bookFilter = nil }
            self.applyFilter()
            self.phase = .done
        }
    }

    func showMore() { visible += Self.pageSize }

    private func applyFilter() {
        visible = Self.pageSize
        guard let index, let filter = bookFilter else { matches = all; return }
        matches = all.filter { index.location(of: $0).book == filter }
    }

    func remember() {
        let text = trimmedQuery
        guard text.count >= 2 else { return }
        recent = Array(([text] + recent.filter { $0.lowercased() != text.lowercased() }).prefix(6))
        UserDefaults.standard.set(recent, forKey: Self.recentKey)
    }
}

// MARK: - View

struct SearchView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette
    @StateObject private var model: SearchModel
    @FocusState private var focused: Bool
    @State private var route: BookRoute?
    @State private var scrollTick = 0

    /// `initialQuery` starts a search straight away (the navigator's "Search the Bible for…").
    init(initialQuery: String = "") {
        _model = StateObject(wrappedValue: SearchModel(query: initialQuery))
    }

    private var books: [BibleBook] { viewModel.books }
    private var translationKey: String { viewModel.selectedTranslation.widgetId }
    private var isHebrew: Bool { viewModel.selectedTranslation == .heb }
    private var translationName: String { translationKey.uppercased() }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    field.id("top")
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .readableWidth(720)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollTick) { proxy.scrollTo("top", anchor: .top) }
        }
        .themedScreen()
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { destination($0) }
        .task(id: "\(translationKey)-\(books.count)") {
            model.run(books: books, translation: translationKey, isHebrew: isHebrew, immediately: true)
            if model.trimmedQuery.isEmpty { focused = true }
        }
        .onChange(of: model.query) {
            model.run(books: books, translation: translationKey, isHebrew: isHebrew)
        }
        .onChange(of: model.phase) { if model.phase == .done { scrollTick += 1 } }
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.inkMuted)
            TextField("Search words, or type John 3:16", text: $model.query)
                .focused($focused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(submit)
            if model.phase == .searching || model.phase == .preparing {
                ProgressView().controlSize(.small)
            }
            if !model.query.isEmpty {
                Button { model.query = ""; focused = true } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(palette.inkMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .themedCard(cornerRadius: 12)
    }

    private func submit() {
        if let reference = typedReference, let book = books.firstIndex(where: { $0.name == reference.bookName }) {
            model.remember()
            route = .reader(book: book, chapter: reference.chapterIndex, verse: reference.verse)
            return
        }
        guard model.hasQuery else { return }
        focused = false
        model.remember()
        model.run(books: books, translation: translationKey, isHebrew: isHebrew, immediately: true)
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if !model.hasQuery {
            start
        } else {
            openCard
            switch model.phase {
            case .preparing:
                status("Preparing search\u{2026}")
            case .idle, .searching, .done:
                if model.phase == .done || !model.matches.isEmpty { results } else { status("Searching\u{2026}") }
            }
        }
    }

    private func status(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(palette.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
    }

    /// Before typing: how it works, and recent searches or a few to try.
    private var start: some View {
        VStack(alignment: .leading, spacing: 14) {
            (Text("Find any word in the \(translationName). Use ")
             + Text("\"quotes\"").font(.footnote.monospaced())
             + Text(" for a phrase and ")
             + Text("love*").font(.footnote.monospaced())
             + Text(" for word starts."))
                .font(.footnote)
                .foregroundStyle(palette.inkMuted)

            Text(model.recent.isEmpty ? "TRY" : "RECENT")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(palette.gold)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: 8) {
                ForEach(model.recent.isEmpty ? SearchModel.suggestions : model.recent, id: \.self) { text in
                    Button {
                        model.query = text
                        focused = false
                        model.run(books: books, translation: translationKey, isHebrew: isHebrew, immediately: true)
                    } label: {
                        Text(text)
                            .font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(palette.surface))
                            .overlay(Capsule().stroke(palette.goldLine))
                            .foregroundStyle(palette.ink)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: Typed reference

    private var typedReference: PassageReference? { PassageReference.parse(model.trimmedQuery, in: books) }

    /// "John 3:16" or a book name on its own: offer to open it.
    @ViewBuilder private var openCard: some View {
        if let reference = typedReference, let book = books.firstIndex(where: { $0.name == reference.bookName }) {
            let chapter = books[book].chapters[reference.chapterIndex].number
            let verse = reference.verse.map { ":\($0)" + (reference.verseEnd.map { "-\($0)" } ?? "") } ?? ""
            openButton(book: book, title: "\(reference.bookName) \(chapter)\(verse)") {
                route = .reader(book: book, chapter: reference.chapterIndex, verse: reference.verse)
            }
        } else if SearchText.terms(model.trimmedQuery).count == 1, PassageReference.normalize(model.trimmedQuery).count >= 3,
                  let book = BookSearch.matches(model.trimmedQuery, in: books.map(\.name)).first {
            openButton(book: book, title: books[book].name) {
                route = books[book].chapters.count == 1 ? .reader(book: book, chapter: 0, verse: nil) : .chapters(book)
            }
        }
    }

    private func openButton(book: Int, title: String, action: @escaping () -> Void) -> some View {
        let group = BookGroup.group(forBook: book)
        return Button {
            model.remember()
            action()
        } label: {
            HStack {
                Image(systemName: "book").foregroundStyle(group?.ink(in: palette) ?? palette.gold)
                Text(title).font(.system(.headline, design: .serif)).foregroundStyle(palette.ink)
                Spacer()
                Text("Open \u{203A}").font(.subheadline.weight(.semibold)).foregroundStyle(group?.ink(in: palette) ?? palette.gold)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill((group?.base ?? palette.gold).opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke((group?.base ?? palette.gold).opacity(0.5)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(title)")
    }

    @ViewBuilder private func destination(_ route: BookRoute) -> some View {
        switch route {
        case .chapters(let index):
            ChapterListView(bookIndex: index, onChoose: nil)
        case .reader(let book, let chapter, let verse):
            if book < books.count, chapter < books[book].chapters.count {
                VerseListView(book: books[book], chapterIndex: chapter, scrollToVerse: verse)
            }
        case .search(let text):
            SearchView(initialQuery: text)
        }
    }

    // MARK: Results

    @ViewBuilder private var results: some View {
        if model.total == 0 {
            if typedReference == nil {
                VStack(spacing: 6) {
                    Text("No verses found for \u{201C}\(model.trimmedQuery)\u{201D} in the \(translationName).")
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSoft)
                        .multilineTextAlignment(.center)
                    Text("Every word must appear. Try fewer words, or a word start like love*.")
                        .font(.footnote)
                        .foregroundStyle(palette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        } else {
            summary
            if model.bookCounts.count > 1 { filterChips }
            ForEach(Array(model.shown), id: \.self) { id in resultRow(id) }
            if model.hasMore {
                Button { model.showMore() } label: {
                    Text("More verses")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.goldLine))
                        .foregroundStyle(palette.gold)
                }
            }
        }
    }

    private var summary: some View {
        let inBooks = model.bookCounts.count
        var text = Text("\(model.total.formatted()) verse\(model.total == 1 ? "" : "s")").bold()
            + Text(" in \(inBooks) book\(inBooks == 1 ? "" : "s")")
        if let filter = model.bookFilter, filter < books.count {
            text = text + Text(" \u{00B7} \(model.matches.count.formatted()) in \(books[filter].name)")
        }
        return text
            .font(.subheadline)
            .foregroundStyle(palette.inkSoft)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", count: model.total, color: palette.gold, selected: model.bookFilter == nil) { model.bookFilter = nil }
                ForEach(model.bookCounts, id: \.book) { entry in
                    if entry.book < books.count {
                        let group = BookGroup.group(forBook: entry.book)
                        chip(books[entry.book].name, count: entry.count, color: group?.ink(in: palette) ?? palette.gold, selected: model.bookFilter == entry.book) {
                            model.bookFilter = model.bookFilter == entry.book ? nil : entry.book
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ title: String, count: Int, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.footnote.weight(.semibold))
                Text(count.formatted()).font(.caption2).opacity(0.8)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(selected ? color.opacity(0.22) : palette.surface))
            .overlay(Capsule().stroke(selected ? color : palette.goldLine, lineWidth: selected ? 1.5 : 1))
            .foregroundStyle(selected ? color : palette.ink)
        }
        .accessibilityLabel("\(title), \(count) verses")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private func resultRow(_ id: Int32) -> some View {
        if let index = model.index {
            let hit = index.verse(of: id)
            let group = BookGroup.group(forBook: hit.location.book)
            let ink = group?.ink(in: palette) ?? palette.gold
            NavigationLink {
                VerseListView(book: books[hit.location.book], chapterIndex: hit.location.chapter, scrollToVerse: hit.verse.number)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(hit.bookName) \(hit.chapterNumber):\(hit.verse.number)")
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(ink)
                    Text(SearchHighlight.attributed(hit.verse.text, terms: model.terms, isHebrew: index.isHebrew, color: palette.goldBright))
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(palette.ink)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 12)
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill((group?.base ?? palette.gold).opacity(0.06)))
                .overlay(alignment: .leading) {
                    Capsule().fill(group?.base ?? palette.gold).frame(width: 3).padding(.vertical, 8).padding(.leading, 4)
                }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.goldLine))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { model.remember() })
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(hit.bookName) \(hit.chapterNumber):\(hit.verse.number). \(hit.verse.text)")
        }
    }
}
