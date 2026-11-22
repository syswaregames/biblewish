//
//  NoteEditorView.swift
//  BibleWish
//
//  Write or edit a study note.
//

import SwiftUI

struct NoteEditorView: View {

    @EnvironmentObject var noteStore: NoteStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    private let original: Note
    private let isNew: Bool

    @State private var draft: Note
    @State private var confirmDelete = false

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
                        TextEditor(text: $draft.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 240)
                            .padding(8)
                            .themedCard(cornerRadius: 10)
                        Text("\(draft.wordCount) word\(draft.wordCount == 1 ? "" : "s")")
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
            }
            .themedScreen()
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

    // MARK: - Pieces

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(palette.gold)
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
