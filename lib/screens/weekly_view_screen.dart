import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
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

          return ListView.builder(
            padding: AppSpacing.screenPadding,
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = index + 1; // 1=Mon..7=Sun
              final isToday = day == todayWeekday;

              // Get activities for this day
              final dayActivities = activities
                  .where((a) =>
                      a.repeatDays.isEmpty || a.repeatDays.contains(day))
                  .toList()
                ..sort((a, b) {
                  final aMin = a.timeOfDay.hour * 60 + a.timeOfDay.minute;
                  final bMin = b.timeOfDay.hour * 60 + b.timeOfDay.minute;
                  return aMin.compareTo(bMin);
                });

              return _DayColumn(
                dayLabel: AppConstants.weekdayFullLabels[day]!,
                shortLabel: AppConstants.weekdayLabels[day]!,
                isToday: isToday,
                activities: dayActivities,
                use24Hour: settings.use24HourFormat,
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day column widget
// ---------------------------------------------------------------------------

class _DayColumn extends StatelessWidget {
  final String dayLabel;
  final String shortLabel;
  final bool isToday;
  final List<dynamic> activities;
  final bool use24Hour;

  const _DayColumn({
    required this.dayLabel,
    required this.shortLabel,
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
          color: isToday ? AppColors.primary.withOpacity(0.04) : AppColors.surface,
          borderRadius: AppRadii.borderRadiusLg,
          border: Border.all(
            color: isToday ? AppColors.primary.withOpacity(0.3) : AppColors.border,
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
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
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
                  Text(
                    '${activities.length} ${activities.length == 1 ? 'activity' : 'activities'}',
                    style: AppTypography.labelMedium,
                  ),
                ],
              ),
            ),

            // Activities list
            if (activities.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No activities',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              ...activities.map((activity) {
                final timeStr = use24Hour
                    ? TimeUtils.format24h(activity.timeOfDay)
                    : TimeUtils.format12h(activity.timeOfDay);

                return Container(
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
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        margin:
                            const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: activity.enabled
                              ? AppColors.primary
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
                          padding:
                              const EdgeInsets.only(left: AppSpacing.xs),
                          child: Icon(
                            Icons.alarm_rounded,
                            size: AppIconSizes.xs,
                            color: activity.enabled
                                ? AppColors.secondary
                                : AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
