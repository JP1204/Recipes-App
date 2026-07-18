//
//  RecipesView.swift
//  RecipesApp
//
//  Lists every recipe. Tap to view detail, + to create, swipe to delete.
//

import SwiftUI
import SwiftData

struct RecipesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    @State private var showingAdd = false
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recipes }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No Recipes Yet",
                        systemImage: "book",
                        description: Text("Tap the + button to create your first recipe.")
                    )
                } else {
                    List {
                        ForEach(filteredRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.name).font(.headline)
                                    Text("\(recipe.ingredients.count) ingredient\(recipe.ingredients.count == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteFromList)
                    }
                    .searchable(text: $searchText, prompt: "Search recipes")
                }
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("New Recipe", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddRecipeView()
            }
        }
    }

    private func deleteFromList(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredRecipes[index])
        }
    }
}

#Preview {
    RecipesView()
        .modelContainer(for: [PantryItem.self, Recipe.self, RecipeIngredient.self],
                        inMemory: true)
}
