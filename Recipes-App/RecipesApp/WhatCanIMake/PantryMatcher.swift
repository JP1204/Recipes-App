//
//  PantryMatcher.swift
//  RecipesApp
//
//  Shared logic for matching recipe ingredients against pantry contents.
//  v1 uses case-insensitive, whitespace-trimmed exact-name matching.
//

import Foundation

enum PantryMatcher {
    /// Canonical form of an ingredient/pantry name for matching purposes.
    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Returns the ingredient names in `recipe` that aren't present in `pantryNames`.
    /// `pantryNames` is expected to already be normalized via `normalize(_:)`.
    static func missingIngredients(forIngredients ingredientNames: [String],
                                   pantryNames: Set<String>) -> [String] {
        ingredientNames.filter { !pantryNames.contains(normalize($0)) }
    }
}
