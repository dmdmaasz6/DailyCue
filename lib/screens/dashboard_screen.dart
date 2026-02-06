import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
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
      body: Consumer<ActivityProvider>(
        builder: (context, provider, _) {
          final totalActivities = provider.activities.length;
          final enabledCount =
              provider.activities.where((a) => a.enabled).length;
          final todayWeekday = DateTime.now().weekday;
          final todayActivities = provider.activities
              .where((a) =>
                  a.enabled &&
                  (a.repeatDays.isEmpty || a.repeatDays.contains(todayWeekday)))
              .toList()
            ..sort((a, b) {
              final aMin = a.timeOfDay.hour * 60 + a.timeOfDay.minute;
              final bMin = b.timeOfDay.hour * 60 + b.timeOfDay.minute;
              return aMin.compareTo(bMin);
            });

          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // Greeting header
              Text(_greeting(), style: AppTypography.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formattedDate(),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Stat cards row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Today',
                      value: '${todayActivities.length}',
                      icon: Icons.today_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _StatCard(
                      label: 'Active',
                      value: '$enabledCount',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _StatCard(
                      label: 'Total',
                      value: '$totalActivities',
                      icon: Icons.schedule_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Today's schedule
              Text("Today's Schedule", style: AppTypography.headingLarge),
              const SizedBox(height: AppSpacing.md),

              if (todayActivities.isEmpty)
                _buildEmptyToday()
              else
                ...todayActivities.map(
                  (activity) => _TodayActivityTile(activity: activity),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyToday() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: AppIconSizes.xl,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No activities scheduled for today',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card widget
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
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
          Icon(icon, size: AppIconSizes.md, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.displayMedium.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's timeline activity tile
// ---------------------------------------------------------------------------

class _TodayActivityTile extends StatelessWidget {
  final dynamic activity;

  const _TodayActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final hour = activity.timeOfDay.hour;
    final minute = activity.timeOfDay.minute;
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    final now = DateTime.now();
    final activityMinutes = hour * 60 + minute;
    final nowMinutes = now.hour * 60 + now.minute;
    final isPast = activityMinutes < nowMinutes;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 56,
            child: Text(
              timeStr,
              style: AppTypography.monoSmall.copyWith(
                color: isPast ? AppColors.textTertiary : AppColors.primary,
              ),
            ),
          ),

          // Timeline dot and line
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isPast
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: AppColors.border,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),

          // Activity content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isPast
                    ? AppColors.surfaceAlt
                    : AppColors.surface,
                borderRadius: AppRadii.borderRadiusMd,
                border: Border.all(
                  color: isPast ? AppColors.border : AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: AppTypography.headingSmall.copyWith(
                      color: isPast
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (activity.description != null &&
                      activity.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      activity.description!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
