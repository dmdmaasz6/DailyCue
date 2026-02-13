import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailycue/models/activity.dart';
import 'package:dailycue/utils/statistics_calculator.dart';

/// Helper to create an Activity with specific completions.
Activity _makeActivity({
  required String title,
  String category = 'general',
  List<int> repeatDays = const [],
  List<DateTime>? completionHistory,
  DateTime? createdAt,
}) {
  return Activity(
    title: title,
    timeOfDay: const TimeOfDay(hour: 8, minute: 0),
    category: category,
    repeatDays: repeatDays,
    createdAt: createdAt ?? DateTime(2025, 1, 1),
    completionHistory: completionHistory ?? [],
  );
}

void main() {
  group('StatisticsCalculator', () {
    test('returns empty stats for empty activity list', () {
      final stats = StatisticsCalculator.calculate(
        activities: [],
        period: StatsPeriod.week,
        now: DateTime(2025, 3, 10),
      );

      expect(stats.totalScheduled, 0);
      expect(stats.totalCompleted, 0);
      expect(stats.completionRate, 0.0);
      expect(stats.categoryStats, isEmpty);
      expect(stats.dailyStats, isEmpty);
    });

    test('calculates overall completion rate correctly', () {
      // A daily activity with completions on 5 of 7 days
      final now = DateTime(2025, 3, 10); // Monday
      final activity = _makeActivity(
        title: 'Morning jog',
        category: 'fitness',
        completionHistory: [
          DateTime(2025, 3, 4), // Tue
          DateTime(2025, 3, 5), // Wed
          DateTime(2025, 3, 6), // Thu
          DateTime(2025, 3, 8), // Sat
          DateTime(2025, 3, 10), // Mon
        ],
      );

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.week,
        now: now,
      );

      // 7 days scheduled (daily), 5 completed
      expect(stats.totalScheduled, 7);
      expect(stats.totalCompleted, 5);
      expect(stats.completionRate, closeTo(5 / 7, 0.001));
    });

    test('respects repeatDays scheduling', () {
      // Activity only on Mon, Wed, Fri (1, 3, 5)
      final now = DateTime(2025, 3, 10); // Monday
      final activity = _makeActivity(
        title: 'Gym',
        repeatDays: [1, 3, 5], // Mon, Wed, Fri
        completionHistory: [
          DateTime(2025, 3, 5), // Wed
          DateTime(2025, 3, 7), // Fri
          DateTime(2025, 3, 10), // Mon
        ],
      );

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.week,
        now: now,
      );

      // 7-day window: Mar 4 (Tue) to Mar 10 (Mon)
      // Active on: Mar 5 (Wed), Mar 7 (Fri), Mar 10 (Mon) = 3 scheduled
      expect(stats.totalScheduled, 3);
      expect(stats.totalCompleted, 3);
      expect(stats.completionRate, closeTo(1.0, 0.001));
    });

    test('respects createdAt boundary', () {
      // Activity created mid-period should only count from createdAt
      final now = DateTime(2025, 3, 10); // Monday
      final activity = _makeActivity(
        title: 'New habit',
        createdAt: DateTime(2025, 3, 7), // Created Friday
        completionHistory: [
          DateTime(2025, 3, 8), // Sat
          DateTime(2025, 3, 10), // Mon
        ],
      );

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.week,
        now: now,
      );

      // Only scheduled from Mar 7-10 (4 days), completed 2
      expect(stats.totalScheduled, 4);
      expect(stats.totalCompleted, 2);
      expect(stats.completionRate, closeTo(0.5, 0.001));
    });

    test('groups by category correctly', () {
      final now = DateTime(2025, 3, 10);
      final activities = [
        _makeActivity(
          title: 'Meditate',
          category: 'health',
          completionHistory: [
            DateTime(2025, 3, 4),
            DateTime(2025, 3, 5),
            DateTime(2025, 3, 6),
          ],
        ),
        _makeActivity(
          title: 'Read',
          category: 'learning',
          completionHistory: [
            DateTime(2025, 3, 4),
            DateTime(2025, 3, 10),
          ],
        ),
      ];

      final stats = StatisticsCalculator.calculate(
        activities: activities,
        period: StatsPeriod.week,
        now: now,
      );

      expect(stats.categoryStats, contains('health'));
      expect(stats.categoryStats, contains('learning'));
      expect(stats.categoryStats['health']!.completed, 3);
      expect(stats.categoryStats['learning']!.completed, 2);
      // Both daily = 7 scheduled each
      expect(stats.categoryStats['health']!.scheduled, 7);
      expect(stats.categoryStats['learning']!.scheduled, 7);
    });

    test('identifies strongest and weakest categories', () {
      final now = DateTime(2025, 3, 10);
      final activities = [
        _makeActivity(
          title: 'Meditate',
          category: 'health',
          completionHistory: [
            DateTime(2025, 3, 4),
            DateTime(2025, 3, 5),
            DateTime(2025, 3, 6),
            DateTime(2025, 3, 7),
            DateTime(2025, 3, 8),
            DateTime(2025, 3, 9),
            DateTime(2025, 3, 10),
          ],
        ),
        _makeActivity(
          title: 'Study',
          category: 'learning',
          completionHistory: [
            DateTime(2025, 3, 4),
          ],
        ),
      ];

      final stats = StatisticsCalculator.calculate(
        activities: activities,
        period: StatsPeriod.week,
        now: now,
      );

      expect(stats.strongestCategory, 'health'); // 7/7 = 100%
      expect(stats.weakestCategory, 'learning'); // 1/7 = ~14%
    });

    test('weakest requires minimum 3 scheduled occurrences', () {
      final now = DateTime(2025, 3, 10);
      final activities = [
        _makeActivity(
          title: 'Meditate',
          category: 'health',
          completionHistory: [
            DateTime(2025, 3, 4),
            DateTime(2025, 3, 5),
            DateTime(2025, 3, 6),
            DateTime(2025, 3, 7),
          ],
        ),
        // Only scheduled on 2 days, so won't qualify as "weakest"
        _makeActivity(
          title: 'Weekend trip',
          category: 'family',
          repeatDays: [6, 7], // Sat, Sun only
          createdAt: DateTime(2025, 3, 8), // Only Sat-Mon in range
          completionHistory: [],
        ),
      ];

      final stats = StatisticsCalculator.calculate(
        activities: activities,
        period: StatsPeriod.week,
        now: now,
      );

      expect(stats.strongestCategory, 'health');
      // Family only has 2 scheduled occurrences (Sat+Sun) -> doesn't qualify
      expect(stats.weakestCategory, isNull);
    });

    test('computes previous period comparison', () {
      final now = DateTime(2025, 3, 14);
      final activity = _makeActivity(
        title: 'Exercise',
        completionHistory: [
          // Previous period (Mar 1-7): 2 completions
          DateTime(2025, 3, 1),
          DateTime(2025, 3, 3),
          // Current period (Mar 8-14): 5 completions
          DateTime(2025, 3, 8),
          DateTime(2025, 3, 9),
          DateTime(2025, 3, 10),
          DateTime(2025, 3, 12),
          DateTime(2025, 3, 14),
        ],
      );

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.week,
        now: now,
      );

      expect(stats.completionRate, closeTo(5 / 7, 0.001));
      expect(stats.previousCompletionRate, closeTo(2 / 7, 0.001));
      expect(stats.trendDelta, greaterThan(0)); // Improving
    });

    test('generates daily stats for each day in period', () {
      final now = DateTime(2025, 3, 10);
      final activity = _makeActivity(title: 'Walk');

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.week,
        now: now,
      );

      expect(stats.dailyStats.length, 7);
      expect(stats.dailyStats.first.date, DateTime(2025, 3, 4));
      expect(stats.dailyStats.last.date, DateTime(2025, 3, 10));
    });

    test('generates weekly stats for quarter view', () {
      final now = DateTime(2025, 3, 31);
      final activity = _makeActivity(title: 'Walk');

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.quarter,
        now: now,
      );

      // 90 days -> ~13 weekly blocks
      expect(stats.weeklyStats.length, greaterThanOrEqualTo(12));
      expect(stats.weeklyStats.length, lessThanOrEqualTo(13));
    });

    test('handles 30-day period correctly', () {
      final now = DateTime(2025, 3, 30);
      final activity = _makeActivity(
        title: 'Read',
        completionHistory: List.generate(
          15,
          (i) => DateTime(2025, 3, 1 + i),
        ),
      );

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.month,
        now: now,
      );

      expect(stats.dailyStats.length, 30);
      expect(stats.totalScheduled, 30);
      expect(stats.totalCompleted, 15);
      expect(stats.completionRate, closeTo(0.5, 0.001));
    });

    test('does not set weakest same as strongest with single category', () {
      final now = DateTime(2025, 3, 10);
      final activity = _makeActivity(
        title: 'Walk',
        category: 'fitness',
        completionHistory: [DateTime(2025, 3, 5)],
      );

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.week,
        now: now,
      );

      // With only one category, strongest is set but weakest should be null
      expect(stats.strongestCategory, 'fitness');
      expect(stats.weakestCategory, isNull);
    });

    test('per-day completionRate is 0 when nothing scheduled', () {
      // Activity only on weekdays but checking a weekend
      final now = DateTime(2025, 3, 9); // Sunday
      final activity = _makeActivity(
        title: 'Work task',
        repeatDays: [1, 2, 3, 4, 5], // Mon-Fri
      );

      final stats = StatisticsCalculator.calculate(
        activities: [activity],
        period: StatsPeriod.week,
        now: now,
      );

      // Find Saturday (Mar 8) and Sunday (Mar 9)
      final saturday = stats.dailyStats.firstWhere(
        (d) => d.date.weekday == 6,
      );
      final sunday = stats.dailyStats.firstWhere(
        (d) => d.date.weekday == 7,
      );

      expect(saturday.scheduled, 0);
      expect(saturday.completionRate, 0.0);
      expect(sunday.scheduled, 0);
      expect(sunday.completionRate, 0.0);
    });
  });
}
