import 'package:flutter_test/flutter_test.dart';
import 'package:avora_ai/services/goal_metrics.dart';

void main() {
  group('GoalMetrics', () {
    test('170 cm and 70 kg gives current BMI 24.2', () {
      final bmi = GoalMetrics.bmi(weightKg: 70, heightCm: 170);
      expect(bmi, isNotNull);
      expect(bmi!.toStringAsFixed(1), '24.2');
    });

    test('weight loss accepts 65 kg and rejects 75 kg at 70 kg current', () {
      expect(
        GoalMetrics.targetError(goal: 'Giảm cân', currentKg: 70, targetKg: 65),
        isNull,
      );
      expect(
        GoalMetrics.targetError(goal: 'Giảm cân', currentKg: 70, targetKg: 75),
        contains('thấp hơn'),
      );
    });

    test('two meals produce exactly two meal names', () {
      expect(GoalMetrics.mealNames(2), ['Bữa 1', 'Bữa 2']);
    });
  });
}
