import 'package:flutter/material.dart';
import 'constants.dart';

class TimeUtils {
  TimeUtils._();

  /// Format a TimeOfDay as HH:mm (24-hour).
  static String format24h(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Format a TimeOfDay as h:mm AM/PM (12-hour).
  static String format12h(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Build a human-readable repeat schedule string.
  static String repeatSummary(List<int> repeatDays) {
    if (repeatDays.isEmpty) return 'Daily';

    final sorted = List<int>.from(repeatDays)..sort();

    // Check for common patterns
    if (_listEquals(sorted, [1, 2, 3, 4, 5])) return 'Weekdays';
    if (_listEquals(sorted, [6, 7])) return 'Weekends';
    if (sorted.length == 7) return 'Daily';

    return sorted.map((d) => AppConstants.weekdayLabels[d] ?? '').join(', ');
  }

  /// Subtract [minutes] from a TimeOfDay, wrapping around midnight.
  static TimeOfDay subtractMinutes(TimeOfDay time, int minutes) {
    int totalMinutes = time.hour * 60 + time.minute - minutes;
    if (totalMinutes < 0) totalMinutes += 24 * 60;
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
