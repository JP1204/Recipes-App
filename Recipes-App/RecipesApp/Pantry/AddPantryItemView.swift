//
//  AddPantryItemView.swift
//  RecipesApp
//
//  Sheet to add or edit a pantry item. Name required; quantity & category
//  optional. Pass an existing item to edit it; omit to create a new one.
//

import SwiftUI
import SwiftData

struct AddPantryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// When set, the form edits this item instead of creating a new one.
    var item: PantryItem?

    @State private var name: String
    @State private var quantity: String
    @State private var category: String
    @State private var inStock: Bool

    init(item: PantryItem? = nil) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item?.quantity ?? "")
        _category = State(initialValue: item?.category ?? "")
        _inStock = State(initialValue: item?.inStock ?? true)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (e.g. Flour, Eggs)", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Optional details") {
                    Toggle("In stock", isOn: $inStock)
                    TextField("Quantity (e.g. 2 cans)", text: $quantity)
                        .disabled(!inStock)
                        .foregroundStyle(inStock ? .primary : .secondary)
                    TextField("Category (e.g. Produce)", text: $category)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(item == nil ? "Add Pantry Item" : "Edit Pantry Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalQuantity = (!inStock || trimmedQuantity.isEmpty) ? nil : quantity
        let finalCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category

        if let item {
            item.name = trimmedName
            item.quantity = finalQuantity
            item.category = finalCategory
            item.inStock = inStock
        } else {
            let newItem = PantryItem(
                name: trimmedName,
                quantity: finalQuantity,
                category: finalCategory,
                inStock: inStock
            )
            context.insert(newItem)
        }
        dismiss()
    }
}

#Preview {
    AddPantryItemView()
        .modelContainer(for: [PantryItem.self, Recipe.self, RecipeIngredient.self],
                        inMemory: true)
}
