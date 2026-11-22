//
//  ChapterListView.swift
//  BibleWish
//
//  The chapters of a book as a grid of square tiles in the book's section color, like the website's
//  navigator. Chapters you have read carry a small check; the one you are on is filled in.
//

import SwiftUI

struct ChapterListView: View {

    let bookIndex: Int
    /// Nil to open the reader here; in the navigator sheet, the choice is reported instead.
    var onChoose: ((Int, Int, Int?) -> Void)?

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .body) private var tileMinimum: CGFloat = 56

    init(bookIndex: Int, onChoose: ((Int, Int, Int?) -> Void)? = nil) {
        self.bookIndex = bookIndex
        self.onChoose = onChoose
    }

    /// For screens that only have the book (its position is found from its name).
    init(book: BibleBook) {
        self.init(bookIndex: BookIndex.of(name: book.name) ?? 0)
    }

    private var book: BibleBook? {
        bookIndex < viewModel.books.count ? viewModel.books[bookIndex] : nil
    }

    private var group: BookGroup? { BookGroup.group(forBook: bookIndex) }

    var body: some View {
        ScrollView {
            if let book {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 8)], spacing: 8) {
                    ForEach(Array(book.chapters.enumerated()), id: \.offset) { index, chapter in
                        tile(book: book, index: index, number: chapter.number)
                    }
                }
                .padding(16)
                .readableWidth(760)
            }
        }
        .themedScreen()
        .navigationTitle(book?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(group?.base ?? palette.gold)
                        .frame(width: 9, height: 9)
                        .shadow(color: (group?.base ?? palette.gold).opacity(0.7), radius: 5)
                    Text(book?.name ?? "")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
        }
    }

    @ViewBuilder
    private func tile(book: BibleBook, index: Int, number: Int) -> some View {
        let tint = group?.base ?? palette.gold
        let isCurrent = viewModel.lastRead?.bookIndex == bookIndex && viewModel.lastRead?.chapterNumber == number
        let isRead = viewModel.isChapterCompleted(book: book.name, chapter: number)

        // A flexible square (it takes the cell's width), with the number on top.
        let label = Color.clear
            .aspectRatio(1, contentMode: .fit)
            .background(
                ZStack {
                    palette.surface
                    if isCurrent {
                        tint.opacity(0.28)
                    } else {
                        LinearGradient(colors: [tint.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                    }
                }
            )
            .overlay {
                Text("\(number)")
                    .font(.system(.body, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(palette.ink)
            }
            .overlay(alignment: .topTrailing) {
                if isRead {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tint)
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? tint : tint.opacity(0.18), lineWidth: isCurrent ? 1.5 : 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(book.name) \(number)")
            .accessibilityValue([isCurrent ? "current" : nil, isRead ? "read" : nil].compactMap { $0 }.joined(separator: ", "))

        if let onChoose {
            Button { onChoose(bookIndex, index, nil) } label: { label }.buttonStyle(.plain)
        } else {
            NavigationLink {
                VerseListView(book: book, chapterIndex: index)
            } label: { label }
            .buttonStyle(.plain)
        }
    }
}
