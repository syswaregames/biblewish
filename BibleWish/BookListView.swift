//
//  BookListView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct BookListView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var versionStore: VersionStore
    
    @State private var refreshID = UUID()
    @State private var showingLibrary = false

    private func refreshBookList() {
        refreshID = UUID()
    }


    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var oldTestamentBooks: [BibleBook] {
        Array(viewModel.books.prefix(39))
    }

    var newTestamentBooks: [BibleBook] {
        Array(viewModel.books.dropFirst(39))
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
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Language picker
                    Picker("Language", selection: $versionStore.selectedLanguageCode) {
                        ForEach(versionStore.languages) { lang in
                            Text(lang.nativeName).tag(lang.code)
                        }
                    }

                    // Version picker for the selected language
                    Picker("Version", selection: $versionStore.selectedVersionID) {
                        ForEach(versionStore.versionsByLanguage[versionStore.selectedLanguageCode] ?? []) { version in
                            Label(version.name, systemImage: version.isDownloaded ? "checkmark.circle.fill" : "icloud.and.arrow.down")
                                .tag(version.id)
                        }
                    }

                    Divider()
                    Button("Manage versions…") { showingLibrary = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.book.closed")
                        VStack(alignment: .leading, spacing: 0) {
                            Text(versionStore.selectedVersion?.name ?? "Version")
                                .font(.subheadline)
                            Text(versionStore.languages.first(where: { $0.code == versionStore.selectedLanguageCode })?.nativeName ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
                                
                            
        }
        .sheet(isPresented: $showingLibrary) {
            VersionLibraryView()
                .environmentObject(versionStore)
        }
                        
    }
}

