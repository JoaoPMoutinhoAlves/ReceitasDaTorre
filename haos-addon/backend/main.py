from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional

from .database import engine, get_db
from . import models, schemas
from .services.recipe_parser import parse_recipe

# Create tables on startup
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Recipe Manager API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Health ──────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok"}


# ─── Parse ───────────────────────────────────────────────────────────────────

@app.post("/api/parse", response_model=schemas.ParseResponse)
async def parse_endpoint(request: schemas.ParseRequest):
    """
    Takes a shared URL/text (from Instagram, TikTok, or any recipe site)
    and returns a structured recipe ready for review and saving.
    """
    try:
        recipe_data = await parse_recipe(
            text=request.text,
            url=request.url,
            platform=request.platform,
        )
        recipe = schemas.RecipeCreate(**recipe_data)
        return schemas.ParseResponse(recipe=recipe, raw_text=request.text)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Parsing failed: {str(e)}")


# ─── Recipes CRUD ─────────────────────────────────────────────────────────────

@app.get("/api/recipes", response_model=list[schemas.RecipeOut])
def list_recipes(
    search: Optional[str] = Query(None, description="Search by name or description"),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(models.Recipe)
    if search:
        q = q.filter(
            or_(
                models.Recipe.name.ilike(f"%{search}%"),
                models.Recipe.description.ilike(f"%{search}%"),
            )
        )
    if category:
        q = q.filter(models.Recipe.category.ilike(category))
    return q.order_by(models.Recipe.created_at.desc()).all()


@app.get("/api/recipes/categories", response_model=list[str])
def list_categories(db: Session = Depends(get_db)):
    rows = (
        db.query(models.Recipe.category)
        .filter(models.Recipe.category.isnot(None))
        .distinct()
        .all()
    )
    return sorted([r[0] for r in rows if r[0]])


@app.get("/api/recipes/{recipe_id}", response_model=schemas.RecipeOut)
def get_recipe(recipe_id: str, db: Session = Depends(get_db)):
    recipe = db.query(models.Recipe).filter(models.Recipe.id == recipe_id).first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe


@app.post("/api/recipes", response_model=schemas.RecipeOut, status_code=201)
def create_recipe(recipe_in: schemas.RecipeCreate, db: Session = Depends(get_db)):
    db_recipe = models.Recipe(
        **recipe_in.model_dump(exclude_none=False),
    )
    # Convert Ingredient objects to dicts for JSON storage
    db_recipe.ingredients = [
        ing.model_dump() if hasattr(ing, "model_dump") else ing
        for ing in (recipe_in.ingredients or [])
    ]
    db.add(db_recipe)
    db.commit()
    db.refresh(db_recipe)
    return db_recipe


@app.put("/api/recipes/{recipe_id}", response_model=schemas.RecipeOut)
def update_recipe(recipe_id: str, recipe_in: schemas.RecipeUpdate, db: Session = Depends(get_db)):
    recipe = db.query(models.Recipe).filter(models.Recipe.id == recipe_id).first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    update_data = recipe_in.model_dump(exclude_unset=True)
    if "ingredients" in update_data and update_data["ingredients"] is not None:
        update_data["ingredients"] = [
            ing.model_dump() if hasattr(ing, "model_dump") else ing
            for ing in update_data["ingredients"]
        ]
    for field, value in update_data.items():
        setattr(recipe, field, value)
    db.commit()
    db.refresh(recipe)
    return recipe


@app.delete("/api/recipes/{recipe_id}", status_code=204)
def delete_recipe(recipe_id: str, db: Session = Depends(get_db)):
    recipe = db.query(models.Recipe).filter(models.Recipe.id == recipe_id).first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    db.delete(recipe)
    db.commit()
