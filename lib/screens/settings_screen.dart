import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: 'DISPLAY'),
          SwitchListTile(
            title: Text('24-hour time format',
                style: AppTypography.bodyLarge),
            subtitle: Text('Use 24-hour clock instead of AM/PM',
                style: AppTypography.bodySmall),
            value: settings.use24HourFormat,
            onChanged: (value) => settings.setUse24HourFormat(value),
          ),
          const Divider(),

          _SectionHeader(title: 'DEFAULTS'),
          ListTile(
            title: Text('Default snooze duration',
                style: AppTypography.bodyLarge),
            subtitle: Text('${settings.defaultSnooze} minutes',
                style: AppTypography.bodySmall),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showSnoozePicker(context, settings),
          ),
          ListTile(
            title: Text('Default reminder offsets',
                style: AppTypography.bodyLarge),
            subtitle: Text(
              settings.defaultReminderOffsets.isEmpty
                  ? 'None'
                  : settings.defaultReminderOffsets
                      .map((o) => '${o}m')
                      .join(', '),
              style: AppTypography.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showReminderOffsetsPicker(context, settings),
          ),
          const Divider(),

          _SectionHeader(title: 'NOTIFICATIONS'),
          ListTile(
            title: Text('Reschedule all notifications',
                style: AppTypography.bodyLarge),
            subtitle: Text('Useful after timezone changes or issues',
                style: AppTypography.bodySmall),
            trailing: const Icon(Icons.refresh_rounded),
            onTap: () => _rescheduleAll(context),
          ),
          const Divider(),

          _SectionHeader(title: 'ABOUT'),
          ListTile(
            title: Text(AppConstants.appName,
                style: AppTypography.bodyLarge),
            subtitle:
                Text('Version 1.0.0', style: AppTypography.bodySmall),
          ),
        ],
      ),
    );
  }

  void _showSnoozePicker(
      BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Default Snooze Duration',
            style: AppTypography.headingMedium),
        children: AppConstants.availableSnoozeDurations.map((duration) {
          return SimpleDialogOption(
            onPressed: () {
              settings.setDefaultSnooze(duration);
              Navigator.pop(context);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    '$duration minutes',
                    style: AppTypography.bodyLarge,
                  ),
                  const Spacer(),
                  if (duration == settings.defaultSnooze)
                    const Icon(Icons.check_rounded,
                        color: AppColors.primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReminderOffsetsPicker(
      BuildContext context, SettingsProvider settings) {
    final selected = List<int>.from(settings.defaultReminderOffsets);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Default Reminder Offsets',
              style: AppTypography.headingMedium),
          content: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children:
                AppConstants.availableReminderOffsets.map((offset) {
              final isSelected = selected.contains(offset);
              return FilterChip(
                label: Text('$offset min'),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      selected.add(offset);
                      selected.sort();
                    } else {
                      selected.remove(offset);
                    }
                  });
                },
                selectedColor: AppColors.primary.withOpacity(0.12),
                checkmarkColor: AppColors.primary,
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                side: BorderSide(
                  color:
                      isSelected ? AppColors.primary : AppColors.border,
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                settings.setDefaultReminderOffsets(selected);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rescheduleAll(BuildContext context) async {
    final provider = context.read<ActivityProvider>();
    await provider.rescheduleAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All notifications rescheduled')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.sectionPadding,
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
