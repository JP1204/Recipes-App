//
//  RecipeIngredient.swift
//  RecipesApp
//
//  One line item in a recipe. The `amount` field is free-form text
//  ("2 cups", "to taste") and is display-only — pantry matching is by name.
//

import Foundation
import SwiftData

@Model
final class RecipeIngredient {
    var name: String
    var amount: String
    var recipe: Recipe?

    init(name: String, amount: String = "") {
        self.name = name
        self.amount = amount
    }
}
