using System.Text.Json;
using AvoraAI.API.Models;

namespace AvoraAI.API.Services;

public sealed record DailyEnergyEstimate(decimal MaintenanceKcal, decimal TargetKcal, int Age, bool IsAdult, bool UsesAverageSexEstimate);

public static class DailyEnergyEstimator
{
    public static DailyEnergyEstimate? Calculate(UserProfile profile, string? goal)
    {
        if (profile.BirthDate is null || profile.HeightCm is null || profile.WeightKg is null ||
            profile.HeightCm <= 0 || profile.WeightKg <= 0)
            return null;

        var age = AgeInYears(profile.BirthDate.Value, DateOnly.FromDateTime(DateTime.Now));
        if (age < 3) return null;

        var gender = profile.Gender?.Trim().ToLowerInvariant();
        var isMale = gender switch
        {
            "nam" => true,
            "nữ" => false,
            _ => (bool?)null,
        };
        var usesAverageSexEstimate = gender != "nam" && gender != "nữ";

        var activity = profile.ActivityLevel?.Trim() switch
        {
            "Ít vận động" => Activity.Inactive,
            "Vận động nhẹ" => Activity.LowActive,
            "Vận động vừa" => Activity.Active,
            "Vận động nhiều" => Activity.VeryActive,
            _ => (Activity?)null,
        };
        if (activity is null) return null;

        var weight = (double)profile.WeightKg.Value;
        var height = (double)profile.HeightCm.Value;
        var maintenance = usesAverageSexEstimate
            ? (EstimateEnergy(age, true, activity.Value, weight, height) +
               EstimateEnergy(age, false, activity.Value, weight, height)) / 2
            : EstimateEnergy(age, isMale!.Value, activity.Value, weight, height);
        if (!double.IsFinite(maintenance) || maintenance is < 800 or > 6000) return null;

        var isAdult = age >= 19;
        var goalFactor = isAdult ? goal switch
        {
            "Giảm cân" => 0.90,
            "Tăng cân" => 1.10,
            _ => 1.00,
        } : 1.00;

        return new DailyEnergyEstimate(
            (decimal)Math.Round(maintenance, MidpointRounding.AwayFromZero),
            (decimal)Math.Round(maintenance * goalFactor, MidpointRounding.AwayFromZero),
            age,
            isAdult,
            usesAverageSexEstimate);
    }

    public static bool RefreshMealTargets(UserProfile profile, UserGoal goal)
        => RefreshMealTargets(profile, goal.Goal, goal.Meals);

    public static bool RefreshMealTargets(UserProfile profile, string? goal, IEnumerable<GoalMealAllocation> meals)
    {
        var estimate = Calculate(profile, goal);
        var changed = false;
        var allocations = meals.OrderBy(x => x.SortOrder).ToArray();
        var ratios = MealAllocationRatios(allocations.Length);
        for (var index = 0; index < allocations.Length; index++)
        {
            var meal = allocations[index];
            if (meal.AllocationRatio != ratios[index])
            {
                meal.AllocationRatio = ratios[index];
                changed = true;
            }
            var targetsJson = estimate is null ? null : BuildMealTargets(estimate.TargetKcal * meal.AllocationRatio);
            if (meal.TargetsJson == targetsJson) continue;
            meal.TargetsJson = targetsJson;
            changed = true;
        }
        return changed;
    }

    public static decimal[] MealAllocationRatios(int mealCount)
    {
        decimal[]? typicalRatios = mealCount switch
        {
            1 => [1.00m],
            2 => [0.50m, 0.50m],
            3 => [0.30m, 0.40m, 0.30m],
            4 => [0.30m, 0.35m, 0.15m, 0.20m],
            5 => [0.25m, 0.05m, 0.35m, 0.15m, 0.20m],
            _ => null,
        };
        if (typicalRatios is not null) return typicalRatios;
        if (mealCount <= 0) return [];

        var equalShare = Math.Round(1m / mealCount, 6, MidpointRounding.AwayFromZero);
        var ratios = Enumerable.Repeat(equalShare, mealCount).ToArray();
        ratios[^1] = 1m - equalShare * (mealCount - 1);
        return ratios;
    }

