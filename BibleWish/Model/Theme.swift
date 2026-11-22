//
//  Theme.swift
//  BibleWish
//
//  Design tokens shared with biblewish.com (css/style.css).
//

import SwiftUI

enum ThemeChoice: String, CaseIterable, Identifiable {
    case dark
    case sepia
    case light
    case auto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .sepia: return "Sepia"
        case .light: return "Light"
        case .auto: return "Auto"
        }
    }
}

struct ThemePalette {
    let ink: Color
    let inkSoft: Color
    let inkMuted: Color
    let gold: Color
    let goldBright: Color
    let goldLine: Color
    let jesus: Color
    let surface: Color
    let panel: Color
    let pageTop: Color
    let pageBottom: Color
    let colorScheme: ColorScheme

    var pageGradient: RadialGradient {
        RadialGradient(
            colors: [pageTop, pageBottom],
            center: .top,
            startRadius: 0,
            endRadius: 900
        )
    }

    static let dark = ThemePalette(
        ink: Color(hex: 0xE7DCCF),
        inkSoft: Color(hex: 0xC9B89E),
        inkMuted: Color(hex: 0xD8CEC1).opacity(0.6),
        gold: Color(hex: 0xC7A96B),
        goldBright: Color(hex: 0xE0BA78),
        goldLine: Color(hex: 0xFFC878).opacity(0.13),
        jesus: Color(hex: 0xC8524A),
        surface: Color.white.opacity(0.03),
        panel: Color(hex: 0x17120E),
        pageTop: Color(hex: 0x2A1F1A),
        pageBottom: Color(hex: 0x0B0A09),
        colorScheme: .dark
    )

    static let sepia = ThemePalette(
        ink: Color(hex: 0x3A2A1B),
        inkSoft: Color(hex: 0x6B5139),
        inkMuted: Color(hex: 0x543E28).opacity(0.74),
        gold: Color(hex: 0x94681F),
        goldBright: Color(hex: 0x8A5D14),
        goldLine: Color(hex: 0x8C6224).opacity(0.2),
        jesus: Color(hex: 0x8E2A22),
        surface: Color(hex: 0x785424).opacity(0.05),
        panel: Color(hex: 0xF6ECD6),
        pageTop: Color(hex: 0xF7EEDB),
        pageBottom: Color(hex: 0xE8D9BB),
        colorScheme: .light
    )

    static let light = ThemePalette(
        ink: Color(hex: 0x1F1A15),
        inkSoft: Color(hex: 0x5A4B3B),
        inkMuted: Color(hex: 0x3C3228).opacity(0.7),
        gold: Color(hex: 0x8A6322),
        goldBright: Color(hex: 0x7D5410),
        goldLine: Color(hex: 0x826028).opacity(0.17),
        jesus: Color(hex: 0x952219),
        surface: Color(hex: 0x3C2D19).opacity(0.035),
        panel: Color.white,
        pageTop: Color(hex: 0xF6F3EE),
        pageBottom: Color(hex: 0xEDE8DF),
        colorScheme: .light
    )
}

final class ThemeStore: ObservableObject {

    @Published var choice: ThemeChoice {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: key) }
    }

    private let key = "biblewish_theme"

    init() {
        let saved = UserDefaults.standard.string(forKey: key)
        self.choice = ThemeChoice(rawValue: saved ?? "") ?? .dark
    }

    func palette(for systemScheme: ColorScheme) -> ThemePalette {
        switch choice {
        case .dark: return .dark
        case .sepia: return .sepia
        case .light: return .light
        case .auto: return systemScheme == .dark ? .dark : .light
        }
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.dark
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

/// Applies the chosen theme: page background, palette in the environment, tint and color scheme.
struct ThemedRoot<Content: View>: View {
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) private var systemScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let palette = themeStore.palette(for: systemScheme)
        content
            .environment(\.palette, palette)
            .tint(palette.gold)
            .preferredColorScheme(themeStore.choice == .auto ? nil : palette.colorScheme)
            .background(palette.pageGradient.ignoresSafeArea())
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
