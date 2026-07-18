"""
recipe_server.py

A small Flask server that takes a TikTok URL, resolves it to a direct
video file via tikwm, downloads it, base64-encodes it, and sends it to
the Gemini API to extract a written recipe.

This moves the heavy lifting (download + base64 encoding) off your
phone/Shortcuts and onto a computer/server, avoiding the memory issues
that were freezing Shortcuts.

SETUP:
  pip install flask requests

  Set your Gemini API key as an environment variable before running:
    export GEMINI_API_KEY="your-key-here"

RUN:
  python recipe_server.py

  This starts a local server on http://localhost:5000

EXPOSE TO YOUR PHONE (for testing):
  Use ngrok (https://ngrok.com, free tier) to get a public URL:
    ngrok http 5000

  This gives you a temporary public URL like https://abcd1234.ngrok.io
  which you can call from your iOS Shortcut instead of localhost.

SHORTCUT USAGE:
  Your Shortcut becomes just:
    1. Receive URL from Share Sheet
    2. "Get Contents of URL" -> POST to https://your-server-url/extract-recipe
       with JSON body: {"tiktok_url": "<Shortcut Input>"}
    3. Get Dictionary from Input -> pull out whichever key you need
       (dish_name / ingredients / instructions), or just pass the whole
       response along to another app (e.g. a Swift app via a URL scheme
       or Shortcuts' "Open [App]" action with this JSON as input).

RESPONSE SHAPE:
  {
    "dish_name": "Garlic Butter Shrimp Pasta",
    "ingredients": [
      {"name": "shrimp", "quantity": "1 lb"},
      {"name": "linguine", "quantity": "8 oz"},
      {"name": "garlic", "quantity": "4 cloves"}
    ],
    "instructions": [
      "Boil the linguine according to package instructions.",
      "Saute garlic in butter until fragrant.",
      "Add shrimp and cook until pink.",
      "Toss cooked pasta with the shrimp and garlic butter."
    ]
  }

All the tikwm resolution, video download, base64 encoding, and Gemini
call happen here on the server, not in Shortcuts.
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
