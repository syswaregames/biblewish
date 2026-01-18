//
//  CovenantDivider.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

struct CovenantDivider: View {

    var body: some View {
        VStack(spacing: 6) {

           

            HStack(spacing: 8) {
                Rectangle()
                    .frame(height: 1)
                    .opacity(0.2)

                Image(systemName: "cross")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Rectangle()
                    .frame(height: 1)
                    .opacity(0.2)
            }

            Text("The Gospel of Grace")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}
