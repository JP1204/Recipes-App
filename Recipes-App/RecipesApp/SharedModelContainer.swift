//
//  SharedModelContainer.swift
//  RecipesApp
//
//  Single ModelContainer shared by the app UI, App Intents (Shortcuts),
//  and the Share Extension, so writes from any of them land in the
//  same store the app reads.
//
//  The store lives in the App Group container rather than each
//  target's own sandbox: an extension and its host app are separate
//  processes with separate sandboxes, and an App Group container is
//  the one place both are allowed to read and write. This requires:
//
//   1. Adding the "App Groups" capability in Xcode's Signing &
//      Capabilities tab, on BOTH the RecipesApp target and the
//      RecipeShareExtension target.
//   2. Using the exact same group ID on both -- `appGroupID` below.
//
//  Until that's done, `containerURL(forSecurityApplicationGroupIdentifier:)`
//  returns nil and this falls back to a process-local store so the app
//  doesn't crash. In that fallback state the app and the extension are
//  silently writing to two different stores -- recipes added via the
//  Share Extension won't show up in the app until the App Group is
//  wired up on both targets.
//

import Foundation
import SwiftData

enum SharedModelContainer {
    /// Must match the App Group ID configured in both targets'
    /// Signing & Capabilities tabs.
    static let appGroupID = "group.com.example.RecipeFinderApp"

    static let shared: ModelContainer = {
        let schema = Schema([
            PantryItem.self,
            Recipe.self,
            RecipeIngredient.self
        ])

        let config: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let storeURL = groupURL.appendingPathComponent("RecipesApp.sqlite")
            config = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
