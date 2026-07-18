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
    // One ModelContainer for the whole app. SwiftData persists locally to disk.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            PantryItem.self,
            Recipe.self,
            RecipeIngredient.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
