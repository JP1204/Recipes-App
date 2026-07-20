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
//  Creates the Recipe and adds any ingredients not already in the
//  pantry as out-of-stock PantryItems (i.e. "needed" items).
//

import AppIntents
import Foundation
import SwiftData

struct AddRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Recipes"
    static var description = IntentDescription(
        "Adds a recipe from JSON and creates pantry items for any missing ingredients."
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

        let name = payload.dish_name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw AddRecipeError.invalidJSON("dish_name is empty.")
        }

        let context = SharedModelContainer.shared.mainContext

        // Build the recipe. The instructions array maps directly onto the
        // recipe's ordered step list; the legacy string is kept mirrored.
        let cleanSteps = payload.instructions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let recipe = Recipe(
            name: name,
            steps: cleanSteps,
            instructions: cleanSteps.joined(separator: "\n")
        )
        recipe.ingredients = payload.ingredients.map {
            RecipeIngredient(name: $0.name, amount: $0.quantity ?? "")
        }
        context.insert(recipe)

        // Add pantry items for ingredients not already in the pantry.
        // New items are marked out of stock so they show up as needed.
        let existing = try context.fetch(FetchDescriptor<PantryItem>())
        var pantryNames = Set(existing.map { PantryMatcher.normalize($0.name) })

        var addedItems: [String] = []
        for ingredient in payload.ingredients {
            let normalized = PantryMatcher.normalize(ingredient.name)
            guard !normalized.isEmpty, !pantryNames.contains(normalized) else { continue }
            context.insert(PantryItem(name: ingredient.name, inStock: false))
            pantryNames.insert(normalized)
            addedItems.append(ingredient.name)
        }

        try context.save()

        let pantrySummary = addedItems.isEmpty
            ? "All ingredients were already in your pantry."
            : "Added \(addedItems.count) needed pantry item\(addedItems.count == 1 ? "" : "s"): \(addedItems.joined(separator: ", "))."
        return .result(dialog: "Added “\(name)” with \(recipe.ingredients.count) ingredients. \(pantrySummary)")
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
