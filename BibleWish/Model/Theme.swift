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

/// Sepia and Light use slightly deeper muted ink and gold than biblewish.com so small text keeps a
/// contrast ratio of at least 4.5:1 on the whole page gradient (checked against the page, bottom of
/// the page and panel colors). Dark already passes.
struct ThemePalette {
    let ink: Color
    let inkSoft: Color
    let inkMuted: Color
    let gold: Color
    let goldBright: Color
    let goldLine: Color
    let jesus: Color
    let greenInk: Color
    let violetInk: Color
    let tealInk: Color
    let roseInk: Color
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
        greenInk: Color(hex: 0xC9E8C0),
        violetInk: Color(hex: 0xBEA4F2),
        tealInk: Color(hex: 0x84D6CD),
        roseInk: Color(hex: 0xF4A593),
        surface: Color.white.opacity(0.03),
        panel: Color(hex: 0x17120E),
        pageTop: Color(hex: 0x2A1F1A),
        pageBottom: Color(hex: 0x0B0A09),
        colorScheme: .dark
    )

    static let sepia = ThemePalette(
        ink: Color(hex: 0x3A2A1B),
        inkSoft: Color(hex: 0x6B5139),
        inkMuted: Color(hex: 0x543E28).opacity(0.82),
        gold: Color(hex: 0x7E5718),
        goldBright: Color(hex: 0x6E4A12),
        goldLine: Color(hex: 0x8C6224).opacity(0.2),
        jesus: Color(hex: 0x8E2A22),
        greenInk: Color(hex: 0x2F6B2A),
        violetInk: Color(hex: 0x5B3FA8),
        tealInk: Color(hex: 0x1F6F66),
        roseInk: Color(hex: 0xA3352B),
        surface: Color(hex: 0x785424).opacity(0.05),
        panel: Color(hex: 0xF6ECD6),
        pageTop: Color(hex: 0xF7EEDB),
        pageBottom: Color(hex: 0xE8D9BB),
        colorScheme: .light
    )

    static let light = ThemePalette(
        ink: Color(hex: 0x1F1A15),
        inkSoft: Color(hex: 0x5A4B3B),
        inkMuted: Color(hex: 0x3C3228).opacity(0.76),
        gold: Color(hex: 0x805A1C),
        goldBright: Color(hex: 0x6F4C14),
        goldLine: Color(hex: 0x826028).opacity(0.17),
        jesus: Color(hex: 0x952219),
        greenInk: Color(hex: 0x2A6326),
        violetInk: Color(hex: 0x523799),
        tealInk: Color(hex: 0x1B645C),
        roseInk: Color(hex: 0xB02E25),
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
            .foregroundStyle(palette.ink)
            .preferredColorScheme(themeStore.choice == .auto ? nil : palette.colorScheme)
            .background(palette.pageGradient.ignoresSafeArea())
    }
}

/// Page gradient behind a screen, plus bars that match the theme.
struct ThemedScreen: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .background(palette.pageGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.panel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(palette.panel, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

/// A themed gold-hairline card, as used on the website's tiles.
struct ThemedCard: ViewModifier {
    @Environment(\.palette) private var palette
    var cornerRadius: CGFloat = 12
    var fill: Color?

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill ?? palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(palette.goldLine)
            )
    }
}

private struct ThemedListRows: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .listRowBackground(palette.surface)
            .listRowSeparatorTint(palette.goldLine)
    }
}

/// Row background for list rows: a warm panel instead of the system's grey.
struct ThemedRowBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.panel.opacity(0.7)
    }
}

/// Keeps content to a comfortable reading width and centers it on wide screens (iPad). On an iPhone
/// the screen is already narrower, so nothing changes.
struct ReadableWidth: ViewModifier {
    var maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func readableWidth(_ maxWidth: CGFloat = 680) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }

    /// Apply to list rows or to a whole `Section`.
    func themedRows() -> some View { listRowBackground(ThemedRowBackground()) }

    func themedScreen() -> some View { modifier(ThemedScreen()) }

    func themedList() -> some View {
        modifier(ThemedListRows()).modifier(ThemedScreen())
    }

    func themedCard(cornerRadius: CGFloat = 12, fill: Color? = nil) -> some View {
        modifier(ThemedCard(cornerRadius: cornerRadius, fill: fill))
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
