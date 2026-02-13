import '../models/activity.dart';

/// Time period for statistics calculations.
enum StatsPeriod {
  week(7, '7 Days'),
  month(30, '30 Days'),
  quarter(90, '90 Days');

  final int days;
  final String label;
  const StatsPeriod(this.days, this.label);
}

/// Computed statistics for a given period.
class PeriodStats {
  final int totalScheduled;
  final int totalCompleted;
  final double completionRate;
  final double previousCompletionRate;
  final Map<String, CategoryStats> categoryStats;
  final List<DayStats> dailyStats;
  final List<WeekStats> weeklyStats;
  final String? strongestCategory;
  final String? weakestCategory;

  const PeriodStats({
    required this.totalScheduled,
    required this.totalCompleted,
    required this.completionRate,
    required this.previousCompletionRate,
    required this.categoryStats,
    required this.dailyStats,
    required this.weeklyStats,
    this.strongestCategory,
    this.weakestCategory,
  });

  double get trendDelta => completionRate - previousCompletionRate;

  static const PeriodStats empty = PeriodStats(
    totalScheduled: 0,
    totalCompleted: 0,
    completionRate: 0,
    previousCompletionRate: 0,
    categoryStats: {},
    dailyStats: [],
    weeklyStats: [],
  );
}

/// Stats for a single category.
class CategoryStats {
  final String category;
  final int scheduled;
  final int completed;
  final double completionRate;
  final int totalCompletions; // raw count for distribution chart

  const CategoryStats({
    required this.category,
    required this.scheduled,
    required this.completed,
    required this.completionRate,
    required this.totalCompletions,
  });
}

/// Stats for a single day.
class DayStats {
  final DateTime date;
  final int scheduled;
  final int completed;
  final double completionRate;

  const DayStats({
    required this.date,
    required this.scheduled,
    required this.completed,
    required this.completionRate,
  });
}

/// Stats for a week (aggregated).
class WeekStats {
  final int weekIndex;
  final DateTime startDate;
  final double averageCompletionRate;
  final int totalScheduled;
  final int totalCompleted;

  const WeekStats({
    required this.weekIndex,
    required this.startDate,
    required this.averageCompletionRate,
    required this.totalScheduled,
    required this.totalCompleted,
  });
}

/// Pure computation class — takes activities + date range, returns statistics.
class StatisticsCalculator {
  const StatisticsCalculator._();

