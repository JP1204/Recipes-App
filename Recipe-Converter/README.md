# Recipe-Converter

A small Flask server that takes a TikTok cooking video URL and returns a structured, machine-readable recipe.

It resolves the URL to a direct video file via [tikwm](https://www.tikwm.com), downloads the video, base64-encodes it, and hands it to the Gemini API with a response schema that forces clean JSON back.

## Why it exists

The original version of this ran entirely inside an iOS Shortcut. Downloading a video and base64-encoding it on the phone kept exhausting Shortcuts' memory and freezing the app. Moving that work onto a computer leaves the client (Shortcut, or the `RecipeShareExtension` Xcode target -- see `../RecipeShareExtension/README.md`) with nothing to do but resolve the video URL and make one HTTP request.

**Note:** tikwm blocks requests from Render's datacenter IPs with a bare 403 (confirmed -- happens even with a browser User-Agent). Because of this, resolving the TikTok URL to a direct video link now normally happens on the client, not here -- see `video_url` in the API section below.

## Setup

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Set your Gemini API key before running — it's read from the environment, never checked in:

```bash
export GEMINI_API_KEY="your-key-here"
```

## Running

Local development:

```bash
python recipe_server.py
# → http://localhost:5000
```

Production / hosted (gunicorn is already in `requirements.txt`):

```bash
gunicorn recipe_server:app --bind 0.0.0.0:$PORT --timeout 180
```

The long timeout matters: a single request downloads a video and waits on a Gemini call, which together can take a minute or more. Default gunicorn worker timeouts will kill it.

`PORT` is read from the environment and defaults to `5000`.

### Exposing it to your phone

For testing against a locally running server, [ngrok](https://ngrok.com) on the free tier is enough:

```bash
ngrok http 5000
```

That gives you a temporary public URL like `https://abcd1234.ngrok.io` to call from the Shortcut instead of `localhost`.

## API

### `POST /extract-recipe`

**Request**

```json
{
  "tiktok_url": "https://www.tiktok.com/@someone/video/123456789",
  "video_url": "https://v16-webapp.tiktok.com/....mp4"
}
```

`video_url` is optional but strongly recommended: if present, this server skips its own tikwm call entirely and downloads that URL directly. Omit it only for local testing from your own machine -- if this server is deployed on Render and has to resolve tikwm itself, it will get the same 403 described above.

**Response — `200 OK`**

```json
{
  "dish_name": "Garlic Butter Shrimp Pasta",
  "ingredients": [
    { "name": "shrimp",   "quantity": "1 lb" },
    { "name": "linguine", "quantity": "8 oz" },
    { "name": "garlic",   "quantity": "4 cloves" }
  ],
  "instructions": [
    "Boil the linguine according to package instructions.",
    "Saute garlic in butter until fragrant.",
    "Add shrimp and cook until pink.",
    "Toss cooked pasta with the shrimp and garlic butter."
  ]
}
```

`dish_name`, `ingredients`, and `instructions` are always present. `quantity` is optional on an ingredient and is free-form text (`"1 lb"`, `"to taste"`) — it's display-only.

The shape is enforced, not hoped for: `RECIPE_RESPONSE_SCHEMA` is passed to Gemini as a `responseSchema` alongside `responseMimeType: application/json`, so the model returns conforming JSON rather than prose that needs parsing out of a code fence.

**Errors**

Every failure returns `{"error": "…"}`, sometimes with a `details` key carrying the upstream response.

| Status | Cause |
|---|---|
| `400` | Missing `tiktok_url` in the request body |
| `413` | Video is over ~19 MB — Gemini's inline-data limit is 20 MB |
| `422` | tikwm couldn't resolve the URL, or returned no video link |
| `500` | `GEMINI_API_KEY` isn't set on the server |
| `502` | tikwm, the video host, or Gemini was unreachable, or Gemini returned something unparseable |

## Calling it from the app

There are two clients, both hitting this same `/extract-recipe` endpoint and both ending up at the same `RecipeImporter.save` in the app:

- **RecipeShareExtension** (recommended) — a Share Sheet extension bundled inside RecipesApp itself, so it works for anyone who's installed the app with no separate setup. It resolves the video via tikwm on-device, then POSTs `{"tiktok_url": ..., "video_url": ...}` here. See `../RecipeShareExtension/README.md` for what it does and the one-time Xcode wiring (App Groups, target membership) it needs.
- **The iOS Shortcut** (legacy, still works) — three actions: Receive URL from the Share Sheet, `POST` to `https://your-server-url/extract-recipe` with `{"tiktok_url": "<Shortcut Input>"}` (no `video_url` — the Shortcut doesn't resolve tikwm itself, so this falls back to this server resolving it, which will 403 on Render), then Get Dictionary from Input and pass the response to the **"Add Recipes"** App Intent, which decodes exactly this shape into a `Recipe`. Kept around mainly for testing; the Share Extension is the one that needs no manual per-user setup.

## Notes and limits

- **TikTok only.** Resolution goes through tikwm, a third-party service with no SLA. If it goes down or changes its response format, this breaks — that's the most fragile link in the chain.
- **No authentication.** Anyone who has the URL can spend your Gemini quota. Fine behind localhost or a short-lived ngrok tunnel; add a shared secret before leaving anything public up.
- **~19 MB video ceiling.** Longer videos need the Files API and a resumable upload instead of inline data.
- **Model is pinned** in `GEMINI_MODEL` at the top of `recipe_server.py`.
- **Single synchronous request.** No queue, no retries, no caching — one video per request, and the caller waits.
