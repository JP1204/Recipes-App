# Recipes App

A two-part personal project for answering one question: **"what can I actually cook right now?"**

It's split into two modules that talk to each other over a small JSON contract:

| Module | What it is | Language |
|---|---|---|
| [`Recipe-Converter/`](Recipe-Converter/) | A Flask server that turns a TikTok cooking video into a structured recipe using Gemini | Python |
| [`Recipes-App/`](Recipes-App/) | A SwiftUI + SwiftData iOS app for the pantry, the recipe book, and pantry-aware matching | Swift |

Neither half requires the other. The app works fine with hand-entered recipes, and the server is a plain HTTP endpoint you could point anything at. Together they form the actual workflow below.

## The end-to-end flow

```
TikTok video
    │  share sheet
    ▼
iOS Shortcut ──POST {"tiktok_url": …}──►  Recipe-Converter (Flask)
                                              │  1. tikwm resolves the URL → direct .mp4
                                              │  2. download the video bytes
                                              │  3. base64 + send to Gemini with a response schema
                                              ▼
                                         structured recipe JSON
                                              │
Shortcut ──"Add Recipes" App Intent──► Recipes App (SwiftData store)
                                              │
                                              ▼
                                    Pantry matching → "What Can I Make?"
```

The download and base64 encoding live on the server on purpose: doing them inside Shortcuts on the phone was running the app out of memory and freezing it.

## The contract between the two halves

This JSON shape is the only coupling point. The server produces it (Gemini is constrained to it via a `responseSchema`), and the app's `AddRecipeIntent` consumes it.

```json
{
  "dish_name": "Garlic Butter Shrimp Pasta",
  "ingredients": [
    { "name": "shrimp",   "quantity": "1 lb" },
    { "name": "linguine", "quantity": "8 oz" }
  ],
  "instructions": [
    "Boil the linguine according to package instructions.",
    "Saute garlic in butter until fragrant."
  ]
}
```

`quantity` is optional; `dish_name`, `ingredients`, and `instructions` are required. Quantities are free-form display text — matching is done on names only. If you change this shape, change it in both `RECIPE_RESPONSE_SCHEMA` (server) and `AddRecipeIntent.Payload` (app).

## Repository layout

```
Recipes App/
├── README.md              ← you are here
├── Recipe-Converter/      ← Python module (see its own README for setup + API reference)
│   ├── recipe_server.py
│   └── requirements.txt
└── Recipes-App/           ← iOS module
    ├── README.md
    ├── RecipesApp.xcodeproj/
    └── RecipesApp/
        ├── RecipesAppApp.swift        @main entry
        ├── ContentView.swift          root TabView
        ├── SharedModelContainer.swift one ModelContainer for the UI and App Intents
        ├── AppIntents/
        │   └── AddRecipeIntent.swift  "Add Recipes" — the Shortcuts entry point
        ├── Pantry/                    PantryItem model + list/add views
        ├── Recipes/                   Recipe & RecipeIngredient models + list/detail/add views
        └── WhatCanIMake/              PantryMatcher + SearchView
```

## Recipe-Converter (Python)

A single Flask endpoint, `POST /extract-recipe`. Give it a TikTok URL, get back the JSON above.

```bash
cd Recipe-Converter
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
export GEMINI_API_KEY="your-key-here"
python recipe_server.py          # http://localhost:5000
```

Full setup, deployment, the API reference, and error codes are in **[`Recipe-Converter/README.md`](Recipe-Converter/README.md)**.

## Recipes App (iOS)

SwiftUI + SwiftData, targeting **iOS 17+**, built with Xcode 15 or later. Three tabs:

- **Pantry** — every item you have on hand. Name is the only required field; quantity and category are optional metadata, and each item carries an `inStock` flag. Searchable, swipe to delete, tap to edit.
- **Recipes** — your recipe book. Create a recipe with any number of ingredients and ordered steps. The detail view checks each ingredient against the pantry and marks what's in stock.
- **What Can I Make?** — splits the book into **Can Make Now** (every ingredient in stock) and **Almost There** (missing one or two, with the missing items named), sorted by fewest missing first.

Ingredients are typed freely — recipes and the pantry are independent lists, and pantry matching is shown as a hint, never enforced at entry time.

**Matching rules (v1):** case-insensitive, whitespace-trimmed, exact name. `"Flour"` in the pantry matches `"flour"` in a recipe; `"olive oil"` does not match `"extra virgin olive oil"`. Only items marked in stock count. All of this lives in `PantryMatcher.swift` — that's the one place to change when matching gets smarter.

**Shortcuts integration:** the app exposes an **"Add Recipes"** App Intent that takes the recipe JSON as a string parameter and writes a `Recipe` into the store. Both the UI and the intent go through `SharedModelContainer.shared`, so a recipe saved from a Shortcut while the app is closed shows up on next launch.

To run it: open `Recipes-App/RecipesApp.xcodeproj`, pick a simulator, press ⌘R. Setup details and code-signing notes are in [`Recipes-App/README.md`](Recipes-App/README.md).

## Current limitations

- **Storage is local to each device.** No CloudKit, so each phone has its own pantry and recipe book.
- **TikTok only.** The converter resolves URLs through tikwm; other sources aren't wired up.
- **~19 MB video ceiling**, imposed by Gemini's inline-data limit.
- **The server is unauthenticated.** Fine on localhost or a private ngrok URL; don't leave a public deployment open.
- **Matching is exact-name.** No plurals, synonyms, quantities, or units.

## Likely next steps

- CloudKit sync so the whole family shares one pantry
- Smarter matching (plurals, synonyms, substring/fuzzy)
- Quantities and units tracked properly, decremented on cook
- Shopping list built from the "Almost There" list
- Photos and tags on recipes
- Other video sources, or a paste-a-URL path that skips Shortcuts entirely
