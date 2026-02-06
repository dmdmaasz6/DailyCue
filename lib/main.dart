import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  final storageService = StorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  // Handle notification actions (dismiss/snooze)
  notificationService.onAction = (actionId, payload) {
    if (payload == null) return;
    final parts = payload.split('|');
    if (parts.isEmpty) return;
    final activityId = parts[0];

    if (actionId == AppConstants.actionSnooze) {
      // Snooze: re-schedule with default snooze duration
      final defaultSnooze = storageService.defaultSnooze;
      final activities = storageService.getAllActivities();
      final activity = activities.where((a) => a.id == activityId).firstOrNull;
      if (activity != null) {
        final snoozeMinutes = activity.snoozeDurationMinutes > 0
            ? activity.snoozeDurationMinutes
            : defaultSnooze;
        // The scheduler service needs the notification service to snooze.
        // This is handled at the provider level; here we just schedule directly.
        notificationService.scheduleSnooze(
          notificationId: activityId.hashCode.abs() % 100000 * 10 + 9,
          title: activity.title,
          body: 'Snoozed - ${activity.description ?? activity.title}',
          delay: Duration(minutes: snoozeMinutes),
          payload: '${activity.id}|snooze',
        );
      }
    } else if (actionId == AppConstants.actionComplete) {
      // Mark activity as complete
      final activities = storageService.getAllActivities();
      final activity = activities.where((a) => a.id == activityId).firstOrNull;
      if (activity != null) {
        final updatedActivity = activity.markCompleted();
        storageService.saveActivity(updatedActivity);
      }
    }
    // Dismiss action is handled automatically by cancelNotification: true
  };

  runApp(DailyCueApp(
    storageService: storageService,
    notificationService: notificationService,
  ));
}
