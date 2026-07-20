//
//  PantryItem.swift
//  RecipesApp
//
//  A single item in the pantry. Name is the only required field —
//  quantity & category are optional metadata.
//

import Foundation
import SwiftData

@Model
final class PantryItem {
    var name: String
    var quantity: String?    // display-only, e.g. "2 cans", "1 bag"
    var category: String?    // e.g. "Produce", "Spices"
    var inStock: Bool = true // whether the item is currently on hand
    var dateAdded: Date

    init(name: String, quantity: String? = nil, category: String? = nil, inStock: Bool = true) {
        self.name = name
        self.quantity = quantity
        self.category = category
        self.inStock = inStock
        self.dateAdded = Date()
    }
}
