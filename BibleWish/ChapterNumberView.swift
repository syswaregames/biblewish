//
//  ChapterNumberView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct ChapterNumberView: View {

    let number: Int
    let isCompleted: Bool

    @Environment(\.palette) private var palette
    /// The tile grows with the text size (ChapterListView sizes its grid the same way).
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 60

    var body: some View {
        Text("\(number)")
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(isCompleted ? palette.goldBright : palette.ink)
            .frame(width: tile, height: tile)
            .themedCard(fill: isCompleted ? palette.gold.opacity(0.18) : nil)
            .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}
