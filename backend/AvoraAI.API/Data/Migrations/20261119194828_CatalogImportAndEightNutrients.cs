using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class CatalogImportAndEightNutrients : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CalciumMg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "IronMg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "PotassiumMg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "VitaminCMg",
                table: "FoodNutrition");

            migrationBuilder.AddColumn<string>(
                name: "AllergenIdsJson",
                table: "Foods",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CatalogSourceCode",
                table: "Foods",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsApprovedForAi",
                table: "Foods",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "AllergenIdsJson",
                table: "Dishes",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Category",
                table: "Dishes",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DietTagsJson",
                table: "Dishes",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsApprovedForAi",
                table: "Dishes",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "SourceCode",
                table: "Dishes",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Foods_CatalogSourceCode",
                table: "Foods",
                column: "CatalogSourceCode",
                unique: true,
                filter: "[CatalogSourceCode] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Dishes_SourceCode",
                table: "Dishes",
                column: "SourceCode",
                unique: true,
                filter: "[SourceCode] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Foods_CatalogSourceCode",
                table: "Foods");

            migrationBuilder.DropIndex(
                name: "IX_Dishes_SourceCode",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "AllergenIdsJson",
                table: "Foods");

            migrationBuilder.DropColumn(
                name: "CatalogSourceCode",
                table: "Foods");

            migrationBuilder.DropColumn(
                name: "IsApprovedForAi",
                table: "Foods");

            migrationBuilder.DropColumn(
                name: "AllergenIdsJson",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "Category",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "DietTagsJson",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "IsApprovedForAi",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "SourceCode",
                table: "Dishes");

            migrationBuilder.AddColumn<decimal>(
                name: "CalciumMg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "IronMg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PotassiumMg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "VitaminCMg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);
        }
    }
}
