import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../providers/activity_provider.dart';
import '../utils/constants.dart';
import '../utils/statistics_calculator.dart';
import '../widgets/donut_chart.dart';
import '../widgets/daily_pattern_chart.dart';
import 'settings_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  StatsPeriod _selectedPeriod = StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final activities = context.watch<ActivityProvider>().activities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: activities.isEmpty
          ? _buildEmptyState()
          : _buildContent(activities),
    );
  }

  Widget _buildContent(List<Activity> activities) {
    final stats = StatisticsCalculator.calculate(
      activities: activities,
      period: _selectedPeriod,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        _buildPeriodSelector(),
        if (stats.totalCompleted == 0)
          _buildNoCompletionsState()
        else ...[
          if (stats.totalCompleted > 0 && stats.totalCompleted < 7)
            _buildSparseDataBanner(),
          _buildOverallSummary(stats),
          _buildCategoryDistribution(stats),
          _buildCategoryCompletion(stats),
          _buildDailyRhythm(stats),
          _buildHighlights(stats),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Period selector
  // ---------------------------------------------------------------------------

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: StatsPeriod.values.map((period) {
          final selected = period == _selectedPeriod;
          return ChoiceChip(
            label: Text(period.label),
            selected: selected,
            onSelected: (_) => setState(() => _selectedPeriod = period),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Overall Summary
  // ---------------------------------------------------------------------------

  Widget _buildOverallSummary(PeriodStats stats) {
    final pct = (stats.completionRate * 100).round();
    final delta = stats.trendDelta;
    final deltaAbs = (delta.abs() * 100).round();

    return _SectionCard(
      child: Row(
        children: [
          // Progress ring
          SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _OverallRingPainter(progress: stats.completionRate),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: AppTypography.displayLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'follow-through',
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Stats column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.totalCompleted} of ${stats.totalScheduled}',
                  style: AppTypography.headingMedium,
                ),
                Text(
                  'activities completed',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _TrendBadge(
                  delta: delta,
                  deltaAbs: deltaAbs,
                  periodLabel: _selectedPeriod.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Where Your Day Goes
  // ---------------------------------------------------------------------------

  Widget _buildCategoryDistribution(PeriodStats stats) {
    final entries = stats.categoryStats.entries
        .where((e) => e.value.totalCompletions > 0)
        .toList()
      ..sort((a, b) => b.value.totalCompletions.compareTo(a.value.totalCompletions));

    if (entries.isEmpty) return const SizedBox.shrink();

    final totalCompletions =
        entries.fold<int>(0, (sum, e) => sum + e.value.totalCompletions);

    final segments = entries.map((e) {
      return DonutSegment(
        label: ActivityCategories.label(e.key),
        value: e.value.totalCompletions.toDouble(),
        color: ActivityCategories.color(e.key),
      );
    }).toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Where Your Day Goes',
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: DonutChart(
              segments: segments,
              size: 170,
              strokeWidth: 22,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$totalCompletions',
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Text('completed', style: AppTypography.labelSmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Legend
          ...entries.map((e) {
            final pct = totalCompletions > 0
                ? (e.value.totalCompletions / totalCompletions * 100).round()
                : 0;
            return DonutLegendItem(
              color: ActivityCategories.color(e.key),
              label: ActivityCategories.label(e.key),
              value: '${e.value.totalCompletions}',
              percentage: '$pct%',
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Follow-Through by Area
  // ---------------------------------------------------------------------------

  Widget _buildCategoryCompletion(PeriodStats stats) {
    final entries = stats.categoryStats.entries
        .where((e) => e.value.scheduled > 0)
        .toList()
      ..sort((a, b) => b.value.completionRate.compareTo(a.value.completionRate));

    if (entries.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.checklist_rounded,
            title: 'Follow-Through by Area',
          ),
          const SizedBox(height: AppSpacing.sm),
          ...entries.map((e) {
            final cs = e.value;
            final pct = (cs.completionRate * 100).round();
            final color = ActivityCategories.color(e.key);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
              child: Row(
                children: [
                  Icon(
                    ActivityCategories.icon(e.key),
                    color: color,
                    size: AppIconSizes.md,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ActivityCategories.label(e.key),
                              style: AppTypography.labelLarge,
                            ),
                            Text(
                              '$pct%',
                              style: AppTypography.labelLarge.copyWith(
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: AppRadii.borderRadiusFull,
                          child: LinearProgressIndicator(
                            value: cs.completionRate,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4: Your Daily Rhythm
  // ---------------------------------------------------------------------------

  Widget _buildDailyRhythm(PeriodStats stats) {
    if (stats.dailyStats.isEmpty) return const SizedBox.shrink();

    Widget chart;
    switch (_selectedPeriod) {
      case StatsPeriod.week:
        chart = DailyPatternBarChart(dailyStats: stats.dailyStats);
      case StatsPeriod.month:
        chart = HeatmapGrid(dailyStats: stats.dailyStats);
      case StatsPeriod.quarter:
        chart = WeeklyBarChart(weeklyStats: stats.weeklyStats);
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.show_chart_rounded,
            title: 'Your Daily Rhythm',
          ),
          const SizedBox(height: AppSpacing.md),
          chart,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 5: Highlights
  // ---------------------------------------------------------------------------

  Widget _buildHighlights(PeriodStats stats) {
    final strongest = stats.strongestCategory;
    final weakest = stats.weakestCategory;

    if (strongest == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _HighlightCard(
              title: 'Strongest Area',
              category: strongest,
              rate: stats.categoryStats[strongest]!.completionRate,
              useAccentColor: true,
            ),
          ),
          if (weakest != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _HighlightCard(
                title: 'Room to Grow',
                category: weakest,
                rate: stats.categoryStats[weakest]!.completionRate,
                useAccentColor: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty / sparse states
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insights_outlined,
                size: AppIconSizes.xl,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No activities yet',
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add activities to your routine, then come back\nto see how your days take shape.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCompletionsState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _OverallRingPainter(progress: 0),
              child: Center(
                child: Text(
                  '0%',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No completions yet',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Complete your daily activities and your\npatterns will appear here.',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSparseDataBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.08),
          borderRadius: AppRadii.borderRadiusMd,
          border: Border.all(color: AppColors.info.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: AppIconSizes.sm,
              color: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Your statistics are just getting started. '
                'They become more meaningful as you complete more activities.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.info,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Private supporting widgets
// =============================================================================

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSizes.sm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.headingSmall),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double delta;
  final int deltaAbs;
  final String periodLabel;

  const _TrendBadge({
    required this.delta,
    required this.deltaAbs,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0.005;
    final isDown = delta < -0.005;
    final icon = isUp
        ? Icons.trending_up_rounded
        : isDown
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final color = isUp
        ? AppColors.success
        : isDown
            ? AppColors.warning
            : AppColors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadii.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.xs, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isUp || isDown
                ? '$deltaAbs% vs prev $periodLabel'
                : 'Stable vs prev $periodLabel',
            style: AppTypography.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String category;
  final double rate;
  final bool useAccentColor;

  const _HighlightCard({
    required this.title,
    required this.category,
    required this.rate,
    required this.useAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        useAccentColor ? ActivityCategories.color(category) : AppColors.textSecondary;
    final bgColor = useAccentColor
        ? ActivityCategories.color(category).withOpacity(0.08)
        : AppColors.surfaceAlt;
    final borderColor = useAccentColor
        ? ActivityCategories.color(category).withOpacity(0.3)
        : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            ActivityCategories.icon(category),
            color: color,
            size: AppIconSizes.lg,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(rate * 100).round()}%',
            style: AppTypography.headingLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ActivityCategories.label(category),
            style: AppTypography.labelMedium.copyWith(
              color: useAccentColor ? color : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            title,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overall progress ring painter (reuses pattern from dashboard)
// ---------------------------------------------------------------------------

class _OverallRingPainter extends CustomPainter {
  final double progress;
  _OverallRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OverallRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
