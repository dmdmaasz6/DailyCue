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
        const Text(
          'Early Reminders',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          'Get notified before the activity is due',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
