//
//  HomeView.swift
//  BibleWish
//
//  The dashboard: a time-of-day hero, the Verse of the Day, continue reading and open a passage.
//

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var achievements: AchievementsStore
    @EnvironmentObject var plansStore: PlansStore
    @Environment(\.palette) private var palette

    @State private var passageText = ""
    @State private var passageNotFound = false
    @State private var target: PassageReference?
    /// The photo grows with the text size so a large greeting still fits on it.
    @ScaledMetric(relativeTo: .largeTitle) private var heroHeight: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero

                VStack(spacing: 16) {
                    if let verse = VerseOfTheDay.load(from: viewModel.books) {
                        verseOfTheDayCard(verse)
                    }
                    todaysReadingCard
                    continueReadingCard
                    openPassageCard
                    progressCard
                    achievementsCard
                    mapsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .readableWidth()
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .themedScreen()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $target) { reference in
            if let book = viewModel.book(named: reference.bookName) {
                VerseListView(
                    book: book,
                    chapterIndex: reference.chapterIndex,
                    scrollToVerse: reference.verse
                )
            }
        }
    }

    // MARK: - Hero

    private enum TimeOfDay {
        case morning, afternoon, evening, night

        init(hour: Int) {
            switch hour {
            case 5..<12: self = .morning
            case 12..<17: self = .afternoon
            case 17..<21: self = .evening
            default: self = .night
            }
        }

        var imageName: String {
            switch self {
            case .morning: return "HeroMorning"
            case .afternoon: return "HeroAfternoon"
            case .evening: return "HeroEvening"
            case .night: return "HeroNight"
            }
        }

        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            case .night: return "Grace and peace"
            }
        }
    }

    private var hero: some View {
        let timeOfDay = TimeOfDay(hour: Calendar.current.component(.hour, from: Date()))

        // The photo sits in an overlay so its fill size can't widen the column.
        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .overlay {
                Image(timeOfDay.imageName)
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.15), .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeOfDay.greeting)
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(.subheadline, design: .serif))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .clipped()
            .accessibilityElement(children: .combine)
    }

    // MARK: - Cards

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(palette.gold)
            .accessibilityAddTraits(.isHeader)
    }

    private func verseOfTheDayCard(_ verse: VerseOfTheDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Verse of the day")

            Text("\u{201C}\(verse.text)\u{201D}")
                .font(.system(.title3, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(palette.ink)

            Text(verse.label)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(palette.goldBright)

            HStack(spacing: 20) {
                Button {
                    target = PassageReference(
                        bookName: verse.bookName,
                        chapterIndex: max(0, verse.chapterNumber - 1),
                        verse: nil
                    )
                } label: {
                    Label("Read chapter", systemImage: "book")
                }

                ShareLink(item: "\u{201C}\(verse.text)\u{201D}\n\u{2014} \(verse.label)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .font(.subheadline)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .themedCard(cornerRadius: 16)
    }

    /// The day to read next in each plan you've started and not finished.
    @ViewBuilder
    private var todaysReadingCard: some View {
        let active = plansStore.catalog.compactMap { plan -> (PlanInfo, PlanSummary, Int)? in
            guard let summary = plansStore.summary(for: plan.id), let next = summary.nextDay else { return nil }
            return (plan, summary, next)
        }

        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Today\u{2019}s reading")

                ForEach(active, id: \.0.id) { plan, summary, day in
                    NavigationLink {
                        PlanDetailView(planId: plan.id)
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.title)
                                    .font(.system(.headline, design: .serif))
                                    .foregroundStyle(palette.ink)
                                Text("Day \(day): \(PlansStore.label(forDay: summary.days[day - 1], bookNames: viewModel.books.map(\.name)))")
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundStyle(palette.goldBright)
                                Text(summary.status.text)
                                    .font(.caption)
                                    .foregroundStyle(palette.inkMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(palette.gold)
                                .padding(.top, 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .themedCard(cornerRadius: 16)
        }
    }

    @ViewBuilder
    private var continueReadingCard: some View {
        if let last = viewModel.lastRead,
           last.bookIndex < viewModel.books.count {
            let book = viewModel.books[last.bookIndex]

            Button {
                if let index = book.chapters.firstIndex(where: { $0.number == last.chapterNumber }) {
                    target = PassageReference(bookName: book.name, chapterIndex: index, verse: nil)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("Continue reading")
                        Text("\(book.name) \(last.chapterNumber)")
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(palette.ink)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(palette.gold)
                }
                .padding(20)
                .themedCard(cornerRadius: 16)
            }
            .buttonStyle(.plain)
        }
    }

    private var openPassageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Open a passage")

            TextField("John 3:16", text: $passageText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit(openPassage)
                .onChange(of: passageText) { passageNotFound = false }
                .padding(12)
                .themedCard(cornerRadius: 10)

            if passageNotFound {
                Text("Couldn\u{2019}t find that passage. Try a book, chapter and verse, like \u{201C}Psalm 23\u{201D}.")
                    .font(.caption)
                    .foregroundStyle(palette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .themedCard(cornerRadius: 16)
    }

    private var progressCard: some View {
        let total = BibleProgress.totalChapters(in: viewModel)
        let done = BibleProgress.readChapters(in: viewModel).count
        let fraction = total == 0 ? 0 : Double(done) / Double(total)

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Your Bible progress")

            Text("\(done) of \(total) chapters read")
                .font(.system(.body, design: .serif))
                .foregroundStyle(palette.ink)

            ProgressView(value: fraction)
                .tint(palette.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .themedCard(cornerRadius: 16)
    }

    private var achievementsCard: some View {
        NavigationLink {
            AchievementsView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Achievements")
                    Text("\(achievements.earned.count) of \(achievements.badges.count) badges")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(palette.ink)
                    if let next = achievements.nextBadge {
                        Text("Next: \(next.icon) \(next.name) \u{00B7} \(achievements.current(next))/\(next.target)")
                            .font(.subheadline)
                            .foregroundStyle(palette.inkMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(palette.gold)
            }
            .padding(20)
            .themedCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private var mapsCard: some View {
        NavigationLink {
            JourneysView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Bible maps")
                    Text("Journeys of Abraham, the Exodus, Jesus and Paul")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(palette.gold)
            }
            .padding(20)
            .themedCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openPassage() {
        if let reference = PassageReference.parse(passageText, in: viewModel.books) {
            passageNotFound = false
            target = reference
        } else {
            passageNotFound = !passageText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}
