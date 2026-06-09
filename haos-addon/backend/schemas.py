from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class Ingredient(BaseModel):
    amount: Optional[str] = None
    unit: Optional[str] = None
    item: str
    note: Optional[str] = None


class RecipeBase(BaseModel):
    name: str
    description: Optional[str] = None
    source_url: Optional[str] = None
    source_platform: Optional[str] = None
    category: Optional[str] = None
    tags: list[str] = []
    ingredients: list[Ingredient] = []
    steps: list[str] = []
    prep_time_minutes: Optional[int] = None
    cook_time_minutes: Optional[int] = None
    total_time_minutes: Optional[int] = None
    servings: Optional[int] = None
    image_url: Optional[str] = None


class RecipeCreate(RecipeBase):
    pass


class RecipeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    source_url: Optional[str] = None
    source_platform: Optional[str] = None
    category: Optional[str] = None
    tags: Optional[list[str]] = None
    ingredients: Optional[list[Ingredient]] = None
    steps: Optional[list[str]] = None
    prep_time_minutes: Optional[int] = None
    cook_time_minutes: Optional[int] = None
    total_time_minutes: Optional[int] = None
    servings: Optional[int] = None
    image_url: Optional[str] = None


class RecipeOut(RecipeBase):
    id: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Parse endpoint ---

class ParseRequest(BaseModel):
    text: Optional[str] = None      # raw caption / description from share intent
    url: Optional[str] = None       # original post URL
    platform: Optional[str] = None  # instagram, tiktok, web


class ParseResponse(BaseModel):
    recipe: RecipeCreate
    raw_text: Optional[str] = None