    private static string BuildMealTargets(decimal energyKcal)
    {
        var energy = Math.Round(energyKcal, 1, MidpointRounding.AwayFromZero);
        var targets = new Dictionary<string, object>
        {
            ["energy_kcal"] = TargetRange(energy, 0.9m, 1.0m, 0.65m, 1.0m, 100m),
            ["protein_g"] = TargetRange(energy * 0.15m / 4m, 0.85m, 1.15m, 0m, 3m, 0.05m),
            ["carbohydrate_g"] = TargetRange(energy * 0.55m / 4m, 0.85m, 1.15m, 0m, 3m, 0.05m),
            ["total_fat_g"] = TargetRange(energy * 0.30m / 9m, 0.85m, 1.15m, 0m, 3m, 0.05m),
        };
        return JsonSerializer.Serialize(targets);
    }

    private static object TargetRange(decimal target, decimal minimum, decimal maximum,
        decimal hardMinimum, decimal hardMaximum, decimal weight) => new
    {
        minimum = Math.Round(target * minimum, 1, MidpointRounding.AwayFromZero),
        maximum = Math.Round(target * maximum, 1, MidpointRounding.AwayFromZero),
        hardMinimum = Math.Round(target * hardMinimum, 1, MidpointRounding.AwayFromZero),
        hardMaximum = Math.Round(target * hardMaximum, 1, MidpointRounding.AwayFromZero),
        weight,
    };

    private static int AgeInYears(DateOnly birthDate, DateOnly today)
    {
        var age = today.Year - birthDate.Year;
        if (birthDate > today.AddYears(-age)) age--;
        return age;
    }

    private static double EstimateEnergy(int age, bool male, Activity activity, double weight, double height)
    {
        if (age >= 19)
        {
            if (male) return activity switch
            {
                Activity.Inactive => 753.07 - 10.83 * age + 6.50 * height + 14.10 * weight,
                Activity.LowActive => 581.47 - 10.83 * age + 8.30 * height + 14.94 * weight,
                Activity.Active => 1004.82 - 10.83 * age + 6.52 * height + 15.91 * weight,
                _ => -517.88 - 10.83 * age + 15.61 * height + 19.11 * weight,
            };

            return activity switch
            {
                Activity.Inactive => 584.90 - 7.01 * age + 5.72 * height + 11.71 * weight,
                Activity.LowActive => 575.77 - 7.01 * age + 6.60 * height + 12.14 * weight,
                Activity.Active => 710.25 - 7.01 * age + 6.54 * height + 12.34 * weight,
                _ => 511.83 - 7.01 * age + 9.07 * height + 12.56 * weight,
            };
        }

        var growthEnergy = age >= 14 ? 20 : male
            ? age == 3 ? 20 : age <= 8 ? 15 : 25
            : age <= 8 ? 15 : 30;
        if (male) return activity switch
        {
            Activity.Inactive => -447.51 + 3.68 * age + 13.01 * height + 13.15 * weight + growthEnergy,
            Activity.LowActive => 19.12 + 3.68 * age + 8.62 * height + 20.28 * weight + growthEnergy,
            Activity.Active => -388.19 + 3.68 * age + 12.66 * height + 20.46 * weight + growthEnergy,
            _ => -671.75 + 3.68 * age + 15.38 * height + 23.25 * weight + growthEnergy,
        };

        return activity switch
        {
            Activity.Inactive => 55.59 - 22.25 * age + 8.43 * height + 17.07 * weight + growthEnergy,
            Activity.LowActive => -297.54 - 22.25 * age + 12.77 * height + 14.73 * weight + growthEnergy,
            Activity.Active => -189.55 - 22.25 * age + 11.74 * height + 18.34 * weight + growthEnergy,
            _ => -709.59 - 22.25 * age + 18.22 * height + 14.25 * weight + growthEnergy,
        };
    }

    private enum Activity { Inactive, LowActive, Active, VeryActive }
}
