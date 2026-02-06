import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import 'activity_editor_screen.dart';
import 'settings_screen.dart';

class WeeklyViewScreen extends StatelessWidget {
  const WeeklyViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly View'),
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
      body: Consumer2<ActivityProvider, SettingsProvider>(
        builder: (context, activityProvider, settings, _) {
          final activities = activityProvider.activities;
          final todayWeekday = DateTime.now().weekday;

          // Build per-day activity map
          final Map<int, List<Activity>> dayMap = {};
          for (int d = 1; d <= 7; d++) {
            dayMap[d] = activities
                .where(
                    (a) => a.repeatDays.isEmpty || a.repeatDays.contains(d))
                .toList()
              ..sort((a, b) {
                final aMin = a.timeOfDay.hour * 60 + a.timeOfDay.minute;
                final bMin = b.timeOfDay.hour * 60 + b.timeOfDay.minute;
                return aMin.compareTo(bMin);
              });
          }

          // Calculate busiest day
          int busiestDay = 1;
          int busiestCount = 0;
          dayMap.forEach((d, list) {
            if (list.length > busiestCount) {
              busiestCount = list.length;
              busiestDay = d;
            }
          });

          final totalSlots = dayMap.values
              .fold<int>(0, (sum, list) => sum + list.length);

          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // Week summary bar
              _WeekSummaryBar(
                dayMap: dayMap,
                todayWeekday: todayWeekday,
                totalSlots: totalSlots,
                busiestDay: busiestDay,
              ),
              const SizedBox(height: AppSpacing.md),

              // Day cards
              for (int day = 1; day <= 7; day++)
                _DayCard(
                  day: day,
                  dayLabel: AppConstants.weekdayFullLabels[day]!,
                  isToday: day == todayWeekday,
                  activities: dayMap[day]!,
                  use24Hour: settings.use24HourFormat,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week summary bar with mini heatmap
// ---------------------------------------------------------------------------

class _WeekSummaryBar extends StatelessWidget {
  final Map<int, List<Activity>> dayMap;
  final int todayWeekday;
  final int totalSlots;
  final int busiestDay;

  const _WeekSummaryBar({
    required this.dayMap,
    required this.todayWeekday,
    required this.totalSlots,
    required this.busiestDay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Week Overview', style: AppTypography.headingSmall),
              const Spacer(),
              Text(
                '$totalSlots activity slots',
                style: AppTypography.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Mini bar chart
          Row(
            children: List.generate(7, (index) {
              final day = index + 1;
              final count = dayMap[day]!.length;
              final maxCount = busiestDay > 0
                  ? dayMap[busiestDay]!.length
                  : 1;
              final fillRatio =
                  maxCount > 0 ? count / maxCount : 0.0;
              final isToday = day == todayWeekday;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < 6 ? AppSpacing.xs : 0,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: AppDurations.normal,
                            height: fillRatio * 48 < 4
                                ? 4
                                : fillRatio * 48,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.primaryLight
                                      .withOpacity(0.5),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(AppRadii.sm),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppConstants.weekdayLabels[day]!
                            .substring(0, 2),
                        style: AppTypography.labelSmall.copyWith(
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$count',
                        style: AppTypography.labelSmall.copyWith(
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day card widget
// ---------------------------------------------------------------------------

class _DayCard extends StatelessWidget {
  final int day;
  final String dayLabel;
  final bool isToday;
  final List<Activity> activities;
  final bool use24Hour;

  const _DayCard({
    required this.day,
    required this.dayLabel,
    required this.isToday,
    required this.activities,
    required this.use24Hour,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.primary.withOpacity(0.04)
              : AppColors.surface,
          borderRadius: AppRadii.borderRadiusLg,
          border: Border.all(
            color: isToday
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.border,
            width: isToday ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary.withOpacity(0.08)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.lg),
                  topRight: Radius.circular(AppRadii.lg),
                ),
              ),
              child: Row(
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      margin:
                          const EdgeInsets.only(right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadii.borderRadiusSm,
                      ),
                      child: Text(
                        'TODAY',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    dayLabel,
                    style: AppTypography.headingSmall.copyWith(
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.border.withOpacity(0.5),
                      borderRadius: AppRadii.borderRadiusFull,
                    ),
                    child: Text(
                      '${activities.length}',
                      style: AppTypography.labelMedium.copyWith(
                        color: isToday
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Activities list
            if (activities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: AppIconSizes.sm,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Free day — no activities',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...activities.map((activity) {
                return _WeeklyActivityRow(
                  activity: activity,
                  use24Hour: use24Hour,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ActivityEditorScreen(activity: activity),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly activity row (tappable)
// ---------------------------------------------------------------------------

class _WeeklyActivityRow extends StatelessWidget {
  final Activity activity;
  final bool use24Hour;
  final VoidCallback onTap;

  const _WeeklyActivityRow({
    required this.activity,
    required this.use24Hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = use24Hour
        ? TimeUtils.format24h(activity.timeOfDay)
        : TimeUtils.format12h(activity.timeOfDay);
    final catColor = ActivityCategories.color(activity.category);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.border.withOpacity(0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                timeStr,
                style: AppTypography.monoSmall.copyWith(
                  color: activity.enabled
                      ? catColor
                      : AppColors.textTertiary,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: activity.enabled
                    ? catColor
                    : AppColors.disabled,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                activity.title,
                style: AppTypography.bodyMedium.copyWith(
                  color: activity.enabled
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            if (activity.alarmEnabled)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.alarm_rounded,
                  size: AppIconSizes.xs,
                  color: activity.enabled
                      ? AppColors.secondary
                      : AppColors.textTertiary,
                ),
              ),
            if (activity.earlyReminderOffsets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.notifications_outlined,
                  size: AppIconSizes.xs,
                  color: activity.enabled
                      ? catColor
                      : AppColors.textTertiary,
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: AppIconSizes.sm,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
