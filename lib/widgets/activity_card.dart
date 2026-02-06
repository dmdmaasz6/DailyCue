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

    return Opacity(
      opacity: activity.enabled ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Time display
                SizedBox(
                  width: 72,
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: activity.enabled
                          ? AppColors.primary
                          : AppColors.disabled,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: activity.enabled ? null : AppColors.disabled,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            repeatStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (activity.alarmEnabled) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.alarm,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                          ],
                          if (activity.earlyReminderOffsets.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.notifications_outlined,
                              size: 14,
                              color: Colors.grey[600],
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
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
