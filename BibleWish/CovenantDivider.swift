//
//  CovenantDivider.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct CovenantDivider: View {

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 6) {

           

            HStack(spacing: 8) {
                Rectangle()
                    .fill(palette.goldLine)
                    .frame(height: 1)

                Image(systemName: "cross")
                    .font(.caption)
                    .foregroundStyle(palette.gold)

                Rectangle()
                    .fill(palette.goldLine)
                    .frame(height: 1)
            }

            Text("The Gospel of Grace")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(palette.inkMuted)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
