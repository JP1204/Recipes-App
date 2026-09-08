//
//  AddRecipeIntent.swift
//  RecipesApp
//
//  "Add Recipes" App Intent for Shortcuts. Takes a JSON string:
//  {
//    "dish_name": "…",
//    "ingredients": [{"name": "…", "quantity": "…"}],
//    "instructions": ["step 1", "step 2"]
//  }
//  Decodes it and hands off to RecipeImporter (Recipes/RecipeImporter.swift)
//  to actually build and save the Recipe -- that logic is shared with the
//  Share Extension's import path, so this file's only job is "parse the
//  JSON text a Shortcut hands us." Recipes and the pantry are independent
//  lists -- this does not touch pantry items.
//

import AppIntents
import Foundation
import SwiftData

struct AddRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Recipes"
    static var description = IntentDescription(
        "Adds a recipe from JSON."
    )

    @Parameter(title: "Recipe JSON", description: "JSON with dish_name, ingredients, and instructions")
    var recipeJSON: String

    // MARK: - JSON payload

    private struct Payload: Decodable {
        struct Ingredient: Decodable {
            let name: String
            let quantity: String?
        }
        let dish_name: String
        let ingredients: [Ingredient]
        let instructions: [String]
    }

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let data = recipeJSON.data(using: .utf8) else {
            throw AddRecipeError.invalidJSON("Could not read the JSON text.")
        }

        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw AddRecipeError.invalidJSON(error.localizedDescription)
        }

        let recipe: Recipe
        do {
            recipe = try RecipeImporter.save(
                dishName: payload.dish_name,
                ingredients: payload.ingredients.map {
                    RecipeImporter.Ingredient(name: $0.name, quantity: $0.quantity)
                },
                instructions: payload.instructions,
                into: SharedModelContainer.shared.mainContext
            )
        } catch {
            throw AddRecipeError.invalidJSON(error.localizedDescription)
        }

        return .result(dialog: "Added “\(recipe.name)” with \(recipe.ingredients.count) ingredients.")
    }
}

enum AddRecipeError: Error, CustomLocalizedStringResourceConvertible {
    case invalidJSON(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidJSON(let detail):
            return "Invalid recipe JSON: \(detail)"
        }
    }
}
