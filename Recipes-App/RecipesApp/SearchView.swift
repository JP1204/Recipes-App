//
//  SearchView.swift
//  RecipesApp
//
//  "What Can I Make?" — splits recipes into:
//   • Can Make Now (every ingredient in stock in the pantry)
//   • Almost There (missing 1 or 2 ingredients), sorted by fewest missing.
//  Only pantry items marked in stock count as available.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var recipes: [Recipe]
    @Query private var pantry: [PantryItem]

    private var pantryNames: Set<String> {
        Set(pantry.filter(\.inStock).map { PantryMatcher.normalize($0.name) })
    }

    private func missingIngredients(for recipe: Recipe) -> [String] {
        PantryMatcher.missingIngredients(
            forIngredients: recipe.ingredients.map { $0.name },
            pantryNames: pantryNames
        )
    }

    private var canMakeNow: [Recipe] {
        recipes
            .filter { !$0.ingredients.isEmpty && missingIngredients(for: $0).isEmpty }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var almostThere: [(recipe: Recipe, missing: [String])] {
        recipes.compactMap { recipe -> (Recipe, [String])? in
            guard !recipe.ingredients.isEmpty else { return nil }
            let missing = missingIngredients(for: recipe)
            guard missing.count >= 1 && missing.count <= 2 else { return nil }
            return (recipe, missing)
        }
        .sorted { lhs, rhs in
            if lhs.1.count != rhs.1.count { return lhs.1.count < rhs.1.count }
            return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No Recipes Yet",
                        systemImage: "fork.knife",
                        description: Text("Add recipes on the Recipes tab to see matches here.")
                    )
                } else {
                    List {
                        Section("Can Make Now (\(canMakeNow.count))") {
                            if canMakeNow.isEmpty {
                                Text("Nothing matches your pantry yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(canMakeNow) { recipe in
                                    NavigationLink(value: recipe) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                            Text(recipe.name).font(.headline)
                                        }
                                    }
                                }
                            }
                        }

                        Section("Almost There — missing 1 or 2") {
                            if almostThere.isEmpty {
                                Text("No close matches. Try adding more pantry items.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(almostThere, id: \.recipe.id) { entry in
                                    NavigationLink(value: entry.recipe) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Image(systemName: entry.missing.count == 1
                                                      ? "1.circle.fill" : "2.circle.fill")
                                                    .foregroundStyle(.orange)
                                                Text(entry.recipe.name).font(.headline)
                                            }
                                            Text("Missing: \(entry.missing.joined(separator: ", "))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("What Can I Make?")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [PantryItem.self, Recipe.self, RecipeIngredient.self],
                        inMemory: true)
}
