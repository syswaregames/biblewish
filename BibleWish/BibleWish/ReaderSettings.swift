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

    private let fontSizeKey = "reader_font_size"
    private let fontKey = "reader_font"

    init() {
        let savedSize = UserDefaults.standard.double(forKey: fontSizeKey)
        self.fontSize = savedSize == 0 ? 18 : savedSize

        let savedFontRaw = UserDefaults.standard.string(forKey: fontKey)
        self.font = ReaderFont(rawValue: savedFontRaw ?? "serif") ?? .serif
    }

    private func save() {
        UserDefaults.standard.set(fontSize, forKey: fontSizeKey)
        UserDefaults.standard.set(font.rawValue, forKey: fontKey)
    }
}
