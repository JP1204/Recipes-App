//
//  TikTokRecipeClient.swift
//  RecipeShareExtension
//
//  Talks to tikwm and to the Recipe-Converter backend (recipe_server.py,
//  in the sibling Recipe-Converter/ folder, deployed on Render).
//
//  tikwm resolution happens here, on-device, rather than on the Render
//  server: tikwm returns a bare 403 to requests coming from Render's
//  datacenter IPs, but has no problem with a normal iPhone making the
//  same request. Only the resolved direct video URL -- not the original
//  TikTok page URL -- gets sent to Render, which still does the actual
//  heavy lifting (downloading the video, base64-encoding it, asking
//  Gemini to extract the recipe). See recipe_server.py's `video_url`
//  request field, which this relies on.
//

import Foundation

enum TikTokRecipeClient {
    /// The Recipe-Converter server's base URL. Update this to your
    /// deployed Render URL.
    static let backendBaseURL = URL(string: "https://recipes-app-ssoa.onrender.com")!

    struct DecodedIngredient {
        let name: String
        let quantity: String?
    }

    struct DecodedRecipe {
        let dishName: String
        let ingredients: [DecodedIngredient]
        let instructions: [String]
    }

    enum ClientError: LocalizedError {
        case tikwmFailed(String)
        case backendFailed(String)
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .tikwmFailed(let detail):
                return "Couldn't resolve the TikTok video (\(detail))."
            case .backendFailed(let detail):
                return detail
            case .malformedResponse:
                return "Got an unexpected response from the recipe server."
            }
        }
    }

    static func extractRecipe(from tiktokURL: URL) async throws -> DecodedRecipe {
        let videoURL = try await resolveVideoURL(tiktokURL: tiktokURL)
        return try await requestRecipe(tiktokURL: tiktokURL, videoURL: videoURL)
    }

    // MARK: - Step 1: resolve the direct video URL via tikwm (on-device)

    private static func resolveVideoURL(tiktokURL: URL) async throws -> String {
        var components = URLComponents(string: "https://www.tikwm.com/api/")!
        components.queryItems = [URLQueryItem(name: "url", value: tiktokURL.absoluteString)]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClientError.tikwmFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClientError.tikwmFailed("HTTP \(status)")
        }

        struct TikwmResponse: Decodable {
            struct DataField: Decodable { let play: String? }
            let code: Int
            let data: DataField?
        }

        guard let decoded = try? JSONDecoder().decode(TikwmResponse.self, from: data) else {
            throw ClientError.tikwmFailed("unreadable response")
        }
        guard decoded.code == 0, let play = decoded.data?.play else {
            throw ClientError.tikwmFailed("video not found or private")
        }
        return play
    }

    // MARK: - Step 2: hand off to Render for download + Gemini extraction

    private static func requestRecipe(tiktokURL: URL, videoURL: String) async throws -> DecodedRecipe {
        let endpoint = backendBaseURL.appendingPathComponent("extract-recipe")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Video download + Gemini extraction together can take a
        // minute or more -- see recipe_server.py's gunicorn --timeout.
        request.timeoutInterval = 180

        let body: [String: Any] = [
            "tiktok_url": tiktokURL.absoluteString,
            "video_url": videoURL,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClientError.backendFailed("Recipe server unreachable: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClientError.backendFailed("Recipe server gave no response.")
        }
        guard (200...299).contains(http.statusCode) else {
            let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw ClientError.backendFailed(serverMessage ?? "Recipe server error (HTTP \(http.statusCode)).")
        }

        struct RecipeResponse: Decodable {
            struct Ingredient: Decodable { let name: String; let quantity: String? }
            let dish_name: String
            let ingredients: [Ingredient]
            let instructions: [String]
        }

        guard let decoded = try? JSONDecoder().decode(RecipeResponse.self, from: data) else {
            throw ClientError.malformedResponse
        }

        return DecodedRecipe(
            dishName: decoded.dish_name,
            ingredients: decoded.ingredients.map { DecodedIngredient(name: $0.name, quantity: $0.quantity) },
            instructions: decoded.instructions
        )
    }
}
