//
//  VerseCardView.swift
//
//  "Image": the selected verses on a picture to share or save, like the website's verse cards
//  (js/verse-card.js): Sunrise, Field, Sunset, Night or Gold, as a square post or a phone story.
//  Drawn on the device; nothing is uploaded.
//

import SwiftUI

enum VerseCardStyle: String, CaseIterable, Identifiable {
    case sunrise, field, sunset, night, gold
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var imageName: String? {
        switch self {
        case .sunrise: return "HeroMorning"
        case .field: return "HeroAfternoon"
        case .sunset: return "HeroEvening"
        case .night: return "HeroNight"
        case .gold: return nil
        }
    }
}

enum VerseCardFormat: String, CaseIterable, Identifiable {
    case square, story
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var size: CGSize { self == .square ? CGSize(width: 1080, height: 1080) : CGSize(width: 1080, height: 1920) }
}

/// The picture itself, laid out at its real pixel size.
struct VerseCardArtwork: View {
    let text: String
    let reference: String
    let translation: String
    let style: VerseCardStyle
    let format: VerseCardFormat

    var body: some View {
        let size = format.size
        ZStack {
            if let name = style.imageName {
                Color.clear.overlay {
                    Image(name).resizable().scaledToFill()
                }
                .clipped()
                Color.black.opacity(0.55)
            } else {
                LinearGradient(colors: [Color(hex: 0xE8C98A), Color(hex: 0xB98A3E)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            VStack(spacing: 44) {
                Rectangle()
                    .fill(accent.opacity(0.8))
                    .frame(width: 140, height: 3)
                Text(text)
                    .font(.system(size: fontSize, weight: .regular, design: .serif))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(fontSize * 0.25)
                    .minimumScaleFactor(0.5)
                Text("\(reference) (\(translation))")
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 110)
            .padding(.vertical, 150)

            VStack {
                Spacer()
                Text("BibleWish \u{00B7} biblewish.com")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(ink.opacity(0.7))
                    .padding(.bottom, 56)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var ink: Color { style == .gold ? Color(hex: 0x2A1B08) : .white }
    private var accent: Color { style == .gold ? Color(hex: 0x4A3010) : Color(hex: 0xE0BA78) }

    /// Shorter passages are set larger.
    private var fontSize: CGFloat {
        let base: CGFloat = format == .story ? 1.15 : 1
        switch text.count {
        case ..<90: return 84 * base
        case ..<200: return 68 * base
        case ..<400: return 54 * base
        case ..<700: return 44 * base
        default: return 36 * base
        }
    }
}

struct VerseCardView: View {
    let text: String
    let reference: String
    let translation: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var style: VerseCardStyle = Self.savedStyle
    @State private var format: VerseCardFormat = .square
    @State private var rendered: Image?

    private static let styleKey = "verse_card_style"
    private static var savedStyle: VerseCardStyle {
        VerseCardStyle(rawValue: UserDefaults.standard.string(forKey: styleKey) ?? "") ?? .sunrise
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    let size = format.size
                    VerseCardArtwork(text: text, reference: reference, translation: translation, style: style, format: format)
                        .scaleEffect(300 / size.width, anchor: .topLeading)
                        .frame(width: 300, height: 300 * size.height / size.width, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.goldLine))
                        .accessibilityLabel("Preview of the verse image")

                    chips(VerseCardStyle.allCases, selection: $style) { $0.title }
                    Picker("Shape", selection: $format) {
                        ForEach(VerseCardFormat.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    if let rendered {
                        ShareLink(item: rendered, preview: SharePreview(reference, image: rendered)) {
                            Label("Share image", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(palette.gold))
                                .foregroundStyle(palette.panel)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 20)
                .readableWidth(520)
            }
            .themedScreen()
            .navigationTitle("Verse image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task(id: "\(style.rawValue)-\(format.rawValue)") { render() }
        }
        .presentationDetents([.large])
    }

    private func chips<T: Identifiable & Equatable>(_ items: [T], selection: Binding<T>, title: @escaping (T) -> String) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button { selection.wrappedValue = item } label: {
                    Text(title(item))
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selection.wrappedValue == item ? palette.gold : palette.surface))
                        .overlay(Capsule().stroke(palette.goldLine))
                        .foregroundStyle(selection.wrappedValue == item ? palette.panel : palette.ink)
                }
                .accessibilityAddTraits(selection.wrappedValue == item ? .isSelected : [])
            }
        }
    }

    @MainActor private func render() {
        UserDefaults.standard.set(style.rawValue, forKey: Self.styleKey)
        let renderer = ImageRenderer(content: VerseCardArtwork(text: text, reference: reference, translation: translation, style: style, format: format))
        renderer.scale = 1
        if let image = renderer.uiImage { rendered = Image(uiImage: image) }
    }
}
