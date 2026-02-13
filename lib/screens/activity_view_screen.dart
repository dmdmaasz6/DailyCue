import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import 'activity_editor_screen.dart';

class ActivityViewScreen extends StatelessWidget {
  final Activity activity;

  const ActivityViewScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final activityProvider = context.watch<ActivityProvider>();
    // Get the latest activity state from the provider
    final currentActivity = activityProvider.getActivity(activity.id) ?? activity;
    final categoryColor = ActivityCategories.color(currentActivity.category);
    final isCompletedToday = currentActivity.isCompletedToday();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _navigateToEdit(context),
            tooltip: 'Edit activity',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with completion status
            _buildHeaderCard(context, categoryColor, isCompletedToday, activityProvider, currentActivity),
            const SizedBox(height: AppSpacing.md),

            // Details Section
            _SectionContainer(
              title: 'Details',
              icon: Icons.info_outline,
              accentColor: categoryColor,
              children: [
                _buildDetailRow(
                  'Title',
                  currentActivity.title,
                  Icons.title_rounded,
                  categoryColor,
                ),
                if (currentActivity.description != null && currentActivity.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildDetailRow(
                    'Description',
                    currentActivity.description!,
                    Icons.description_outlined,
                    categoryColor,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _buildDetailRow(
                  'Category',
                  ActivityCategories.label(currentActivity.category),
                  ActivityCategories.icon(currentActivity.category),
                  categoryColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Schedule Section
            _SectionContainer(
              title: 'Schedule',
              icon: Icons.schedule_outlined,
              accentColor: categoryColor,
              children: [
                _buildTimeDisplay(settings, categoryColor, currentActivity),
                const SizedBox(height: AppSpacing.md),
                _buildRepeatDaysDisplay(categoryColor, currentActivity),
                const SizedBox(height: AppSpacing.md),
                _buildStatusRow(
                  currentActivity.enabled ? 'Active' : 'Disabled',
                  currentActivity.enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
                  currentActivity.enabled ? AppColors.success : AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Notifications Section
            _SectionContainer(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              accentColor: categoryColor,
              children: [
                _buildRemindersDisplay(categoryColor, currentActivity),
                const SizedBox(height: AppSpacing.md),
                _buildStatusRow(
                  currentActivity.alarmEnabled ? 'Alarm enabled' : 'Alarm disabled',
                  Icons.alarm_rounded,
                  currentActivity.alarmEnabled ? categoryColor : AppColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildDetailRow(
                  'Snooze duration',
                  '${currentActivity.snoozeDurationMinutes} minutes',
                  Icons.snooze_rounded,
                  categoryColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Completion History Section
            _SectionContainer(
              title: 'Completion History',
              icon: Icons.history_rounded,
              accentColor: categoryColor,
              children: [
                _buildCompletionStats(categoryColor, currentActivity),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context, categoryColor, isCompletedToday, activityProvider, currentActivity),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Color categoryColor, bool isCompletedToday, ActivityProvider provider, Activity currentActivity) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [categoryColor.withOpacity(0.1), categoryColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: categoryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: AppRadii.borderRadiusMd,
                ),
                child: Icon(
                  ActivityCategories.icon(currentActivity.category),
                  color: categoryColor,
                  size: AppIconSizes.xl,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentActivity.title,
                      style: AppTypography.headingLarge.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      ActivityCategories.label(currentActivity.category),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCompletedToday) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: AppRadii.borderRadiusSm,
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: AppIconSizes.sm,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Completed today',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(SettingsProvider settings, Color accentColor, Activity currentActivity) {
    final timeStr = settings.use24HourFormat
        ? TimeUtils.format24h(currentActivity.timeOfDay)
        : TimeUtils.format12h(currentActivity.timeOfDay);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            color: accentColor,
            size: AppIconSizes.lg,
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time',
                style: AppTypography.labelSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                timeStr,
                style: AppTypography.headingLarge.copyWith(
                  color: accentColor,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatDaysDisplay(Color accentColor, Activity currentActivity) {
    final daysText = TimeUtils.repeatSummary(currentActivity.repeatDays);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.repeat_rounded,
            size: AppIconSizes.sm,
            color: accentColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repeat',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  daysText,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!currentActivity.isDaily) ...[
            const SizedBox(width: AppSpacing.sm),
            _buildDayDots(accentColor, currentActivity),
          ],
        ],
      ),
    );
  }

  Widget _buildDayDots(Color accentColor, Activity currentActivity) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final dayNum = i + 1;
        final isActive = currentActivity.isActiveOn(dayNum);
        return Container(
          margin: EdgeInsets.only(left: i > 0 ? AppSpacing.xxs : 0),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isActive ? accentColor.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? accentColor : AppColors.border,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                days[i],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? accentColor : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRemindersDisplay(Color accentColor, Activity currentActivity) {
    if (currentActivity.earlyReminderOffsets.isEmpty) {
      return _buildDetailRow(
        'Reminders',
        'None',
        Icons.notifications_off_outlined,
        AppColors.textTertiary,
      );
    }

    final reminderTexts = currentActivity.earlyReminderOffsets
        .map((offset) => '$offset min before')
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: AppIconSizes.sm,
            color: accentColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminders',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  reminderTexts,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStats(Color accentColor, Activity currentActivity) {
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    final todayCount = currentActivity.isCompletedToday() ? 1 : 0;
    final weekCount = currentActivity.getCompletionCount(weekAgo, today);
    final monthCount = currentActivity.getCompletionCount(monthAgo, today);
    final totalCount = currentActivity.completionHistory.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Today',
                todayCount.toString(),
                Icons.today_rounded,
                accentColor,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildStatCard(
                'Week',
                weekCount.toString(),
                Icons.calendar_view_week_rounded,
                accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Month',
                monthCount.toString(),
                Icons.calendar_month_rounded,
                accentColor,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildStatCard(
                'Total',
                totalCount.toString(),
                Icons.history_rounded,
                accentColor,
              ),
            ),
          ],
        ),
        if (currentActivity.completionHistory.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _buildRecentCompletions(accentColor, currentActivity),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppIconSizes.md),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.headingLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCompletions(Color accentColor, Activity currentActivity) {
    final recentCompletions = currentActivity.completionHistory
        .toList()
        ..sort((a, b) => b.compareTo(a));
    final displayCount = recentCompletions.length > 5 ? 5 : recentCompletions.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Completions',
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(displayCount, (index) {
            final completion = recentCompletions[index];
            final isToday = DateTime.now().difference(completion).inDays == 0;
            return Padding(
              padding: EdgeInsets.only(top: index > 0 ? AppSpacing.xs : 0),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: AppIconSizes.xs,
                    color: accentColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isToday
                        ? 'Today at ${completion.hour.toString().padLeft(2, '0')}:${completion.minute.toString().padLeft(2, '0')}'
                        : '${completion.month}/${completion.day}/${completion.year} at ${completion.hour.toString().padLeft(2, '0')}:${completion.minute.toString().padLeft(2, '0')}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSizes.sm, color: iconColor),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.labelSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: AppIconSizes.sm, color: color),
        const SizedBox(width: AppSpacing.md),
        Text(
          text,
          style: AppTypography.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, Color categoryColor, bool isCompletedToday, ActivityProvider provider, Activity currentActivity) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _navigateToEdit(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: isCompletedToday
                    ? null
                    : () => _markComplete(context, provider, currentActivity),
                icon: Icon(
                  isCompletedToday ? Icons.check_circle_rounded : Icons.check_circle_outline,
                ),
                label: Text(isCompletedToday ? 'Completed' : 'Mark Complete'),
                style: FilledButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ActivityEditorScreen(activity: activity),
      ),
    );

    if (result == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _markComplete(BuildContext context, ActivityProvider provider, Activity currentActivity) {
    provider.markActivityComplete(currentActivity.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: AppIconSizes.sm),
            const SizedBox(width: AppSpacing.sm),
            Text('${currentActivity.title} marked as complete'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _SectionContainer({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
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
              Icon(icon, size: AppIconSizes.md, color: accentColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.headingMedium.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
