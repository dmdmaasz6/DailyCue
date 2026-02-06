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
  bool _exactAlarmsAllowed = false;
  static const int _testNotificationId = 990001;
  static const int _testAlarmId = 990002;

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo is String
          ? (timeZoneInfo as String)
          : (timeZoneInfo as dynamic).identifier?.toString() ??
              timeZoneInfo.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (error) {
      debugPrint('Timezone init failed: $error');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
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
            sound: UriAndroidNotificationSound(
                'content://settings/system/alarm_alert'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
          ),
        );
        final exactAllowed = await androidPlugin.canScheduleExactNotifications();
        _exactAlarmsAllowed = exactAllowed ?? false;
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
      await android?.requestExactAlarmsPermission();
      await android?.requestFullScreenIntentPermission();
      final exactAllowed = await android?.canScheduleExactNotifications();
      _exactAlarmsAllowed = exactAllowed ?? false;
      return granted ?? false;
    }
    return true;
  }

  Future<bool> refreshExactAlarmsAllowed() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exactAllowed = await android?.canScheduleExactNotifications();
    _exactAlarmsAllowed = exactAllowed ?? false;
    return _exactAlarmsAllowed;
  }

  /// Schedule a standard reminder notification.
  Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
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
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          matchDateTimeComponents ?? DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// Schedule a high-priority alarm notification with dismiss/snooze actions.
  Future<void> scheduleAlarm({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.alarmChannelId,
          AppConstants.alarmChannelName,
          channelDescription: AppConstants.alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          ongoing: true,
          autoCancel: false,
          enableVibration: true,
          actions: const [
            AndroidNotificationAction(
              AppConstants.actionComplete,
              'Complete',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionSnooze,
              'Snooze',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionDismiss,
              'Dismiss',
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
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          matchDateTimeComponents ?? DateTimeComponents.dayOfWeekAndTime,
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
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.alarmChannelId,
          AppConstants.alarmChannelName,
          channelDescription: AppConstants.alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          ongoing: true,
          autoCancel: false,
          enableVibration: true,
          actions: const [
            AndroidNotificationAction(
              AppConstants.actionComplete,
              'Complete',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionSnooze,
              'Snooze',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionDismiss,
              'Dismiss',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancel a specific notification by ID.
  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(id: notificationId);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<int> pendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  Future<void> showTestNotification() async {
    await _plugin.show(
      id: _testNotificationId,
      title: 'DailyCue test notification',
      body: 'If you see this, notifications work.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.reminderChannelId,
          AppConstants.reminderChannelName,
          channelDescription: AppConstants.reminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showTestAlarmNow() async {
    await _plugin.show(
      id: _testAlarmId + 10,
      title: 'DailyCue alarm (immediate)',
      body: 'If you see this, the alarm channel can display.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.alarmChannelId,
          AppConstants.alarmChannelName,
          channelDescription: AppConstants.alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
    );
  }

  Future<void> scheduleTestAlarm(Duration delay) async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);
    if (kDebugMode) {
      debugPrint(
          'Test alarm scheduled for $scheduledDate (exact=$_exactAlarmsAllowed)');
    }
    await _plugin.zonedSchedule(
      id: _testAlarmId,
      title: 'DailyCue test alarm',
      body: 'Alarm scheduled ${delay.inSeconds}s from now.',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.alarmChannelId,
          AppConstants.alarmChannelName,
          channelDescription: AppConstants.alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleTestReminder(Duration delay) async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);
    if (kDebugMode) {
      debugPrint(
          'Test reminder scheduled for $scheduledDate (exact=$_exactAlarmsAllowed)');
    }
    await _plugin.zonedSchedule(
      id: _testNotificationId + 1,
      title: 'DailyCue scheduled reminder',
      body: 'Reminder scheduled ${delay.inSeconds}s from now.',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
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
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
