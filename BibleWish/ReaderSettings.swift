//
//  ReaderSettings.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

class ReaderSettings: ObservableObject {

    @Published var fontSize: CGFloat {
        didSet { save() }
    }

    @Published var font: ReaderFont {
        didSet { save() }
    }

    @Published var redLetterEnabled: Bool {
        didSet { save() }
    }

    @Published var redLetterIncludeActsRevelation: Bool {
        didSet { save() }
    }

    /// "Book" frames the chapter like a printed page; "plain" is the bare reading column.
    @Published var bookPage: Bool {
        didSet { save() }
    }

    /// Hides verse numbers and the reading time so only the text is left.
    @Published var focusMode: Bool {
        didSet { save() }
    }

    private let bookPageKey = "reader_book_page"
    private let focusModeKey = "reader_focus_mode"
    /// The color a tapped verse gets (the reader can change it from the selection bar).
    @Published var highlightColor: HighlightColor {
        didSet { save() }
    }

    private let highlightColorKey = "reader_highlight_color"
    private let fontSizeKey = "reader_font_size"
    private let fontKey = "reader_font"
    private let redLetterEnabledKey = "reader_red_letter_enabled"
    private let redLetterIncludeActsRevelationKey = "reader_red_letter_include_acts_revelation"

    init() {
        let savedSize = UserDefaults.standard.double(forKey: fontSizeKey)
        self.fontSize = savedSize == 0 ? 18 : savedSize

        let savedFontRaw = UserDefaults.standard.string(forKey: fontKey)
        self.font = ReaderFont(rawValue: savedFontRaw ?? "serif") ?? .serif

        self.highlightColor = HighlightColor(rawValue: UserDefaults.standard.string(forKey: highlightColorKey) ?? "") ?? .yellow
        self.bookPage = UserDefaults.standard.object(forKey: bookPageKey) as? Bool ?? true
        self.focusMode = UserDefaults.standard.object(forKey: focusModeKey) as? Bool ?? false

        let savedRedLetter = UserDefaults.standard.object(forKey: redLetterEnabledKey) as? Bool
        self.redLetterEnabled = savedRedLetter ?? false

        let savedIncludeActsRevelation = UserDefaults.standard.object(forKey: redLetterIncludeActsRevelationKey) as? Bool
        self.redLetterIncludeActsRevelation = savedIncludeActsRevelation ?? false
    }

    private func save() {
        UserDefaults.standard.set(fontSize, forKey: fontSizeKey)
        UserDefaults.standard.set(font.rawValue, forKey: fontKey)
        UserDefaults.standard.set(highlightColor.rawValue, forKey: highlightColorKey)
        UserDefaults.standard.set(bookPage, forKey: bookPageKey)
        UserDefaults.standard.set(focusMode, forKey: focusModeKey)
        UserDefaults.standard.set(redLetterEnabled, forKey: redLetterEnabledKey)
        UserDefaults.standard.set(
            redLetterIncludeActsRevelation,
            forKey: redLetterIncludeActsRevelationKey
        )
    }
}
