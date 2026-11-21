using AvoraAI.API.Models;
using Microsoft.EntityFrameworkCore;

namespace AvoraAI.API.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<UserProfile> Profiles => Set<UserProfile>();
    public DbSet<WeightHistoryEntry> WeightHistoryEntries => Set<WeightHistoryEntry>();
    public DbSet<OtpChallenge> OtpChallenges => Set<OtpChallenge>();
    public DbSet<RefreshSession> RefreshSessions => Set<RefreshSession>();
    public DbSet<FridgeItem> FridgeItems => Set<FridgeItem>();
    public DbSet<Food> Foods => Set<Food>();
    public DbSet<FoodGroup> FoodGroups => Set<FoodGroup>();
    public DbSet<FoodNutrition> FoodNutrition => Set<FoodNutrition>();
    public DbSet<NutritionSource> NutritionSources => Set<NutritionSource>();
    public DbSet<Dish> Dishes => Set<Dish>();
    public DbSet<DishIngredient> DishIngredients => Set<DishIngredient>();
    public DbSet<DishStep> DishSteps => Set<DishStep>();
    public DbSet<Favorite> Favorites => Set<Favorite>();
    public DbSet<Rating> Ratings => Set<Rating>();
    public DbSet<UserGoal> UserGoals => Set<UserGoal>();
    public DbSet<GoalMealAllocation> GoalMealAllocations => Set<GoalMealAllocation>();
    public DbSet<MealSuggestion> MealSuggestions => Set<MealSuggestion>();
    public DbSet<ConsumedMealLog> ConsumedMealLogs => Set<ConsumedMealLog>();
    public DbSet<ExtraCalorieEntry> ExtraCalorieEntries => Set<ExtraCalorieEntry>();
    public DbSet<AdminActionLog> AdminActionLogs => Set<AdminActionLog>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<AppUser>().HasIndex(x => x.Username).IsUnique().HasFilter("[Username] IS NOT NULL AND [IsDeleted] = 0");
        b.Entity<AppUser>().HasIndex(x => x.Email).IsUnique().HasFilter("[Email] IS NOT NULL AND [IsDeleted] = 0");
        b.Entity<AppUser>().HasIndex(x => x.Phone).IsUnique().HasFilter("[Phone] IS NOT NULL AND [IsDeleted] = 0");
        b.Entity<AdminActionLog>().Property(x => x.Outcome).HasDefaultValue("Succeeded");
        b.Entity<UserProfile>().HasKey(x => x.UserId);
        b.Entity<AppUser>().HasOne(x => x.Profile).WithOne(x => x.User).HasForeignKey<UserProfile>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<WeightHistoryEntry>().HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<WeightHistoryEntry>().HasIndex(x => new { x.UserId, x.RecordedOn }).IsUnique();
        b.Entity<WeightHistoryEntry>().Property(x => x.WeightKg).HasPrecision(6, 2);
        b.Entity<UserProfile>().Property(x => x.AllergiesJson).HasDefaultValue("[]");
        b.Entity<OtpChallenge>().HasIndex(x => new { x.Destination, x.Purpose, x.CreatedAtUtc });
        b.Entity<OtpChallenge>().HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<RefreshSession>().HasIndex(x => x.TokenHash).IsUnique();
        b.Entity<FridgeItem>().HasIndex(x => new { x.UserId, x.Name }).IsUnique();
        b.Entity<FridgeItem>().HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<FridgeItem>().HasOne<Food>().WithMany().HasForeignKey(x => x.FoodId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<Food>().HasIndex(x => x.Name).IsUnique().HasFilter("[IsDeleted] = 0");
        b.Entity<Food>().HasIndex(x => x.CatalogSourceCode).IsUnique().HasFilter("[CatalogSourceCode] IS NOT NULL");
        b.Entity<Food>().Property(x => x.IsDeleted).HasDefaultValue(false);
        b.Entity<Dish>().HasIndex(x => new { x.Status, x.IsDeleted });
        b.Entity<Dish>().HasIndex(x => x.SourceCode).IsUnique().HasFilter("[SourceCode] IS NOT NULL");
        b.Entity<Dish>().Property(x => x.Status).HasDefaultValue("Draft");
        b.Entity<Dish>().Property(x => x.Servings).HasPrecision(5, 1);
        b.Entity<FoodGroup>().HasIndex(x => x.Code).IsUnique();
        b.Entity<FoodGroup>().HasData(
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000001"), Code = "VEGETABLE", Name = "Rau" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000002"), Code = "FRUIT", Name = "Trái cây" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000003"), Code = "MEAT", Name = "Thịt" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000004"), Code = "ROOT", Name = "Củ" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000005"), Code = "NUT", Name = "Hạt" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000006"), Code = "FISH", Name = "Cá" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000007"), Code = "SEAFOOD", Name = "Hải sản khác" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000008"), Code = "EGG", Name = "Trứng" },
            new FoodGroup { Id = Guid.Parse("10000000-0000-0000-0000-000000000009"), Code = "SHRIMP", Name = "Tôm" });
        b.Entity<Food>().HasOne(x => x.FoodGroup).WithMany(x => x.Foods).HasForeignKey(x => x.FoodGroupId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<FoodNutrition>().HasKey(x => x.FoodId);
        b.Entity<Food>().HasOne(x => x.Nutrition).WithOne(x => x.Food).HasForeignKey<FoodNutrition>(x => x.FoodId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<Favorite>().HasKey(x => new { x.UserId, x.DishId });
        b.Entity<Rating>().HasKey(x => new { x.UserId, x.DishId });
        b.Entity<Favorite>().HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<Favorite>().HasOne<Dish>().WithMany().HasForeignKey(x => x.DishId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<Rating>().HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<Rating>().HasOne<Dish>().WithMany().HasForeignKey(x => x.DishId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<UserGoal>().HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<UserGoal>().HasIndex(x => new { x.UserId, x.IsActive });
        b.Entity<UserGoal>().Property(x => x.TargetWeightKg).HasPrecision(6, 2);
        b.Entity<GoalMealAllocation>().HasOne(x => x.UserGoal).WithMany(x => x.Meals).HasForeignKey(x => x.UserGoalId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<GoalMealAllocation>().HasIndex(x => new { x.UserGoalId, x.SortOrder }).IsUnique();
        b.Entity<GoalMealAllocation>().Property(x => x.AllocationRatio).HasPrecision(8, 6);
        b.Entity<MealSuggestion>().HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
        b.Entity<MealSuggestion>().HasOne(x => x.UserGoal).WithMany().HasForeignKey(x => x.UserGoalId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<MealSuggestion>().HasOne(x => x.Dish).WithMany().HasForeignKey(x => x.DishId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<MealSuggestion>().HasIndex(x => new { x.UserId, x.SessionId }).IsUnique();
        b.Entity<MealSuggestion>().Property(x => x.ServingWeightGrams).HasPrecision(8, 1);
        b.Entity<ConsumedMealLog>().HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
        b.Entity<ConsumedMealLog>().HasOne(x => x.MealSuggestion).WithMany().HasForeignKey(x => x.MealSuggestionId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<ConsumedMealLog>().HasIndex(x => x.MealSuggestionId).IsUnique();
        b.Entity<ConsumedMealLog>().HasOne(x => x.Dish).WithMany().HasForeignKey(x => x.DishId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<ExtraCalorieEntry>().HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<ExtraCalorieEntry>().HasIndex(x => new { x.UserId, x.MealDate });
        b.Entity<ExtraCalorieEntry>().Property(x => x.CaloriesKcal).HasPrecision(8, 1);
        b.Entity<DishIngredient>().HasOne(x => x.Dish).WithMany(x => x.Ingredients).HasForeignKey(x => x.DishId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<DishIngredient>().HasOne(x => x.Food).WithMany().HasForeignKey(x => x.FoodId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<DishStep>().HasOne(x => x.Dish).WithMany(x => x.Steps).HasForeignKey(x => x.DishId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<DishStep>().HasIndex(x => new { x.DishId, x.StepNumber }).IsUnique();
        foreach (var p in typeof(FoodNutrition).GetProperties().Where(p => p.PropertyType == typeof(decimal?)))
            b.Entity<FoodNutrition>().Property<decimal?>(p.Name).HasPrecision(12, 3);
        b.Entity<UserProfile>().Property(x => x.HeightCm).HasPrecision(6, 2);
        b.Entity<UserProfile>().Property(x => x.WeightKg).HasPrecision(6, 2);
        b.Entity<UserProfile>().Property(x => x.TargetWeightKg).HasPrecision(6, 2);
    }
}
