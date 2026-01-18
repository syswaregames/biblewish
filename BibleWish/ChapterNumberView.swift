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

    private var backgroundColor: Color {
            guard isCompleted else {
                return  Color.primary.opacity(0.35) // not completed
            }
            return Color(.secondarySystemBackground) // completed
        }
    
    var body: some View {
        Text("\(number)")
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
            .frame(width: 60, height: 60)
            .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(backgroundColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.15))
                        )
        
            .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}
