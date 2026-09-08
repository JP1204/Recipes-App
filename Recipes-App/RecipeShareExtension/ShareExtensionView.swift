//
//  ShareExtensionView.swift
//  RecipeShareExtension
//
//  The extension's entire visible UI: a small sheet that runs the
//  import pipeline against the shared TikTok link and shows progress,
//  success, or an error. It never touches SwiftData directly -- it
//  calls TikTokRecipeClient to do the network side, then RecipeImporter
//  (shared with the main app target -- see
//  ../RecipesApp/Recipes/RecipeImporter.swift) to save the result,
//  which is the exact same save path the Shortcut/AddRecipeIntent uses.
//

import SwiftUI
import SwiftData

struct ShareExtensionView: View {
    let sharedURL: URL?
    let onDone: () -> Void

    @State private var state: ImportState = .working

    enum ImportState {
        case working
        case success(dishName: String, ingredientCount: Int)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch state {
                case .working:
                    ProgressView("Extracting recipe…")
                        .padding()
                case .success(let dishName, let count):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("Added “\(dishName)”")
                        .font(.headline)
                    Text("\(count) ingredient\(count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                case .failure(let message):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("Couldn't add recipe")
                        .font(.headline)
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Recipes App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .task { await run() }
    }

    @MainActor
    private func run() async {
        guard let sharedURL else {
            state = .failure("No TikTok link was shared.")
            return
        }
        do {
            let recipe = try await TikTokRecipeClient.extractRecipe(from: sharedURL)
            let saved = try RecipeImporter.save(
                dishName: recipe.dishName,
                ingredients: recipe.ingredients.map {
                    RecipeImporter.Ingredient(name: $0.name, quantity: $0.quantity)
                },
                instructions: recipe.instructions,
                into: SharedModelContainer.shared.mainContext
            )
            state = .success(dishName: saved.name, ingredientCount: saved.ingredients.count)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
