//
//  VerseListView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct VerseListView: View {

    let book: BibleBook
    let scrollToVerse: Int?
    
    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var readerSettings: ReaderSettings
    @Environment(\.palette) private var palette

    @State private var didAutoCompleteChapter = false
    @State private var currentChapterIndex: Int
    @State private var slideDirection: CGFloat = 0
    @State private var isAnimating = false
    @State private var showPlaces = false
    /// Focus mode: a tap on the text shows the verse numbers until the chapter changes.
    @State private var focusPeek = false
    @ScaledMetric(relativeTo: .largeTitle) private var chapterNumberSize: CGFloat = 52
    @ScaledMetric(relativeTo: .title3) private var ornamentSize: CGFloat = 22

    init(
        book: BibleBook,
        chapterIndex: Int,
        scrollToVerse: Int? = nil
    ) {
        self.book = book
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
                            focusPeek: focusPeek,
                            onFocusTap: { withAnimation(.easeInOut(duration: 0.2)) { focusPeek = true } }
                        )
                        .id(verse.number)
                        
                        .onAppear {
                            if verse.number == chapter.verses.last?.number {
                                autoCompleteChapterIfNeeded()
                            }
                        }
                    }
                    }

                    if readerSettings.bookPage {
                        Text("\u{2766}")
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded(handleSwipe)
            )
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
        .sheet(isPresented: $showPlaces) {
            ChapterPlacesView(bookName: book.name, chapter: chapter.number, mentions: placesInChapter)
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .navigationBarTitleDisplayMode(.inline)
        
        
        .toolbar {
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

