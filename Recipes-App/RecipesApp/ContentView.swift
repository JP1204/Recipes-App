//
//  ContentView.swift
//  RecipesApp
//
//  Root TabView. Three tabs: Pantry, Recipes, and "What Can I Make?".
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PantryView()
                .tabItem { Label("Pantry", systemImage: "cabinet") }

            RecipesView()
                .tabItem { Label("Recipes", systemImage: "book") }

            SearchView()
                .tabItem { Label("What Can I Make?", systemImage: "fork.knife") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PantryItem.self, Recipe.self, RecipeIngredient.self],
                        inMemory: true)
}
