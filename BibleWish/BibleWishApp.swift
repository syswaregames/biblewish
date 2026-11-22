//
//  BibleWishApp.swift
//  BibleWish
//
//  Created by Patrick Carvalho on 2026-01-17.
//

import SwiftUI

@main
struct BibleWishApp: App {
    
    @StateObject private var viewModel = BibleViewModel()
    @StateObject private var themeStore = ThemeStore()
    
    var body: some Scene {
        WindowGroup {
            ThemedRoot {
                ContentView()
            }
            .environmentObject(viewModel)
            .environmentObject(themeStore)
        }
    }
}
