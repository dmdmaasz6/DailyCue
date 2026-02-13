import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/activity.dart';
import '../utils/constants.dart';

/// Top-level function for handling background notification actions.
/// Runs in a separate isolate, so it must be fully self-contained —
/// it cannot rely on any state from the main isolate.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId == null || actionId.isEmpty) return;

  // Dismiss is handled automatically by cancelNotification: true
  if (actionId == AppConstants.actionDismiss) return;

  final payload = response.payload;
  if (payload == null) return;
  final parts = payload.split('|');
  if (parts.isEmpty) return;
  final activityId = parts[0];

  try {
    // Initialize Flutter bindings for background isolate
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Hive storage in this isolate
    await Hive.initFlutter();
    final activityBox = Hive.isBoxOpen(AppConstants.hiveBoxActivities)
        ? Hive.box<Map>(AppConstants.hiveBoxActivities)
        : await Hive.openBox<Map>(AppConstants.hiveBoxActivities);
    final settingsBox = Hive.isBoxOpen(AppConstants.hiveBoxSettings)
        ? Hive.box(AppConstants.hiveBoxSettings)
        : await Hive.openBox(AppConstants.hiveBoxSettings);

    final raw = activityBox.get(activityId);
    if (raw == null) return;
    final activity = Activity.fromJson(Map<String, dynamic>.from(raw));

    if (actionId == AppConstants.actionComplete) {
      // Mark activity as completed and persist
      final updatedActivity = activity.markCompleted();
      await activityBox.put(activityId, updatedActivity.toJson());
    } else if (actionId == AppConstants.actionSnooze) {
      // Determine snooze duration
      final defaultSnooze =
          settingsBox.get('defaultSnooze', defaultValue: 5) as int? ?? 5;
      final snoozeMinutes = activity.snoozeDurationMinutes > 0
          ? activity.snoozeDurationMinutes
          : defaultSnooze;

      // Initialize timezone for scheduling
      tz.initializeTimeZones();
      try {
        final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = timeZoneInfo is String
            ? (timeZoneInfo as String)
            : (timeZoneInfo as dynamic).identifier?.toString() ??
                timeZoneInfo.toString();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {}

      // Determine schedule mode
      var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        final androidPlugin = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final exactAllowed =
            await androidPlugin?.canScheduleExactNotifications() ?? false;
        if (exactAllowed) {
          scheduleMode = AndroidScheduleMode.alarmClock;
        }
      }

      // Schedule the snooze notification
      final snoozeId = activityId.hashCode.abs() % 100000 * 10 + 9;
      final scheduledDate =
          tz.TZDateTime.now(tz.local).add(Duration(minutes: snoozeMinutes));

      await plugin.zonedSchedule(
        id: snoozeId,
        title: activity.title,
        body: 'Snoozed - ${activity.description ?? activity.title}',
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
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                AppConstants.actionSnooze,
                'Snooze',
                cancelNotification: true,
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                AppConstants.actionDismiss,
                'Dismiss',
                cancelNotification: true,
                showsUserInterface: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: scheduleMode,
        payload: '${activity.id}|snooze',
      );
    }
  } catch (e) {
    debugPrint('Background notification action error: $e');
  }
}

/// Callback for handling notification actions (dismiss / snooze).
typedef NotificationActionCallback = void Function(String actionId, String? payload);

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  NotificationActionCallback? _onAction;
  NotificationResponse? _pendingActionResponse;
  bool _exactAlarmsAllowed = false;

  /// Sets the action callback. If a notification action arrived before
  /// this was set (e.g. app launched from a notification action), it is
  /// replayed immediately.
  set onAction(NotificationActionCallback? callback) {
    _onAction = callback;
    if (callback != null && _pendingActionResponse != null) {
      final response = _pendingActionResponse!;
      _pendingActionResponse = null;
      _dispatchActionResponse(response);
    }
  }

  NotificationActionCallback? get onAction => _onAction;

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
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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
    _dispatchActionResponse(response);
  }

  void _dispatchActionResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (actionId != null && actionId.isNotEmpty) {
      if (_onAction != null) {
        _onAction!.call(actionId, payload);
      } else {
        // Buffer until onAction is set (app launching from notification)
        _pendingActionResponse = response;
      }
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
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionSnooze,
              'Snooze',
              cancelNotification: true,
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionDismiss,
              'Dismiss',
              cancelNotification: true,
              showsUserInterface: true,
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
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionSnooze,
              'Snooze',
              cancelNotification: true,
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              AppConstants.actionDismiss,
              'Dismiss',
              cancelNotification: true,
              showsUserInterface: true,
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
}
