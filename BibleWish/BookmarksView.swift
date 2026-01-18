//
//  BookmarksView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct BookmarksView: View {

    @EnvironmentObject var bookmarkManager: BookmarkManager

    var body: some View {
        List {
            if bookmarkManager.bookmarks.isEmpty {
                Text("No bookmarks yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(bookmarkManager.bookmarks) { bookmark in
                    NavigationLink {
                        BookmarkDetailView(bookmark: bookmark)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(bookmark.verseText)
                                .lineLimit(2)
                        }
                    }
                }
                .onDelete { indexSet in
                    bookmarkManager.delete(at: indexSet)
                }

                
            }
        }
        .navigationTitle("Bookmarks")
    }
}

#Preview {
    BookmarksView()
}
