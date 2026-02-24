//
//  TranslationSettingsView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-02-24.
//

import SwiftUI

struct TranslationSettingsView: View {
    @EnvironmentObject var viewModel: BibleViewModel

    var body: some View {
        List {
            Section {
                ForEach(BibleTranslation.allCases) { translation in
                    Button {
                        viewModel.selectedTranslation = translation
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(translation.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(translation.shortDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if viewModel.selectedTranslation == translation {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .font(.title3)
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Changing translation also updates search and reading progress for that translation.")
            }
        }
        .navigationTitle("Language & Version")
    }
}

#Preview {
    NavigationStack {
        TranslationSettingsView()
            .environmentObject(BibleViewModel())
    }
}
