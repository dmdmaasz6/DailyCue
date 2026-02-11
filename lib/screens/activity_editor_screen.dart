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
  late String _category;

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
    _category = a?.category ?? ActivityCategories.general;
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
    final categoryColor = ActivityCategories.color(_category);

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
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: categoryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          children: [
            // ── Section 1: Details ────────────────────────────────
            _SectionContainer(
              title: 'Details',
              icon: Icons.edit_outlined,
              accentColor: categoryColor,
              children: [
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
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g., School drop-off',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 2: Category ───────────────────────────────
            _SectionContainer(
              title: 'Category',
              icon: Icons.palette_outlined,
              accentColor: categoryColor,
              children: [
                _CategoryPicker(
                  selected: _category,
                  onChanged: (cat) => setState(() => _category = cat),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 3: Schedule ───────────────────────────────
            _SectionContainer(
              title: 'Schedule',
              icon: Icons.schedule_outlined,
              accentColor: categoryColor,
              children: [
                _buildTimePicker(settings, categoryColor),
                const SizedBox(height: AppSpacing.lg),
                WeekdaySelector(
                  selectedDays: _repeatDays,
                  onChanged: (days) => setState(() => _repeatDays = days),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Section 4: Notifications ──────────────────────────
            _SectionContainer(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              accentColor: categoryColor,
              children: [
                ReminderOffsetPicker(
                  selectedOffsets: _reminderOffsets,
                  onChanged: (offsets) =>
                      setState(() => _reminderOffsets = offsets),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildAlarmToggle(categoryColor),
                const SizedBox(height: AppSpacing.md),
                _buildSnoozePicker(categoryColor),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(SettingsProvider settings, Color accentColor) {
    final timeStr = settings.use24HourFormat
        ? TimeUtils.format24h(_selectedTime)
        : TimeUtils.format12h(_selectedTime);

    return InkWell(
      onTap: _pickTime,
      borderRadius: AppRadii.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
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
            Expanded(
              child: Column(
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
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: AppIconSizes.md,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmToggle(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(
              Icons.alarm_rounded,
              size: AppIconSizes.sm,
              color: _alarmEnabled ? accentColor : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Alarm at due time', style: AppTypography.bodyLarge),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: AppIconSizes.sm + AppSpacing.sm),
          child: Text(
            'Full-screen alarm when activity is due',
            style: AppTypography.bodySmall,
          ),
        ),
        value: _alarmEnabled,
        activeColor: accentColor,
        onChanged: (value) => setState(() => _alarmEnabled = value),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
        ),
      ),
    );
  }

  Widget _buildSnoozePicker(Color accentColor) {
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
          Icon(
            Icons.snooze_rounded,
            size: AppIconSizes.sm,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Snooze duration', style: AppTypography.bodyLarge),
          ),
          DropdownButton<int>(
            value: _snoozeDuration,
            underline: const SizedBox.shrink(),
            style: AppTypography.labelLarge.copyWith(
              color: accentColor,
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
        category: _category,
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
        category: _category,
      );
      await provider.addActivity(newActivity);
    }

    if (mounted) Navigator.pop(context, true);
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

// ---------------------------------------------------------------------------
// Section container with accent header
// ---------------------------------------------------------------------------

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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadii.lg),
                topRight: Radius.circular(AppRadii.lg),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: AppIconSizes.sm, color: accentColor),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category picker — horizontal scrollable chips
// ---------------------------------------------------------------------------

class _CategoryPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryPicker({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ActivityCategories.all.map((cat) {
        final isSelected = cat == selected;
        final color = ActivityCategories.color(cat);
        final label = ActivityCategories.labels[cat]!;
        final icon = ActivityCategories.icons[cat]!;

        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.12) : AppColors.surfaceAlt,
              borderRadius: AppRadii.borderRadiusFull,
              border: Border.all(
                color: isSelected ? color : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: AppIconSizes.sm,
                  color: isSelected ? color : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected ? color : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
