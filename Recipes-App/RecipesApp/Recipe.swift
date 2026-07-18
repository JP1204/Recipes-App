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
    var instructions: String
    var notes: String
    var dateCreated: Date

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    init(name: String, instructions: String = "", notes: String = "") {
        self.name = name
        self.instructions = instructions
        self.notes = notes
        self.dateCreated = Date()
    }
}
