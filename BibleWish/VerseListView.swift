//
//  VerseListView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct VerseListView: View {

    /// The open book. State, so choosing another from the navigator switches in place.
    @State private var book: BibleBook
    let scrollToVerse: Int?
    
    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var readerSettings: ReaderSettings
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @EnvironmentObject var highlightManager: HighlightManager
    @EnvironmentObject var versionStore: VersionStore
    @Environment(\.palette) private var palette

    @State private var didAutoCompleteChapter = false
    @State private var currentChapterIndex: Int
    @State private var slideDirection: CGFloat = 0
    @State private var isAnimating = false
    @State private var showPlaces = false
    @State private var showNavigator = false
    /// A verse to scroll to after the navigator changed the chapter.
    @State private var pendingVerse: Int?
    /// Focus mode: a tap on the text shows the verse numbers until the chapter changes.
    @State private var focusPeek = false
    @State private var toast: ReaderToast?
    @State private var noteReference: String?
    @State private var showCard = false
    @State private var showRelated = false
    @State private var showWords = false
    @State private var showSend = false
    /// The verse at the top of the screen, so a change of version can stay on it.
    @State private var topVerse: Int?
    /// Where the reader was when the version was changed; used once the new books arrive.
    @State private var versionCarry: (canonical: Int?, position: Int, chapter: Int, verse: Int?)?
    @ScaledMetric(relativeTo: .largeTitle) private var chapterNumberSize: CGFloat = 52
    @ScaledMetric(relativeTo: .title3) private var ornamentSize: CGFloat = 22

    init(
        book: BibleBook,
        chapterIndex: Int,
        scrollToVerse: Int? = nil
    ) {
        self._book = State(initialValue: book)
        self.scrollToVerse = scrollToVerse
        self._currentChapterIndex = State(initialValue: chapterIndex)
    }

    private var chapter: Chapter {
        book.chapters[currentChapterIndex]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    chapterHeading

                    LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(chapter.verses) { verse in
                        VerseTextView(
                            verse: verse,
                            bookName: book.name,
                            chapterNumber: chapter.number,
                            dropCap: readerSettings.bookPage && verse.number == 1,
                            isFavorite: favoriteVerses.contains(verse.number),
                            onTap: { tapVerse(verse.number) },
                            onLongPress: { extendSelection(to: verse.number) },
                            focusPeek: focusPeek
                        )
                        .id(verse.number)
                        
                        .onAppear {
                            if verse.number == chapter.verses.last?.number {
                                autoCompleteChapterIfNeeded()
                            }
                        }
                    }
                    }
                    .scrollTargetLayout()

                    if !omittedVerses.isEmpty && (!readerSettings.focusMode || focusPeek) {
                        omittedFootnote
                    }

                    if readerSettings.bookPage {
                        Text("\u{2766}\u{FE0E}")
                            .font(.system(size: ornamentSize, design: .serif))
                            .accessibilityHidden(true)
                            .foregroundStyle(palette.gold)
                            .padding(.top, 20)
                    }
                }
                .padding(readerSettings.bookPage ? 20 : 0)
                .background(readerSettings.bookPage ? palette.surface : Color.clear)
                .overlay(pageFrame)
                .padding(.horizontal, readerSettings.bookPage ? 10 : 12)
                .padding(.vertical, readerSettings.bookPage ? 12 : 0)
                .padding(.top, 8)
                .readableWidth(720)
                
                .opacity(isAnimating ? 0 : 1)
                .offset(x: isAnimating ? slideDirection * 12 : 0)
                
                .animation(.easeInOut(duration: 0.3), value: isAnimating)

                
                .id(currentChapterIndex)
            }
            .scrollPosition(id: $topVerse, anchor: .top)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded(handleSwipe)
            )
            .onChange(of: viewModel.booksRevision) { restoreAfterVersionChange() }
            .onChange(of: pendingVerse) {
                guard let verse = pendingVerse else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { proxy.scrollTo(verse, anchor: .top) }
                pendingVerse = nil
            }
            .onAppear {
                scrollIfNeeded(proxy)
                viewModel.recordLastRead(bookName: book.name, chapterNumber: chapter.number)
            }
            
            
            .onChange(of: readerSettings.focusMode) {
                focusPeek = false
            }

            .onChange(of: currentChapterIndex) {
                didAutoCompleteChapter = false
                focusPeek = false
                viewModel.recordLastRead(bookName: book.name, chapterNumber: chapter.number)
            }

        }
        .themedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !selection.isEmpty {
                VerseSelectionBar(
                    label: selectionLabel,
                    shareText: shareText,
                    allSaved: allSelectionSaved,
                    hasPlaces: !placesInChapter.isEmpty,
                    hasCanonicalBook: canonicalBook != nil,
                    onColor: { setPenColor($0) },
                    onSave: saveOrUnsave,
                    onNote: { noteReference = selectionLabel },
                    onImage: { showCard = true },
                    onSend: { showSend = true },
                    onWords: { showWords = true },
                    onRelated: { showRelated = true },
                    onPlaces: { showPlaces = true },
                    onCopy: copySelection,
                    onClear: clearSelection
                )
                .padding(.top, 8)
                .background(palette.pageBottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selection)
        .overlay(alignment: .top) {
            if let toast {
                ReaderToastView(toast: toast) { self.toast = nil }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: toast)
        .sheet(isPresented: Binding(get: { noteReference != nil }, set: { if !$0 { noteReference = nil } })) {
            NoteEditorView(reference: noteReference ?? "")
        }
        .sheet(isPresented: $showCard) {
            VerseCardView(
                text: VerseSelection.plainText(chapter.verses, selected: selection),
                reference: selectionLabel,
                translation: translationId.uppercased()
            )
        }
        .sheet(isPresented: $showWords) {
            if let canonicalBook {
                OriginalWordsView(bookIndex: canonicalBook, chapter: chapter.number, verses: selection, reference: selectionLabel)
            }
        }
        .sheet(isPresented: $showSend) {
            if let canonicalBook, let range = SendVerse.range(of: selection) {
                SendVerseView(
                    translation: translationId,
                    bookIndex: canonicalBook,
                    chapter: chapter.number,
                    range: range,
                    reference: SendVerse.reference(chapter: "\(book.name) \(chapter.number)", range: range),
                    text: VerseSelection.plainText(chapter.verses.filter { range.contains($0.number) }, selected: Array(range))
                )
            }
        }
        .sheet(isPresented: $showRelated) {
            CrossReferencesView(bookIndex: bookIndex, chapter: chapter.number, verse: selection.first ?? 1)
        }
        .sheet(isPresented: $showPlaces) {
            ChapterPlacesView(bookName: book.name, chapter: chapter.number, mentions: placesInChapter)
        }
        .sheet(isPresented: $showNavigator) {
            NavigationStack {
                BookNavigatorView(onChoose: goTo, skipCurrentRecent: true)
                    .themedScreen()
                    .navigationTitle("Books")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showNavigator = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .navigationBarTitleDisplayMode(.inline)
        
        
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showNavigator = true
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(BookGroup.group(forBook: bookPosition)?.base ?? palette.gold)
                            .frame(width: 8, height: 8)
                            .shadow(color: (BookGroup.group(forBook: bookPosition)?.base ?? palette.gold).opacity(0.7), radius: 4)
                        Text("\(book.name) \(chapter.number)")
                            .font(.headline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.inkMuted)
                    }
                }
                .accessibilityLabel("\(book.name) \(chapter.number). Choose book and chapter")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                versionMenu
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if !placesInChapter.isEmpty {
                    Button {
                        showPlaces = true
                    } label: {
                        Image(systemName: "map")
                    }
                    .accessibilityLabel("Places in this chapter")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    readerSettings.focusMode.toggle()
                } label: {
                    Image(systemName: readerSettings.focusMode ? "eye.fill" : "eye")
                }
                .accessibilityLabel(readerSettings.focusMode ? "Turn focus mode off" : "Turn focus mode on")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleChapterCompleted()
                } label: {
                    Image(systemName: isChapterCompleted
                          ? "checkmark.seal.fill"
                          : "circle")
                }
                .accessibilityLabel(
                    isChapterCompleted
                    ? "Mark chapter as unread"
                    : "Mark chapter as read"
                )
            }
        }


    }
    
    // MARK: - Changing the Bible version

    /// A small pill with the open version; its menu lists the versions to switch to.
    private var versionMenu: some View {
        Menu {
            ForEach(versionStore.languages) { language in
                Section(language.nativeName) {
                    ForEach(versionStore.versionsByLanguage[language.code] ?? []) { version in
                        Button {
                            switchVersion(to: version)
                        } label: {
                            if version.id == versionStore.selectedVersionID {
                                Label(version.name, systemImage: "checkmark")
                            } else {
                                Text(version.name)
                            }
                        }
                    }
                }
            }
        } label: {
            Text(translationId.uppercased())
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.gold.opacity(0.7)))
        }
        .accessibilityLabel("Bible version \(versionStore.selectedVersion?.name ?? translationId.uppercased()). Change version")
    }

    private func switchVersion(to version: BibleVersion) {
        guard version.id != versionStore.selectedVersionID else { return }
        versionCarry = (
            canonical: BookIndex.of(name: book.name),
            position: bookPosition,
            chapter: chapter.number,
            verse: (topVerse ?? 1) > 1 ? topVerse : nil
        )
        versionStore.setSelected(languageCode: version.languageCode, versionID: version.id)
        UISelectionFeedbackGenerator().selectionChanged()
        show(version.name)
    }

    /// The new translation's books have loaded: open the same book, chapter and verse in them. Books
    /// are matched by their place in the 66-book order (Hebrew lists them differently).
    private func restoreAfterVersionChange() {
        guard let carry = versionCarry else { return }
        versionCarry = nil
        guard let place = ReaderPosition.locate(canonical: carry.canonical, position: carry.position, chapter: carry.chapter, in: viewModel.books) else { return }
        goTo(book: place.book, chapter: place.chapter, verse: carry.verse)
    }

    // MARK: - Verses Biblia Livre leaves out

    private var omittedVerses: [Int] { chapter.verses.filter { $0.omitted == true }.map(\.number) }

    /// The website's footnote, in Portuguese like the text it explains.
    private var omittedFootnote: some View {
        let numbers = omittedVerses
        let many = numbers.count > 1
        return Text("* \(many ? "vv." : "v.") \(numbers.map(String.init).joined(separator: ", ")): \(many ? "estes vers\u{00ED}culos n\u{00E3}o aparecem" : "este vers\u{00ED}culo n\u{00E3}o aparece") nos manuscritos mais antigos, por isso a B\u{00ED}blia Livre \(many ? "os omite" : "o omite"). Tradu\u{00E7}\u{00E3}o do BibleWish.")
            .font(.footnote.italic())
            .foregroundStyle(palette.inkSoft)
            .environment(\.locale, Locale(identifier: "pt"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .overlay(alignment: .top) { Rectangle().fill(palette.goldLine).frame(height: 1) }
            .padding(.top, 20)
    }

    // MARK: - Selecting verses
    //
    // As on the website, a selected verse is a highlighted one: tap to select, tap again to
    // deselect; the bar at the bottom acts on the selection.

    private var translationId: String { viewModel.selectedTranslation.widgetId }
    private var bookIndex: Int { viewModel.books.firstIndex { $0.name == book.name } ?? -1 }

    /// The book's place in the 66-book order, which the word study and Send are keyed by.
    private var canonicalBook: Int? { BookIndex.of(name: book.name) }

    private var selection: [Int] {
        highlightManager.selected(translation: translationId, bookIndex: bookIndex, chapter: chapter.number)
    }

    private var selectionLabel: String {
        VerseSelection.label(chapter: "\(book.name) \(chapter.number)", verses: selection)
    }

    private var shareText: String {
        VerseSelection.shareText(
            label: selectionLabel,
            translation: translationId.uppercased(),
            text: VerseSelection.numberedText(chapter.verses, selected: selection),
            link: VerseSelection.link(forLabel: selectionLabel)
        )
    }

    private var favoriteVerses: Set<Int> {
        bookmarkManager.favoriteVerses(bookName: book.name, chapter: chapter.number)
    }

    private var allSelectionSaved: Bool {
        !selection.isEmpty && favoriteVerses.isSuperset(of: selection)
    }

    private func show(_ message: String, undoTitle: String? = nil, undo: (() -> Void)? = nil) {
        let item = ReaderToast(message: message, undoTitle: undoTitle, undo: undo)
        toast = item
        Task {
            try? await Task.sleep(nanoseconds: undo == nil ? 2_500_000_000 : 6_000_000_000)
            if toast == item { toast = nil }
        }
    }

    private func tapVerse(_ number: Int) {
        if readerSettings.focusMode && !focusPeek {
            withAnimation(.easeInOut(duration: 0.2)) { focusPeek = true }
            return
        }
        select(number)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func select(_ number: Int) {
        highlightManager.toggle(translation: translationId, bookIndex: bookIndex, bookName: book.name, chapter: chapter.number, verse: number, color: readerSettings.highlightColor)
    }

    /// Long press: select every verse from the nearest selected one to this one.
    private func extendSelection(to number: Int) {
        let current = selection
        let anchor = current.min { abs($0 - number) < abs($1 - number) } ?? number
        for verse in min(anchor, number)...max(anchor, number) where !current.contains(verse) {
            select(verse)
        }
    }

    private func setPenColor(_ color: HighlightColor) {
        readerSettings.highlightColor = color
        highlightManager.setColor(color, translation: translationId, bookIndex: bookIndex, bookName: book.name, chapter: chapter.number, verses: selection)
    }

    private func clearSelection() {
        let removed = highlightManager.clear(translation: translationId, bookIndex: bookIndex, chapter: chapter.number)
        let (translation, index, number) = (translationId, bookIndex, chapter.number)
        show("Selection cleared") {
            highlightManager.restore(removed, translation: translation, bookIndex: index, chapter: number)
        }
    }

    private func copySelection() {
        UIPasteboard.general.string = shareText
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        show("Copied")
    }

    /// One favorite per run of verses; saving again removes them (the heart shows which).
    private func saveOrUnsave() {
        let runs = VerseSelection.runs(selection)
        if allSelectionSaved {
            bookmarkManager.remove(runs: runs, bookName: book.name, chapter: chapter.number)
            show("Removed from your favorites")
            return
        }
        let texts = runs.map { run in
            (range: run, text: run.count == 1
                ? VerseSelection.plainText(chapter.verses, selected: Array(run))
                : VerseSelection.numberedText(chapter.verses, selected: Array(run)))
        }
        let result = bookmarkManager.save(runs: texts, bookName: book.name, chapter: chapter.number, translation: translationId)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        show(result.added > 0 ? "Saved to your favorites \u{2661}" : "Already in your favorites")
    }

    // MARK: - Choosing another chapter

    private var bookPosition: Int {
        viewModel.books.firstIndex { $0.name == book.name } ?? -1
    }

    /// The navigator chose a chapter: show it here, in place.
    private func goTo(book bookIndex: Int, chapter chapterIndex: Int, verse: Int?) {
        guard bookIndex < viewModel.books.count, chapterIndex < viewModel.books[bookIndex].chapters.count else { return }
        showNavigator = false
        book = viewModel.books[bookIndex]
        currentChapterIndex = chapterIndex
        didAutoCompleteChapter = false
        focusPeek = false
        pendingVerse = verse
    }

    // MARK: - Places

    private var placesInChapter: [PlaceMention] {
        guard let index = viewModel.books.firstIndex(where: { $0.name == book.name }) else { return [] }
        return PlacesStore.shared.places(book: index, chapter: chapter.number)
    }

    // MARK: - Book page

    /// Book name, big chapter number, reading time and an ornamental divider.
    @ViewBuilder
    private var chapterHeading: some View {
        if readerSettings.bookPage {
            VStack(spacing: 6) {
                Text(book.name.uppercased())
                    .font(.system(.caption, design: .serif, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(palette.gold)

                Text("\(chapter.number)")
                    .font(.system(size: chapterNumberSize, weight: .regular, design: .serif))
                    .foregroundStyle(palette.goldBright)

                if !readerSettings.focusMode || focusPeek {
                    Text("~\(readingMinutes) min read")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(palette.inkMuted)
                }

                HStack(spacing: 8) {
                    Rectangle().fill(palette.goldLine).frame(height: 1)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(palette.gold)
                        .accessibilityHidden(true)
                    Rectangle().fill(palette.goldLine).frame(height: 1)
                }
                .padding(.vertical, 12)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        } else if !readerSettings.focusMode || focusPeek {
            Text("~\(readingMinutes) min read")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
        }
    }

    /// A double gold border, as on the website's book page.
    @ViewBuilder
    private var pageFrame: some View {
        if readerSettings.bookPage {
            ZStack {
                RoundedRectangle(cornerRadius: 14).stroke(palette.gold.opacity(0.55), lineWidth: 1)
                RoundedRectangle(cornerRadius: 10).stroke(palette.goldLine, lineWidth: 1).padding(5)
            }
            .allowsHitTesting(false)
        }
    }

    /// Reading time at 200 words a minute, never less than one.
    private var readingMinutes: Int {
        let words = chapter.verses.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        return max(1, Int((Double(words) / 200).rounded()))
    }

    private func autoCompleteChapterIfNeeded() {
        // Prevent repeated execution in the same lifecycle
        guard !didAutoCompleteChapter else { return }

        // Only mark if NOT already completed
        guard !viewModel.isChapterCompleted(
            book: book.name,
            chapter: chapter.number
        ) else {
            didAutoCompleteChapter = true
            return
        }

        didAutoCompleteChapter = true

        viewModel.toggleChapterCompleted(
            book: book.name,
            chapter: chapter.number
        )

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }


    
    private var chapterKey: String {
        "\(book.name)-\(chapter.number)"
    }

    private var isChapterCompleted: Bool {
        viewModel.isChapterCompleted(
            book: book.name,
            chapter: chapter.number
        )
    }

    private func toggleChapterCompleted() {
        viewModel.toggleChapterCompleted(
            book: book.name,
            chapter: chapter.number
        )
    }



    // MARK: - Swipe Handling

    private func handleSwipe(_ value: DragGesture.Value) {
        guard !isAnimating else { return }

        let horizontal = value.translation.width
        let vertical = value.translation.height

        guard abs(horizontal) > abs(vertical) else { return }

        if horizontal < -60 {
            goToNextChapter()
        } else if horizontal > 60 {
            goToPreviousChapter()
        }
    }

    private func goToNextChapter() {
        guard currentChapterIndex + 1 < book.chapters.count else { return }

        slideDirection = -1
        changeChapter(to: currentChapterIndex + 1)
    }

    private func goToPreviousChapter() {
        guard currentChapterIndex - 1 >= 0 else { return }

        slideDirection = 1
        changeChapter(to: currentChapterIndex - 1)
    }

    private func changeChapter(to index: Int) {
        isAnimating = true

        // Phase 1 — fade out
        withAnimation(.easeOut(duration: 0.12)) {
            // opacity handled by state
        }

        // Phase 2 — swap content at peak fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            currentChapterIndex = index
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Phase 3 — fade in
            withAnimation(.easeIn(duration: 0.18)) {
                isAnimating = false
            }
        }
    }


    // MARK: - Scroll Logic

    private func scrollIfNeeded(_ proxy: ScrollViewProxy) {
        guard let verse = scrollToVerse else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            proxy.scrollTo(verse, anchor: .top)
        }
    }
    
    private func markChapterCompletedIfNeeded() {
        viewModel.toggleChapterCompleted(
            book: book.name,
            chapter: chapter.number
        )
    }

}

