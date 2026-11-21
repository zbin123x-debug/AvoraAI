"""Idempotently import the Avora 221-food and 151-recipe workbooks into SQL Server.

The importer keeps source values and source notes, never infers missing values,
and never upgrades food or recipe AI approval. It uses Windows authentication.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
import uuid
from decimal import Decimal, InvalidOperation
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET

import pyodbc

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")

NS = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}
FOOD_FIELDS = (
    ("C", "EnergyKcal"),
    ("D", "ProteinG"),
    ("E", "CarbohydrateG"),
    ("F", "FatG"),
    ("G", "FiberG"),  # Source column is cellulose; retain source note, do not mark checked.
    ("H", "SugarG"),
    ("I", "SaturatedFatG"),
    ("J", "SodiumMg"),
)
EXPECTED_GROUP_COUNTS = {
    "Thịt": 36,
    "Rau": 52,
    "Quả (rau ăn quả)": 19,
    "Củ": 23,
    "Trái cây": 31,
    "Cá": 30,
    "Tôm": 2,
    "Hải sản khác": 16,
    "Nguyên liệu": 11,
    "Hạt": 1,
}


def normalize(value: str) -> str:
    value = " ".join(value.split()).casefold()
    value = "".join(c for c in unicodedata.normalize("NFD", value)
                    if unicodedata.category(c) != "Mn")
    return value.replace("đ", "d")


def explicit_source_food_state(name: str) -> str | None:
    # Only infer a processing state when the source name makes it explicit.
    # "Ripe" fruit is not the same state as cooked food.
    return "Cooked" if normalize(name).startswith("com trang chin ") else None


def read_xlsx(path: Path) -> dict[str, list[dict[str, str]]]:
    with ZipFile(path) as archive:
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        targets = {item.attrib["Id"]: item.attrib["Target"].lstrip("/")
                   for item in relationships}
        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            xml = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            shared_strings = ["".join(t.text or "" for t in item.findall(".//m:t", NS))
                              for item in xml.findall("m:si", NS)]
        result: dict[str, list[dict[str, str]]] = {}
        for sheet in workbook.findall("m:sheets/m:sheet", NS):
            target = targets[sheet.attrib[f"{{{NS['r']}}}id"]]
            xml = ET.fromstring(archive.read(target))
            rows = []
            for row in xml.findall(".//m:sheetData/m:row", NS):
                values: dict[str, str] = {}
                for cell in row.findall("m:c", NS):
                    match = re.match(r"[A-Z]+", cell.attrib["r"])
                    if not match:
                        continue
                    value = cell.find("m:v", NS)
                    text = value.text if value is not None else ""
                    if cell.attrib.get("t") == "s" and text:
                        text = shared_strings[int(text)]
                    elif cell.attrib.get("t") == "inlineStr":
                        text = "".join(t.text or "" for t in cell.findall(".//m:t", NS))
                    values[match.group()] = text or ""
                rows.append(values)
            result[sheet.attrib["name"]] = rows
        return result


def decimal_or_none(value: str) -> Decimal | None:
    if not value.strip():
        return None
    try:
        return Decimal(value.strip().replace(",", "."))
    except InvalidOperation as exc:
        raise ValueError(f"Invalid numeric source value: {value!r}") from exc


def source_citation(row: dict[str, str], field: str) -> tuple[str, str]:
    source = row.get("O", "").strip()
    status = row.get("R", "").strip()
    other_check = row.get("U", "").strip()
    note = row.get("S", "").strip()
    latest_review = row.get("AA", "").strip()
    latest_status = row.get("AB", "").strip()
    latest_note = row.get("AC", "").strip()
    if field == "FatG":
        url = row.get("P", "").strip()
    else:
        url = row.get("Q", "").strip() or row.get("X", "").strip()
    url = row.get("AD", "").strip() or url
    citation = " | ".join(part for part in (
        f"Raw source Celluloza={row.get('G', '').strip() or 'blank'} g; not mapped to total FiberG until verified"
        if field == "FiberG" else "",
        source,
        f"Review status: {latest_review}" if latest_review else "",
        f"Verification status: {latest_status}" if latest_status else "",
        f"Review note: {latest_note}" if latest_note else "",
        f"Chỉ tiêu: {field}",
        f"Trạng thái chất béo nguồn: {status}" if status else "",
        f"Đối chiếu 11 chỉ tiêu khác: {other_check}" if other_check else "",
        f"Ghi chú nguồn: {note}" if note else "",
        "Celluloza nguồn chưa được xác nhận tương đương chất xơ tổng"
        if field == "FiberG" else "",
    ) if part)
    return citation[:500], url[:1000]


def load_sources(food_path: Path, recipe_path: Path):
    food_sheets = read_xlsx(food_path)
    recipe_sheets = read_xlsx(recipe_path)
    if "THUC_PHAM_221" not in food_sheets:
        raise ValueError("Missing THUC_PHAM_221 sheet")
    if not {"CONG_THUC_1_NGUOI", "NGUYEN_LIEU_TUNG_MON"}.issubset(recipe_sheets):
        raise ValueError("Missing recipe workbook sheets")
    foods = food_sheets["THUC_PHAM_221"][1:]
    dishes = recipe_sheets["CONG_THUC_1_NGUOI"][1:]
    ingredients = recipe_sheets["NGUYEN_LIEU_TUNG_MON"][1:]
    if len(foods) != 221 or len(dishes) != 151 or len(ingredients) != 454:
        raise ValueError(f"Unexpected source counts: foods={len(foods)}, dishes={len(dishes)}, ingredients={len(ingredients)}")
    group_counts = {group: sum(row.get("A", "") == group for row in foods)
                    for group in EXPECTED_GROUP_COUNTS}
    if group_counts != EXPECTED_GROUP_COUNTS:
        raise ValueError(f"Unexpected food group counts: {group_counts}")
    food_by_key: dict[tuple[str, str], tuple[int, dict[str, str]]] = {}
    for excel_row, row in enumerate(foods, start=2):
        key = (normalize(row.get("B", "")), normalize(row.get("A", "")))
        if not key[0] or key in food_by_key:
            raise ValueError(f"Blank or duplicate source food at row {excel_row}: {row}")
        food_by_key[key] = (excel_row, row)
    grouped: dict[str, list[tuple[dict[str, str], Decimal, int]]] = {}
    unmatched_ingredients = []
    for excel_row, row in enumerate(ingredients, start=2):
        name, group = row.get("C", "").strip(), row.get("D", "").strip()
        source_row = int(Decimal(row.get("E", "0")))
        key = (normalize(name), normalize(group))
        match = food_by_key.get(key)
        if match is None:
            unmatched_ingredients.append({
                "recipe_code": row.get("A", ""), "workbook_row": excel_row,
                "name": name, "group": group, "reason": "Không có khớp duy nhất theo tên và nhóm",
            })
        elif match[0] != source_row:
            unmatched_ingredients.append({
                "recipe_code": row.get("A", ""), "workbook_row": excel_row,
                "name": name, "group": group,
                "reason": f"Dòng nguồn khai báo {source_row}, dòng khớp là {match[0]}",
            })
        amount = decimal_or_none(row.get("F", ""))
        if amount is None or amount <= 0 or row.get("G", "").strip().casefold() != "g":
            raise ValueError(f"Invalid ingredient amount at workbook row {excel_row}")
        grouped.setdefault(row.get("A", ""), []).append((row, amount, excel_row))
    if len(grouped) != 151 or any(len(grouped.get(row.get("A", ""), [])) == 0 for row in dishes):
        raise ValueError("At least one recipe has no ingredient mapping")
    return foods, dishes, ingredients, food_by_key, grouped, unmatched_ingredients


def run(args) -> None:
    foods, dishes, ingredient_rows, food_by_key, grouped_ingredients, unmatched_ingredients = load_sources(
        Path(args.foods), Path(args.recipes))
    source_eight_numeric_including_cellulose = sum(
        all(food.get(column, "").strip() for column in "CDEFGHIJ") for food in foods
    )
    connection_string = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={args.server};DATABASE={args.database};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;Connection Timeout=8"
    )
    conn = pyodbc.connect(connection_string, autocommit=False)
    try:
        cur = conn.cursor()
        database_name = cur.execute("SELECT DB_NAME()").fetchval()
        if database_name != "AvoraAI_DB" or args.database != "AvoraAI_DB":
            raise RuntimeError("Import is restricted to AvoraAI_DB")
        group_rows = cur.execute("SELECT Id, Code, Name FROM dbo.FoodGroups").fetchall()
        group_by_name = {normalize(row.Name): (row.Id, row.Code) for row in group_rows}
        for group_name in EXPECTED_GROUP_COUNTS:
            key = normalize(group_name)
            if key in group_by_name:
                continue
            code = {
                "Quả (rau ăn quả)": "PRODUCE_FRUIT",
                "Nguyên liệu": "INGREDIENT",
            }.get(group_name, "AVORA_" + uuid.uuid5(uuid.NAMESPACE_URL, key).hex[:18].upper())
            existing_code = cur.execute("SELECT Id, Name FROM dbo.FoodGroups WHERE Code = ?", code).fetchone()
            if existing_code:
                raise RuntimeError(f"Food group code collision: {code} / {existing_code.Name}")
            group_id = str(uuid.uuid4())
            cur.execute("INSERT INTO dbo.FoodGroups (Id, Code, Name) VALUES (?, ?, ?)",
                        group_id, code, group_name)
            group_by_name[key] = (group_id, code)

        existing_foods = cur.execute(
            "SELECT Id, Name, FoodGroupId, FoodState, IsVerified, IsApprovedForAi, CatalogSourceCode "
            "FROM dbo.Foods WHERE IsDeleted = 0").fetchall()
        existing_by_code = {row.CatalogSourceCode: row for row in existing_foods
                            if row.CatalogSourceCode}
        existing_by_name = {(normalize(row.Name), str(row.FoodGroupId or "")): row
                            for row in existing_foods}
        counts = {"foods_added": 0, "foods_updated": 0, "nutrient_values_loaded": 0,
                  "foods_all_8_values": 0, "foods_verified": 0, "foods_ai_approved": 0}
        for excel_row, food in enumerate(foods, start=2):
            name, group_name = food.get("B", "").strip(), food.get("A", "").strip()
            source_state = explicit_source_food_state(name)
            group_id = str(group_by_name[normalize(group_name)][0])
            source_code = f"AVORA221:{excel_row}"
            current = existing_by_code.get(source_code)
            if current is None:
                current = existing_by_name.get((normalize(name), group_id))
            if current and str(current.FoodGroupId or "") != group_id:
                raise RuntimeError(f"Existing food group conflicts with source row {excel_row}: {name}")
            is_new = current is None
            food_id = str(uuid.uuid4()) if is_new else str(current.Id)
            if is_new:
                cur.execute(
                    "INSERT INTO dbo.Foods (Id, Name, CatalogSourceCode, FoodState, Basis, FoodGroupId, IsVerified, IsApprovedForAi, AllergenIdsJson, IsDeleted, CreatedAtUtc) "
                    "VALUES (?, ?, ?, 'Unprocessed', N'100 g phần ăn được', ?, 0, 0, NULL, 0, SYSUTCDATETIME())",
                    food_id, name, source_code, group_id)
                counts["foods_added"] += 1
                if source_state is not None:
                    cur.execute("UPDATE dbo.Foods SET FoodState=? WHERE Id=?", source_state, food_id)
                source_checks: dict[str, bool] = {}
                existing_values = {field: None for _, field in FOOD_FIELDS}
            else:
                food_id = str(current.Id)
                cur.execute("UPDATE dbo.Foods SET Name=?, CatalogSourceCode=? WHERE Id=?",
                            name, source_code, food_id)
                if source_state is not None and current.FoodState == "Unprocessed":
                    cur.execute("UPDATE dbo.Foods SET FoodState=? WHERE Id=?", source_state, food_id)
                counts["foods_updated"] += 1
                source_rows = cur.execute(
                    "SELECT FieldName, IsChecked FROM dbo.NutritionSources WHERE FoodId=?",
                    food_id).fetchall()
                source_checks = {}
                for source_row in source_rows:
                    source_checks[source_row.FieldName] = (
                        source_checks.get(source_row.FieldName, False) or bool(source_row.IsChecked)
                    )
                values_row = cur.execute(
                    "SELECT " + ",".join(field for _, field in FOOD_FIELDS) +
                    " FROM dbo.FoodNutrition WHERE FoodId=?", food_id).fetchone()
                existing_values = ({field: getattr(values_row, field) for _, field in FOOD_FIELDS}
                                   if values_row else {field: None for _, field in FOOD_FIELDS})

            values: dict[str, Decimal | None] = {}
            for col, field in FOOD_FIELDS:
                source_value = None if field == "FiberG" else decimal_or_none(food.get(col, ""))
                values[field] = existing_values[field] if source_checks.get(field, False) else source_value
                citation, url = source_citation(food, field)
                prior = cur.execute(
                    "SELECT TOP (1) Id, IsChecked FROM dbo.NutritionSources WHERE FoodId=? AND FieldName=? ORDER BY IsChecked DESC",
                    food_id, field).fetchone()
                if prior:
                    if not bool(prior.IsChecked):
                        cur.execute("UPDATE dbo.NutritionSources SET Citation=?, Url=? WHERE Id=?",
                                    citation, url, prior.Id)
                else:
                    cur.execute(
                        "INSERT INTO dbo.NutritionSources (Id, FoodId, FieldName, Citation, Url, IsChecked) VALUES (?, ?, ?, ?, ?, 0)",
                        str(uuid.uuid4()), food_id, field, citation, url)
            columns = ",".join(field for _, field in FOOD_FIELDS)
            placeholders = ",".join("?" for _ in FOOD_FIELDS)
            params = [values[field] for _, field in FOOD_FIELDS]
            exists = cur.execute("SELECT 1 FROM dbo.FoodNutrition WHERE FoodId=?", food_id).fetchone()
            if exists:
                cur.execute("UPDATE dbo.FoodNutrition SET " + ",".join(f"{field}=?" for _, field in FOOD_FIELDS) + " WHERE FoodId=?", *params, food_id)
            else:
                cur.execute(f"INSERT INTO dbo.FoodNutrition (FoodId, {columns}) VALUES (?, {placeholders})", food_id, *params)
            counts["nutrient_values_loaded"] += sum(value is not None for value in values.values())
            counts["foods_all_8_values"] += all(value is not None for value in values.values())
            checked_fields = {row.FieldName for row in cur.execute(
                "SELECT FieldName FROM dbo.NutritionSources WHERE FoodId=? AND IsChecked=1", food_id).fetchall()}
            verified = all(values[field] is not None and field in checked_fields for _, field in FOOD_FIELDS)
            cur.execute("UPDATE dbo.Foods SET IsVerified=? WHERE Id=?", int(verified), food_id)
            counts["foods_verified"] += verified
            counts["foods_ai_approved"] += bool(current and current.IsApprovedForAi)
            existing_by_code[source_code] = type("FoodRow", (), {
                "Id": food_id, "Name": name, "FoodGroupId": group_id,
                "FoodState": "Unprocessed", "IsVerified": verified,
                "IsApprovedForAi": bool(current and current.IsApprovedForAi),
                "CatalogSourceCode": source_code,
            })()
        conn.commit()

        results = {"recipes_added": 0, "recipes_updated": 0,
                   "recipe_ingredients_linked": 0, "recipes_published": 0,
                   "recipes_ai_approved": 0, "recipes_skipped": 0,
                   "recipes_pending_review": 0}
        unmatched_rows = {row["workbook_row"] for row in unmatched_ingredients}
        food_id_by_key = {}
        rows = cur.execute("SELECT Id, Name, FoodGroupId FROM dbo.Foods WHERE IsDeleted=0").fetchall()
        group_names = {str(row.Id): row.Name for row in cur.execute("SELECT Id, Name FROM dbo.FoodGroups").fetchall()}
        for row in rows:
            food_id_by_key[(normalize(row.Name), normalize(group_names[str(row.FoodGroupId)]))] = str(row.Id)
        for recipe in dishes:
            recipe_code = recipe.get("A", "").strip()
            name = recipe.get("B", "").strip()
            category = recipe.get("C", "").strip()
            ingredient_specs = grouped_ingredients.get(recipe_code, [])
            linked = []
            for ingredient, amount, workbook_row in ingredient_specs:
                key = (normalize(ingredient.get("C", "")), normalize(ingredient.get("D", "")))
                food_id = None if workbook_row in unmatched_rows else food_id_by_key.get(key)
                linked.append((food_id, ingredient.get("C", "").strip(), amount))
            pending_review = any(food_id is None for food_id, _, _ in linked)
            recipe_status = "Draft" if pending_review else "Published"
            results["recipes_pending_review"] += pending_review
            existing = cur.execute("SELECT Id, Status FROM dbo.Dishes WHERE SourceCode=?", recipe_code).fetchone()
            if pending_review and existing is not None:
                # Keep a previously imported complete recipe intact. The CLI
                # report records the unresolved source rows for Admin review.
                results["recipes_skipped"] += 1
                continue
            was_new = existing is None
            dish_id = str(uuid.uuid4()) if was_new else str(existing.Id)
            steps = recipe.get("F", "").strip()
            note = recipe.get("G", "").strip()
            cooking_notes = steps + ("\n\nLưu ý: " + note if note else "")
            cur.execute("BEGIN TRANSACTION")
            try:
                if was_new:
                    cur.execute(
                        "INSERT INTO dbo.Dishes (Id, SourceCode, Name, Category, CookingNotes, Servings, Status, IsApprovedForAi, IsDeleted, CreatedAtUtc, UpdatedAtUtc) "
                        "VALUES (?, ?, ?, ?, ?, 1, ?, 0, 0, SYSUTCDATETIME(), SYSUTCDATETIME())",
                        dish_id, recipe_code, name, category, cooking_notes, recipe_status)
                    results["recipes_added"] += 1
                else:
                    cur.execute(
                        "UPDATE dbo.Dishes SET Name=?, Category=?, CookingNotes=?, Servings=1, Status=?, UpdatedAtUtc=SYSUTCDATETIME() WHERE Id=?",
                        name, category, cooking_notes, recipe_status, dish_id)
                    results["recipes_updated"] += 1
                cur.execute("DELETE FROM dbo.DishIngredients WHERE DishId=?", dish_id)
                cur.execute("DELETE FROM dbo.DishSteps WHERE DishId=?", dish_id)
                cur.executemany(
                    "INSERT INTO dbo.DishIngredients (Id, DishId, FoodId, IngredientName, AmountInstruction, SortOrder) VALUES (?, ?, ?, ?, ?, ?)",
                    [(str(uuid.uuid4()), dish_id, food_id, ingredient_name,
                      f"{amount.normalize():f} g", index)
                     for index, (food_id, ingredient_name, amount) in enumerate(linked)])
                results["recipe_ingredients_linked"] += len(linked)
                results["recipes_published"] += 1
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        final = cur.execute(
            "SELECT (SELECT COUNT(*) FROM dbo.FoodGroups), (SELECT COUNT(*) FROM dbo.Foods WHERE IsDeleted=0), "
            "(SELECT COUNT(*) FROM dbo.Dishes WHERE IsDeleted=0 AND SourceCode LIKE 'CT%'), "
            "(SELECT COUNT(*) FROM dbo.DishIngredients i INNER JOIN dbo.Dishes d ON d.Id=i.DishId WHERE d.SourceCode LIKE 'CT%' AND i.FoodId IS NOT NULL), "
            "(SELECT COUNT(*) FROM dbo.Foods f INNER JOIN dbo.FoodNutrition n ON n.FoodId=f.Id WHERE f.CatalogSourceCode LIKE 'AVORA221:%' AND "
            "n.EnergyKcal IS NOT NULL AND n.ProteinG IS NOT NULL AND n.CarbohydrateG IS NOT NULL AND n.FatG IS NOT NULL AND "
            "n.FiberG IS NOT NULL AND n.SugarG IS NOT NULL AND n.SaturatedFatG IS NOT NULL AND n.SodiumMg IS NOT NULL), "
            "(SELECT COUNT(*) FROM dbo.Foods WHERE CatalogSourceCode LIKE 'AVORA221:%' AND IsVerified=1), "
            "(SELECT COUNT(*) FROM dbo.Dishes WHERE SourceCode LIKE 'CT%' AND IsApprovedForAi=1), "
            "(SELECT COUNT(*) FROM dbo.DishIngredients i INNER JOIN dbo.Dishes d ON d.Id=i.DishId WHERE d.SourceCode LIKE 'CT%'), "
            "(SELECT COUNT(*) FROM dbo.Dishes WHERE IsDeleted=0 AND SourceCode LIKE 'CT%' AND Status='Published'), "
            "(SELECT COUNT(*) FROM dbo.Dishes WHERE IsDeleted=0 AND SourceCode LIKE 'CT%' AND Status='Draft'), "
            "(SELECT COUNT(*) FROM dbo.Foods WHERE CatalogSourceCode LIKE 'AVORA221:%' AND IsApprovedForAi=1)").fetchone()
        source_group_counts = cur.execute(
            "SELECT g.Name, COUNT(*) AS FoodCount FROM dbo.Foods f "
            "INNER JOIN dbo.FoodGroups g ON g.Id=f.FoodGroupId "
            "WHERE f.CatalogSourceCode LIKE 'AVORA221:%' AND f.IsDeleted=0 "
            "GROUP BY g.Name ORDER BY g.Name").fetchall()
        conn.commit()
        print("Import summary")
        print(f"Groups in database (including existing custom groups): {final[0]}")
        print(f"Foods added/updated: {counts['foods_added']}/{counts['foods_updated']}; current source foods: {final[1]}")
        print("Source food group counts:")
        for group in source_group_counts:
            print(f"  {group.Name}: {group.FoodCount}")
        print(f"Nutrient values loaded (8 target fields): {counts['nutrient_values_loaded']}; DB foods with all 8 values: {final[4]}; verified: {final[5]}")
        print(f"Workbook rows with 8 numeric source cells including Celluloza: {source_eight_numeric_including_cellulose}; Celluloza is retained in source citation, not mapped as total fiber")
        print(f"Recipes added/updated: {results['recipes_added']}/{results['recipes_updated']}; source recipes: {final[2]} (published {final[8]}, draft review {final[9]})")
        print(f"Ingredient rows this run: {results['recipe_ingredients_linked']}; current rows {final[7]} (FoodID linked {final[3]}); skipped: {results['recipes_skipped']}")
        print(f"Recipes held as Draft for Admin review: {results['recipes_pending_review']}")
        print(f"Unmatched source ingredient rows: {len(unmatched_ingredients)}")
        for row in unmatched_ingredients:
            print(f"  {row['recipe_code']} / workbook row {row['workbook_row']} / {row['name']} / {row['group']} / {row['reason']}")
        print(f"AI-approved foods/recipes: {final[10]}/{final[6]} (approval is not inferred by import)")
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--foods", required=True)
    parser.add_argument("--recipes", required=True)
    parser.add_argument("--server", default="localhost\\MSSQLSERVER01")
    parser.add_argument("--database", default="AvoraAI_DB")
    run(parser.parse_args())


if __name__ == "__main__":
    main()
