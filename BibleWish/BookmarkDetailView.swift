//
//  BookmarkDetailView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct BookmarkDetailView: View {
    let bookmark: Bookmark

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(bookmark.reference)
                    .font(.headline)

                Text(bookmark.verseText)
            }
            .padding()
        }
        .themedScreen()
        .navigationTitle("Bookmark")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//#Preview {
    //BookmarkDetailView()
//}
