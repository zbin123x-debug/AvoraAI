using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class DishManagement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CookingMethod",
                table: "Dishes",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CookingMinutes",
                table: "Dishes",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAtUtc",
                table: "Dishes",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAtUtc",
                table: "Dishes",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "DeletedByUserId",
                table: "Dishes",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ImagePath",
                table: "Dishes",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsDeleted",
                table: "Dishes",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "PreparationMinutes",
                table: "Dishes",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Servings",
                table: "Dishes",
                type: "decimal(5,1)",
                precision: 5,
                scale: 1,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Source",
                table: "Dishes",
                type: "nvarchar(1200)",
                maxLength: 1200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "Dishes",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Draft");

            migrationBuilder.AddColumn<string>(
                name: "Tips",
                table: "Dishes",
                type: "nvarchar(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAtUtc",
                table: "Dishes",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.Sql("UPDATE [Dishes] SET [CreatedAtUtc] = SYSUTCDATETIME(), [UpdatedAtUtc] = SYSUTCDATETIME() WHERE [CreatedAtUtc] = '0001-01-01T00:00:00' OR [UpdatedAtUtc] = '0001-01-01T00:00:00'");

            migrationBuilder.CreateTable(
                name: "DishIngredients",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DishId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FoodId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    IngredientName = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    AmountInstruction = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: true),
                    SortOrder = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DishIngredients", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DishIngredients_Dishes_DishId",
                        column: x => x.DishId,
                        principalTable: "Dishes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_DishIngredients_Foods_FoodId",
                        column: x => x.FoodId,
                        principalTable: "Foods",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "DishSteps",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DishId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StepNumber = table.Column<int>(type: "int", nullable: false),
                    Instruction = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DishSteps", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DishSteps_Dishes_DishId",
                        column: x => x.DishId,
                        principalTable: "Dishes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Dishes_Status_IsDeleted",
                table: "Dishes",
                columns: new[] { "Status", "IsDeleted" });

            migrationBuilder.CreateIndex(
                name: "IX_DishIngredients_DishId",
                table: "DishIngredients",
                column: "DishId");

            migrationBuilder.CreateIndex(
                name: "IX_DishIngredients_FoodId",
                table: "DishIngredients",
                column: "FoodId");

            migrationBuilder.CreateIndex(
                name: "IX_DishSteps_DishId_StepNumber",
                table: "DishSteps",
                columns: new[] { "DishId", "StepNumber" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DishIngredients");

            migrationBuilder.DropTable(
                name: "DishSteps");

            migrationBuilder.DropIndex(
                name: "IX_Dishes_Status_IsDeleted",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "CookingMethod",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "CookingMinutes",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "CreatedAtUtc",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "DeletedAtUtc",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "DeletedByUserId",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "ImagePath",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "IsDeleted",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "PreparationMinutes",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "Servings",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "Source",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "Tips",
                table: "Dishes");

            migrationBuilder.DropColumn(
                name: "UpdatedAtUtc",
                table: "Dishes");
        }
    }
}
