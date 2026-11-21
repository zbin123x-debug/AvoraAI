using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class ReduceFoodNutritionToTwelve : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FolateMcg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "MagnesiumMg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "VitaminAMcg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "VitaminB12Mcg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "VitaminDMcg",
                table: "FoodNutrition");

            migrationBuilder.DropColumn(
                name: "ZincMg",
                table: "FoodNutrition");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "FolateMcg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "MagnesiumMg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "VitaminAMcg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "VitaminB12Mcg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "VitaminDMcg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ZincMg",
                table: "FoodNutrition",
                type: "decimal(12,3)",
                precision: 12,
                scale: 3,
                nullable: true);
        }
    }
}
