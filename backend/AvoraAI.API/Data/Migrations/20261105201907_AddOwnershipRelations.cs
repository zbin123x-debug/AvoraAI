using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddOwnershipRelations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Ratings_DishId",
                table: "Ratings",
                column: "DishId");

            migrationBuilder.CreateIndex(
                name: "IX_OtpChallenges_UserId",
                table: "OtpChallenges",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_FridgeItems_FoodId",
                table: "FridgeItems",
                column: "FoodId");

            migrationBuilder.CreateIndex(
                name: "IX_Favorites_DishId",
                table: "Favorites",
                column: "DishId");

            migrationBuilder.AddForeignKey(
                name: "FK_Favorites_Dishes_DishId",
                table: "Favorites",
                column: "DishId",
                principalTable: "Dishes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Favorites_Users_UserId",
                table: "Favorites",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_FridgeItems_Foods_FoodId",
                table: "FridgeItems",
                column: "FoodId",
                principalTable: "Foods",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_FridgeItems_Users_UserId",
                table: "FridgeItems",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_OtpChallenges_Users_UserId",
                table: "OtpChallenges",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Ratings_Dishes_DishId",
                table: "Ratings",
                column: "DishId",
                principalTable: "Dishes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Ratings_Users_UserId",
                table: "Ratings",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Favorites_Dishes_DishId",
                table: "Favorites");

            migrationBuilder.DropForeignKey(
                name: "FK_Favorites_Users_UserId",
                table: "Favorites");

            migrationBuilder.DropForeignKey(
                name: "FK_FridgeItems_Foods_FoodId",
                table: "FridgeItems");

            migrationBuilder.DropForeignKey(
                name: "FK_FridgeItems_Users_UserId",
                table: "FridgeItems");

            migrationBuilder.DropForeignKey(
                name: "FK_OtpChallenges_Users_UserId",
                table: "OtpChallenges");

            migrationBuilder.DropForeignKey(
                name: "FK_Ratings_Dishes_DishId",
                table: "Ratings");

            migrationBuilder.DropForeignKey(
                name: "FK_Ratings_Users_UserId",
                table: "Ratings");

            migrationBuilder.DropIndex(
                name: "IX_Ratings_DishId",
                table: "Ratings");

            migrationBuilder.DropIndex(
                name: "IX_OtpChallenges_UserId",
                table: "OtpChallenges");

            migrationBuilder.DropIndex(
                name: "IX_FridgeItems_FoodId",
                table: "FridgeItems");

            migrationBuilder.DropIndex(
                name: "IX_Favorites_DishId",
                table: "Favorites");
        }
    }
}
