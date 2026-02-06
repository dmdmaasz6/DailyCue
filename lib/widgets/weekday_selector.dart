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
            const Text('Repeat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            TextButton(
              onPressed: () {
                if (_isDaily) {
                  // Switch to weekdays only
                  onChanged([1, 2, 3, 4, 5]);
                } else {
                  // Switch to daily
                  onChanged([]);
                }
              },
              child: Text(_isDaily ? 'Daily' : 'Custom'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final day = index + 1; // 1=Mon..7=Sun
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

    // If all days selected or none selected, treat as daily
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
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label.substring(0, 2),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
