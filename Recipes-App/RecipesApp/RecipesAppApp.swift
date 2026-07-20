//
//  RecipesAppApp.swift
//  RecipesApp
//
//  App entry point. Sets up the SwiftData ModelContainer shared across all views.
//

import SwiftUI
import SwiftData

@main
struct RecipesAppApp: App {
    // One ModelContainer for the whole app, shared with App Intents.
    let modelContainer = SharedModelContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
