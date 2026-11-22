//
//  VerseTextView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct VerseTextView: View {

    let verse: Verse
    let bookName: String
    let chapterNumber: Int
    /// Verse 1 of a book-page chapter: its first letter is drawn as a large gold initial.
    var dropCap = false
    /// Whether the verse is in the reader's favorites: a small heart after the text.
    var isFavorite = false
    /// A tap selects the verse (in focus mode it first brings the numbers back, until the next chapter).
    var onTap: () -> Void = {}
    /// A long press extends the selection from the nearest selected verse to this one.
    var onLongPress: () -> Void = {}

    @EnvironmentObject var highlightManager: HighlightManager
    @EnvironmentObject var readerSettings: ReaderSettings
    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette
    /// 1 at the default text size, larger with Dynamic Type; the reader's own size slider is the base.
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    /// In focus mode the numbers are hidden until a tap brings them back.
    var focusPeek = false

    var body: some View {

        let highlight = highlightManager.highlightFor(
            translation: savedTranslation,
            bookIndex: bookIndex,
            chapter: chapterNumber,
            verse: verse.number
        )

        (
            numberText
            +
            verseText
            +
            omittedMark
            +
            heartText
        )
        .font(
            .system(
                size: readerSettings.fontSize * textScale,
                design: readerSettings.font.fontDesign
            )
        )
        .lineSpacing(6)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(highlight?.color.fill(onDark: palette.colorScheme == .dark) ?? Color.clear)
        .overlay(alignment: .leading) {
            if highlight != nil {
                Capsule().fill(highlight?.color.iconColor ?? palette.gold).frame(width: 3).padding(.vertical, 3)
            }
        }
        .cornerRadius(6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verse \(verse.number). \(verse.text)" + (verse.omitted == true ? " Not in the oldest manuscripts; supplied by BibleWish." : ""))
        .accessibilityValue(accessibilityState(highlighted: highlight != nil))
        .accessibilityHint(highlight != nil ? "Double tap to deselect" : "Double tap to select")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityAction(named: "Select up to this verse") { onLongPress() }
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.4) {
            onLongPress()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    /// The translation and book number highlights are saved under (like biblewish.com).
    private var savedTranslation: String { viewModel.selectedTranslation.widgetId }
    private var bookIndex: Int { viewModel.books.firstIndex { $0.name == bookName } ?? -1 }

    private func accessibilityState(highlighted: Bool) -> String {
        [highlighted ? "Selected" : nil, isFavorite ? "In favorites" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// A verse BibleWish supplies in Biblia Livre: a small gold * (the footnote is at the chapter's end).
    private var omittedMark: Text {
        guard verse.omitted == true else { return Text("") }
        return Text("*").font(.caption.weight(.semibold)).foregroundColor(palette.gold).baselineOffset(6)
    }

    private var heartText: Text {
        guard isFavorite else { return Text("") }
        return Text(" ") + Text(Image(systemName: "heart.fill")).font(.caption2).foregroundColor(palette.gold)
    }

    /// The verse number. Hidden in focus mode, and for a drop-cap verse, where the initial stands in.
    private var numberText: Text {
        if (readerSettings.focusMode && !focusPeek) || dropCap {
            return Text("")
        }
        return Text("\(verse.number) ")
            .font(.caption2)
            .foregroundColor(palette.gold)
    }

    /// The verse text, with the words of Jesus in red when the reader has turned that on.
    private var verseText: Text {
        let utf16 = Array(verse.text.utf16)

        var spans: [Range<Int>] = []
        if readerSettings.redLetterEnabled,
           let translationId = viewModel.selectedTranslation.redLetterId {
            spans = RedLetterRanges.shared.spans(
                translation: translationId,
                bookName: bookName,
                chapter: chapterNumber,
                verse: verse.number,
                includeExtras: readerSettings.redLetterIncludeActsRevelation
            )
        }

        // Cut the text into runs: plain or red, with the drop-cap letter split off the front.
        var runs: [(range: Range<Int>, red: Bool)] = []
        var position = 0
        for span in spans where span.lowerBound >= position && span.upperBound <= utf16.count {
            if span.lowerBound > position { runs.append((position..<span.lowerBound, false)) }
            runs.append((span, true))
            position = span.upperBound
        }
        if position < utf16.count { runs.append((position..<utf16.count, false)) }

        var initialEnd = 0
        if dropCap, let first = verse.text.first {
            initialEnd = min(String(first).utf16.count, utf16.count)
        }

        var result = Text("")
        for run in runs {
            var pieces: [(Range<Int>, Bool)] = []
            if run.range.lowerBound < initialEnd && initialEnd < run.range.upperBound {
                pieces = [(run.range.lowerBound..<initialEnd, true), (initialEnd..<run.range.upperBound, false)]
            } else {
                pieces = [(run.range, run.range.upperBound <= initialEnd)]
            }
            for (range, isInitial) in pieces {
                var piece = Text(String(decoding: utf16[range], as: UTF16.self))
                if isInitial {
                    piece = piece
                        .font(.system(size: readerSettings.fontSize * textScale * 1.9, weight: .semibold, design: .serif))
                        .foregroundColor(palette.goldBright)
                } else if run.red {
                    piece = piece.foregroundColor(palette.jesus)
                }
                result = result + piece
            }
        }
        return result
    }
}
