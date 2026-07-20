//
//  Recipe.swift
//  RecipesApp
//
//  A recipe owns a list of RecipeIngredient. Deleting a Recipe cascades
//  and removes its ingredients automatically.
//

import Foundation
import SwiftData

@Model
final class Recipe {
    var name: String
    /// Ordered, step-by-step instructions. Each element is one step.
    var steps: [String] = []
    /// Legacy single-blob instructions, kept for migration/back-compat.
    var instructions: String
    var notes: String
    var dateCreated: Date

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    init(name: String, steps: [String] = [], instructions: String = "", notes: String = "") {
        self.name = name
        self.steps = steps
        self.instructions = instructions
        self.notes = notes
        self.dateCreated = Date()
    }
}
