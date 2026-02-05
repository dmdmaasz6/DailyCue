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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Display'),
          SwitchListTile(
            title: const Text('24-hour time format'),
            subtitle: const Text('Use 24-hour clock instead of AM/PM'),
            value: settings.use24HourFormat,
            onChanged: (value) => settings.setUse24HourFormat(value),
            activeColor: AppColors.primary,
          ),
          const Divider(),

          const _SectionHeader(title: 'Defaults'),
          ListTile(
            title: const Text('Default snooze duration'),
            subtitle: Text('${settings.defaultSnooze} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSnoozePicker(context, settings),
          ),
          ListTile(
            title: const Text('Default reminder offsets'),
            subtitle: Text(
              settings.defaultReminderOffsets.isEmpty
                  ? 'None'
                  : settings.defaultReminderOffsets.map((o) => '${o}m').join(', '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReminderOffsetsPicker(context, settings),
          ),
          const Divider(),

          const _SectionHeader(title: 'Notifications'),
          ListTile(
            title: const Text('Reschedule all notifications'),
            subtitle: const Text('Useful after timezone changes or issues'),
            trailing: const Icon(Icons.refresh),
            onTap: () => _rescheduleAll(context),
          ),
          const Divider(),

          const _SectionHeader(title: 'About'),
          const ListTile(
            title: Text(AppConstants.appName),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  void _showSnoozePicker(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Default Snooze Duration'),
        children: AppConstants.availableSnoozeDurations.map((duration) {
          return SimpleDialogOption(
            onPressed: () {
              settings.setDefaultSnooze(duration);
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('$duration minutes', style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  if (duration == settings.defaultSnooze)
                    const Icon(Icons.check, color: AppColors.primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReminderOffsetsPicker(BuildContext context, SettingsProvider settings) {
    final selected = List<int>.from(settings.defaultReminderOffsets);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Default Reminder Offsets'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.availableReminderOffsets.map((offset) {
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
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
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
        const SnackBar(content: Text('All notifications rescheduled')),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
