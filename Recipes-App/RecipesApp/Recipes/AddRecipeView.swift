//
//  AddRecipeView.swift
//  RecipesApp
//
//  Sheet to create or edit a recipe. Pass an existing recipe to edit it;
//  omit to create a new one. Ingredients are typed freely — recipes and
//  the pantry are independent lists; pantry matching (used elsewhere for
//  "What Can I Make?") is shown here only as a hint, never required.
//

import SwiftUI
import SwiftData

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.name) private var pantryItems: [PantryItem]

    /// When set, the form edits this recipe instead of creating a new one.
    var recipe: Recipe?

    @State private var name: String
    @State private var steps: [DraftStep]
    @State private var notes: String
    @State private var ingredients: [DraftIngredient]
    @FocusState private var focusedIngredient: UUID?

    /// In-memory draft (not persisted until Save).
    struct DraftIngredient: Identifiable, Hashable {
        let id = UUID()
        var name: String = ""
        var amount: String = ""
    }

    /// In-memory draft for one instruction step.
    struct DraftStep: Identifiable, Hashable {
        let id = UUID()
        var text: String = ""
    }

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _name = State(initialValue: recipe?.name ?? "")
        _notes = State(initialValue: recipe?.notes ?? "")

        // Seed steps from the recipe's step list, or migrate a legacy
        // single-blob `instructions` string by splitting it into lines.
        let existingSteps = recipe?.steps ?? []
        let seededSteps: [DraftStep]
        if !existingSteps.isEmpty {
            seededSteps = existingSteps.map { DraftStep(text: $0) }
        } else if let legacy = recipe?.instructions,
                  !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            seededSteps = legacy
                .split(whereSeparator: \.isNewline)
                .map { DraftStep(text: String($0).trimmingCharacters(in: .whitespaces)) }
        } else {
            seededSteps = []
        }
        _steps = State(initialValue: seededSteps.isEmpty ? [DraftStep()] : seededSteps)

        let drafts = (recipe?.ingredients ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { DraftIngredient(name: $0.name, amount: $0.amount) }
        _ingredients = State(initialValue: drafts.isEmpty ? [DraftIngredient()] : drafts)
    }

    /// 1-based position of a step, for display numbering.
    private func stepNumber(for step: DraftStep) -> Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalized pantry name → canonical display name.
    private var pantryLookup: [String: String] {
        Dictionary(pantryItems.map { (PantryMatcher.normalize($0.name), $0.name) },
                   uniquingKeysWith: { first, _ in first })
    }

    private func isInPantry(_ name: String) -> Bool {
        pantryLookup[PantryMatcher.normalize(name)] != nil
    }

    /// Pantry names matching the typed text (excluding an exact match).
    private func suggestions(for text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmed.isEmpty
            ? pantryItems.map(\.name)
            : pantryItems.map(\.name).filter {
                $0.localizedCaseInsensitiveContains(trimmed)
                    && PantryMatcher.normalize($0) != PantryMatcher.normalize(trimmed)
            }
        return Array(matches.prefix(6))
    }

    private var hasAnyIngredient: Bool {
        ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && hasAnyIngredient
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name (e.g. Chicken Curry)", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    ForEach($ingredients) { $ing in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Ingredient", text: $ing.name)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($focusedIngredient, equals: ing.id)

                            if !ing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                && !isInPantry(ing.name) && focusedIngredient != ing.id {
                                Text("Not currently in pantry")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if focusedIngredient == ing.id {
                                ForEach(suggestions(for: ing.name), id: \.self) { suggestion in
                                    Button {
                                        ing.name = suggestion
                                        focusedIngredient = nil
                                    } label: {
                                        Label(suggestion, systemImage: "arrow.up.left")
                                            .font(.subheadline)
                                            .foregroundStyle(.tint)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            TextField("Amount (optional, e.g. 2 cups)", text: $ing.amount)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        ingredients.remove(atOffsets: offsets)
                        if ingredients.isEmpty {
                            ingredients.append(DraftIngredient())
                        }
                    }

                    Button {
                        ingredients.append(DraftIngredient())
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    if !pantryItems.isEmpty {
                        Text("Type any ingredient. Matching pantry items are suggested as you type, but recipes don't need to match your pantry.")
                    }
                }

                Section {
                    ForEach($steps) { $step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(stepNumber(for: step)).")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            TextField("Describe this step",
                                      text: $step.text,
                                      axis: .vertical)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    .onMove { indices, newOffset in
                        steps.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { offsets in
                        steps.remove(atOffsets: offsets)
                        if steps.isEmpty { steps.append(DraftStep()) }
                    }

                    Button {
                        steps.append(DraftStep())
                    } label: {
                        Label("Add Step", systemImage: "plus.circle")
                    }
                } header: {
                    HStack {
                        Text("Instructions")
                        Spacer()
                        if steps.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
                            EditButton()
                                .font(.body)
                                .textCase(nil)
                        }
                    }
                } footer: {
                    Text("Tap a step to edit. Tap Edit to drag-reorder or delete steps.")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        // Trim each step and drop empties, preserving order.
        let cleanSteps = steps
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let target: Recipe
        if let recipe {
            target = recipe
            target.name = trimmedName
            target.steps = cleanSteps
            // Keep the legacy field mirrored so nothing else breaks.
            target.instructions = cleanSteps.joined(separator: "\n")
            target.notes = notes
            // Replace ingredients wholesale — simplest way to apply edits.
            for ing in target.ingredients {
                context.delete(ing)
            }
            target.ingredients.removeAll()
        } else {
            target = Recipe(name: trimmedName,
                            steps: cleanSteps,
                            instructions: cleanSteps.joined(separator: "\n"),
                            notes: notes)
            context.insert(target)
        }

        for draft in ingredients {
            let cleanName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanName.isEmpty else { continue }
            let ing = RecipeIngredient(name: cleanName, amount: draft.amount)
            ing.recipe = target
            target.ingredients.append(ing)
            context.insert(ing)
        }
        dismiss()
    }
}

#Preview {
    AddRecipeView()
        .modelContainer(for: [PantryItem.self, Recipe.self, RecipeIngredient.self],
                        inMemory: true)
}
