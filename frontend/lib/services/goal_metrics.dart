class GoalMetrics {
  const GoalMetrics._();

  static double? bmi({required double? weightKg, required double? heightCm}) {
    if (weightKg == null ||
        heightCm == null ||
        weightKg <= 0 ||
        heightCm <= 0) {
      return null;
    }
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  static String? targetError({
    required String goal,
    required double? currentKg,
    required double? targetKg,
  }) {
    if (goal == 'Giữ cân') return null;
    if (targetKg == null || targetKg <= 0) {
      return 'Nhập cân nặng mong muốn lớn hơn 0.';
    }
    if (currentKg == null || currentKg <= 0) {
      return 'Bổ sung cân nặng hiện tại trong hồ sơ trước.';
    }
    if (goal == 'Giảm cân' && targetKg >= currentKg) {
      return 'Cân nặng mong muốn phải thấp hơn cân nặng hiện tại.';
    }
    if (goal == 'Tăng cân' && targetKg <= currentKg) {
      return 'Cân nặng mong muốn phải cao hơn cân nặng hiện tại.';
    }
    return null;
  }

  static List<String> mealNames(int mealsPerDay) => [
    for (var index = 1; index <= mealsPerDay; index++) 'Bữa $index',
  ];
}
