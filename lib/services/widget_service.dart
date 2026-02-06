import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../models/activity.dart';
import '../utils/time_utils.dart';

/// Service for managing home screen widget updates
class WidgetService {
  static final WidgetService _instance = WidgetService._();
  factory WidgetService() => _instance;
  WidgetService._();

  static const String _androidWidgetName = 'DailyCueWidgetProvider';
  static const String _iOSWidgetName = 'DailyCueWidget';

  /// Initialize the widget service
  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId('group.com.dailycue.app');
    } catch (e) {
      // iOS only, ignore on Android
    }
  }

  /// Update the widget with the next activity and stats
  Future<void> updateWidget(
    Activity? nextActivity, {
    int completedCount = 0,
    int remainingCount = 0,
    int totalCount = 0,
    bool allCompleted = false,
  }) async {
    try {
      // Save stats data
      await HomeWidget.saveWidgetData<int>('completed_count', completedCount);
      await HomeWidget.saveWidgetData<int>('remaining_count', remainingCount);
      await HomeWidget.saveWidgetData<int>('total_count', totalCount);
      await HomeWidget.saveWidgetData<bool>('all_completed', allCompleted);

      if (allCompleted && totalCount > 0) {
        // All activities completed - show congratulatory message
        await HomeWidget.saveWidgetData<String>('activity_title', 'All Done!');
        await HomeWidget.saveWidgetData<String>('activity_time', '');
        await HomeWidget.saveWidgetData<String>(
          'activity_description',
          "You've completed all your activities for today!",
        );
        await HomeWidget.saveWidgetData<String>('activity_category', 'general');
        await HomeWidget.saveWidgetData<String>('activity_countdown', '');
        await HomeWidget.saveWidgetData<bool>('has_activity', false);
      } else if (nextActivity != null) {
        final now = DateTime.now();
        final activityTime = DateTime(
          now.year,
          now.month,
          now.day,
          nextActivity.timeOfDay.hour,
          nextActivity.timeOfDay.minute,
        );
        final diff = activityTime.difference(now);

        // Save data to widget
        await HomeWidget.saveWidgetData<String>('activity_title', nextActivity.title);
        await HomeWidget.saveWidgetData<String>(
          'activity_time',
          TimeUtils.format24h(nextActivity.timeOfDay),
        );
        await HomeWidget.saveWidgetData<String>(
          'activity_description',
          nextActivity.description ?? '',
        );
        await HomeWidget.saveWidgetData<String>('activity_category', nextActivity.category);

        // Calculate countdown
        String countdown;
        if (diff.inSeconds <= 0) {
          countdown = 'Now';
        } else if (diff.inMinutes < 1) {
          countdown = 'In ${diff.inSeconds}s';
        } else if (diff.inMinutes < 60) {
          countdown = 'In ${diff.inMinutes} min';
        } else {
          final h = diff.inHours;
          final m = diff.inMinutes % 60;
          countdown = m > 0 ? 'In ${h}h ${m}m' : 'In ${h}h';
        }
        await HomeWidget.saveWidgetData<String>('activity_countdown', countdown);
        await HomeWidget.saveWidgetData<bool>('has_activity', true);
      } else {
        // No activity scheduled
        await HomeWidget.saveWidgetData<String>('activity_title', 'No activities');
        await HomeWidget.saveWidgetData<String>('activity_time', '--:--');
        await HomeWidget.saveWidgetData<String>('activity_description', 'No activities scheduled');
        await HomeWidget.saveWidgetData<String>('activity_category', 'general');
        await HomeWidget.saveWidgetData<String>('activity_countdown', '');
        await HomeWidget.saveWidgetData<bool>('has_activity', false);
      }

      // Update the widget
      if (Platform.isAndroid) {
        await HomeWidget.updateWidget(
          androidName: _androidWidgetName,
        );
      } else if (Platform.isIOS) {
        await HomeWidget.updateWidget(
          iOSName: _iOSWidgetName,
        );
      }
    } catch (e) {
      // Handle error silently - widget update is not critical
      print('Error updating widget: $e');
    }
  }

  /// Register for widget updates (called when widget is clicked)
  void registerBackgroundCallback(Function callback) {
    // HomeWidget.registerBackgroundCallback(callback as Function(Uri?)?);
  }

  /// Get the initial widget data (for handling widget taps)
  Future<Uri?> getWidgetData() async {
    return await HomeWidget.initiallyLaunchedFromHomeWidget();
  }
}
