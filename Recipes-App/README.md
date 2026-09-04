# Recipes App (iOS)

The iOS half of the [Recipes App project](../README.md). A SwiftUI + SwiftData app for tracking a family pantry and recipe book, and answering "what can I make right now?"

For the project overview, the pipeline diagram, and the recipe JSON contract shared with the converter, see the [root README](../README.md). This file covers building and working on the app itself.

## Requirements

- macOS with **Xcode 15 or later** (SwiftData requires the iOS 17 SDK)
- Deployment target: **iOS 17.0+**
- Universal — iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`)
- Swift 5
- Simulator, or a real device with a free Apple Developer account for signing

## Build and run

1. Open **`RecipesApp.xcodeproj`**.
2. Pick a simulator from the device dropdown.
3. Press **⌘R**.

If Xcode complains about code signing: select the project in the navigator → **RecipesApp** target → **Signing & Capabilities** → set **Team** to your Apple ID (it appears once you've signed in under Xcode → Settings → Accounts). The bundle identifier is currently `com.example.RecipeFinderApp` — change it to something unique like `com.<yourname>.RecipesApp` before running on a device.

Testing the Shortcuts integration requires a **real device or a simulator with Shortcuts installed**; App Intents don't surface without it.

### Builds on a real device expire after 7 days

With a **free** Apple ID (no paid Developer Program membership), Xcode signs the build with a provisioning profile that is valid for **7 days**. After that the app stops launching on the device — iOS reports it as unavailable or unverifiable. Nothing is wrong with the code; re-run from Xcode over USB and the profile is reissued. Free accounts are also capped at 10 app IDs per 7 days.

A paid Developer Program membership raises the profile lifetime to a year. Separately, turn **Settings → App Store → Offload Unused Apps off** on any device running this build: an offloaded app is re-downloaded from the App Store, and a Xcode-installed app has nowhere to come back from.

## Screens

### Pantry
Everything currently on hand. Name is the only required field; quantity and category are optional. Each row has an in-stock toggle — tapping it flips the item and clears its quantity when it goes out of stock. Searchable by name, swipe to delete, tap a row to edit.

### Recipes
The recipe book. Each recipe has a name, freely-typed ingredients with optional free-form amounts, ordered instruction steps, and notes. The add/edit sheet suggests matching pantry items as you type an ingredient and flags ones that aren't in the pantry, but it never requires a match — **recipes and the pantry are independent lists**. Steps can be drag-reordered and deleted via the Edit button. Saving an edit replaces the recipe's ingredients wholesale.

The detail view checks each ingredient against the pantry and shows a green check for anything in stock.

### What Can I Make?
Splits the book into two sections:

- **Can Make Now** — every ingredient is in stock, sorted by name.
- **Almost There** — missing exactly one or two ingredients, with the missing items named, sorted by fewest missing first.

Recipes with no ingredients are excluded from both.

## Matching rules (v1)

All of it lives in `PantryMatcher.swift`:

- Names are normalized by trimming whitespace and lowercasing, then compared for **exact equality**.
- `"Flour"` in the pantry matches `"flour"` in a recipe. `"olive oil"` does **not** match `"extra virgin olive oil"`, and `"egg"` does not match `"eggs"`.
- **Only items marked in stock count.** An out-of-stock pantry item is treated as absent.

That's the one place to change when matching needs to get smarter — plurals, synonyms, or substring/fuzzy matching.

## Shortcuts integration

The app exposes an App Intent named **"Add Recipes"** (`AppIntents/AddRecipeIntent.swift`). It takes a single string parameter containing recipe JSON:

```json
{
  "dish_name": "Garlic Butter Shrimp Pasta",
  "ingredients": [{ "name": "shrimp", "quantity": "1 lb" }],
  "instructions": ["Boil the linguine.", "Saute garlic in butter."]
}
```

It decodes that, creates a `Recipe` with the instructions mapped onto ordered steps, and saves. `quantity` is optional and lands in `RecipeIngredient.amount`; a missing or empty `dish_name` is rejected. It does not touch pantry items.

This is the same shape the [Recipe-Converter](../Recipe-Converter/) server returns, so a Shortcut can pipe the server's response straight into this intent.

**Both the UI and the intent go through `SharedModelContainer.shared`** — a single `ModelContainer` built once for the whole app. This is load-bearing: if the intent built its own container, recipes saved from a Shortcut while the app was closed would land in a different store and never appear.

## Data model

```
PantryItem            name, quantity?, category?, inStock, dateAdded
Recipe                name, steps: [String], instructions: String, notes, dateCreated
  └── ingredients     @Relationship(deleteRule: .cascade)
