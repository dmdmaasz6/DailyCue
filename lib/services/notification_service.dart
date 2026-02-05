import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../utils/constants.dart';

/// Callback for handling notification actions (dismiss / snooze).
typedef NotificationActionCallback = void Function(String actionId, String? payload);

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  NotificationActionCallback? onAction;

  Future<void> init() async {
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            AppConstants.reminderChannelId,
            AppConstants.reminderChannelName,
            description: AppConstants.reminderChannelDescription,
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            AppConstants.alarmChannelId,
            AppConstants.alarmChannelName,
            description: AppConstants.alarmChannelDescription,
            importance: Importance.max,
            sound: RawResourceAndroidNotificationSound('alarm_sound'),
            enableVibration: true,
          ),
        );
      }
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (actionId != null && actionId.isNotEmpty) {
      onAction?.call(actionId, payload);
    }
  }

  /// Request notification permissions (iOS + Android 13+).
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a standard reminder notification.
  Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          AppConstants.reminderChannelId,
          AppConstants.reminderChannelName,
          channelDescription: AppConstants.reminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// Schedule a high-priority alarm notification with dismiss/snooze actions.
  Future<void> scheduleAlarm({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.alarmChannelId,
          AppConstants.alarmChannelName,
          channelDescription: AppConstants.alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          actions: const [
            AndroidNotificationAction(
              AppConstants.actionDismiss,
              'Dismiss',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionSnooze,
              'Snooze',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// Schedule a snooze (one-time notification after delay).
  Future<void> scheduleSnooze({
    required int notificationId,
    required String title,
    required String body,
    required Duration delay,
    String? payload,
  }) async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.alarmChannelId,
          AppConstants.alarmChannelName,
          channelDescription: AppConstants.alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          actions: const [
            AndroidNotificationAction(
              AppConstants.actionDismiss,
              'Dismiss',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionSnooze,
              'Snooze',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: payload,
    );
  }

  /// Cancel a specific notification by ID.
  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
