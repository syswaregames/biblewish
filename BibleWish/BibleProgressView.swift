//
//  BibleProgressView.swift
//
//  How much of each book you have read, Old Testament and New Testament.
//

import SwiftUI

/// Chapters read, counted once whatever translation they were read in.
enum BibleProgress {

    static func readChapters(in viewModel: BibleViewModel) -> Set<ChapterRef> {
        AchievementMetrics.chapterRefs(fromKeys: viewModel.readingProgress.completedChapters)
    }

    static func totalChapters(in viewModel: BibleViewModel) -> Int {
        viewModel.books.reduce(0) { $0 + $1.chapters.count }
    }
}

/// The overall bar on the Plans screen, linking to the per-book view.
struct BibleProgressCard: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette

    var body: some View {
        let read = BibleProgress.readChapters(in: viewModel).count
        let total = BibleProgress.totalChapters(in: viewModel)

        NavigationLink {
            BibleProgressView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your Bible progress")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(palette.gold)
                }
                ProgressView(value: total == 0 ? 0 : Double(read) / Double(total))
                    .tint(palette.gold)
                Text("\(read) of \(total) chapters read \u{00B7} see every book")
                    .font(.caption)
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

struct BibleProgressView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette

    var body: some View {
        let read = BibleProgress.readChapters(in: viewModel)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                section("Old Testament", range: 0..<39, read: read)
                section("New Testament", range: 39..<66, read: read)
            }
            .padding(16)
        }
        .themedScreen()
        .navigationTitle("Bible Progress")
    }

    @ViewBuilder
    private func section(_ title: String, range: Range<Int>, read: Set<ChapterRef>) -> some View {
        Text(title.uppercased())
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(palette.gold)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, range.lowerBound == 0 ? 0 : 14)

        ForEach(range.filter { $0 < viewModel.books.count }, id: \.self) { index in
            let book = viewModel.books[index]
            let done = read.filter { $0.book == index }.count
            let total = book.chapters.count

            NavigationLink {
                ChapterListView(book: book)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(book.name)
                            .font(.system(.body, design: .serif, weight: .semibold))
                            .foregroundStyle(palette.ink)
                        Spacer()
                        Text(done == total ? "Complete" : "\(done) / \(total)")
                            .font(.caption.weight(done == total ? .semibold : .regular))
                            .foregroundStyle(done == total ? palette.goldBright : palette.inkMuted)
                    }
                    ProgressView(value: total == 0 ? 0 : Double(done) / Double(total))
                        .tint(palette.gold)
                }
                .padding(14)
                .themedCard(cornerRadius: 12)
            }
            .buttonStyle(.plain)
        }
    }
}
