import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final timeStr = settings.use24HourFormat
        ? TimeUtils.format24h(activity.timeOfDay)
        : TimeUtils.format12h(activity.timeOfDay);
    final repeatStr = TimeUtils.repeatSummary(activity.repeatDays);

    return AnimatedOpacity(
      opacity: activity.enabled ? 1.0 : 0.55,
      duration: AppDurations.fast,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.borderRadiusLg,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Row(
              children: [
                // Time display
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    timeStr,
                    style: AppTypography.mono.copyWith(
                      color: activity.enabled
                          ? AppColors.primary
                          : AppColors.disabled,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Vertical accent line
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activity.enabled
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.disabled.withOpacity(0.3),
                    borderRadius: AppRadii.borderRadiusFull,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Title and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: AppTypography.headingSmall.copyWith(
                          color: activity.enabled
                              ? AppColors.textPrimary
                              : AppColors.disabledText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Text(
                            repeatStr,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (activity.alarmEnabled) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              Icons.alarm_rounded,
                              size: AppIconSizes.xs,
                              color: activity.enabled
                                  ? AppColors.secondary
                                  : AppColors.textTertiary,
                            ),
                          ],
                          if (activity.earlyReminderOffsets.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              Icons.notifications_outlined,
                              size: AppIconSizes.xs,
                              color: activity.enabled
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Enable/disable toggle
                Switch(
                  value: activity.enabled,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
