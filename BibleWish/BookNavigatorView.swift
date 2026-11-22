//
//  BookNavigatorView.swift
//
//  Choosing a book, laid out like the website's navigator: a search field that also takes a
//  reference ("John 3:16"), recent chapters, Old / New Testament tabs, colored section chips, and
//  the books of each section as tinted tiles with a colored edge. Used as the Bible tab and, from
//  the reader's title, as a sheet.
//

import SwiftUI

/// Where choosing something leads.
enum BookRoute: Hashable {
    case chapters(Int)
    case reader(book: Int, chapter: Int, verse: Int?)
    case search(String)
}

struct BookNavigatorView: View {

    /// Nil in the Bible tab, which opens screens. In a sheet the chosen chapter is reported instead:
    /// (book position, chapter position, verse).
    var onChoose: ((Int, Int, Int?) -> Void)?
    /// The first recent chapter is the one already open when this is a sheet over the reader.
    var skipCurrentRecent = false

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .body) private var tileMinimum: CGFloat = 150

    @State private var query = ""
    @State private var testament: BookGroup.Testament = .old
    @State private var openedOnReadingTestament = false
    @State private var typedRoute: BookRoute?
    @FocusState private var searchFocused: Bool

    private var books: [BibleBook] { viewModel.books }
    private var canGroup: Bool { books.count == 66 }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
    private var isSearching: Bool { !PassageReference.normalize(query).isEmpty }
    private var typedReference: PassageReference? { PassageReference.parse(query, in: books) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchField
                    if let hint = referenceHint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(palette.goldBright)
                    }

                    if !isSearching { recentChips }

                    if books.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if isSearching {
                        searchResults
                    } else if canGroup {
                        testamentTabs
                        groupChips(proxy)
                        sections
                    } else {
                        tiles(Array(books.indices))
                    }
                }
                .padding(16)
                .readableWidth(760)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationDestination(for: BookRoute.self) { destination($0) }
        .navigationDestination(item: $typedRoute) { destination($0) }
        .onAppear {
            // Open on the testament of the book being read.
            guard !openedOnReadingTestament, let last = viewModel.lastRead else { return }
            openedOnReadingTestament = true
            testament = BookGroup.testament(ofBook: last.bookIndex)
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.inkMuted)
            TextField("Find a book, or type John 3:16", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($searchFocused)
                .onSubmit(openTyped)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(palette.inkMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .themedCard(cornerRadius: 12)
    }

    private var referenceHint: String? {
        guard let reference = typedReference else { return nil }
        let verse = reference.verse.map { ":\($0)" + (reference.verseEnd.map { "-\($0)" } ?? "") } ?? ""
        guard let book = books.first(where: { $0.name == reference.bookName }),
              reference.chapterIndex < book.chapters.count else { return nil }
        return "Press Go to open \(reference.bookName) \(book.chapters[reference.chapterIndex].number)\(verse)"
    }

    @ViewBuilder
    private var searchResults: some View {
        let matches = BookSearch.matches(query, in: books.map(\.name))
        if typedReference != nil && matches.isEmpty {
            EmptyView()
        } else if matches.isEmpty {
            VStack(spacing: 10) {
                Text("No book matches that search.")
                    .font(.subheadline)
                    .foregroundStyle(palette.inkMuted)
                Button {
                    open(.search(trimmedQuery))
                } label: {
                    Label("Search the Bible for \u{201C}\(trimmedQuery)\u{201D}", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            tiles(matches)
        }
    }

    private func openTyped() {
        if let reference = typedReference,
           let book = books.firstIndex(where: { $0.name == reference.bookName }) {
            open(.reader(book: book, chapter: reference.chapterIndex, verse: reference.verse))
            return
        }
        let matches = BookSearch.matches(query, in: books.map(\.name))
        if matches.count == 1 { openBook(matches[0]) }
    }

    // MARK: - Opening

    private func openBook(_ index: Int) {
        if books[index].chapters.count == 1 {
            open(.reader(book: index, chapter: 0, verse: nil))
        } else {
            open(.chapters(index))
        }
    }

    private func open(_ route: BookRoute) {
        if let onChoose, case .reader(let book, let chapter, let verse) = route {
            onChoose(book, chapter, verse)
        } else {
            typedRoute = route
        }
    }

    @ViewBuilder
    private func destination(_ route: BookRoute) -> some View {
        switch route {
        case .chapters(let index):
            ChapterListView(bookIndex: index, onChoose: onChoose)
        case .reader(let book, let chapter, let verse):
            if book < books.count, chapter < books[book].chapters.count {
                VerseListView(book: books[book], chapterIndex: chapter, scrollToVerse: verse)
            }
        case .search(let text):
            SearchView(initialQuery: text)
        }
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentChips: some View {
        let recent = Array(viewModel.recentChapters.dropFirst(skipCurrentRecent ? 1 : 0))
            .filter { entry in entry.bookIndex < books.count && books[entry.bookIndex].chapters.contains { $0.number == entry.chapterNumber } }

        if !recent.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recent, id: \.self) { entry in
                        let tint = BookGroup.group(forBook: entry.bookIndex)?.base ?? palette.gold
                        Button {
                            let chapterIndex = books[entry.bookIndex].chapters.firstIndex { $0.number == entry.chapterNumber } ?? 0
                            open(.reader(book: entry.bookIndex, chapter: chapterIndex, verse: nil))
                        } label: {
                            Text("\(books[entry.bookIndex].name) \(entry.chapterNumber)")
                                .font(.subheadline)
                                .foregroundStyle(palette.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(Capsule().fill(palette.surface))
                                .overlay(Capsule().stroke(tint.opacity(0.4)))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(tint).frame(width: 3, height: 18).padding(.leading, 5)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .accessibilityLabel("Recently read")
        }
    }

    // MARK: - Testaments and sections

    private var testamentTabs: some View {
        HStack(spacing: 0) {
            ForEach(BookGroup.Testament.allCases, id: \.self) { option in
                let selected = testament == option
                Button {
                    testament = option
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? palette.goldBright : palette.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? palette.gold.opacity(0.18) : Color.clear)
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.goldLine))
    }

    /// Colored shortcuts that jump to each section.
    private func groupChips(_ proxy: ScrollViewProxy) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(BookGroup.groups(in: testament)) { group in
                Button {
                    withAnimation { proxy.scrollTo("group-\(group.id)", anchor: .top) }
                } label: {
                    Text(group.short)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(group.ink(in: palette))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(group.base.opacity(0.10)))
                        .overlay(Capsule().stroke(group.base.opacity(0.45)))
                }
                .accessibilityLabel("Jump to \(group.label)")
            }
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(BookGroup.groups(in: testament)) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(group.base)
                            .frame(width: 8, height: 8)
                            .shadow(color: group.base.opacity(0.7), radius: 5)
                        Text(group.label.uppercased())
                            .font(.system(size: 11.5, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(group.ink(in: palette))
                    }
                    .padding(.horizontal, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    tiles(Array(group.books))
                }
                .id("group-\(group.id)")
            }
        }
    }

    // MARK: - Tiles

    private func tiles(_ indexes: [Int]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 8)], spacing: 8) {
            ForEach(indexes, id: \.self) { index in
                tile(index)
            }
        }
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        let label = BookTileLabel(
            name: books[index].name,
            group: BookGroup.group(forBook: index),
            isCurrent: viewModel.lastRead?.bookIndex == index,
            progress: viewModel.progressForBook(books[index])
        )

        if books[index].chapters.count == 1 {
            if onChoose != nil {
                Button { openBook(index) } label: { label }.buttonStyle(.plain)
            } else {
                NavigationLink(value: BookRoute.reader(book: index, chapter: 0, verse: nil)) { label }.buttonStyle(.plain)
            }
        } else {
            NavigationLink(value: BookRoute.chapters(index)) { label }.buttonStyle(.plain)
        }
    }
}

