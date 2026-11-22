//
//  BookCardView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct BookCardView: View {
    
    @EnvironmentObject var viewModel: BibleViewModel
    @Environment(\.palette) private var palette
    
    let book: BibleBook
    
    let bookName: String
    let progress: Double

    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {

            Text(bookName)
                .font(.system(.callout, design: .serif, weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text("\(Int(progress * 100))% read")
                .font(.caption)
                .foregroundStyle(palette.inkMuted)

            ProgressView(value: viewModel.progressForBook(book))
                .progressViewStyle(.linear)
                .tint(palette.gold)
                .scaleEffect(y: 0.6)

        }
        .padding(12)
        .frame(minHeight: 110)
        .themedCard()
    }
}
