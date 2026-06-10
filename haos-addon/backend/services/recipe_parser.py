"""
Uses Claude API to parse raw shared content (Instagram/TikTok captions, URLs)
into the standard recipe format.
"""
import json
import re
import httpx
from anthropic import Anthropic
from ..config import settings

client = Anthropic(api_key=settings.claude_api_key)

SYSTEM_PROMPT = """You are a recipe extraction assistant. Given raw text (such as an Instagram or TikTok caption, a recipe blog post, or a URL) you extract structured recipe data.

Always respond with a valid JSON object matching this exact schema:
{
  "name": "string (required, recipe title)",
  "description": "string or null",
  "category": "string or null (e.g. Breakfast, Lunch, Dinner, Dessert, Snack, Drink, Sauce, Other)",
  "tags": ["string"],
  "ingredients": [
    {"amount": "string or null", "unit": "string or null", "item": "string (required)", "note": "string or null"}
  ],
  "steps": ["string (each step as a sentence or short paragraph)"],
  "prep_time_minutes": integer or null,
  "cook_time_minutes": integer or null,
  "total_time_minutes": integer or null,
  "servings": integer or null,
  "image_url": "string or null"
}

Rules:
- Extract as much information as possible from the raw text.
- If the text is not a recipe, return {"name": "Unknown Recipe", "ingredients": [], "steps": [], ...} with all other fields null/empty.
- For ingredients, always split amount, unit, and item (e.g. "2 cups flour" -> amount:"2", unit:"cups", item:"flour").
- Steps should be in order, one per array element.
- Do not invent information not present in the source.
- Return ONLY the JSON object, no markdown, no explanation.
"""


async def fetch_url_text(url: str) -> str:
    """Fetch plain text from a URL (best-effort)."""
    try:
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client_http:
            resp = await client_http.get(url, headers={"User-Agent": "Mozilla/5.0"})
            resp.raise_for_status()
            text = re.sub(r"<[^>]+>", " ", resp.text)
            text = re.sub(r"\s+", " ", text).strip()
            return text[:8000]
    except Exception:
        return ""


async def fetch_og_tags(url: str) -> str:
    """Extract Open Graph meta tags from a URL."""
    try:
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client_http:
            resp = await client_http.get(url, headers={
                "User-Agent": "Mozilla/5.0 (compatible; Googlebot/2.1)",
            })
            html = resp.text
        tags = {}
        for m in re.finditer(r'<meta[^>]+property=["\']og:(\w+)["\'][^>]+content=["\']([^"\']+)["\']', html, re.I):
            tags[m.group(1)] = m.group(2)
        for m in re.finditer(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:(\w+)["\']', html, re.I):
            tags[m.group(2)] = m.group(1)
        if not tags:
            return ""
        parts = []
        if "title" in tags:
            parts.append(f"Title: {tags['title']}")
        if "description" in tags:
            parts.append(f"Description: {tags['description']}")
        return "\n".join(parts)
    except Exception:
        return ""


async def fetch_tiktok_oembed(url: str) -> dict:
    """Use TikTok's public oEmbed API — works for videos AND photo/slideshow posts without auth."""
    try:
        oembed_url = f"https://www.tiktok.com/oembed?url={url}"
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as c:
            resp = await c.get(oembed_url, headers={"User-Agent": "Mozilla/5.0"})
            resp.raise_for_status()
            data = resp.json()
        parts = []
        if data.get("title"):
            parts.append(f"Caption: {data['title']}")
        if data.get("author_name"):
            parts.append(f"Author: {data['author_name']}")
        return {
            "text": "\n".join(parts),
            "thumbnail": data.get("thumbnail_url"),
        }
    except Exception as e:
        print(f"TikTok oEmbed failed: {e}")
        return {"text": "", "thumbnail": None}


async def fetch_instagram_oembed(url: str) -> dict:
    """Use Instagram's public oEmbed API to get caption and thumbnail."""
    try:
        oembed_url = f"https://api.instagram.com/oembed/?url={url}"
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as c:
            resp = await c.get(oembed_url, headers={"User-Agent": "Mozilla/5.0"})
            resp.raise_for_status()
            data = resp.json()
        parts = []
        if data.get("title"):
            parts.append(f"Caption: {data['title']}")
        if data.get("author_name"):
            parts.append(f"Author: {data['author_name']}")
        return {
            "text": "\n".join(parts),
            "thumbnail": data.get("thumbnail_url"),
        }
    except Exception as e:
        print(f"Instagram oEmbed failed: {e}")
        return {"text": "", "thumbnail": None}


async def fetch_video_metadata(url: str, platform: str | None) -> dict:
    """
    Extract caption and thumbnail from a social media URL.
    Strategy: oEmbed (most reliable) → yt-dlp (full description) → OG tags (fallback)
    """
    # 1. Try platform-specific oEmbed API first (works for all post types, no auth needed)
    if platform == "tiktok" or "tiktok.com" in url:
        result = await fetch_tiktok_oembed(url)
        if result["text"] or result["thumbnail"]:
            return result

    if platform == "instagram" or "instagram.com" in url:
        result = await fetch_instagram_oembed(url)
        if result["text"] or result["thumbnail"]:
            return result

    # 2. Try yt-dlp (gets full description for videos)
    try:
        import yt_dlp
        import asyncio

        opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
        }

        def _extract():
            with yt_dlp.YoutubeDL(opts) as ydl:
                info = ydl.extract_info(url, download=False)
                parts = []
                if info.get("title"):
                    parts.append(f"Title: {info['title']}")
                if info.get("description"):
                    parts.append(f"Caption:\n{info['description']}")
                if info.get("uploader"):
                    parts.append(f"Author: {info['uploader']}")
                return {
                    "text": "\n\n".join(parts),
                    "thumbnail": info.get("thumbnail"),
                }

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, _extract)
        if result["text"] or result["thumbnail"]:
            return result
    except Exception as e:
        print(f"yt-dlp extraction failed for {url}: {e}")

    # 3. OG tags as last resort
    og = await fetch_og_tags(url)
    return {"text": og, "thumbnail": None}


async def parse_recipe(text: str | None, url: str | None, platform: str | None) -> dict:
    """
    Call Claude to extract a structured recipe from raw text and/or URL.
    Returns a dict matching RecipeCreate schema.
    """
    content_parts = []
    thumbnail_url = None

    if url:
        content_parts.append(f"Source URL: {url}")
        if platform in ("instagram", "tiktok"):
            metadata = await fetch_video_metadata(url, platform)
            thumbnail_url = metadata.get("thumbnail")
            if metadata["text"]:
                content_parts.append(f"Post metadata:\n{metadata['text']}")
        else:
            fetched = await fetch_url_text(url)
            if fetched:
                content_parts.append(f"Page content (truncated):\n{fetched}")

    if text:
        content_parts.append(f"Shared text / caption:\n{text}")

    if not content_parts:
        raise ValueError("No text or URL provided")

    user_message = "\n\n".join(content_parts)

    message = client.messages.create(
        model=settings.claude_model,
        max_tokens=2048,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )

    raw_json = message.content[0].text.strip()

    if raw_json.startswith("```"):
        raw_json = raw_json.split("```")[1]
        if raw_json.startswith("json"):
            raw_json = raw_json[4:]
        raw_json = raw_json.strip()

    data = json.loads(raw_json)

    data["source_url"] = url
    data["source_platform"] = platform

    # Use yt-dlp thumbnail if Claude didn't extract an image URL
    if not data.get("image_url") and thumbnail_url:
        data["image_url"] = thumbnail_url

    return data