/// A book: a tinted tile with its section's color along the left edge; the book being read glows.
struct BookTileLabel: View {

    let name: String
    let group: BookGroup?
    let isCurrent: Bool
    let progress: Double

    @Environment(\.palette) private var palette

    var body: some View {
        let tint = group?.base ?? palette.gold

        Text(name)
            .font(.subheadline)
            .foregroundStyle(palette.ink)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 14)
            .background(
                ZStack {
                    palette.surface
                    LinearGradient(colors: [tint.opacity(0.12), tint.opacity(0.03)], startPoint: .leading, endPoint: UnitPoint(x: 0.7, y: 0.5))
                }
            )
            .overlay(alignment: .leading) {
                Rectangle().fill(tint).frame(width: 3)
            }
            .overlay(alignment: .bottomLeading) {
                // A hairline of how much of the book you have read.
                if progress > 0 {
                    GeometryReader { proxy in
                        Rectangle().fill(tint.opacity(0.75)).frame(width: proxy.size.width * progress, height: 2)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? tint : tint.opacity(0.2), lineWidth: isCurrent ? 1.5 : 1))
            .shadow(color: isCurrent ? tint.opacity(0.25) : .clear, radius: 8)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name + (isCurrent ? ", the book you are reading" : ""))
            .accessibilityValue(progress > 0 ? "\(Int(progress * 100)) percent read" : "")
    }
}

/// Items in rows that wrap, like the website's section chips.
struct FlowLayout: Layout {

    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arranged = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in arranged.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, CGSize(width: widest, height: y + rowHeight))
    }
}