  /// Calculate all statistics for the given [period] ending at [now].
  static PeriodStats calculate({
    required List<Activity> activities,
    required StatsPeriod period,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final endDate = DateTime(today.year, today.month, today.day);
    final startDate = endDate.subtract(Duration(days: period.days - 1));

    // Previous period for comparison
    final prevEndDate = startDate.subtract(const Duration(days: 1));
    final prevStartDate = prevEndDate.subtract(Duration(days: period.days - 1));

    if (activities.isEmpty) {
      return PeriodStats.empty;
    }

    // Compute daily stats
    final dailyStats = _computeDailyStats(activities, startDate, endDate);
    final prevDailyStats =
        _computeDailyStats(activities, prevStartDate, prevEndDate);

    // Aggregate totals
    int totalScheduled = 0;
    int totalCompleted = 0;
    for (final day in dailyStats) {
      totalScheduled += day.scheduled;
      totalCompleted += day.completed;
    }

    int prevScheduled = 0;
    int prevCompleted = 0;
    for (final day in prevDailyStats) {
      prevScheduled += day.scheduled;
      prevCompleted += day.completed;
    }

    final completionRate =
        totalScheduled > 0 ? totalCompleted / totalScheduled : 0.0;
    final previousCompletionRate =
        prevScheduled > 0 ? prevCompleted / prevScheduled : 0.0;

    // Category stats
    final categoryStats =
        _computeCategoryStats(activities, startDate, endDate);

    // Weekly stats (for 90-day view)
    final weeklyStats = _computeWeeklyStats(dailyStats);

    // Best / worst categories (minimum 3 scheduled occurrences for worst)
    String? strongest;
    String? weakest;
    double highestRate = -1;
    double lowestRate = 2;

    for (final entry in categoryStats.entries) {
      final cs = entry.value;
      if (cs.scheduled > 0 && cs.completionRate > highestRate) {
        highestRate = cs.completionRate;
        strongest = entry.key;
      }
      if (cs.scheduled >= 3 && cs.completionRate < lowestRate) {
        lowestRate = cs.completionRate;
        weakest = entry.key;
      }
    }

    // If weakest == strongest (only one qualifying category), clear weakest
    if (weakest == strongest) {
      weakest = null;
    }

    return PeriodStats(
      totalScheduled: totalScheduled,
      totalCompleted: totalCompleted,
      completionRate: completionRate,
      previousCompletionRate: previousCompletionRate,
      categoryStats: categoryStats,
      dailyStats: dailyStats,
      weeklyStats: weeklyStats,
      strongestCategory: strongest,
      weakestCategory: weakest,
    );
  }

  /// Compute per-day scheduled/completed counts.
  static List<DayStats> _computeDailyStats(
    List<Activity> activities,
    DateTime startDate,
    DateTime endDate,
  ) {
    final stats = <DayStats>[];
    var current = startDate;

    while (!current.isAfter(endDate)) {
      int scheduled = 0;
      int completed = 0;

      for (final activity in activities) {
        final createdDate = DateTime(
          activity.createdAt.year,
          activity.createdAt.month,
          activity.createdAt.day,
        );
        if (createdDate.isAfter(current)) continue;
        if (!activity.isActiveOn(current.weekday)) continue;

        scheduled++;
        if (activity.isCompletedOn(current)) {
          completed++;
        }
      }

      stats.add(DayStats(
        date: current,
        scheduled: scheduled,
        completed: completed,
        completionRate: scheduled > 0 ? completed / scheduled : 0.0,
      ));

      current = current.add(const Duration(days: 1));
    }

    return stats;
  }

  /// Compute per-category aggregation.
  static Map<String, CategoryStats> _computeCategoryStats(
    List<Activity> activities,
    DateTime startDate,
    DateTime endDate,
  ) {
    final grouped = <String, List<Activity>>{};
    for (final activity in activities) {
      grouped.putIfAbsent(activity.category, () => []).add(activity);
    }

    final result = <String, CategoryStats>{};

    for (final entry in grouped.entries) {
      final category = entry.key;
      final categoryActivities = entry.value;

      int scheduled = 0;
      int completed = 0;

      var current = startDate;
      while (!current.isAfter(endDate)) {
        for (final activity in categoryActivities) {
          final createdDate = DateTime(
            activity.createdAt.year,
            activity.createdAt.month,
            activity.createdAt.day,
          );
          if (createdDate.isAfter(current)) continue;
          if (!activity.isActiveOn(current.weekday)) continue;

          scheduled++;
          if (activity.isCompletedOn(current)) {
            completed++;
          }
        }
        current = current.add(const Duration(days: 1));
      }

      if (scheduled > 0 || completed > 0) {
        result[category] = CategoryStats(
          category: category,
          scheduled: scheduled,
          completed: completed,
          completionRate: scheduled > 0 ? completed / scheduled : 0.0,
          totalCompletions: completed,
        );
      }
    }

    return result;
  }

  /// Group daily stats into weekly aggregations.
  static List<WeekStats> _computeWeeklyStats(List<DayStats> dailyStats) {
    if (dailyStats.isEmpty) return [];

    final weeks = <WeekStats>[];
    int weekIndex = 0;

    for (int i = 0; i < dailyStats.length; i += 7) {
      final end =
          (i + 7 < dailyStats.length) ? i + 7 : dailyStats.length;
      final weekDays = dailyStats.sublist(i, end);

      int scheduled = 0;
      int completed = 0;
      for (final day in weekDays) {
        scheduled += day.scheduled;
        completed += day.completed;
      }

      weeks.add(WeekStats(
        weekIndex: weekIndex,
        startDate: weekDays.first.date,
        averageCompletionRate:
            scheduled > 0 ? completed / scheduled : 0.0,
        totalScheduled: scheduled,
        totalCompleted: completed,
      ));
      weekIndex++;
    }

    return weeks;
  }
}
