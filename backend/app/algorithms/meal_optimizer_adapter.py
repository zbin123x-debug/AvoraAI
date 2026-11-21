"""JSON process adapter for the ASP.NET Core API and the GA-PSO module."""

from __future__ import annotations

import json
import sys
from decimal import Decimal

from adaptive_hybrid_ga_pso import (
    Food,
    Ingredient,
    MealRequest,
    Recipe,
    SearchBudget,
    Target,
    recommend_meal,
)


def number(value):
    return Decimal(str(value)) if value is not None else None


def read_ids(values):
    return None if values is None else frozenset(str(value) for value in values)


def main() -> None:
    payload = json.load(sys.stdin)
    foods = {
        item["foodId"]: Food(
            food_id=item["foodId"],
            group_id=item["groupId"],
            name=item["name"],
            verified_per_100g={key: number(value) for key, value in item["verifiedPer100g"].items()},
            approved_for_ai=bool(item["approvedForAi"]),
            allergen_ids=read_ids(item.get("allergenIds")),
        )
        for item in payload["foods"]
    }
    recipes = [
        Recipe(
            recipe_id=item["recipeId"],
            name=item["name"],
            cooking_notes=item["cookingNotes"],
            ingredients=tuple(
                Ingredient(line["foodId"], number(line["standardG"]),
                           number(line.get("minG")), number(line.get("maxG")))
                for line in item["ingredients"]
            ),
            approved_for_ai=bool(item["approvedForAi"]),
            diet_tags=read_ids(item.get("dietTags")) or frozenset(),
            meal_tags=read_ids(item.get("mealTags")) or frozenset(),
            allergen_ids=read_ids(item.get("allergenIds")),
        )
        for item in payload["recipes"]
    ]
    target_map = {
        key: Target(
            minimum=number(value.get("minimum")),
            maximum=number(value.get("maximum")),
            hard_minimum=number(value.get("hardMinimum")),
            hard_maximum=number(value.get("hardMaximum")),
            weight=number(value.get("weight", 1)),
        )
        for key, value in payload.get("targets", {}).items()
    }
    request = MealRequest(
        meal=payload["meal"],
        targets=target_map,
        pantry_food_ids=read_ids(payload.get("pantryFoodIds")) or frozenset(),
        allergy_ids=read_ids(payload.get("allergyIds")),
        required_diet_tags=read_ids(payload.get("requiredDietTags")) or frozenset(),
        avoid_food_ids=read_ids(payload.get("avoidFoodIds")) or frozenset(),
        exclude_recipe_ids=read_ids(payload.get("excludeRecipeIds")) or frozenset(),
        favorite_recipe_ids=read_ids(payload.get("favoriteRecipeIds")) or frozenset(),
        recent_recipe_ids=read_ids(payload.get("recentRecipeIds")) or frozenset(),
        dish_count=int(payload.get("dishCount", 1)),
    )
    budget_data = payload.get("budget", {})
    budget = SearchBudget(**budget_data)
    result = recommend_meal(
        foods,
        recipes,
        request,
        seed=payload.get("seed"),
        budget=budget,
    )
    print(json.dumps({
        "status": result.status,
        "estimatedNutrients": result.estimated_nutrients,
        "dishes": [
            {
                "recipeId": dish.recipe_id,
                "name": dish.name,
                "cookingNotes": dish.cooking_notes,
                "ingredients": [
                    {"foodId": line.food_id, "name": line.name,
                     "grams": line.grams, "inPantry": line.in_pantry}
                    for line in dish.ingredients
                ],
            }
            for dish in result.dishes
        ],
    }, ensure_ascii=False, allow_nan=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(json.dumps({"error": type(exc).__name__, "message": str(exc)}, ensure_ascii=False))
        sys.exit(1)
