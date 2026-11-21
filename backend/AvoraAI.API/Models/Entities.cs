using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace AvoraAI.API.Models;

public sealed class AppUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(32)] public string? Username { get; set; }
    [MaxLength(320)] public string? Email { get; set; }
    [MaxLength(32)] public string? Phone { get; set; }
    [MaxLength(500)] public string PasswordHash { get; set; } = "";
    [MaxLength(20)] public string Role { get; set; } = "User";
    public bool IsActive { get; set; } = true;
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
    public Guid? DeletedByUserId { get; set; }
    [MaxLength(500)] public string? DeletionReason { get; set; }
    public bool MustChangePassword { get; set; }
    public bool IsEmailVerified { get; set; }
    public bool IsPhoneVerified { get; set; }
    public int TokenVersion { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public UserProfile? Profile { get; set; }
    public ICollection<RefreshSession> Sessions { get; set; } = [];
}

public sealed class UserProfile
{
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    [MaxLength(120)] public string? FullName { get; set; }
    public DateOnly? BirthDate { get; set; }
    [MaxLength(30)] public string? Gender { get; set; }
    public decimal? HeightCm { get; set; }
    public decimal? WeightKg { get; set; }
    [MaxLength(20)] public string? Goal { get; set; }
    public decimal? TargetWeightKg { get; set; }
    [MaxLength(500)] public string? WeightGainNote { get; set; }
    [MaxLength(30)] public string? WeightGainTendency { get; set; }
    public int? MealsPerDay { get; set; }
    [MaxLength(30)] public string? Diet { get; set; }
    public bool NoAllergies { get; set; }
    public string AllergiesJson { get; set; } = "[]";
    [MaxLength(30)] public string? ActivityLevel { get; set; }
    [MaxLength(500), JsonIgnore] public string? AvatarPath { get; set; }
    public int OnboardingStep { get; set; } = 1;
    public bool IsComplete { get; set; }
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class WeightHistoryEntry
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public DateOnly RecordedOn { get; set; }
    public decimal WeightKg { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class OtpChallenge
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? UserId { get; set; }
    [MaxLength(320)] public string Destination { get; set; } = "";
    [MaxLength(30)] public string Purpose { get; set; } = "";
    [MaxLength(128)] public string CodeHash { get; set; } = "";
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? ConsumedAtUtc { get; set; }
    public int FailedAttempts { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class RefreshSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    [MaxLength(128)] public string TokenHash { get; set; } = "";
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
}

public sealed class FridgeItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    [MaxLength(160)] public string Name { get; set; } = "";
    public Guid? FoodId { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class Food
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(160)] public string Name { get; set; } = "";
    [MaxLength(80)] public string? CatalogSourceCode { get; set; }
    public string FoodState { get; set; } = "Unprocessed";
    public string Basis { get; set; } = "100 g phần ăn được";
    [MaxLength(500), JsonIgnore] public string? ImagePath { get; set; }
    public Guid? FoodGroupId { get; set; }
    public FoodGroup? FoodGroup { get; set; }
    [NotMapped] public bool HasImage => !string.IsNullOrWhiteSpace(ImagePath);
    public FoodNutrition? Nutrition { get; set; }
    public ICollection<NutritionSource> Sources { get; set; } = [];
    public bool IsVerified { get; set; }
    public bool IsApprovedForAi { get; set; }
    public string? AllergenIdsJson { get; set; }
    [JsonIgnore] public Guid? VerifiedByUserId { get; set; }
    public DateTime? VerifiedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
    [JsonIgnore] public Guid? DeletedByUserId { get; set; }
    [MaxLength(20)] public string? DeletedByRole { get; set; }
    [NotMapped] public string? DeletedByName { get; set; }
    [NotMapped] public string? DeletedByEmail { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class FoodGroup
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(40)] public string Code { get; set; } = "";
    [MaxLength(100)] public string Name { get; set; } = "";
    public ICollection<Food> Foods { get; set; } = [];
}

public sealed class FoodNutrition
{
    public Guid FoodId { get; set; }
    public Food Food { get; set; } = null!;
    public decimal? EnergyKcal { get; set; }
    public decimal? ProteinG { get; set; }
    public decimal? CarbohydrateG { get; set; }
    public decimal? FatG { get; set; }
    public decimal? FiberG { get; set; }
    public decimal? SugarG { get; set; }
    public decimal? SaturatedFatG { get; set; }
    public decimal? SodiumMg { get; set; }
}

public sealed class NutritionSource
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FoodId { get; set; }
    public Food Food { get; set; } = null!;
    [MaxLength(40)] public string FieldName { get; set; } = "";
    [MaxLength(500)] public string Citation { get; set; } = "";
    [MaxLength(1000)] public string Url { get; set; } = "";
    public bool IsChecked { get; set; }
    public DateTime? CheckedAtUtc { get; set; }
}

