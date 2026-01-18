//
//  BookListView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct BookListView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    
    
    @State private var refreshID = UUID()

    private func refreshBookList() {
        refreshID = UUID()
    }


    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var oldTestamentBooks: [BibleBook] {
        viewModel.books.filter { $0.isOldTestament }
    }

    var newTestamentBooks: [BibleBook] {
        viewModel.books.filter { !$0.isOldTestament }
    }
    
    var body: some View {
        
        let _ = viewModel.readingProgress
        
        ScrollView {
            VStack(spacing: 6) {

                Image("BibleWishLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                Text("📜 Old Testament")
                    .font(.headline)

                Text("The Law and the Prophets")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(oldTestamentBooks) { book in
                        NavigationLink {
                            ChapterListView(book: book)
                        } label: {
                            BookCardView(book: book, bookName: book.name, progress: viewModel.progressForBook(book))
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.brown.opacity(0.06))
                                )
                                .id(viewModel.readingProgress.completedChapters)
                        }
                    }
                }
                .padding(.horizontal)

                CovenantDivider()

                Text("✨ New Testament")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(newTestamentBooks) { book in
                        NavigationLink {
                            ChapterListView(book: book)
                        } label: {
                            BookCardView(book: book, bookName: book.name, progress: viewModel.progressForBook(book))
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.04))
                                )
                                .id(viewModel.readingProgress.completedChapters)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 96)
            
            VStack(spacing: 12) {
                

                Text("“The grace of the Lord Jesus be with God’s people. Amen.”")
                    .font(.footnote)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text("Revelation 22:21")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 32)
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationTitle("BibleWish")
        .navigationBarTitleDisplayMode(.inline)
        
        .id(refreshID)
        .refreshable {
            //refreshBookList()
            refreshID = UUID()
        }
        
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("BibleWish")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
                                
                            
        }
                        
    }
}
