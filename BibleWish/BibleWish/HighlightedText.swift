//
//  HighlightedText.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct HighlightedText: View {

    let text: String
    let query: String

    var body: some View {
        buildText()
    }

    private func buildText() -> Text {
        guard !query.isEmpty else {
            return Text(text)
        }

        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()

        var result = Text("")
        var currentIndex = lowerText.startIndex

        while let range = lowerText.range(
            of: lowerQuery,
            range: currentIndex..<lowerText.endIndex
        ) {
            let before = String(text[currentIndex..<range.lowerBound])
            if !before.isEmpty {
                result = result + Text(before)
            }

            let match = String(text[range])
            result = result + Text(match)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)

            currentIndex = range.upperBound
        }

        let remainder = String(text[currentIndex..<lowerText.endIndex])
        if !remainder.isEmpty {
            result = result + Text(remainder)
        }

        return result
    }
}
