//
//  SettingsView.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            NavigationLink("Reading Font") {
                FontSettingsView()
            }
        }
        .navigationTitle("Settings")
        
        VStack(spacing: 12) {

            
            Text("BibleWish")
                .font(.headline)

            Image("BibleWishLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .opacity(0.9)
            
            Divider()
                .padding(.vertical, 12)

            VStack(spacing: 6) {

                Text("""
                “The fear of the Lord is the beginning of wisdom:
                and the knowledge of the holy is understanding.”
                """)
                .font(.footnote)
                .italic()
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Text("Proverbs 9:10")
                    .font(.caption)
                    .foregroundColor(.secondary)

            }
            .padding(.horizontal, 24)


            Text("© \(String(Calendar.current.component(.year, from: Date()))) BibleWish")

            Text("Created and designed by Patrick Carvalho")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            //.padding(.vertical, 8)

            Link(destination: URL(string: "https://instagram.com/patricksysware")!) {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Text("@patricksysware")
                }
            }
            
            Divider()
            
            .font(.footnote)
            .foregroundColor(.secondary)

        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)



    }
}

#Preview {
    SettingsView()
}
