import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/statistics_calculator.dart';

/// Bar chart showing daily or weekly completion ratios.
class DailyPatternBarChart extends StatelessWidget {
  final List<DayStats> dailyStats;
  final double height;

  const DailyPatternBarChart({
    super.key,
    required this.dailyStats,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BarChartPainter(dailyStats: dailyStats),
        size: Size.infinite,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DayStats> dailyStats;

  _BarChartPainter({required this.dailyStats});

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyStats.isEmpty) return;

    final barCount = dailyStats.length;
    final maxBarWidth = 32.0;
    final spacing = math.max(2.0, (size.width - barCount * maxBarWidth) / (barCount + 1));
    final barWidth = math.min(maxBarWidth, (size.width - spacing * (barCount + 1)) / barCount);

    final labelHeight = 20.0;
    final chartHeight = size.height - labelHeight;

    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < barCount; i++) {
      final day = dailyStats[i];
      final x = spacing + i * (barWidth + spacing);

      // Bar background
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = AppColors.border.withAlpha(128),
      );

      // Bar fill
      if (day.completionRate > 0) {
        final fillHeight = chartHeight * day.completionRate;
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartHeight - fillHeight, barWidth, fillHeight),
          const Radius.circular(4),
        );
        final opacity = 0.4 + (day.completionRate * 0.6);
        canvas.drawRRect(
          fillRect,
          Paint()..color = AppColors.primary.withOpacity(opacity),
        );
      }

      // Day label
      final dayLabel = _weekdayAbbrev(day.date.weekday);
      labelPainter.text = TextSpan(
        text: dayLabel,
        style: AppTypography.labelSmall.copyWith(fontSize: 9),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          x + (barWidth - labelPainter.width) / 2,
          chartHeight + 4,
        ),
      );
    }
  }

  String _weekdayAbbrev(int weekday) {
    const labels = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};
    return labels[weekday] ?? '';
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) =>
      oldDelegate.dailyStats != dailyStats;
}

/// Calendar-style heatmap grid for 30-day view.
class HeatmapGrid extends StatelessWidget {
  final List<DayStats> dailyStats;
  final double cellSize;
  final double cellSpacing;

  const HeatmapGrid({
    super.key,
    required this.dailyStats,
    this.cellSize = 18,
    this.cellSpacing = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) return const SizedBox.shrink();

    // Organize into rows of 7 (Mon-Sun)
    final rows = <List<DayStats?>>[];
    List<DayStats?> currentRow = [];

    // Pad the first row to start on the correct weekday
    if (dailyStats.isNotEmpty) {
      final firstWeekday = dailyStats.first.date.weekday; // 1=Mon
      for (int i = 1; i < firstWeekday; i++) {
        currentRow.add(null);
      }
    }

    for (final day in dailyStats) {
      currentRow.add(day);
      if (currentRow.length == 7) {
        rows.add(currentRow);
        currentRow = [];
      }
    }
    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add(null);
      }
      rows.add(currentRow);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((label) {
            return SizedBox(
              width: cellSize + cellSpacing,
              child: Center(
                child: Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(fontSize: 9),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Grid rows
        ...rows.map((row) {
          return Padding(
            padding: EdgeInsets.only(bottom: cellSpacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((day) {
                return Container(
                  width: cellSize,
                  height: cellSize,
                  margin: EdgeInsets.symmetric(horizontal: cellSpacing / 2),
                  decoration: BoxDecoration(
                    color: _cellColor(day),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Color _cellColor(DayStats? day) {
    if (day == null) return Colors.transparent;
    if (day.scheduled == 0) return AppColors.border.withAlpha(64);

    final rate = day.completionRate;
    if (rate == 0) return AppColors.border;
    if (rate < 0.4) return AppColors.primary.withOpacity(0.25);
    if (rate < 0.7) return AppColors.primary.withOpacity(0.50);
    if (rate < 0.9) return AppColors.primary.withOpacity(0.75);
    return AppColors.primary;
  }
}

/// Bar chart for weekly aggregated stats (90-day view).
class WeeklyBarChart extends StatelessWidget {
  final List<WeekStats> weeklyStats;
  final double height;

  const WeeklyBarChart({
    super.key,
    required this.weeklyStats,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyStats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WeeklyBarPainter(weeklyStats: weeklyStats),
        size: Size.infinite,
      ),
    );
  }
}

class _WeeklyBarPainter extends CustomPainter {
  final List<WeekStats> weeklyStats;

  _WeeklyBarPainter({required this.weeklyStats});

  @override
  void paint(Canvas canvas, Size size) {
    if (weeklyStats.isEmpty) return;

    final barCount = weeklyStats.length;
    final maxBarWidth = 28.0;
    final spacing = math.max(3.0, (size.width - barCount * maxBarWidth) / (barCount + 1));
    final barWidth = math.min(maxBarWidth, (size.width - spacing * (barCount + 1)) / barCount);

    final labelHeight = 20.0;
    final chartHeight = size.height - labelHeight;

    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < barCount; i++) {
      final week = weeklyStats[i];
      final x = spacing + i * (barWidth + spacing);

      // Bar background
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = AppColors.border.withAlpha(128),
      );

      // Bar fill
      if (week.averageCompletionRate > 0) {
        final fillHeight = chartHeight * week.averageCompletionRate;
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartHeight - fillHeight, barWidth, fillHeight),
          const Radius.circular(4),
        );
        final opacity = 0.4 + (week.averageCompletionRate * 0.6);
        canvas.drawRRect(
          fillRect,
          Paint()..color = AppColors.primary.withOpacity(opacity),
        );
      }

      // Week label
      labelPainter.text = TextSpan(
        text: 'W${i + 1}',
        style: AppTypography.labelSmall.copyWith(fontSize: 9),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          x + (barWidth - labelPainter.width) / 2,
          chartHeight + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_WeeklyBarPainter oldDelegate) =>
      oldDelegate.weeklyStats != weeklyStats;
}
