//
//  FontSettingsView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct FontSettingsView: View {

    @EnvironmentObject var readerSettings: ReaderSettings

    var body: some View {
        Form {

            Section(header: Text("Font Size")) {
                Slider(
                    value: $readerSettings.fontSize,
                    in: 14...28,
                    step: 1
                )
                Text("Size: \(Int(readerSettings.fontSize))")
                    .font(.caption)
            }

            Section(header: Text("Font Style")) {
                Picker("Font", selection: $readerSettings.font) {
                    ForEach(ReaderFont.allCases) { font in
                        Text(font.displayName).tag(font)
                    }
                }
                .pickerStyle(.segmented)
            }


            // MARK: - Preview
                        Section(header: Text("Preview")) {
                            Text("In the beginning God created the heaven and the earth.")
                                .font(
                                    .system(
                                        size: readerSettings.fontSize,
                                        design: readerSettings.font.fontDesign
                                    )
                                )
                                .lineSpacing(6)
                                .padding(.vertical)
                        }
                    }
                    .navigationTitle("Reading Font")
    }
}
