import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import '../widgets/weekday_selector.dart';
import '../widgets/reminder_offset_picker.dart';

class ActivityEditorScreen extends StatefulWidget {
  final Activity? activity;

  const ActivityEditorScreen({super.key, this.activity});

  @override
  State<ActivityEditorScreen> createState() => _ActivityEditorScreenState();
}

class _ActivityEditorScreenState extends State<ActivityEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TimeOfDay _selectedTime;
  late List<int> _repeatDays;
  late List<int> _reminderOffsets;
  late bool _alarmEnabled;
  late int _snoozeDuration;

  bool get _isEditing => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _titleController = TextEditingController(text: a?.title ?? '');
    _descriptionController =
        TextEditingController(text: a?.description ?? '');
    _selectedTime = a?.timeOfDay ?? TimeOfDay.now();
    _repeatDays = a != null ? List.from(a.repeatDays) : [];
    _reminderOffsets =
        a != null ? List.from(a.earlyReminderOffsets) : [5];
    _alarmEnabled = a?.alarmEnabled ?? true;
    _snoozeDuration =
        a?.snoozeDurationMinutes ?? AppConstants.defaultSnoozeDuration;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Activity' : 'New Activity'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
              tooltip: 'Delete activity',
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Activity Title',
                hintText: 'e.g., Leave home, Brush teeth',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., School drop-off',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Time picker
            _buildTimePicker(settings),
            const SizedBox(height: AppSpacing.lg),

            // Weekday selector
            WeekdaySelector(
              selectedDays: _repeatDays,
              onChanged: (days) => setState(() => _repeatDays = days),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Early reminders
            ReminderOffsetPicker(
              selectedOffsets: _reminderOffsets,
              onChanged: (offsets) =>
                  setState(() => _reminderOffsets = offsets),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Alarm toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: AppRadii.borderRadiusMd,
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                title: Text('Alarm at due time',
                    style: AppTypography.bodyLarge),
                subtitle: Text(
                  'Full-screen alarm when activity is due',
                  style: AppTypography.bodySmall,
                ),
                value: _alarmEnabled,
                onChanged: (value) =>
                    setState(() => _alarmEnabled = value),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Snooze duration
            _buildSnoozePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(SettingsProvider settings) {
    final timeStr = settings.use24HourFormat
        ? TimeUtils.format24h(_selectedTime)
        : TimeUtils.format12h(_selectedTime);

    return InkWell(
      onTap: _pickTime,
      borderRadius: AppRadii.borderRadiusMd,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Time',
          suffixIcon: Icon(Icons.access_time_rounded),
        ),
        child: Text(timeStr, style: AppTypography.headingMedium),
      ),
    );
  }

  Widget _buildSnoozePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Snooze duration', style: AppTypography.bodyLarge),
          ),
          DropdownButton<int>(
            value: _snoozeDuration,
            underline: const SizedBox.shrink(),
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.primary,
            ),
            items: AppConstants.availableSnoozeDurations
                .map((d) =>
                    DropdownMenuItem(value: d, child: Text('$d min')))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _snoozeDuration = value);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ActivityProvider>();
    final activity = widget.activity;

    if (activity != null) {
      final updated = activity.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        timeOfDay: _selectedTime,
        repeatDays: _repeatDays,
        earlyReminderOffsets: _reminderOffsets,
        alarmEnabled: _alarmEnabled,
        snoozeDurationMinutes: _snoozeDuration,
      );
      await provider.updateActivity(updated);
    } else {
      final newActivity = Activity(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        timeOfDay: _selectedTime,
        repeatDays: _repeatDays,
        earlyReminderOffsets: _reminderOffsets,
        alarmEnabled: _alarmEnabled,
        snoozeDurationMinutes: _snoozeDuration,
      );
      await provider.addActivity(newActivity);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final activity = widget.activity;
    if (activity == null) return;

    final confirmed = await _confirmDelete(context, activity.title);
    if (confirmed != true) return;

    final provider = context.read<ActivityProvider>();
    await provider.deleteActivity(activity.id);

    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _confirmDelete(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