RecipeIngredient      name, amount, recipe?
```

Deleting a `Recipe` cascades to its ingredients automatically.

`Recipe` carries **two** representations of its instructions. `steps` is the live one — an ordered array, one element per step. `instructions` is the original single-blob string, kept mirrored (steps joined by newlines) on every save for back-compat. `RecipeDetailView` renders `steps` when present and falls back to `instructions` for legacy recipes not yet re-saved; `AddRecipeView` migrates a legacy blob by splitting it on newlines. If you ever confirm no legacy rows are left, dropping `instructions` is a straightforward cleanup.

`RecipeIngredient.amount` is free-form display text (`"2 cups"`, `"to taste"`) and plays no part in matching.

## Project layout

```
Recipes-App/
├── RecipesApp.xcodeproj/
└── RecipesApp/
    ├── RecipesAppApp.swift          @main entry; attaches the shared container
    ├── ContentView.swift            root TabView
    ├── SharedModelContainer.swift   the one ModelContainer, shared with App Intents
    ├── AppIntents/
    │   └── AddRecipeIntent.swift    "Add Recipes" — the Shortcuts entry point
    ├── Pantry/
    │   ├── PantryItem.swift         @Model
    │   ├── PantryView.swift         Pantry tab + PantryRow
    │   └── AddPantryItemView.swift  add/edit sheet
    ├── Recipes/
    │   ├── Recipe.swift             @Model, cascades to ingredients
    │   ├── RecipeIngredient.swift   @Model
    │   ├── RecipesView.swift        Recipes tab
    │   ├── RecipeDetailView.swift   single-recipe detail
    │   └── AddRecipeView.swift      add/edit sheet
    ├── WhatCanIMake/
    │   ├── PantryMatcher.swift      normalization + missing-ingredient logic
    │   └── SearchView.swift         "What Can I Make?" tab
    └── Assets.xcassets/
        ├── AppIcon.appiconset/   single 1024×1024 universal icon
        └── AccentColor.colorset/  terracotta accent, light + dark variants
```

There is no `Preview Content/` folder — the previews use no bundled assets, so it and its `DEVELOPMENT_ASSET_PATHS` build setting were removed. If you later want sample images that ship only to previews and not to the app, re-add the folder and point that setting back at it.

## Notes for the developer

- **Storage is local to the device.** No CloudKit, so each family member's phone has its own pantry and recipe book. Adding sync means an iCloud container, the CloudKit entitlement, and making every model property optional or defaulted.
- **`SearchView` recomputes all matches on every render.** Fine at this scale; if the book grows into the hundreds, cache `pantryNames` and the missing lists.
- **Previews use `inMemory: true`** so SwiftUI previews don't write into the on-disk store. `ENABLE_PREVIEWS` is on; there are no preview-only bundled assets.
- **The accent color** (`AccentColor.colorset`) is terracotta, picked to match the icon: `#C9482A` in light mode, `#F2704A` in dark. It drives `.tint` — the step-number badges in `RecipeDetailView` and the pantry suggestions in `AddRecipeView`. One caveat: those badges draw white text on the tint, and the dark-mode variant only reaches about 3.4:1 against white. It's decorative numbering next to the step text, so it's legible, but if you want it to clear 4.5:1 use a darker dark-mode variant or switch the badge text to a dark color.
- **The app icon is a single 1024×1024 PNG** (`Assets.xcassets/AppIcon.appiconset/AppIcon.png`), RGB with no alpha channel — Xcode rejects icons with transparency. iOS applies its own rounded-corner mask, so the source art is full-bleed square.
- **Deletes are index-based against the *filtered* list** in `PantryView` and `RecipesView`, which is correct as written — the `onDelete` offsets refer to the same filtered array being rendered.
- There are no tests yet. `PantryMatcher` is pure and has no SwiftData dependency, so it's the obvious first thing to cover.

## If the project won't open

`project.pbxproj` was originally generated by script. If Xcode ever rejects it, rebuilding by hand takes about a minute:

1. Xcode → **File → New → Project…** → **iOS → App**.
2. Product Name `RecipesApp`, Interface **SwiftUI**, Language **Swift**, Storage **SwiftData**. Save it somewhere temporary.
3. Delete the auto-generated `ContentView.swift`, `Item.swift`, and `RecipesAppApp.swift`.
4. Drag the `RecipesApp/` source folders into the project navigator with **"Copy items if needed"** checked, **"Create groups"** selected, and the **RecipesApp** target ticked.
5. Build with **⌘R**.
