//
//  PrayerListView.swift
//
//  Your private prayer list, with a place to write down how a prayer was answered.
//

import SwiftUI

struct PrayerListView: View {

    @EnvironmentObject var prayerStore: PrayerStore
    @Environment(\.palette) private var palette

    @State private var filter: PrayerStatus = .active
    @State private var editing: Prayer?

    private var visible: [Prayer] {
        prayerStore.prayers.filter { $0.status == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterChips

            if visible.isEmpty {
                VStack(spacing: 8) {
                    Text(emptyTitle)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(palette.ink)
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(palette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(visible) { prayer in
                        Button {
                            editing = prayer
                        } label: {
                            row(prayer)
                        }
                        .buttonStyle(.plain)
                        .themedRows()
                        .swipeActions(edge: .leading) {
                            if prayer.status != .answered {
                                Button { set(prayer, .answered) } label: { Label("Answered", systemImage: "checkmark.circle") }
                                    .tint(palette.greenInk)
                            }
                            if prayer.status != .active {
                                Button { set(prayer, .active) } label: { Label("Active", systemImage: "arrow.uturn.backward") }
                                    .tint(palette.gold)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { prayerStore.delete(id: prayer.id) } label: { Label("Delete", systemImage: "trash") }
                            if prayer.status != .archived {
                                Button { set(prayer, .archived) } label: { Label("Archive", systemImage: "archivebox") }
                                    .tint(palette.tealInk)
                            }
                        }
                    }
                }
                .themedList()
            }
        }
        .sheet(item: $editing) { prayer in
            PrayerEditorView(prayer: prayer)
        }
    }

    // MARK: - Pieces

    private var emptyTitle: String {
        switch filter {
        case .active: return prayerStore.prayers.isEmpty ? "No prayers yet" : "Nothing active"
        case .answered: return "No answered prayers yet"
        case .archived: return "Nothing archived"
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .active: return "Tap + to add something to pray for. It stays private."
        case .answered: return "When a prayer is answered, mark it here and write down how."
        case .archived: return "Archive prayers you no longer need to see."
        }
    }

    private func set(_ prayer: Prayer, _ status: PrayerStatus) {
        var changed = prayer
        changed.status = status
        prayerStore.save(changed)
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(PrayerStatus.allCases) { status in
                let selected = filter == status
                let count = prayerStore.prayers.filter { $0.status == status }.count
                Button {
                    filter = status
                } label: {
                    Text(count > 0 ? "\(status.label) \u{00B7} \(count)" : status.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? palette.goldBright : palette.inkMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(selected ? palette.gold.opacity(0.18) : Color.clear))
                        .overlay(Capsule().stroke(selected ? palette.gold : palette.goldLine))
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func row(_ prayer: Prayer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prayer.title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(palette.ink)
                .lineLimit(2)

            if !prayer.details.isEmpty {
                Text(prayer.details)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSoft)
                    .lineLimit(2)
            }

            if prayer.status == .answered, !prayer.answerNote.isEmpty {
                Label(prayer.answerNote, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(palette.greenInk)
                    .lineLimit(2)
            }

            Text(prayer.status == .answered && prayer.answeredAt != nil
                 ? "Answered \(prayer.answeredAt!.formatted(date: .abbreviated, time: .omitted))"
                 : "Added \(prayer.createdAt.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(palette.inkMuted)
        }
        .padding(.vertical, 4)
    }
}

struct PrayerEditorView: View {

    @EnvironmentObject var prayerStore: PrayerStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    private let original: Prayer
    private let isNew: Bool

    @State private var draft: Prayer
    @State private var confirmDelete = false

    init(prayer: Prayer? = nil) {
        let start = prayer ?? Prayer()
        self.original = start
        self.isNew = prayer == nil
        self._draft = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Prayer") {
                        TextField("What are you praying for?", text: $draft.title, axis: .vertical)
                            .lineLimit(1...3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Details")
                        TextEditor(text: $draft.details)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(8)
                            .themedCard(cornerRadius: 10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Status")
                        Picker("Status", selection: $draft.status) {
                            ForEach(PrayerStatus.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if draft.status == .answered {
                        VStack(alignment: .leading, spacing: 8) {
                            label("How was it answered?")
                            TextEditor(text: $draft.answerNote)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .padding(8)
                                .themedCard(cornerRadius: 10)
                        }
                    }

                    Text("Your prayer list is private. It is only shared between your devices.")
                        .font(.caption)
                        .foregroundStyle(palette.inkMuted)

                    if !isNew {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Delete prayer", systemImage: "trash")
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .readableWidth()
            }
            .themedScreen()
            .navigationTitle(isNew ? "New Prayer" : "Prayer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !draft.isEmpty { prayerStore.save(draft) }
                        dismiss()
                    }
                    .disabled(draft.isEmpty)
                }
            }
            .confirmationDialog("Delete this prayer?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    prayerStore.delete(id: original.id)
                    dismiss()
                }
            }
        }
    }

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
}
