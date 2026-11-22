//
//  StudyView.swift
//  BibleWish
//
//  Your favorite verses and your study notes.
//

import SwiftUI

struct StudyView: View {

    @EnvironmentObject var noteStore: NoteStore
    @Environment(\.palette) private var palette

    private enum Section: String, CaseIterable, Identifiable {
        case favorites = "Favorites"
        case notes = "Notes"
        var id: String { rawValue }
    }

    @State private var section: Section = .favorites
    @State private var tagFilter: NoteTag?
    @State private var showingNewNote = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Study", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            switch section {
            case .favorites:
                BookmarksView()
            case .notes:
                notesList
            }
        }
        .themedScreen()
        .navigationTitle("Study")
        .toolbar {
            if section == .notes {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New note")
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NoteEditorView()
        }
    }

    // MARK: - Notes

    private var visibleNotes: [Note] {
        guard let tagFilter else { return noteStore.notes }
        return noteStore.notes.filter { $0.tags.contains(tagFilter) }
    }

    private var notesList: some View {
        VStack(spacing: 0) {
            filterChips

            if visibleNotes.isEmpty {
                VStack(spacing: 8) {
                    Text(noteStore.notes.isEmpty ? "No notes yet" : "No notes with this tag")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(palette.ink)
                    Text("Tap the pencil to write one, or long-press a verse while reading.")
                        .font(.subheadline)
                        .foregroundStyle(palette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(visibleNotes) { note in
                        NavigationLink {
                            NoteDetailView(noteID: note.id)
                        } label: {
                            noteRow(note)
                        }
                        .themedRows()
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { visibleNotes[$0].id }
                        ids.forEach(noteStore.delete(id:))
                    }
                }
                .themedList()
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", color: palette.gold, selected: tagFilter == nil) { tagFilter = nil }
                ForEach(NoteTag.allCases) { tag in
                    chip(tag.label, color: tag.color(in: palette), selected: tagFilter == tag) {
                        tagFilter = tagFilter == tag ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func chip(_ title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? color : palette.inkMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? color.opacity(0.18) : Color.clear))
                .overlay(Capsule().stroke(selected ? color : palette.goldLine))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.displayTitle)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(palette.ink)
                .lineLimit(1)

            if !note.reference.isEmpty {
                Text(note.reference)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(palette.goldBright)
            }

            if !note.body.isEmpty, note.title.trimmingCharacters(in: .whitespaces) != "" {
                Text(note.body)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSoft)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                ForEach(note.tags) { tag in
                    Text(tag.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tag.color(in: palette))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(tag.color(in: palette).opacity(0.7)))
                }
                Spacer()
                Text("Edited \(note.updatedAt.formatted(.relative(presentation: .named))) \u{00B7} \(note.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(palette.inkMuted)
            }
        }
        .padding(.vertical, 4)
    }
}
