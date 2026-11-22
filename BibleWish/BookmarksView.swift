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
                    .foregroundStyle(.secondary)
                    .themedRows()
            } else {
                ForEach(bookmarkManager.bookmarks) { bookmark in
                    NavigationLink {
                        BookmarkDetailView(bookmark: bookmark)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bookmark.reference)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(bookmark.verseText)
                                .lineLimit(2)
                        }
                    }
                    .themedRows()
                }
                .onDelete { indexSet in
                    bookmarkManager.delete(at: indexSet)
                }

                
            }
        }
        .themedList()
    }
}

#Preview {
    BookmarksView()
}
