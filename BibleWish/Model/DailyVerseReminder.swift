//
//  DailyVerseReminder.swift
//
//  An optional daily notification with the verse of the day, in the selected translation. The next
//  30 days are scheduled at once (each day has a different verse) and topped up whenever the app opens.
//

import Foundation
import UserNotifications

final class DailyVerseReminder: ObservableObject {

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: enabledKey) }
    }

    /// Only the hour and minute are used.
    @Published var time: Date {
        didSet { UserDefaults.standard.set(time.timeIntervalSince1970, forKey: timeKey) }
    }

    /// True when the reader turned the reminder on but the system won't let it notify.
    @Published private(set) var permissionDenied = false

    static let daysAhead = 30
    private static let identifierPrefix = "votd-"

    /// Bumped by every reschedule so an older, slower one stops instead of mixing its reminders in.
    private var generation = 0

    private let enabledKey = "daily_verse_enabled"
    private let timeKey = "daily_verse_time"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)

        let saved = UserDefaults.standard.double(forKey: timeKey)
        if saved > 0 {
            time = Date(timeIntervalSince1970: saved)
        } else {
            time = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
        }
    }

    /// Turns the reminder on after asking permission, or off.
    @MainActor
    func setEnabled(_ enabled: Bool, books: [BibleBook]) async {
        guard enabled else {
            isEnabled = false
            permissionDenied = false
            await clear()
            return
        }

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        permissionDenied = !granted
        isEnabled = granted
        if granted { await reschedule(books: books) }
    }

    /// One reminder to schedule.
    struct Planned: Equatable {
        let identifier: String
        let body: String
        let components: DateComponents
    }

    /// The reminders for the next days at `time`: one per day, skipping a time that has already
    /// passed today. Pure, so it can be checked without the notification center.
    static func planned(books: [BibleBook], time: Date, now: Date = Date(), calendar: Calendar = .current) -> [Planned] {
        let clock = calendar.dateComponents([.hour, .minute], from: time)

        return (0..<daysAhead).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: clock.hour ?? 8, minute: clock.minute ?? 0, second: 0, of: day),
                  fireDate > now,
                  let verse = VerseOfTheDay.load(from: books, date: fireDate) else { return nil }

            return Planned(
                identifier: identifierPrefix + PlansStore.isoDay(fireDate),
                body: "\u{201C}\(verse.text)\u{201D}\n\u{2014} \(verse.label)",
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            )
        }
    }

    /// Replaces the scheduled reminders with the next days' verses.
    @MainActor
    func reschedule(books: [BibleBook], now: Date = Date()) async {
        generation += 1
        let mine = generation

        await clear()
        guard mine == generation, isEnabled, !books.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        for reminder in Self.planned(books: books, time: time, now: now) {
            let content = UNMutableNotificationContent()
            content.title = "Verse of the Day"
            content.body = reminder.body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: reminder.components, repeats: false)
            )
            guard mine == generation else { return }
            try? await center.add(request)
        }
    }

    private func clear() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Re-checks the system setting (the reader may have changed it in Settings).
    @MainActor
    func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        permissionDenied = isEnabled && !allowed
    }
}
