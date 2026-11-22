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

    var body: some View {
        Text("\(number)")
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(isCompleted ? palette.goldBright : palette.ink)
            .frame(width: 60, height: 60)
            .themedCard(fill: isCompleted ? palette.gold.opacity(0.18) : nil)
            .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}
