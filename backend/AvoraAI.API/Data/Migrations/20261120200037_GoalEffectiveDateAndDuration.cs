using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AvoraAI.API.Data.Migrations
{
    /// <inheritdoc />
    public partial class GoalEffectiveDateAndDuration : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DurationDays",
                table: "UserGoals",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "EffectiveStartDate",
                table: "UserGoals",
                type: "date",
                nullable: true);

            migrationBuilder.Sql("UPDATE [UserGoals] SET [DurationDays] = 90, [EffectiveStartDate] = CONVERT(date, [CreatedAtUtc]);");

            migrationBuilder.AlterColumn<int>(
                name: "DurationDays",
                table: "UserGoals",
                type: "int",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AlterColumn<DateOnly>(
                name: "EffectiveStartDate",
                table: "UserGoals",
                type: "date",
                nullable: false,
                oldClrType: typeof(DateOnly),
                oldType: "date",
                oldNullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DurationDays",
                table: "UserGoals");

            migrationBuilder.DropColumn(
                name: "EffectiveStartDate",
                table: "UserGoals");
        }
    }
}
