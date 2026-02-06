import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'DailyCue';
  static const String hiveBoxActivities = 'activities';
  static const String hiveBoxSettings = 'settings';

  // Notification channel IDs (Android)
  static const String reminderChannelId = 'dailycue_reminders';
  static const String reminderChannelName = 'Routine Reminders';
  static const String reminderChannelDescription = 'Standard reminders before activities';

  static const String alarmChannelId = 'dailycue_alarms';
  static const String alarmChannelName = 'Routine Alarms';
  static const String alarmChannelDescription = 'High-priority alarms when activities are due';

  // Notification action IDs
  static const String actionDismiss = 'dismiss';
  static const String actionSnooze = 'snooze';

  // Default settings
  static const int defaultSnoozeDuration = 5; // minutes
  static const List<int> availableSnoozeDurations = [1, 3, 5, 10, 15];
  static const List<int> availableReminderOffsets = [1, 2, 3, 5, 10, 15, 20, 30];

  // Weekday labels (Mon=1 .. Sun=7, matching DateTime.weekday)
  static const Map<int, String> weekdayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static const Map<int, String> weekdayFullLabels = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };
}

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5C6BC0);
  static const Color primaryDark = Color(0xFF3949AB);
  static const Color accent = Color(0xFFFF7043);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
}
