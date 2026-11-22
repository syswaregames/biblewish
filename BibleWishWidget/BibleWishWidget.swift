//
//  BibleWishWidget.swift
//
//  The Verse of the Day widget: the same verse list as the app and the website, in the translation
//  the reader chose in the app. Carries its own copy of the verse texts (Data/votd).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: WidgetVerse
}

struct VerseProvider: TimelineProvider {

    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: Date(), verse: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        let verse = context.isPreview
            ? WidgetVerse.sample
            : VerseLibrary.verse(on: Date(), translation: SharedConfig.widgetTranslation)
        completion(VerseEntry(date: Date(), verse: verse))
    }

    /// One entry per day for the next week, each changing at midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let calendar = Calendar.current
        let translation = SharedConfig.widgetTranslation
        let today = calendar.startOfDay(for: Date())

        let entries = (0..<7).compactMap { offset -> VerseEntry? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return VerseEntry(date: offset == 0 ? Date() : day, verse: VerseLibrary.verse(on: day, translation: translation))
        }
        let refresh = calendar.date(byAdding: .day, value: 7, to: today) ?? today.addingTimeInterval(7 * 86_400)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - Widget

struct VerseWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    private var size: VerseWidgetSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .accessoryRectangular: return .lockRectangular
        case .accessoryInline: return .lockInline
        default: return .large
        }
    }

    var body: some View {
        VerseWidgetContent(verse: entry.verse, size: size)
            .containerBackground(for: .widget) { VerseWidgetContent.background }
    }
}

struct VerseOfTheDayWidget: Widget {

    let kind = "VerseOfTheDay"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
            VerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("A verse for every day, in your translation.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct BibleWishWidgetBundle: WidgetBundle {
    var body: some Widget {
        VerseOfTheDayWidget()
    }
}

#Preview("Small", as: .systemSmall) {
    VerseOfTheDayWidget()
} timeline: {
    VerseEntry(date: Date(), verse: .sample)
}

#Preview("Medium", as: .systemMedium) {
    VerseOfTheDayWidget()
} timeline: {
    VerseEntry(date: Date(), verse: .sample)
}
