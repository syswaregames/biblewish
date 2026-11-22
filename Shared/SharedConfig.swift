//
//  SharedConfig.swift
//
//  What the app and the widget agree on. Compiled into both targets.
//

import Foundation

enum SharedConfig {

    /// The App Group both targets belong to (set in their entitlements and registered in the
    /// Apple Developer account).
    static let appGroup = "group.Sysware.BibleWish"

    /// Which translation the widget shows: "kjv", "web", "bliv" or "heb".
    static let translationKey = "widget_translation"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// The translation the widget should use; KJV when the group isn't available.
    static var widgetTranslation: String {
        defaults?.string(forKey: translationKey) ?? "kjv"
    }
}

/// One day's verse as the widget shows it.
struct WidgetVerse {
    let label: String
    let text: String
    /// Hebrew reads right to left.
    let isRightToLeft: Bool

    static let sample = WidgetVerse(
        label: "Philippians 4:19",
        text: "But my God shall supply all your need according to his riches in glory by Christ Jesus.",
        isRightToLeft: false
    )
}
