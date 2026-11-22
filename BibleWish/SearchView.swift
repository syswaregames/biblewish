//
//  SearchView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct SearchView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette

    @State private var searchText: String
    @State private var searchTask: Task<Void, Never>?
    @State private var results: [SearchResult] = []

    /// `initialQuery` starts a search straight away (the navigator's "Search the Bible for…").
    init(initialQuery: String = "") {
        self._searchText = State(initialValue: initialQuery)
    }


    var body: some View {
        VStack {

            TextField("Search the Bible...", text: $searchText)
                .padding(12)
                .themedCard(cornerRadius: 10)
                .padding()
                .onChange(of: searchText) { _, newValue in
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
                    .foregroundStyle(.secondary)
                    .padding()

            } else if results.isEmpty {
                Text("No results found")
                    .foregroundStyle(.secondary)
                    .padding()

            } else {
                
                List($results, id: \.id) { $result in
                    NavigationLink {
                        if viewModel.chapterFor(
                            bookName: result.bookName,
                            chapterNumber: result.chapterNumber
                        ) != nil {
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
                                .foregroundStyle(.secondary)

                            HighlightedText(
                                text: result.verseText,
                                query: searchText
                            )
                            .lineLimit(2)
                        }
                    }
                    .themedRows()
                }
                .themedList()
            }
        }
        .themedScreen()
        .task {
            if !searchText.isEmpty { results = viewModel.search(query: searchText) }
        }
        .navigationTitle("Search")
    }
}
