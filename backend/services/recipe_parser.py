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
- For ingredients, ALWAYS split into amount, unit, and item. The amount field must contain ONLY the numeric value as a string (e.g. "2", "1/2", "2.5"). The unit field contains the unit of measurement. The item field contains only the ingredient name with no numbers. Example: "6 ovos" → amount:"6", unit:null, item:"ovos". "2 xícaras de farinha" → amount:"2", unit:"xícaras", item:"farinha". Never put a number inside the item field.
- Steps should be in order, one per array element.
- Do not invent information not present in the source.
- Return ONLY the JSON object, no markdown, no explanation.
"""


async def fetch_url_text(url: str) -> str:
    """Attempt to fetch plain text from a URL (best-effort, works for recipe websites)."""
    try:
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client_http:
            resp = await client_http.get(url, headers={"User-Agent": "Mozilla/5.0"})
            resp.raise_for_status()
            # Very naive text extraction: strip HTML tags
            import re
            text = re.sub(r"<[^>]+>", " ", resp.text)
            text = re.sub(r"\s+", " ", text).strip()
            return text[:8000]  # Limit context size
    except Exception:
        return ""


async def parse_recipe(text: str | None, url: str | None, platform: str | None) -> dict:
    """
    Call Claude to extract a structured recipe from raw text and/or URL.
    Returns a dict matching RecipeCreate schema.
    """
    content_parts = []

    if url:
        content_parts.append(f"Source URL: {url}")
        # For non-social platforms, try fetching the page
        if platform not in ("instagram", "tiktok") and url:
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
