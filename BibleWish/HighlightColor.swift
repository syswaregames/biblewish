//
//  HighlightColor.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

enum HighlightColor: String, Codable, CaseIterable {
    case yellow
    case green
    case blue
    case pink

    var color: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.35)
        case .green:  return Color.green.opacity(0.30)
        case .blue:   return Color.blue.opacity(0.25)
        case .pink:   return Color.pink.opacity(0.30)
        }
    }

    /// The wash behind a highlighted verse: gentler on a dark page, so red words stay readable.
    func fill(onDark: Bool) -> Color {
        onDark ? iconColor.opacity(0.2) : color
    }

    var iconColor: Color {
        switch self {
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .pink:   return .pink
        }
    }
}

//#Preview {
//    HighlightColor()
//}
