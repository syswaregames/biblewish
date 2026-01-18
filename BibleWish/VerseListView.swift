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

    @State private var didAutoCompleteChapter = false
    @State private var currentChapterIndex: Int
    @State private var slideDirection: CGFloat = 0
    @State private var isAnimating = false

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
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(chapter.verses) { verse in
                        VerseTextView(
                            verse: verse,
                            bookName: book.name,
                            chapterNumber: chapter.number
                        )
                        .id(verse.number)
                        
                        .onAppear {
                            if verse.number == chapter.verses.last?.number {
                                autoCompleteChapterIfNeeded()
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
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
            }
            
            
            .onChange(of: currentChapterIndex) { _ in
                didAutoCompleteChapter = false
            }

        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .navigationBarTitleDisplayMode(.inline)
        
        
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleChapterCompleted()
                } label: {
                    Image(systemName: isChapterCompleted
                          ? "bookmark.fill"
                          : "bookmark")
                }
                .accessibilityLabel(
                    isChapterCompleted
                    ? "Mark chapter as unread"
                    : "Mark chapter as read"
                )
            }
        }


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

