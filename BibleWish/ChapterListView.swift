//
//  ChapterListView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct ChapterListView: View {

    let book: BibleBook
        
    @EnvironmentObject var viewModel: BibleViewModel
        

    // Adaptive grid: fits 4–6 columns depending on screen
    let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 12)
    ]

    var body: some View {

        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(book.chapters) { chapter in
                    NavigationLink {
                        VerseListView(
                            book: book,
                            chapterIndex: book.chapters.firstIndex(where: { $0.number == chapter.number })!,
                            scrollToVerse: 0
                            
                        )

                    } label: {
                        ChapterNumberView(
                            number: chapter.number,
                            isCompleted: viewModel.isChapterCompleted(
                                book: book.name,
                                chapter: chapter.number
                            )
                        )

                    }
                }
            }
            .padding()
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
