//
//  SharedModelContainer.swift
//  RecipesApp
//
//  Single ModelContainer shared by the app UI and App Intents so
//  Shortcuts writes land in the same store the app reads.
//

import Foundation
import SwiftData

enum SharedModelContainer {
    static let shared: ModelContainer = {
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
}
