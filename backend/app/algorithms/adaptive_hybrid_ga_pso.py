"""Avora AI: select catalog recipes and optimize ingredient portions for one meal.

Python 3.10+. This module uses the standard library. The application supplies
approved foods, recipe records, a validated goal and its per-meal targets.
All quantities use the edible weight and processing state of the food record.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR
from itertools import combinations
from math import comb, fsum, isclose, isfinite
from random import Random
from typing import Callable, Iterable, Mapping

# Order also defines the internal nutrient vectors. Units refer to 100 g of food.
NUTRIENTS = (
    "energy_kcal", "protein_g", "carbohydrate_g", "total_fat_g",
    "fiber_g", "total_sugars_g", "saturated_fat_g", "sodium_mg",
)
EMPTY_IDS: frozenset[str] = frozenset()
Amount = int | float | Decimal  # SQL Server DECIMAL is commonly returned as Decimal.


@dataclass(frozen=True)
class Food:
    food_id: str
    group_id: str
    name: str
    verified_per_100g: Mapping[str, Amount | None]
    approved_for_ai: bool
    allergen_ids: frozenset[str] | None = None  # None = unreviewed.


@dataclass(frozen=True)
class Ingredient:
    food_id: str
    standard_g: Amount
    min_g: Amount | None = None  # Supply both reviewed bounds or keep standard_g fixed.
    max_g: Amount | None = None


@dataclass(frozen=True)
class Recipe:
    recipe_id: str
    name: str
    cooking_notes: str
    ingredients: tuple[Ingredient, ...]
    approved_for_ai: bool
    diet_tags: frozenset[str] = EMPTY_IDS
    meal_tags: frozenset[str] = EMPTY_IDS  # Empty = no meal restriction in the catalog.
    allergen_ids: frozenset[str] | None = None  # Reviewed at dish level as well.


@dataclass(frozen=True)
class Target:
    """Desired interval in a meal. Either end can be omitted.

    Equal desired bounds specify a point target. Hard bounds are enforced on
    the returned grams. A lower bound alone never penalizes an excess, and an
    upper bound alone never penalizes a shortfall.
    """
    minimum: Amount | None = None
    maximum: Amount | None = None
    hard_minimum: Amount | None = None
    hard_maximum: Amount | None = None
    weight: Amount = 1.0


@dataclass(frozen=True)
class MealRequest:
    meal: str
    targets: Mapping[str, Target]
    pantry_food_ids: frozenset[str]  # Presence only. No stock weights are inferred.
    allergy_ids: frozenset[str] | None  # Empty = confirmed none; None = unknown profile.
    required_diet_tags: frozenset[str] = EMPTY_IDS
    avoid_food_ids: frozenset[str] = EMPTY_IDS
    exclude_recipe_ids: frozenset[str] = EMPTY_IDS  # e.g. the dish being replaced
    favorite_recipe_ids: frozenset[str] = EMPTY_IDS
    recent_recipe_ids: frozenset[str] = EMPTY_IDS
    dish_count: int = 1


@dataclass(frozen=True)
class SearchBudget:
    population: int = 14
    generations: int = 10
    particles: int = 10
    steps: int = 16


@dataclass(frozen=True)
class Portion:
    food_id: str
    name: str
    grams: float
    in_pantry: bool


@dataclass(frozen=True)
class SuggestedDish:
    recipe_id: str
    name: str
    cooking_notes: str
    ingredients: tuple[Portion, ...]


@dataclass(frozen=True)
class Result:
    status: str  # Internal status for the application service.
    dishes: tuple[SuggestedDish, ...] = ()
    estimated_nutrients: Mapping[str, float | None] | None = None  # Backend only.


@dataclass(frozen=True)
class _Line:
    food: Food
    per_tick: tuple[float, ...]  # Nutrients in one 0.1 g tick.
    standard_ticks: float
    lower: int
    upper: int


@dataclass(frozen=True)
class _Candidate:
    recipe: Recipe
    lines: tuple[_Line, ...]


@dataclass(frozen=True)
class _Fit:
    hard_gap: float
    soft_gap: float
    drift: float
    ticks: tuple[int, ...]
    totals: tuple[float, ...]

    def rank(self) -> tuple[float, float, float]:
        return self.hard_gap, self.soft_gap, self.drift


def _number(value: object) -> bool:
    if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
        return False
    try:
        return isfinite(float(value)) and value >= 0
    except (ValueError, OverflowError):
        return False


def _valid_targets(targets: Mapping[str, Target]) -> bool:
    # An empty mapping means the user has no explicit per-meal nutrient budget.
    # In that case, preserve each approved recipe's standard serving sizes.
    if not targets:
        return True
    core_nutrients = set(NUTRIENTS[:4])
    if not core_nutrients.issubset(targets) or any(key not in NUTRIENTS for key in targets):
        return False
    for target in targets.values():
        if not isinstance(target, Target) or not _number(target.weight) or target.weight == 0:
            return False
        bounds = (target.minimum, target.maximum, target.hard_minimum, target.hard_maximum)
        if all(x is None for x in bounds) or any(x is not None and not _number(x) for x in bounds):
            return False
        for low, high in ((target.minimum, target.maximum), (target.hard_minimum, target.hard_maximum)):
            if low is not None and high is not None and low > high:
                return False
    return True


def _prepared_line(item: Ingredient, food: Food) -> _Line | None:
    if not food.approved_for_ai or not food.group_id or not _number(item.standard_g) or item.standard_g == 0:
        return None
    raw_values = tuple(food.verified_per_100g.get(key) for key in NUTRIENTS)
    if not all(_number(value) for value in raw_values[:4]):
        return None
    if any(value is not None and not _number(value) for value in raw_values[4:]):
        return None
    values = tuple(value if value is not None else 0 for value in raw_values)
    if item.min_g is None and item.max_g is None:
        low = high = item.standard_g
    else:
        low, high = item.min_g, item.max_g
    if not _number(low) or not _number(high) or low <= 0 or low > high:
        return None
    # Round bounds inwards, so the displayed recommendation meets the same bounds.
    lower = int((Decimal(str(low)) * 10).to_integral_value(rounding=ROUND_CEILING))
    upper = int((Decimal(str(high)) * 10).to_integral_value(rounding=ROUND_FLOOR))
    if lower > upper:
        return None
    return _Line(food, tuple(float(value) / 1000 for value in values),
                 float(item.standard_g) * 10, lower, upper)


def _allergy_conflict(allergies: frozenset[str], declared: frozenset[str] | None) -> bool:
    return bool(allergies) and (declared is None or not allergies.isdisjoint(declared))


def _eligible(recipe: Recipe, foods: Mapping[str, Food], req: MealRequest) -> _Candidate | None:
    if (req.allergy_ids is None or not recipe.approved_for_ai or not recipe.recipe_id or not recipe.name.strip()
            or not recipe.cooking_notes.strip() or not recipe.ingredients
            or recipe.recipe_id in req.exclude_recipe_ids
            or not req.required_diet_tags.issubset(recipe.diet_tags)
            or (recipe.meal_tags and req.meal not in recipe.meal_tags)
            or _allergy_conflict(req.allergy_ids, recipe.allergen_ids)):
        return None
    seen: set[str] = set()
    lines: list[_Line] = []
    for item in recipe.ingredients:
        food = foods.get(item.food_id)
        if (food is None or food.food_id != item.food_id or item.food_id in seen
                or item.food_id in req.avoid_food_ids
                or _allergy_conflict(req.allergy_ids, food.allergen_ids)):
            return None
        line = _prepared_line(item, food)
        if line is None:
            return None  # Retain every recipe ingredient, including oil and seasonings.
        seen.add(item.food_id)
        lines.append(line)
    return _Candidate(recipe, tuple(lines))


def _gap(value: float, low: float | None, high: float | None) -> float:
    if low is not None and value < low and not isclose(value, low, rel_tol=1e-12, abs_tol=1e-12):
        return (low - value) / max(low, 1.0)
    if high is not None and value > high and not isclose(value, high, rel_tol=1e-12, abs_tol=1e-12):
        return (value - high) / max(high, 1.0)
    return 0.0


def _measure(lines: tuple[_Line, ...], positions: list[float], targets: tuple[Target, ...]) -> _Fit:
    ticks = tuple(min(line.upper, max(line.lower, round(x))) for x, line in zip(positions, lines))
    totals = tuple(fsum(n * line.per_tick[j] for n, line in zip(ticks, lines))
                   for j in range(len(NUTRIENTS)))
    hard = fsum(_gap(v, t.hard_minimum, t.hard_maximum) for v, t in zip(totals, targets))
    soft = fsum(t.weight * _gap(v, t.minimum, t.maximum) ** 2 for v, t in zip(totals, targets))
    drift = fsum((n / line.standard_ticks - 1.0) ** 2 for n, line in zip(ticks, lines)) / len(lines)
    return _Fit(hard, soft, drift, ticks, totals)


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _optimize_grams(lines: tuple[_Line, ...], targets: tuple[Target, ...],
                    budget: SearchBudget, rng: Random) -> _Fit:
    base = [_clamp(line.standard_ticks, line.lower, line.upper) for line in lines]
    if not targets:
        return _measure(lines, base, targets)
    start = _measure(lines, base, targets)
    if all(line.lower == line.upper for line in lines):
        return start

    # Seed the swarm both at the catalog portion and near the meal energy target.
    energy_bounds = [v for v in (targets[0].minimum, targets[0].maximum) if v is not None]
    factor = 1.0
    if energy_bounds and start.totals[0] > 0:
        factor = (sum(energy_bounds) / len(energy_bounds)) / start.totals[0]
    positions = [base, [_clamp(x * factor, l.lower, l.upper) for x, l in zip(base, lines)],
                 [l.lower for l in lines], [l.upper for l in lines]]
    while len(positions) < budget.particles:
        positions.append([rng.uniform(l.lower, l.upper) for l in lines])
    spans = [line.upper - line.lower for line in lines]
    velocity = [[rng.uniform(-0.1, 0.1) * span for span in spans] for _ in positions]
    bests = [_measure(lines, p, targets) for p in positions]
    best = min(bests, key=_Fit.rank)
    stalled = 0
    for step in range(budget.steps):
        progress = step / max(1, budget.steps - 1)
        pressure = min(1.0, stalled / 4)
        inertia = 0.82 - 0.4 * progress + 0.12 * pressure
        personal_pull = 1.9 - 0.5 * progress
        group_pull = 1.2 + 0.7 * progress
        previous = best.rank()
        for i, position in enumerate(positions):
            for j, line in enumerate(lines):
                speed = (inertia * velocity[i][j]
                         + personal_pull * rng.random() * (bests[i].ticks[j] - position[j])
                         + group_pull * rng.random() * (best.ticks[j] - position[j]))
                velocity[i][j] = _clamp(speed, -spans[j] / 2, spans[j] / 2)
                position[j] = _clamp(position[j] + velocity[i][j], line.lower, line.upper)
            fit = _measure(lines, position, targets)
            if fit.rank() < bests[i].rank():
                bests[i] = fit
            if fit.rank() < best.rank():
                best = fit
        stalled = stalled + 1 if best.rank() == previous else 0
    return best


def _genetic_search(pool: tuple[str, ...], count: int, budget: SearchBudget, rng: Random,
                    rank: Callable[[tuple[str, ...]], tuple]) -> tuple[str, ...]:
    # A chromosome is an unordered set of distinct recipe IDs for this meal.
    if len(pool) == count:
        rank(pool)
        return pool
    if comb(len(pool), count) <= budget.population:
        population = list(combinations(pool, count))
        population.extend(rng.choices(population, k=budget.population - len(population)))
    else:
        population = [tuple(sorted(rng.sample(pool, count))) for _ in range(budget.population)]
    best = min(population, key=rank)
    stalled = 0
    for _ in range(budget.generations):
        def tournament():
            return min(rng.sample(population, 3), key=rank)

        crowding = 1 - len(set(population)) / len(population)
        pressure = max(crowding, min(1.0, stalled / 4))
        crossover_rate = 0.9 - 0.3 * pressure
        mutation_rate = 0.15 + 0.55 * pressure
        children = [best]
        while len(children) < budget.population:
            genes = tournament()
            if rng.random() < crossover_rate:
                union = sorted(set(genes) | set(tournament()))
                genes = tuple(sorted(rng.sample(union, count)))
            if rng.random() < mutation_rate:
                free = [identifier for identifier in pool if identifier not in genes]
                if free:
                    mutable = list(genes)
                    mutable[rng.randrange(count)] = rng.choice(free)
                    genes = tuple(sorted(mutable))
            children.append(genes)
        winner = min(children, key=rank)
        if rank(winner) < rank(best):
            best, stalled = winner, 0
        else:
            stalled += 1
        population = children
    return best


def recommend_meal(
    foods: Mapping[str, Food], recipes: Iterable[Recipe], request: MealRequest,
    *, seed: int | None = None, budget: SearchBudget = SearchBudget(),
) -> Result:
    """Return one suggestion from existing recipes. This function performs no writes.

    approved_for_ai, verified_per_100g, bounds and per-meal targets come from a
    trusted backend adapter. Build user-visible DTOs from result.dishes only.
    The caller may retain estimated_nutrients as an internal calculation.
    """
    if not _valid_targets(request.targets):
        return Result("INCOMPLETE_MEAL_TARGETS")
    if request.allergy_ids is None or not request.meal.strip():
        return Result("INCOMPLETE_PROFILE_OR_MEAL")
    if type(request.dish_count) is not int or request.dish_count < 1:
        raise ValueError("dish_count must be a positive integer")
    for value, lo, hi in ((budget.population, 4, 256), (budget.generations, 1, 200),
                          (budget.particles, 4, 128), (budget.steps, 1, 300)):
        if type(value) is not int or not lo <= value <= hi:
            raise ValueError("invalid backend search budget")

    candidates: dict[str, _Candidate] = {}
    ids_seen: set[str] = set()
    for recipe in recipes:
        if recipe.recipe_id in ids_seen:
            raise ValueError("duplicate recipe_id in catalog")
        ids_seen.add(recipe.recipe_id)
        candidate = _eligible(recipe, foods, request)
        if candidate:
            candidates[recipe.recipe_id] = candidate
    if len(candidates) < request.dish_count:
        return Result("NO_ELIGIBLE_COMBINATION")

    cache = {}
    def numeric_target(t: Target) -> Target:
        bounds = (t.minimum, t.maximum, t.hard_minimum, t.hard_maximum)
        return Target(*(None if v is None else float(v) for v in bounds), weight=float(t.weight))

    targets = tuple(numeric_target(request.targets[key]) for key in NUTRIENTS if key in request.targets)
    rng = Random(seed)
    catalog_foods = {line.food.food_id for c in candidates.values() for line in c.lines}
    useful_pantry = request.pantry_food_ids & catalog_foods

    def rank(genes: tuple[str, ...]):
        if genes not in cache:
            lines = tuple(line for key in genes for line in candidates[key].lines)
            fit = _optimize_grams(lines, targets, budget, Random(rng.getrandbits(64)))
            ingredient_ids = {l.food.food_id for l in lines}
            missing = ingredient_ids - useful_pantry
            recent = sum(key in request.recent_recipe_ids for key in genes)
            favorites = sum(key in request.favorite_recipe_ids for key in genes)
            # Without overlap the pantry gives no basis for preferring a recipe.
            # These preference terms are ranking weights, not dietary targets.
            missing_fraction = len(missing) / len(ingredient_ids) if useful_pantry else 0.0
            variety_cost = (0.04 * recent + 0.02 * (len(genes) - favorites)) / len(genes)
            order = (fit.hard_gap, missing_fraction, fit.soft_gap + variety_cost, fit.drift, genes)
            cache[genes] = (order, fit)
        return cache[genes][0]

    catalog = tuple(sorted(candidates))
    pantry = tuple(key for key in catalog
                   if all(l.food.food_id in request.pantry_food_ids for l in candidates[key].lines))
    pools = [pantry, catalog] if pantry != catalog else [catalog]
    for pool in pools:
        if len(pool) < request.dish_count:
            continue
        genes = _genetic_search(pool, request.dish_count, budget, rng, rank)
        fit = cache[genes][1]
        if fit.hard_gap != 0:
            continue
        ticks = iter(fit.ticks)
        dishes = []
        for key in genes:
            candidate = candidates[key]
            portions = tuple(Portion(line.food.food_id, line.food.name, next(ticks) / 10,
                                     line.food.food_id in request.pantry_food_ids)
                             for line in candidate.lines)
            dishes.append(SuggestedDish(key, candidate.recipe.name, candidate.recipe.cooking_notes, portions))
        estimated_nutrients: dict[str, float | None] = dict(zip(NUTRIENTS, fit.totals))
        for key in NUTRIENTS[4:]:
            if any(candidates[recipe_id].lines[index].food.verified_per_100g.get(key) is None
                   for recipe_id in genes
                   for index in range(len(candidates[recipe_id].lines))):
                estimated_nutrients[key] = None
        return Result("OK", tuple(dishes), estimated_nutrients)
    return Result("NO_FEASIBLE_RESULT_WITHIN_BUDGET")
