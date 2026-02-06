import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/activity.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

/// Converts Activity definitions into scheduled notifications and alarms.
///
/// Notification ID scheme:
///   Each activity gets a base ID derived from its UUID hash.
///   - Alarm:     baseId + 0
///   - Reminder offsets: baseId + offset index + 1
///   Per weekday variant: baseId * 10 + weekday
class SchedulerService {
  final NotificationService _notificationService;

  SchedulerService(this._notificationService);

  /// Reschedule all notifications for the given activities.
  Future<void> rescheduleAll(List<Activity> activities) async {
    await _notificationService.cancelAll();
    for (final activity in activities) {
      if (activity.enabled) {
        await _scheduleActivity(activity);
      }
    }
  }

  /// Schedule notifications for a single activity.
  Future<void> scheduleActivity(Activity activity) async {
    // Cancel existing notifications for this activity first
    await cancelActivity(activity);
    if (activity.enabled) {
      await _scheduleActivity(activity);
    }
  }

  /// Cancel all notifications for a single activity.
  Future<void> cancelActivity(Activity activity) async {
    final baseId = _baseNotificationId(activity.id);
    final days = activity.isDaily ? [0] : activity.repeatDays;

    for (final day in days) {
      final dayBase = baseId * 10 + day;
      // Cancel alarm
      await _notificationService.cancel(dayBase);
      // Cancel reminders (support up to 10 offsets)
      for (int i = 1; i <= 10; i++) {
        await _notificationService.cancel(dayBase + i * 100);
      }
    }
  }

  Future<void> _scheduleActivity(Activity activity) async {
    final baseId = _baseNotificationId(activity.id);
    final now = tz.TZDateTime.now(tz.local);

    if (activity.isDaily) {
      final dayBase = baseId * 10; // daily slot
      final scheduledDate = _nextDateTimeForTime(activity.timeOfDay);

      if (activity.alarmEnabled) {
        await _notificationService.scheduleAlarm(
          notificationId: dayBase,
          title: activity.title,
          body: activity.description ?? 'Time for: ${activity.title}',
          scheduledDate: scheduledDate,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '${activity.id}|alarm',
        );
      } else {
        await _notificationService.scheduleReminder(
          notificationId: dayBase,
          title: activity.title,
          body: activity.description ?? 'Time for: ${activity.title}',
          scheduledDate: scheduledDate,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '${activity.id}|due',
        );
      }

      for (int i = 0; i < activity.earlyReminderOffsets.length; i++) {
        final offset = activity.earlyReminderOffsets[i];
        var reminderTime = scheduledDate.subtract(Duration(minutes: offset));
        if (reminderTime.isBefore(now)) {
          reminderTime = reminderTime.add(const Duration(days: 1));
        }

        await _notificationService.scheduleReminder(
          notificationId: dayBase + (i + 1) * 100,
          title: '${activity.title} in $offset min',
          body: activity.description ?? 'Coming up: ${activity.title}',
          scheduledDate: reminderTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '${activity.id}|reminder|$offset',
        );
      }

      return;
    }

    final days = activity.repeatDays;

    for (final day in days) {
      final dayBase = baseId * 10 + day;
      final scheduledDate = _nextDateTimeForDayAndTime(day, activity.timeOfDay);

      // Schedule due-time alarm
      if (activity.alarmEnabled) {
        await _notificationService.scheduleAlarm(
          notificationId: dayBase,
          title: activity.title,
          body: activity.description ?? 'Time for: ${activity.title}',
          scheduledDate: scheduledDate,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '${activity.id}|alarm',
        );
      } else {
        // Schedule as standard notification if alarm is disabled
        await _notificationService.scheduleReminder(
          notificationId: dayBase,
          title: activity.title,
          body: activity.description ?? 'Time for: ${activity.title}',
          scheduledDate: scheduledDate,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '${activity.id}|due',
        );
      }

      // Schedule early reminders
      for (int i = 0; i < activity.earlyReminderOffsets.length; i++) {
        final offset = activity.earlyReminderOffsets[i];
        final reminderTime = scheduledDate.subtract(Duration(minutes: offset));

        // Only schedule if the reminder time is in the future
        if (reminderTime.isAfter(tz.TZDateTime.now(tz.local))) {
          await _notificationService.scheduleReminder(
            notificationId: dayBase + (i + 1) * 100,
            title: '${activity.title} in $offset min',
            body: activity.description ?? 'Coming up: ${activity.title}',
            scheduledDate: reminderTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: '${activity.id}|reminder|$offset',
          );
        }
      }
    }
  }

  tz.TZDateTime _nextDateTimeForTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now) || scheduled.isAtSameMomentAs(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Handle snooze action for an activity.
  Future<void> snooze(Activity activity, int snoozeMinutes) async {
    final snoozeId = _baseNotificationId(activity.id) * 10 + 9; // special snooze slot
    await _notificationService.scheduleSnooze(
      notificationId: snoozeId,
      title: activity.title,
      body: 'Snoozed - ${activity.description ?? activity.title}',
      delay: Duration(minutes: snoozeMinutes),
      payload: '${activity.id}|snooze',
    );
  }

  /// Generate a stable base notification ID from activity UUID.
  int _baseNotificationId(String activityId) {
    // Use hashCode and ensure it's positive and within a reasonable range
    return activityId.hashCode.abs() % 100000;
  }

  /// Compute the next TZDateTime for a given weekday (1=Mon..7=Sun) and time.
  tz.TZDateTime _nextDateTimeForDayAndTime(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Adjust to the correct weekday
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // If the time has already passed for this week's occurrence, move to next week
    if (scheduled.isBefore(now) || scheduled.isAtSameMomentAs(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    return scheduled;
  }
}
