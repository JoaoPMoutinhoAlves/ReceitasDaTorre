"""
Uses Claude API to parse raw shared content (Instagram/TikTok captions, URLs)
into the standard recipe format.
"""
import json
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
- For ingredients, always split amount, unit, and item (e.g. "2 cups flour" → amount:"2", unit:"cups", item:"flour").
- Steps should be in order, one per array element.
- Do not invent information not present in the source.
- Return ONLY the JSON object, no markdown, no explanation.
"""


import re

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
    """Extract Open Graph meta tags from a URL — works on many public Instagram/TikTok posts."""
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


async def fetch_video_description(url: str) -> str:
    """Use yt-dlp to extract the caption/description from an Instagram or TikTok video URL."""
    try:
        import yt_dlp
        import asyncio

        opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "extract_flat": False,
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
                return "\n\n".join(parts)

        # Run the blocking yt-dlp call in a thread pool
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _extract)
    except Exception as e:
        print(f"yt-dlp extraction failed for {url}: {e}")
        return ""


async def parse_recipe(text: str | None, url: str | None, platform: str | None) -> dict:
    """
    Call Claude to extract a structured recipe from raw text and/or URL.
    Returns a dict matching RecipeCreate schema.
    """
    content_parts = []

    if url:
        content_parts.append(f"Source URL: {url}")
        if platform in ("instagram", "tiktok"):
            # Try yt-dlp first (extracts full caption), fall back to OG tags
            video_desc = await fetch_video_description(url)
            if video_desc:
                content_parts.append(f"Post metadata:\n{video_desc}")
            else:
                og = await fetch_og_tags(url)
                if og:
                    content_parts.append(f"Post metadata:\n{og}")
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

    # Strip markdown code fences if present
    if raw_json.startswith("```"):
        raw_json = raw_json.split("```")[1]
        if raw_json.startswith("json"):
            raw_json = raw_json[4:]
        raw_json = raw_json.strip()

    data = json.loads(raw_json)

    # Inject source fields
    data["source_url"] = url
    data["source_platform"] = platform

    return data
