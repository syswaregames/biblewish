//
//  NoteEditorView.swift
//  BibleWish
//
//  Write or edit a study note.
//

import SwiftUI

struct NoteEditorView: View {

    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var bibleVM: BibleViewModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    private let original: Note
    private let isNew: Bool

    @State private var draft: Note
    @State private var confirmDelete = false

    @StateObject private var editor = NoteEditorController()
    @State private var preview = false
    @State private var paletteMode: PaletteMode?
    @State private var showVersePanel = false
    @State private var verseReference = ""
    @State private var verseTranslation: BibleTranslation?
    @State private var verseMessage: String?
    @State private var lookingUpVerse = false

    private enum PaletteMode { case color, mark, box }

    /// Edit `note`, or start a new one (optionally about a passage).
    init(note: Note? = nil, reference: String = "") {
        let start = note ?? Note(reference: reference)
        self.original = start
        self.isNew = note == nil
        self._draft = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Title") {
                        TextField("Optional", text: $draft.title)
                    }

                    field("Passage") {
                        TextField("John 3:16", text: $draft.reference)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Tags")
                        tagChips
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Note")
                        Group {
                            if preview {
                                Group {
                                    if draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Nothing to preview yet.").foregroundStyle(palette.inkMuted)
                                    } else {
                                        NoteBodyView(text: draft.body)
                                            .font(.system(.body, design: .serif))
                                            .lineSpacing(4)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                                .padding(14)
                            } else {
                                NoteTextView(text: $draft.body, controller: editor)
                                    .frame(minHeight: 280)
                                    .padding(4)
                            }
                        }
                        .themedCard(cornerRadius: 10)

                        Text("\(draft.wordCount) word\(draft.wordCount == 1 ? "" : "s") \u{00B7} formatted like biblewish.com; verses like John 3:16 become links")
                            .font(.caption)
                            .foregroundStyle(palette.inkMuted)
                    }

                    if !isNew {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Delete note", systemImage: "trash")
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .readableWidth()
            }
            .themedScreen()
            .safeAreaInset(edge: .bottom) { formattingBar }
            .navigationTitle(isNew ? "New Note" : "Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !draft.isEmpty { noteStore.save(draft) }
                        dismiss()
                    }
                    .disabled(draft.isEmpty)
                }
            }
            .confirmationDialog("Delete this note?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    noteStore.delete(id: original.id)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Formatting toolbar

    private var formattingBar: some View {
        VStack(spacing: 8) {
            if let mode = paletteMode, !preview {
                HStack(spacing: 14) {
                    ForEach(NoteColor.allCases, id: \.self) { color in
                        Button {
                            choose(color, mode)
                        } label: {
                            Circle()
                                .fill(color.color(in: palette))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(palette.ink.opacity(0.35), lineWidth: 1))
                        }
                        .accessibilityLabel(color.rawValue.capitalized)
                    }
                    Spacer()
                    Text(mode == .box ? "Box color" : mode == .mark ? "Highlight color" : "Text color")
                        .font(.caption)
                        .foregroundStyle(palette.inkMuted)
                }
            }

            if showVersePanel, !preview {
                versePanel
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    tool("Bold", { Text("B").font(.system(.body, design: .serif, weight: .bold)) }) {
                        editor.perform { NoteEditing.wrap($0, $1, marker: "**", placeholder: "bold text") }
                    }
                    tool("Italic", { Text("I").font(.system(.body, design: .serif)).italic() }) {
                        editor.perform { NoteEditing.wrap($0, $1, marker: "*", placeholder: "italic text") }
                    }
                    tool("Heading", { Text("H").font(.system(.body, design: .serif, weight: .semibold)) }) {
                        editor.perform { NoteEditing.lines($0, $1, style: .heading) }
                    }
                    tool("Bulleted list", { Image(systemName: "list.bullet") }) {
                        editor.perform { NoteEditing.lines($0, $1, style: .bullet) }
                    }
                    tool("Numbered list", { Image(systemName: "list.number") }) {
                        editor.perform { NoteEditing.lines($0, $1, style: .numbered) }
                    }
                    tool("Quote", { Image(systemName: "text.quote") }) {
                        editor.perform { NoteEditing.lines($0, $1, style: .quote) }
                    }
                    tool("Link", { Image(systemName: "link") }) {
                        editor.perform { NoteEditing.link($0, $1) }
                    }
                    divider
                    tool("Text color", { Text("A").font(.system(.body, design: .serif, weight: .semibold)).foregroundStyle(palette.goldBright) }) {
                        togglePalette(.color)
                    }
                    tool("Highlight words", { Image(systemName: "highlighter") }) {
                        togglePalette(.mark)
                    }
                    tool("Colored box", { Image(systemName: "rectangle.leadinghalf.inset.filled") }) {
                        togglePalette(.box)
                    }
                    tool("Insert a verse", { Image(systemName: "book") }) {
                        paletteMode = nil
                        showVersePanel.toggle()
                    }
                    divider
                    Button {
                        preview.toggle()
                        paletteMode = nil
                        showVersePanel = false
                        if !preview { editor.focus() }
                    } label: {
                        Label(preview ? "Edit" : "Preview", systemImage: preview ? "pencil" : "eye")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.goldBright)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(Capsule().fill(preview ? palette.gold.opacity(0.2) : Color.clear))
                            .overlay(Capsule().stroke(palette.goldLine))
                    }
                    .accessibilityLabel(preview ? "Back to editing" : "Preview the note")
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .background(palette.panel.opacity(0.98))
        .overlay(alignment: .top) { Rectangle().fill(palette.goldLine).frame(height: 1) }
    }

    private var divider: some View {
        Rectangle().fill(palette.goldLine).frame(width: 1, height: 22).padding(.horizontal, 2)
    }

    private func tool<Content: View>(_ name: String, @ViewBuilder _ content: () -> Content, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(palette.ink)
                .frame(width: 42, height: 38)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.goldLine))
        }
        .disabled(preview)
        .opacity(preview ? 0.4 : 1)
        .accessibilityLabel(name)
    }

    private func togglePalette(_ mode: PaletteMode) {
        showVersePanel = false
        paletteMode = paletteMode == mode ? nil : mode
    }

    private func choose(_ color: NoteColor, _ mode: PaletteMode) {
        switch mode {
        case .color: editor.perform { NoteEditing.color($0, $1, id: color.rawValue, mark: false) }
        case .mark: editor.perform { NoteEditing.color($0, $1, id: color.rawValue, mark: true) }
        case .box: editor.perform { NoteEditing.box($0, $1, id: color.rawValue) }
        }
        paletteMode = nil
    }

    // MARK: - Insert a verse

    /// A reference and a translation; the verse text is copied into the note as a verse card. Works
    /// offline: every translation is in the app.
    private var versePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Verse, e.g. John 3:16", text: $verseReference)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { Task { await insertVerse() } }
                    .padding(10)
                    .themedCard(cornerRadius: 8)

                Picker("Translation", selection: Binding(
                    get: { verseTranslation ?? bibleVM.selectedTranslation },
                    set: { verseTranslation = $0 }
                )) {
                    ForEach(BibleTranslation.allCases) { Text($0.widgetId.uppercased()).tag($0) }
                }
                .pickerStyle(.menu)

                Button {
                    Task { await insertVerse() }
                } label: {
                    if lookingUpVerse { ProgressView() } else { Text("Insert").fontWeight(.semibold) }
                }
                .disabled(lookingUpVerse || verseReference.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let verseMessage {
                Text(verseMessage).font(.caption).foregroundStyle(palette.roseInk)
            }
        }
    }

    @MainActor
    private func insertVerse() async {
        let translation = verseTranslation ?? bibleVM.selectedTranslation
        lookingUpVerse = true
        verseMessage = nil
        defer { lookingUpVerse = false }

        // The open translation is already in memory; another is read from the app's files.
        let books: [BibleBook]
        if translation == bibleVM.selectedTranslation {
            books = bibleVM.books
        } else {
            let loaded = await Task.detached { translation.loadBooks() }.value
            guard let loaded else {
                verseMessage = "Couldn\u{2019}t open that translation."
                return
            }
            books = loaded
        }

        guard let passage = PassageReference.parse(verseReference, in: books), let first = passage.verse,
              let book = books.first(where: { $0.name == passage.bookName }),
              passage.chapterIndex < book.chapters.count else {
            verseMessage = "Type a verse like John 3:16 or Psalm 23:1-3."
            return
        }

        let chapter = book.chapters[passage.chapterIndex]
        let last = min(passage.verseEnd ?? first, first + 29)
        let verses = chapter.verses.filter { $0.number >= first && $0.number <= last }
        guard !verses.isEmpty else {
            verseMessage = "That verse does not exist in this translation."
            return
        }

        let label = "\(book.name) \(chapter.number):\(first)" + (last > first ? "-\(last)" : "")
        editor.perform {
            NoteEditing.verseCard($0, $1, reference: label, translation: translation.widgetId.uppercased(), text: verses.map(\.text).joined(separator: " "))
        }
        verseReference = ""
        showVersePanel = false
        editor.focus()
    }

    // MARK: - Pieces

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(palette.gold)
            .accessibilityAddTraits(.isHeader)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label(title)
            content()
                .padding(12)
                .themedCard(cornerRadius: 10)
        }
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NoteTag.allCases) { tag in
                    let selected = draft.tags.contains(tag)
                    let color = tag.color(in: palette)

                    Button {
                        if selected {
                            draft.tags.removeAll { $0 == tag }
                        } else {
                            draft.tags.append(tag)
                        }
                    } label: {
                        Text(tag.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected ? color : palette.inkMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(selected ? color.opacity(0.18) : Color.clear))
                            .overlay(Capsule().stroke(selected ? color : palette.goldLine))
                    }
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
