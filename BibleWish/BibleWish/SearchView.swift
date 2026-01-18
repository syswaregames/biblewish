//
//  SearchView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct SearchView: View {

    @EnvironmentObject var viewModel: BibleViewModel

    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var results: [SearchResult] = []


    var body: some View {
        VStack {

            TextField("Search the Bible...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: searchText) { newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms debounce
                        let found = viewModel.search(query: newValue)
                        await MainActor.run {
                            results = found
                        }
                    }
                }

            if searchText.isEmpty {
                Text("Type a word or phrase to search")
                    .foregroundColor(.secondary)
                    .padding()

            } else if results.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .padding()

            } else {
                
                List($results, id: \.id) { $result in
                    NavigationLink {
                        if let chapter = viewModel.chapterFor(
                            bookName: result.bookName,
                            chapterNumber: result.chapterNumber
                        ) {
                            if let book = viewModel.book(named: result.bookName) {
                                VerseListView(
                                    book: book,
                                    chapterIndex: result.chapterNumber - 1,
                                    scrollToVerse: result.verseNumber
                                )
                            }

                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(result.bookName) \(result.chapterNumber):\(result.verseNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HighlightedText(
                                text: result.verseText,
                                query: searchText
                            )
                            .lineLimit(2)
                        }
                    }
                }






            }
        }
        .navigationTitle("Search")
    }
}
