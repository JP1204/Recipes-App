//
//  PantryView.swift
//  RecipesApp
//
//  Lists every pantry item. Tap + to add. Swipe a row to delete.
//

import SwiftUI
import SwiftData

struct PantryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.name) private var items: [PantryItem]

    @State private var showingAdd = false
    @State private var editingItem: PantryItem?
    @State private var searchText = ""

    private var filteredItems: [PantryItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Pantry is empty",
                        systemImage: "cabinet",
                        description: Text("Tap the + button to add your first item.")
                    )
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            PantryRow(item: item) {
                                editingItem = item
                            }
                        }
                        .onDelete(perform: deleteFromList)
                    }
                    .searchable(text: $searchText, prompt: "Search pantry")
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddPantryItemView()
            }
            .sheet(item: $editingItem) { item in
                AddPantryItemView(item: item)
            }
        }
    }

    private func deleteFromList(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredItems[index])
        }
    }
}

private struct PantryRow: View {
    @Bindable var item: PantryItem
    var onTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.inStock.toggle()
                if !item.inStock { item.quantity = nil }
            } label: {
                Image(systemName: item.inStock ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.inStock ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.inStock ? "In stock" : "Out of stock")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(item.inStock ? .primary : .secondary)
                HStack(spacing: 6) {
                    if !item.inStock {
                        Text("Out of stock")
                    } else if let q = item.quantity, !q.isEmpty {
                        Text(q)
                    }
                    if let c = item.category, !c.isEmpty {
                        if !item.inStock || item.quantity?.isEmpty == false {
                            Text("•")
                        }
                        Text(c)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PantryView()
        .modelContainer(for: [PantryItem.self, Recipe.self, RecipeIngredient.self],
                        inMemory: true)
}
