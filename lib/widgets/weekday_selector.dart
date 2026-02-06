import 'package:flutter/material.dart';
import '../utils/constants.dart';

class WeekdaySelector extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;

  const WeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  bool get _isDaily => selectedDays.isEmpty || selectedDays.length == 7;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Repeat', style: AppTypography.headingSmall),
            const Spacer(),
            TextButton(
              onPressed: () {
                if (_isDaily) {
                  onChanged([1, 2, 3, 4, 5]);
                } else {
                  onChanged([]);
                }
              },
              child: Text(_isDaily ? 'Daily' : 'Custom'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final day = index + 1;
            final isSelected = _isDaily || selectedDays.contains(day);
            return _DayChip(
              label: AppConstants.weekdayLabels[day]!,
              isSelected: isSelected,
              onTap: () => _toggleDay(day),
            );
          }),
        ),
      ],
    );
  }

  void _toggleDay(int day) {
    final current = _isDaily
        ? [1, 2, 3, 4, 5, 6, 7]
        : List<int>.from(selectedDays);

    if (current.contains(day)) {
      current.remove(day);
    } else {
      current.add(day);
    }

    if (current.length == 7 || current.isEmpty) {
      onChanged([]);
    } else {
      onChanged(current);
    }
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.substring(0, 2),
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
