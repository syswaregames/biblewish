//
//  VerseDetailView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct VerseDetailView: View {

    let result: SearchResult
    @EnvironmentObject var bookmarkManager: BookmarkManager

    var bookmark: Bookmark {
        Bookmark(
            bookName: result.bookName,
            chapterNumber: result.chapterNumber,
            verseNumber: result.verseNumber,
            verseText: result.verseText
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                HStack {
                    Text("\(result.bookName) \(result.chapterNumber):\(result.verseNumber)")
                        .font(.headline)

                    Spacer()

                    Button {
                        bookmarkManager.toggle(bookmark)
                    } label: {
                        Image(systemName:
                            bookmarkManager.isBookmarked(bookmark)
                            ? "star.fill"
                            : "star"
                        )
                    }
                }

                Text(result.verseText)
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle("Verse")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//#Preview {
    //result VerseDetailView()
//}
