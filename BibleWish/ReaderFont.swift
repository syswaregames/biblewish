//
//  ReaderFont.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

enum ReaderFont: String, CaseIterable, Identifiable, Codable {
    case serif
    case sans
    case rounded
    case monospaced

    var id: String { rawValue }

    var fontDesign: Font.Design {
        switch self {
        case .serif:       return .serif
        case .sans:        return .default
        case .rounded:     return .rounded
        case .monospaced:  return .monospaced
        }
    }

    var displayName: String {
        switch self {
        case .serif: return "Serif"
        case .sans: return "Sans"
        case .rounded: return "Rounded"
        case .monospaced: return "Monospaced"
        }
    }
}
