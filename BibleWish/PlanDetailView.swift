//
//  PlanDetailView.swift
//  BibleWish
//
//  One plan: stats, the day to read with a chapter checklist, and every day of the plan.
//

import SwiftUI

struct PlanDetailView: View {

    let planId: String

    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var plansStore: PlansStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    /// A day picked from "All days"; nil follows the next unfinished day.
    @State private var pickedDay: Int?
    @State private var confirmStop = false

    private var bookNames: [String] { viewModel.books.map(\.name) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let plan = plansStore.info(planId), let summary = plansStore.summary(for: planId) {
                    VStack(alignment: .leading, spacing: 20) {
                        statsCard(summary)
                            .id("top")

                        dayCard(plan: plan, summary: summary)

                        allDays(summary: summary, proxy: proxy)

                        Button(role: .destructive) {
                            confirmStop = true
                        } label: {
                            Label("Stop this plan", systemImage: "xmark.circle")
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                } else {
                    Text("This plan isn\u{2019}t started.")
                        .foregroundStyle(palette.inkMuted)
                        .padding()
                }
            }
            .navigationTitle(plansStore.info(planId)?.title ?? "Plan")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PassageReference.self) { reference in
                if let book = viewModel.book(named: reference.bookName) {
                    VerseListView(book: book, chapterIndex: reference.chapterIndex, scrollToVerse: reference.verse)
                }
            }
            .confirmationDialog(
                "Stop this plan?",
                isPresented: $confirmStop,
                titleVisibility: .visible
            ) {
                Button("Stop and delete progress", role: .destructive) {
                    plansStore.stop(planId)
                    dismiss()
                }
            } message: {
                Text("Your progress in this plan will be removed. Your chapters marked as read in the Bible stay.")
            }
        }
        .themedScreen()
    }

    // MARK: - Pieces

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(palette.gold)
            .accessibilityAddTraits(.isHeader)
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(palette.goldBright)
            Text(caption)
                .font(.caption)
                .foregroundStyle(palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func statsCard(_ summary: PlanSummary) -> some View {
        VStack(spacing: 14) {
            ProgressView(value: summary.fraction)
                .tint(palette.gold)

            HStack {
                stat(summary.percentLabel, "complete")
                stat("\(summary.completedDays)/\(summary.days.count)", "days done")
                stat("\(summary.streak)", "day streak")
            }

            Text(summary.status.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(summary.status == .complete ? palette.goldBright : palette.inkSoft)
        }
        .padding(20)
        .themedCard(cornerRadius: 16)
    }

    @ViewBuilder
    private func dayCard(plan: PlanInfo, summary: PlanSummary) -> some View {
        if let day = pickedDay ?? summary.nextDay {
            let items = summary.days[day - 1]

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(pickedDay == nil ? "Up next" : "Day \(day)")

                Text("Day \(day) of \(summary.days.count)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(palette.ink)

                ForEach(Array(items.enumerated()), id: \.offset) { index, chapter in
                    chapterRow(day: day, index: index, chapter: chapter, summary: summary)
                }

                if pickedDay != nil, let next = summary.nextDay {
                    Button("Back to day \(next)") { pickedDay = nil }
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .themedCard(cornerRadius: 16)
        } else {
            Text("You\u{2019}ve finished this plan. Well done.")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(palette.goldBright)
                .frame(maxWidth: .infinity)
                .padding(20)
                .themedCard(cornerRadius: 16)
        }
    }

    private func chapterRow(day: Int, index: Int, chapter: PlanChapter, summary: PlanSummary) -> some View {
        let done = summary.isItemDone(day: day, item: index)
        let name = chapter.book < viewModel.books.count ? viewModel.books[chapter.book].name : "Book \(chapter.book + 1)"

        return HStack(spacing: 12) {
            Button {
                plansStore.toggle(planId: planId, day: day, item: index)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(done ? palette.goldBright : palette.inkMuted)
            }
            .accessibilityLabel(done ? "Mark \(name) \(chapter.chapter) as not read" : "Mark \(name) \(chapter.chapter) as read")

            NavigationLink(value: reference(for: chapter)) {
                HStack {
                    Text("\(name) \(chapter.chapter)")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(done ? palette.inkMuted : palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(palette.gold)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func reference(for chapter: PlanChapter) -> PassageReference {
        let book = chapter.book < viewModel.books.count ? viewModel.books[chapter.book] : nil
        let index = book?.chapters.firstIndex { $0.number == chapter.chapter } ?? 0
        return PassageReference(bookName: book?.name ?? "", chapterIndex: index, verse: nil)
    }

    private func allDays(summary: PlanSummary, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("All days")
                .padding(.bottom, 10)

            LazyVStack(spacing: 0) {
                ForEach(1...summary.days.count, id: \.self) { day in
                    Button {
                        pickedDay = day
                        withAnimation { proxy.scrollTo("top", anchor: .top) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: summary.isDayDone(day) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(summary.isDayDone(day) ? palette.goldBright : palette.inkMuted)
                                .accessibilityHidden(true)
                            Text("Day \(day)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.ink)
                            Text(PlansStore.label(forDay: summary.days[day - 1], bookNames: bookNames))
                                .font(.subheadline)
                                .foregroundStyle(palette.inkMuted)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Day \(day), \(PlansStore.label(forDay: summary.days[day - 1], bookNames: bookNames)), \(summary.isDayDone(day) ? "done" : "not done")")
                    .accessibilityHint("Shows this day's chapters")

                    Divider().overlay(palette.goldLine)
                }
            }
        }
    }
}
