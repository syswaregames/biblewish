//
//  VerseSelectionBar.swift
//
//  The bar at the bottom of the reader while verses are selected, like the website's selection
//  bar (read.html): the reference, the pen colors and Save, Note, Image, Study, Copy, Share, Clear.
//

import SwiftUI

/// A short message at the top of the reader, with an optional Undo.
struct ReaderToast: Equatable {
    let id = UUID()
    let message: String
    var undoTitle: String?
    var undo: (() -> Void)?

    static func == (lhs: ReaderToast, rhs: ReaderToast) -> Bool { lhs.id == rhs.id }
}

struct ReaderToastView: View {
    let toast: ReaderToast
    let dismiss: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(palette.ink)
            if let undo = toast.undo {
                Button(toast.undoTitle ?? "Undo") {
                    undo()
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.goldBright)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(palette.panel))
        .overlay(Capsule().stroke(palette.goldLine))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
}

struct VerseSelectionBar: View {

    let label: String
    let shareText: String
    let allSaved: Bool
    let hasPlaces: Bool
    /// Original words and Send need the book's place in the 66-book order (as on the website).
    let hasCanonicalBook: Bool
    let onColor: (HighlightColor) -> Void
    let onSave: () -> Void
    let onNote: () -> Void
    let onImage: () -> Void
    let onSend: () -> Void
    let onWords: () -> Void
    let onRelated: () -> Void
    let onPlaces: () -> Void
    let onCopy: () -> Void
    let onClear: () -> Void

    @EnvironmentObject private var readerSettings: ReaderSettings
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                ForEach(HighlightColor.allCases, id: \.self) { color in
                    Button { onColor(color) } label: {
                        Circle()
                            .fill(color.iconColor)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if readerSettings.highlightColor == color {
                                    Circle().stroke(palette.ink, lineWidth: 2).padding(-4)
                                }
                            }
                            .padding(6)
                    }
                    .accessibilityLabel("\(color.rawValue.capitalized) highlight")
                    .accessibilityAddTraits(readerSettings.highlightColor == color ? .isSelected : [])
                }
            }

            HStack(spacing: 0) {
                action(allSaved ? "heart.fill" : "heart", allSaved ? "Saved" : "Save", allSaved ? "Remove from favorites" : "Save to favorites", onSave)
                action("square.and.pencil", "Note", "Write a note", onNote)
                action("photo", "Image", "Share as an image", onImage)
                if hasCanonicalBook {
                    action("paperplane", "Send", "Send to someone", onSend)
                }

                Menu {
                    Button { onRelated() } label: { Label("Related verses", systemImage: "link") }
                    if hasCanonicalBook {
                        Button { onWords() } label: { Label("Original words", systemImage: "character.book.closed") }
                    }
                    if hasPlaces {
                        Button { onPlaces() } label: { Label("Places in this chapter", systemImage: "map") }
                    }
                } label: {
                    item("books.vertical", "Study")
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Study tools")

                action("doc.on.doc", "Copy", "Copy the verses", onCopy)

                ShareLink(item: shareText) { item("square.and.arrow.up", "Share") }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Share the verses")

                action("xmark", "Clear", "Clear the selection", onClear)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(RoundedRectangle(cornerRadius: 22).fill(palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.goldLine))
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func action(_ icon: String, _ title: String, _ hint: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { item(icon, title) }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(hint)
    }

    private func item(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(height: 22)
            if !typeSize.isAccessibilitySize {
                Text(title).font(.caption2)
            }
        }
        .foregroundStyle(palette.gold)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
