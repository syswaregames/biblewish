//
//  OriginalWordsView.swift
//
//  "Original words" for the selected verses, like the website's word study: each KJV word with the
//  Hebrew or Greek behind it; tap a word for its full dictionary entry.
//

import SwiftUI

struct OriginalWordsView: View {

    let bookIndex: Int
    let chapter: Int
    let verses: [Int]
    let reference: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var open: Set<String> = []

    private var shown: [Int] { Array(verses.prefix(StrongsStore.maxVerses)) }
    private var isHebrew: Bool { bookIndex < 39 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(reference)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(palette.goldBright)
                        .padding(.bottom, 2)

                    if verses.count > shown.count {
                        Text("Showing the first \(shown.count) verses.")
                            .font(.footnote)
                            .foregroundStyle(palette.inkMuted)
                    }

                    ForEach(shown, id: \.self) { verse in
                        verseSection(verse)
                    }

                    Text("Words as in the King James Version, tagged with Strong\u{2019}s numbers (eBible.org). Definitions: Strong\u{2019}s Hebrew and Greek dictionaries (1890), digitized by Open Scriptures (CC BY-SA).")
                        .font(.caption)
                        .foregroundStyle(palette.inkMuted)
                        .padding(.top, 14)
                }
                .padding(16)
                .readableWidth(640)
            }
            .themedScreen()
            .navigationTitle("Original words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder private func verseSection(_ verse: Int) -> some View {
        let words = StrongsStore.shared.words(book: bookIndex, chapter: chapter, verse: verse)
        Text("VERSE \(verse)")
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(palette.gold)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
        if words.isEmpty {
            Text("No original-word data for this verse.")
                .font(.subheadline)
                .foregroundStyle(palette.inkMuted)
        } else {
            ForEach(words) { word in row(word, key: "\(verse)-\(word.id)") }
        }
    }

    private func row(_ word: StrongsWord, key: String) -> some View {
        let entry = StrongsStore.shared.entry(for: word.number)
        let expanded = open.contains(key)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expanded { open.remove(key) } else { open.insert(key) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(word.english)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(palette.ink)
                        .frame(minWidth: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        if let entry {
                            Text(entry.lemma)
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(palette.goldBright)
                                .environment(\.layoutDirection, word.isHebrew ? .rightToLeft : .leftToRight)
                            Text(entry.xlit).font(.caption).foregroundStyle(palette.inkMuted)
                        } else {
                            Text(word.number).font(.caption).foregroundStyle(palette.inkMuted)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(palette.inkMuted)
                }
                if let def = entry?.def, !expanded {
                    Text(StrongsStore.shorten(def))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                if expanded, let entry {
                    detail(word, entry)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(expanded ? "Double tap to close the entry" : "Double tap to open the entry")
    }

    private func detail(_ word: StrongsWord, _ entry: StrongsEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fact("Strong\u{2019}s", "\(word.number) \u{00B7} \(word.isHebrew ? "Hebrew" : "Greek")")
            fact("Pronounced", entry.pron)
            fact("Meaning", entry.def)
            fact("In the KJV", entry.kjv)
            fact("Origin", entry.derivation)
            if let count = entry.count, count > 0 {
                fact("Used", "\(count.formatted()) time\(count == 1 ? "" : "s") in the KJV")
            }
        }
    }

    @ViewBuilder private func fact(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(palette.gold)
                Text(value).font(.footnote).foregroundStyle(palette.ink).multilineTextAlignment(.leading)
            }
        }
    }
}
