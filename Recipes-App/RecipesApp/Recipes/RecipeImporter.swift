//
//  RecipeImporter.swift
//  RecipesApp
//
//  Turns already-parsed recipe pieces (dish name, ingredients,
//  instructions) into a saved `Recipe`. This is the single place that
//  logic lives -- both entry points that bring recipes in from outside
//  the app funnel through here:
//
//   - AddRecipeIntent: the Shortcuts path. Receives raw JSON text,
//     decodes it into these same pieces, then calls `save`.
//   - RecipeShareExtension (see ../../RecipeShareExtension): the Share
//     Sheet path. TikTokRecipeClient resolves the video and calls
//     Gemini directly, then calls `save` with the typed result.
//
//  Keeping this in one place means a change to "what counts as a valid
//  recipe" or "how ingredients get attached" only has to happen once.
//

import Foundation
import SwiftData

enum RecipeImporter {
    struct Ingredient {
        let name: String
        let quantity: String?
    }

    enum ImportError: LocalizedError {
        case emptyName

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "The recipe's dish name was empty."
            }
        }
    }

    /// Builds a `Recipe` from its parts, inserts it into `context`, and
    /// saves. Throws `ImportError.emptyName` if `dishName` is blank
    /// after trimming.
    @discardableResult
    static func save(
        dishName: String,
        ingredients: [Ingredient],
        instructions: [String],
        into context: ModelContext
    ) throws -> Recipe {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ImportError.emptyName }

        // The instructions array maps directly onto the recipe's ordered
        // step list; the legacy joined-string field is kept mirrored for
        // any code that still reads `instructions` as one blob.
        let cleanSteps = instructions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let recipe = Recipe(
            name: name,
            steps: cleanSteps,
            instructions: cleanSteps.joined(separator: "\n")
        )
        recipe.ingredients = ingredients.map {
            RecipeIngredient(name: $0.name, amount: $0.quantity ?? "")
        }

        context.insert(recipe)
        try context.save()
        return recipe
    }
}
