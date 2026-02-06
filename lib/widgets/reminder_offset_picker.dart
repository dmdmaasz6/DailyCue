import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ReminderOffsetPicker extends StatelessWidget {
  final List<int> selectedOffsets;
  final ValueChanged<List<int>> onChanged;

  const ReminderOffsetPicker({
    super.key,
    required this.selectedOffsets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Early Reminders', style: AppTypography.headingSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Get notified before the activity is due',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: AppConstants.availableReminderOffsets.map((offset) {
            final isSelected = selectedOffsets.contains(offset);
            return FilterChip(
              label: Text('$offset min'),
              selected: isSelected,
              onSelected: (selected) {
                final updated = List<int>.from(selectedOffsets);
                if (selected) {
                  updated.add(offset);
                  updated.sort();
                } else {
                  updated.remove(offset);
                }
                onChanged(updated);
              },
              selectedColor: AppColors.primary.withOpacity(0.12),
              checkmarkColor: AppColors.primary,
              labelStyle: AppTypography.labelMedium.copyWith(
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
