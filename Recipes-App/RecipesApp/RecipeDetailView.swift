//
//  RecipeDetailView.swift
//  RecipesApp
//
//  Detail screen for one recipe. Shows ingredients with check marks for
//  items currently in stock in the pantry, plus instructions and notes.
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Query private var pantry: [PantryItem]
    @State private var showingEdit = false

    private var pantryNames: Set<String> {
        Set(pantry.filter(\.inStock).map { PantryMatcher.normalize($0.name) })
    }

    var body: some View {
        Form {
            Section("Ingredients") {
                if recipe.ingredients.isEmpty {
                    Text("No ingredients").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedIngredients) { ing in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: have(ing) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(have(ing) ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name)
                                if !ing.amount.trimmingCharacters(in: .whitespaces).isEmpty {
                                    Text(ing.amount)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !recipe.instructions.trimmingCharacters(in: .whitespaces).isEmpty {
                Section("Instructions") {
                    Text(recipe.instructions)
                }
            }

            if !recipe.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                Section("Notes") {
                    Text(recipe.notes)
                }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddRecipeView(recipe: recipe)
        }
    }

    private var sortedIngredients: [RecipeIngredient] {
        recipe.ingredients.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func have(_ ing: RecipeIngredient) -> Bool {
        pantryNames.contains(PantryMatcher.normalize(ing.name))
    }
}
