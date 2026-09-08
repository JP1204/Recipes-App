# RecipeShareExtension

An iOS Share Extension: the target that makes "share a TikTok cooking
video → it shows up in Recipes App" work with zero setup, for anyone
who has the app installed. This replaces the old iOS Shortcut, which
required every user to manually import and wire up a Shortcut
themselves.

## Why this exists instead of the Shortcut

The Shortcut worked, but it was a separate thing each person had to
install and configure. A Share Extension ships inside the app bundle:
the moment `RecipesApp` is installed, iOS registers it with the system
Share Sheet automatically, so it just appears as a share target from
TikTok (or Safari) without the user doing anything.

## Files

- `ShareViewController.swift` — the extension's entry point (set as
  `NSExtensionPrincipalClass` in Info.plist). Pulls the shared TikTok
  URL out of the extension context and hands it to `ShareExtensionView`.
- `ShareExtensionView.swift` — the small SwiftUI sheet shown while the
  recipe is being extracted, and the success/error state after.
- `TikTokRecipeClient.swift` — resolves the TikTok URL via tikwm
  **on-device** (tikwm blocks Render's datacenter IPs — see
  `../Recipe-Converter/README.md`), then POSTs to the Recipe-Converter
  backend for the actual video download + Gemini extraction.
- `Info.plist` — declares this as a share extension that accepts one
  shared URL or piece of text.

This target does **not** contain its own copy of the `Recipe` /
`RecipeIngredient` models or the save logic — see "Shared files" below.

## One-time Xcode setup (manual — can't be scripted from outside Xcode)

1. **Create the target.** In Xcode: File → New → Target → Share
   Extension. Name it `RecipeShareExtension`, language Swift, and let
   Xcode embed it in the `RecipesApp` target. Xcode will generate its
   own placeholder `ShareViewController.swift` / storyboard / Info.plist
   — delete those and add the files already in this folder instead
   (File → Add Files to "RecipesApp"…, select this folder's `.swift`
   files and `Info.plist`, target: RecipeShareExtension only).

2. **Shared files.** Select each of these in the Project Navigator,
   open the File Inspector (⌥⌘1), and check the `RecipeShareExtension`
   box under Target Membership (in addition to the existing `RecipesApp`
   box):
   - `RecipesApp/PantryItem.swift`
   - `RecipesApp/Recipes/Recipe.swift`
   - `RecipesApp/Recipes/RecipeIngredient.swift`
   - `RecipesApp/Recipes/RecipeImporter.swift`
   - `RecipesApp/SharedModelContainer.swift`

   All four model/container files need to be compiled into both
   targets — the extension builds its own `ModelContainer` pointed at
   the same store file, and SwiftData needs the schema (including
   `PantryItem`, even though the extension never touches pantry items)
   to match exactly on both sides.

3. **App Groups.** On **both** targets (`RecipesApp` and
   `RecipeShareExtension`), Signing & Capabilities → + Capability →
   App Groups → add `group.com.example.RecipeFinderApp`. Xcode creates
   and wires up the `.entitlements` file for you here — nothing to
   hand-edit. This must match `SharedModelContainer.appGroupID` exactly.

4. **Backend URL.** In `TikTokRecipeClient.swift`, update
   `backendBaseURL` to your actual deployed Render URL.

5. Build and run. Share a TikTok video URL (from the TikTok app, or a
   Safari tab on a TikTok page) and "Recipes App" should appear in the
   Share Sheet.

## Notes and limits

- Same tikwm caveats as the old Shortcut/server flow apply — see
  `../Recipe-Converter/README.md`'s notes section.
- Share Extensions have a tighter memory ceiling (~120MB) than the main
  app. This one only ever handles a URL string and a small JSON
  dictionary — the actual video bytes are downloaded and processed on
  Render, never in this process — so that ceiling isn't a practical
  concern here.
- If recipes added via the Share Extension aren't showing up in the
  app, step 3 (App Groups) is the most likely thing that's missing or
  mismatched — see the comment at the top of `SharedModelContainer.swift`.
