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
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _selectedTime = a?.timeOfDay ?? TimeOfDay.now();
    _repeatDays = a != null ? List.from(a.repeatDays) : [];
    _reminderOffsets = a != null ? List.from(a.earlyReminderOffsets) : [5];
    _alarmEnabled = a?.alarmEnabled ?? true;
    _snoozeDuration = a?.snoozeDurationMinutes ?? AppConstants.defaultSnoozeDuration;
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _delete,
              tooltip: 'Delete activity',
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Activity Title',
                hintText: 'e.g., Leave home, Brush teeth',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., School drop-off',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Time picker
            _buildTimePicker(settings),
            const SizedBox(height: 24),

            // Weekday selector
            WeekdaySelector(
              selectedDays: _repeatDays,
              onChanged: (days) => setState(() => _repeatDays = days),
            ),
            const SizedBox(height: 24),

            // Early reminders
            ReminderOffsetPicker(
              selectedOffsets: _reminderOffsets,
              onChanged: (offsets) => setState(() => _reminderOffsets = offsets),
            ),
            const SizedBox(height: 24),

            // Alarm toggle
            SwitchListTile(
              title: const Text('Alarm at due time'),
              subtitle: const Text('Full-screen alarm when activity is due'),
              value: _alarmEnabled,
              onChanged: (value) => setState(() => _alarmEnabled = value),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

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
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Time',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.access_time),
        ),
        child: Text(
          timeStr,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildSnoozePicker() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Snooze duration',
            style: TextStyle(fontSize: 16),
          ),
        ),
        DropdownButton<int>(
          value: _snoozeDuration,
          items: AppConstants.availableSnoozeDurations
              .map((d) => DropdownMenuItem(value: d, child: Text('$d min')))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _snoozeDuration = value);
          },
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
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
      // Update existing
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
      // Create new
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
