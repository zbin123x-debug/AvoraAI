using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class ExtraMealCaloriesOnly : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ExtraCalorieEntries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MealDate = table.Column<DateOnly>(type: "date", nullable: false),
                    CaloriesKcal = table.Column<decimal>(type: "decimal(8,1)", precision: 8, scale: 1, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExtraCalorieEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ExtraCalorieEntries_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ExtraCalorieEntries_UserId_MealDate",
                table: "ExtraCalorieEntries",
                columns: new[] { "UserId", "MealDate" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ExtraCalorieEntries");
        }
    }
}
