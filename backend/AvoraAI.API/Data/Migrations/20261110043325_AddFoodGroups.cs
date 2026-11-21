using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddFoodGroups : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "FoodGroupId",
                table: "Foods",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "FoodGroups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodGroups", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "FoodGroups",
                columns: new[] { "Id", "Code", "Name" },
                values: new object[,]
                {
                    { new Guid("10000000-0000-0000-0000-000000000001"), "VEGETABLE", "Rau" },
                    { new Guid("10000000-0000-0000-0000-000000000002"), "FRUIT", "Trái cây" },
                    { new Guid("10000000-0000-0000-0000-000000000003"), "MEAT", "Thịt" },
                    { new Guid("10000000-0000-0000-0000-000000000004"), "ROOT", "Củ" },
                    { new Guid("10000000-0000-0000-0000-000000000005"), "NUT", "Hạt" },
                    { new Guid("10000000-0000-0000-0000-000000000006"), "FISH", "Cá" },
                    { new Guid("10000000-0000-0000-0000-000000000007"), "SEAFOOD", "Hải sản khác" },
                    { new Guid("10000000-0000-0000-0000-000000000008"), "EGG", "Trứng" },
                    { new Guid("10000000-0000-0000-0000-000000000009"), "SHRIMP", "Tôm" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Foods_FoodGroupId",
                table: "Foods",
                column: "FoodGroupId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodGroups_Code",
                table: "FoodGroups",
                column: "Code",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Foods_FoodGroups_FoodGroupId",
                table: "Foods",
                column: "FoodGroupId",
                principalTable: "FoodGroups",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Foods_FoodGroups_FoodGroupId",
                table: "Foods");

            migrationBuilder.DropTable(
                name: "FoodGroups");

            migrationBuilder.DropIndex(
                name: "IX_Foods_FoodGroupId",
                table: "Foods");

            migrationBuilder.DropColumn(
                name: "FoodGroupId",
                table: "Foods");
        }
    }
}
