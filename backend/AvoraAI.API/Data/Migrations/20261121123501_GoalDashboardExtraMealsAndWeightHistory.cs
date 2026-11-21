using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class GoalDashboardExtraMealsAndWeightHistory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsExtraMeal",
                table: "MealSuggestions",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<TimeOnly>(
                name: "MealTime",
                table: "MealSuggestions",
                type: "time",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ServingWeightGrams",
                table: "MealSuggestions",
                type: "decimal(8,1)",
                precision: 8,
                scale: 1,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "WeightHistoryEntries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RecordedOn = table.Column<DateOnly>(type: "date", nullable: false),
                    WeightKg = table.Column<decimal>(type: "decimal(6,2)", precision: 6, scale: 2, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WeightHistoryEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WeightHistoryEntries_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WeightHistoryEntries_UserId_RecordedOn",
                table: "WeightHistoryEntries",
                columns: new[] { "UserId", "RecordedOn" },
                unique: true);

            migrationBuilder.Sql(
                "INSERT INTO [WeightHistoryEntries] ([Id], [UserId], [RecordedOn], [WeightKg], [CreatedAtUtc]) " +
                "SELECT NEWID(), [UserId], CONVERT(date, [UpdatedAtUtc]), [WeightKg], SYSUTCDATETIME() " +
                "FROM [Profiles] WHERE [WeightKg] IS NOT NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "WeightHistoryEntries");

            migrationBuilder.DropColumn(
                name: "IsExtraMeal",
                table: "MealSuggestions");

            migrationBuilder.DropColumn(
                name: "MealTime",
                table: "MealSuggestions");

            migrationBuilder.DropColumn(
                name: "ServingWeightGrams",
                table: "MealSuggestions");
        }
    }
}
