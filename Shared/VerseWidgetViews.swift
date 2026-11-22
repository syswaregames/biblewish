//
//  VerseWidgetViews.swift
//
//  How the Verse of the Day widget looks. Plain SwiftUI with no WidgetKit types, so the app can
//  render it for checking. Compiled into the app and the widget.
//

import SwiftUI

enum VerseWidgetSize {
    case small, medium, large, lockRectangular, lockInline
}

private extension Color {
    init(widgetHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct VerseWidgetContent: View {

    let verse: WidgetVerse
    let size: VerseWidgetSize

    private let ink = Color(widgetHex: 0xE7DCCF)
    private let gold = Color(widgetHex: 0xC7A96B)

    /// The warm dark page the app uses.
    static var background: LinearGradient {
        LinearGradient(
            colors: [Color(widgetHex: 0x2A1F1A), Color(widgetHex: 0x0B0A09)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Group {
            switch size {
            case .lockInline:
                Text("\(verse.label) \u{00B7} \(verse.text)")
                    .lineLimit(1)
            case .lockRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(verse.label)
                        .font(.system(.caption, design: .serif, weight: .semibold))
                        .widgetAccentable()
                    Text(verse.text)
                        .font(.system(.caption, design: .serif))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .small, .medium, .large:
                page
            }
        }
        .environment(\.layoutDirection, verse.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if size != .small {
                Text("VERSE OF THE DAY")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(2)
                    .foregroundStyle(gold)
            }

            Text("\u{201C}\(verse.text)\u{201D}")
                .font(.system(size: textSize, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.6)
                .frame(maxHeight: .infinity, alignment: .topLeading)

            Text(verse.label)
                .font(.system(size: size == .small ? 12 : 13, weight: .semibold, design: .serif))
                .foregroundStyle(gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spacing: CGFloat { size == .small ? 6 : 8 }

    private var textSize: CGFloat {
        switch size {
        case .small: return 14
        case .medium: return 16
        default: return 21
        }
    }

    private var lineLimit: Int {
        switch size {
        case .small: return 7
        case .medium: return 4
        default: return 9
        }
    }
}
