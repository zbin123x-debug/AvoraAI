using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class GoalMealsAndConsumption : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UserGoals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Goal = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    TargetWeightKg = table.Column<decimal>(type: "decimal(6,2)", precision: 6, scale: 2, nullable: false),
                    MealsPerDay = table.Column<int>(type: "int", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserGoals", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserGoals_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "GoalMealAllocations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserGoalId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MealName = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    AllocationRatio = table.Column<decimal>(type: "decimal(8,6)", precision: 8, scale: 6, nullable: false),
                    TargetsJson = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GoalMealAllocations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GoalMealAllocations_UserGoals_UserGoalId",
                        column: x => x.UserGoalId,
                        principalTable: "UserGoals",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "MealSuggestions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserGoalId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MealDate = table.Column<DateOnly>(type: "date", nullable: false),
                    MealName = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    DishId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PersonalizedIngredientsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    EstimatedNutrientsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ExcludedDishIdsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MealSuggestions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MealSuggestions_Dishes_DishId",
                        column: x => x.DishId,
                        principalTable: "Dishes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MealSuggestions_UserGoals_UserGoalId",
                        column: x => x.UserGoalId,
                        principalTable: "UserGoals",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MealSuggestions_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ConsumedMealLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MealSuggestionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DishId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MealDate = table.Column<DateOnly>(type: "date", nullable: false),
                    MealName = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    ConsumedIngredientsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ConfirmedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConsumedMealLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConsumedMealLogs_Dishes_DishId",
                        column: x => x.DishId,
                        principalTable: "Dishes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ConsumedMealLogs_MealSuggestions_MealSuggestionId",
                        column: x => x.MealSuggestionId,
                        principalTable: "MealSuggestions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ConsumedMealLogs_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_ConsumedMealLogs_DishId",
                table: "ConsumedMealLogs",
                column: "DishId");

            migrationBuilder.CreateIndex(
                name: "IX_ConsumedMealLogs_MealSuggestionId",
                table: "ConsumedMealLogs",
                column: "MealSuggestionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ConsumedMealLogs_UserId",
                table: "ConsumedMealLogs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_GoalMealAllocations_UserGoalId_SortOrder",
                table: "GoalMealAllocations",
                columns: new[] { "UserGoalId", "SortOrder" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MealSuggestions_DishId",
                table: "MealSuggestions",
                column: "DishId");

            migrationBuilder.CreateIndex(
                name: "IX_MealSuggestions_UserGoalId",
                table: "MealSuggestions",
                column: "UserGoalId");

            migrationBuilder.CreateIndex(
                name: "IX_MealSuggestions_UserId_SessionId",
                table: "MealSuggestions",
                columns: new[] { "UserId", "SessionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserGoals_UserId_IsActive",
                table: "UserGoals",
                columns: new[] { "UserId", "IsActive" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ConsumedMealLogs");

            migrationBuilder.DropTable(
                name: "GoalMealAllocations");

            migrationBuilder.DropTable(
                name: "MealSuggestions");

            migrationBuilder.DropTable(
                name: "UserGoals");
        }
    }
}