public sealed class Dish
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(20)] public string? SourceCode { get; set; }
    [MaxLength(160)] public string Name { get; set; } = "";
    [MaxLength(80)] public string? Category { get; set; }
    [MaxLength(8000)] public string? CookingNotes { get; set; }
    public string? Description { get; set; }
    [MaxLength(80)] public string? CookingMethod { get; set; }
    public int? PreparationMinutes { get; set; }
    public int? CookingMinutes { get; set; }
    public decimal? Servings { get; set; }
    [MaxLength(2000)] public string? Tips { get; set; }
    [MaxLength(1200)] public string? Source { get; set; }
    [MaxLength(500), JsonIgnore] public string? ImagePath { get; set; }
    [NotMapped] public bool HasImage => !string.IsNullOrWhiteSpace(ImagePath);
    [MaxLength(20)] public string Status { get; set; } = "Draft";
    public bool IsApprovedForAi { get; set; }
    public string? DietTagsJson { get; set; }
    public string? AllergenIdsJson { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
    [JsonIgnore] public Guid? DeletedByUserId { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    public ICollection<DishIngredient> Ingredients { get; set; } = [];
    public ICollection<DishStep> Steps { get; set; } = [];
}

public sealed class DishIngredient
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid DishId { get; set; }
    public Dish Dish { get; set; } = null!;
    public Guid? FoodId { get; set; }
    public Food? Food { get; set; }
    [MaxLength(160)] public string IngredientName { get; set; } = "";
    [MaxLength(120)] public string? AmountInstruction { get; set; }
    public int SortOrder { get; set; }
}

public sealed class DishStep
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid DishId { get; set; }
    public Dish Dish { get; set; } = null!;
    public int StepNumber { get; set; }
    [MaxLength(2000)] public string Instruction { get; set; } = "";
}

public sealed class Favorite
{
    public Guid UserId { get; set; }
    public Guid DishId { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class Rating
{
    public Guid UserId { get; set; }
    public Guid DishId { get; set; }
    public int Stars { get; set; }
    [MaxLength(2000)] public string? Comment { get; set; }
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class UserGoal
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    [MaxLength(20)] public string Goal { get; set; } = "";
    public decimal TargetWeightKg { get; set; }
    public int MealsPerDay { get; set; }
    public DateOnly EffectiveStartDate { get; set; }
    public int DurationDays { get; set; } = 90;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public ICollection<GoalMealAllocation> Meals { get; set; } = [];
}

public sealed class GoalMealAllocation
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserGoalId { get; set; }
    public UserGoal UserGoal { get; set; } = null!;
    [MaxLength(40)] public string MealName { get; set; } = "";
    public int SortOrder { get; set; }
    public decimal AllocationRatio { get; set; }
    public string? TargetsJson { get; set; }
}

public sealed class MealSuggestion
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public Guid UserGoalId { get; set; }
    public UserGoal UserGoal { get; set; } = null!;
    public Guid SessionId { get; set; }
    public DateOnly MealDate { get; set; }
    [MaxLength(40)] public string MealName { get; set; } = "";
    public bool IsExtraMeal { get; set; }
    public TimeOnly? MealTime { get; set; }
    public decimal? ServingWeightGrams { get; set; }
    public Guid DishId { get; set; }
    public Dish Dish { get; set; } = null!;
    public string PersonalizedIngredientsJson { get; set; } = "[]";
    public string EstimatedNutrientsJson { get; set; } = "{}";
    public string ExcludedDishIdsJson { get; set; } = "[]";
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class ConsumedMealLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public Guid MealSuggestionId { get; set; }
    public MealSuggestion MealSuggestion { get; set; } = null!;
    public Guid DishId { get; set; }
    public Dish Dish { get; set; } = null!;
    public DateOnly MealDate { get; set; }
    [MaxLength(40)] public string MealName { get; set; } = "";
    public string ConsumedIngredientsJson { get; set; } = "[]";
    public DateTime ConfirmedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class ExtraCalorieEntry
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;
    public DateOnly MealDate { get; set; }
    public decimal CaloriesKcal { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class AdminActionLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid AdminUserId { get; set; }
    [MaxLength(80)] public string Action { get; set; } = "";
    public Guid? TargetUserId { get; set; }
    [MaxLength(500)] public string Reason { get; set; } = "";
    [MaxLength(30)] public string Outcome { get; set; } = "Succeeded";
    public string? BeforeJson { get; set; }
    public string? AfterJson { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
