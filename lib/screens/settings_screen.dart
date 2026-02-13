import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import 'model_selection_screen.dart';

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

          _SectionHeader(title: 'AI COACH'),
          Consumer<StorageService>(
            builder: (context, storage, _) {
              return ListTile(
                title: Text('AI Model', style: AppTypography.bodyLarge),
                subtitle: Text(
                  storage.selectedModel.displayName,
                  style: AppTypography.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModelSelectionScreen(),
                    ),
                  );
                },
              );
            },
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
          const _NotificationHealthTiles(),
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

class _NotificationHealthTiles extends StatefulWidget {
  const _NotificationHealthTiles();

  @override
  State<_NotificationHealthTiles> createState() =>
      _NotificationHealthTilesState();
}

class _NotificationHealthTilesState extends State<_NotificationHealthTiles>
    with WidgetsBindingObserver {
  PermissionStatus? _notificationStatus;
  PermissionStatus? _exactAlarmStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    if (!Platform.isAndroid) return;
    final notificationStatus = await Permission.notification.status;
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    if (!mounted) return;
    setState(() {
      _notificationStatus = notificationStatus;
      _exactAlarmStatus = exactAlarmStatus;
    });
  }

  String _statusLabel(PermissionStatus? status) {
    if (status == null) return 'Checking...';
    if (status.isGranted) return 'Allowed';
    if (status.isLimited) return 'Limited';
    if (status.isPermanentlyDenied) return 'Blocked';
    return 'Not allowed';
  }

  IconData _statusIcon(PermissionStatus? status) {
    if (status == null) return Icons.hourglass_empty_rounded;
    if (status.isGranted) return Icons.check_circle_rounded;
    return Icons.warning_rounded;
  }

  Color _statusColor(PermissionStatus? status) {
    if (status == null) return AppColors.textTertiary;
    if (status.isGranted) return AppColors.primary;
    return AppColors.error;
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await Permission.notification.request();
    }
    await _refreshStatuses();
  }

  Future<void> _requestExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await Permission.scheduleExactAlarm.request();
    }
    await _refreshStatuses();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ListTile(
          title: Text('Notification permission',
              style: AppTypography.bodyLarge),
          subtitle: Text(_statusLabel(_notificationStatus),
              style: AppTypography.bodySmall),
          trailing: Icon(
            _statusIcon(_notificationStatus),
            color: _statusColor(_notificationStatus),
          ),
          onTap: _requestNotificationPermission,
        ),
        ListTile(
          title: Text('Exact alarms permission',
              style: AppTypography.bodyLarge),
          subtitle: Text(_statusLabel(_exactAlarmStatus),
              style: AppTypography.bodySmall),
          trailing: Icon(
            _statusIcon(_exactAlarmStatus),
            color: _statusColor(_exactAlarmStatus),
          ),
          onTap: _requestExactAlarmPermission,
        ),
        const Divider(),
      ],
    );
  }
}