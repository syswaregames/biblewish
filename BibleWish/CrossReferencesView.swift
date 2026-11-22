//
//  CrossReferencesView.swift
//
//  Other passages that speak to a verse, with their text in the open translation.
//

import SwiftUI

struct CrossReferencesView: View {

    let bookIndex: Int
    let chapter: Int
    let verse: Int

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    private var references: [CrossReference] {
        CrossReferenceStore.shared.references(book: bookIndex, chapter: chapter, verse: verse)
    }

    private var title: String {
        let name = bookIndex < viewModel.books.count ? viewModel.books[bookIndex].name : ""
        return "\(name) \(chapter):\(verse)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if references.isEmpty {
                        Text("No cross-references for this verse.")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(palette.inkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(references) { reference in
                            row(reference)
                        }
                    }
                }
                .padding(16)
                .readableWidth()
            }
            .themedScreen()
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: PassageReference.self) { target in
                if let book = viewModel.book(named: target.bookName) {
                    VerseListView(book: book, chapterIndex: target.chapterIndex, scrollToVerse: target.verse)
                }
            }
        }
    }

    private func row(_ reference: CrossReference) -> some View {
        let book = reference.book < viewModel.books.count ? viewModel.books[reference.book] : nil
        let range = reference.verseStart == reference.verseEnd
            ? "\(reference.verseStart)" : "\(reference.verseStart)\u{2013}\(reference.verseEnd)"
        let label = "\(book?.name ?? "") \(reference.chapter):\(range)"

        let chapterIndex = book?.chapters.firstIndex { $0.number == reference.chapter }
        let text = book?.chapters.first { $0.number == reference.chapter }?
            .verses.filter { $0.number >= reference.verseStart && $0.number <= reference.verseEnd }
            .map(\.text).joined(separator: " ") ?? ""

        let content = VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(palette.goldBright)
            Text(text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(palette.ink)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themedCard(cornerRadius: 14)

        return Group {
            if let book, let chapterIndex {
                NavigationLink(value: PassageReference(bookName: book.name, chapterIndex: chapterIndex, verse: reference.verseStart)) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}
