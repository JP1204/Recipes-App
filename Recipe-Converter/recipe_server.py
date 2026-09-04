"""
recipe_server.py

Flask server that turns a TikTok cooking video URL into a structured
recipe: resolves the URL via tikwm, downloads the video, base64-encodes
it, and asks Gemini for the recipe under a fixed response schema.

Setup, running, the API reference, and the Shortcut wiring are in
README.md in this folder.
"""

import os
import base64
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
GEMINI_MODEL = "gemini-3.5-flash"
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
)

RECIPE_PROMPT = (
    "Watch this cooking video and extract the recipe. Identify the dish "
    "name, every ingredient with its quantity and unit (if stated), and "
    "the step-by-step instructions in order."
)

# Forces Gemini to return JSON matching this exact shape, instead of
# free-form text. This makes the response reliably parseable by another
# app (e.g. a Swift app comparing ingredients against a pantry list).
RECIPE_RESPONSE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "dish_name": {"type": "STRING"},
        "ingredients": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "name": {"type": "STRING"},
                    "quantity": {"type": "STRING"},
                },
                "required": ["name"],
            },
        },
        "instructions": {
            "type": "ARRAY",
            "items": {"type": "STRING"},
        },
    },
    "required": ["dish_name", "ingredients", "instructions"],
}


@app.route("/extract-recipe", methods=["POST"])
def extract_recipe():
    if not GEMINI_API_KEY:
        return jsonify({"error": "GEMINI_API_KEY not set on server"}), 500

    body = request.get_json(silent=True) or {}
    tiktok_url = body.get("tiktok_url")
    if not tiktok_url:
        return jsonify({"error": "Missing 'tiktok_url' in request body"}), 400

    # Step 1: resolve the TikTok URL to a direct video link via tikwm
    try:
        resolve_resp = requests.get(
            "https://www.tikwm.com/api/",
            params={"url": tiktok_url},
            timeout=20,
        )
        resolve_data = resolve_resp.json()
    except Exception as e:
        return jsonify({"error": f"Failed to reach tikwm: {e}"}), 502

    if resolve_data.get("code") != 0:
        return jsonify({
            "error": "tikwm could not resolve this TikTok URL",
            "details": resolve_data,
        }), 422

    video_url = resolve_data.get("data", {}).get("play")
    if not video_url:
        return jsonify({"error": "No video URL found in tikwm response"}), 422

    # Step 2: download the actual video bytes
    try:
        video_resp = requests.get(video_url, timeout=60)
        video_resp.raise_for_status()
        video_bytes = video_resp.content
    except Exception as e:
        return jsonify({"error": f"Failed to download video: {e}"}), 502

    if len(video_bytes) > 19 * 1024 * 1024:  # ~19MB, safety margin under 20MB inline limit
        return jsonify({
            "error": "Video too large for inline Gemini request (over ~19MB).",
            "size_bytes": len(video_bytes),
        }), 413

    # Step 3: base64-encode and send to Gemini
    video_b64 = base64.b64encode(video_bytes).decode("utf-8")

    gemini_payload = {
        "contents": [{
            "parts": [
                {"text": RECIPE_PROMPT},
                {"inline_data": {"mime_type": "video/mp4", "data": video_b64}},
            ]
        }],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": RECIPE_RESPONSE_SCHEMA,
        },
    }

    try:
        gemini_resp = requests.post(
            GEMINI_URL,
            headers={"Content-Type": "application/json"},
            json=gemini_payload,
            timeout=120,
        )
        gemini_data = gemini_resp.json()
    except Exception as e:
        return jsonify({"error": f"Failed to reach Gemini: {e}"}), 502

    if "candidates" not in gemini_data:
        return jsonify({"error": "Unexpected Gemini response", "details": gemini_data}), 502

    try:
        recipe_json_text = gemini_data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError):
        return jsonify({"error": "Could not parse Gemini response", "details": gemini_data}), 502

    # Because of responseSchema above, this text should already be a
    # clean JSON string matching RECIPE_RESPONSE_SCHEMA. Parse it into a
    # real dict so it comes back as nested JSON, not a JSON-encoded string.
    try:
        import json
        recipe_structured = json.loads(recipe_json_text)
    except json.JSONDecodeError:
        return jsonify({
            "error": "Gemini did not return valid JSON",
            "raw_text": recipe_json_text,
        }), 502

    return jsonify(recipe_structured)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
