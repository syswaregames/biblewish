//
//  BookCardView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct BookCardView: View {
    
    @EnvironmentObject var viewModel: BibleViewModel
    
    let book: BibleBook
    
    let bookName: String
    let progress: Double

    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {

            Text(bookName)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text("\(Int(progress * 100))% read")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: viewModel.progressForBook(book))
                .progressViewStyle(.linear)
                .scaleEffect(y: 0.6)

        }
        .padding(12)
        .frame(minHeight: 110)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08))
        )
    }
}
