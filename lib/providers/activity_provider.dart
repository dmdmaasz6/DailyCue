import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../services/storage_service.dart';
import '../services/scheduler_service.dart';
import '../services/widget_service.dart';

class ActivityProvider extends ChangeNotifier {
  final StorageService _storage;
  final SchedulerService _scheduler;
  final WidgetService _widgetService;

  List<Activity> _activities = [];
  List<Activity> get activities => List.unmodifiable(_activities);

  ActivityProvider({
    required StorageService storage,
    required SchedulerService scheduler,
    required WidgetService widgetService,
  })  : _storage = storage,
        _scheduler = scheduler,
        _widgetService = widgetService;

  /// Load all activities from storage.
  Future<void> loadActivities() async {
    _activities = _storage.getAllActivities();
    await _updateWidget();
    notifyListeners();
  }

  /// Add a new activity.
  Future<void> addActivity(Activity activity) async {
    final withOrder = activity.copyWith(sortOrder: _activities.length);
    _activities.add(withOrder);
    await _storage.saveActivity(withOrder);
    await _scheduler.scheduleActivity(withOrder);
    await _updateWidget();
    notifyListeners();
  }

  /// Update an existing activity.
  Future<void> updateActivity(Activity activity) async {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index == -1) return;
    _activities[index] = activity;
    await _storage.saveActivity(activity);
    await _scheduler.scheduleActivity(activity);
    await _updateWidget();
    notifyListeners();
  }

  /// Delete an activity.
  Future<void> deleteActivity(String id) async {
    final activity = _activities.firstWhere((a) => a.id == id);
    _activities.removeWhere((a) => a.id == id);
    await _storage.deleteActivity(id);
    await _scheduler.cancelActivity(activity);
    _reindex();
    await _updateWidget();
    notifyListeners();
  }

  /// Toggle an activity's enabled state.
  Future<void> toggleActivity(String id) async {
    final index = _activities.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final activity = _activities[index];
    final updated = activity.copyWith(enabled: !activity.enabled);
    _activities[index] = updated;
    await _storage.saveActivity(updated);
    await _scheduler.scheduleActivity(updated);
    await _updateWidget();
    notifyListeners();
  }

  /// Reorder activities by moving [oldIndex] to [newIndex].
  Future<void> reorderActivities(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _activities.removeAt(oldIndex);
    _activities.insert(newIndex, item);
    _reindex();
    await _storage.saveAllActivities(_activities);
    notifyListeners();
  }

  /// Reschedule all notifications (e.g., after timezone change or reboot).
  Future<void> rescheduleAll() async {
    await _scheduler.rescheduleAll(_activities);
  }

  /// Handle snooze for an activity.
  Future<void> snoozeActivity(String id, int snoozeMinutes) async {
    final activity = _activities.firstWhere((a) => a.id == id);
    await _scheduler.snooze(activity, snoozeMinutes);
  }

  /// Mark an activity as completed.
  Future<void> markActivityComplete(String id, {DateTime? completionTime}) async {
    final index = _activities.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final activity = _activities[index];
    // Prevent duplicate completions on the same day
    if (activity.isCompletedToday()) return;
    final updated = activity.markCompleted(completionTime: completionTime);
    _activities[index] = updated;
    await _storage.saveActivity(updated);
    await _updateWidget();
    notifyListeners();
  }

  /// Get activity by ID.
  Activity? getActivity(String id) {
    try {
      return _activities.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get the next upcoming activity
  Activity? getNextActivity() {
    final now = DateTime.now();
    final enabledActivities = _activities.where((a) => a.enabled).toList();

    if (enabledActivities.isEmpty) return null;

    // Find the next activity
    final nextActivities = enabledActivities
        .where((a) => a.nextOccurrence(now).isAfter(now))
        .toList()
      ..sort((a, b) => a.nextOccurrence(now).compareTo(b.nextOccurrence(now)));

    return nextActivities.isNotEmpty ? nextActivities.first : null;
  }

  /// Update the home screen widget
  Future<void> _updateWidget() async {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final todayWeekday = now.weekday;

    // Get today's activities
    final todayActivities = _activities
        .where((a) =>
            a.enabled &&
            (a.repeatDays.isEmpty || a.repeatDays.contains(todayWeekday)))
        .toList();

    // Calculate stats
    final completedCount = todayActivities.where((a) => a.isCompletedToday()).length;
    final totalCount = todayActivities.length;
    final remainingCount = totalCount - completedCount;
    final allCompleted = totalCount > 0 && completedCount == totalCount;

    // Find next upcoming activity
    Activity? nextActivity;
    for (final a in todayActivities) {
      if (a.timeOfDay.hour * 60 + a.timeOfDay.minute >= nowMinutes) {
        nextActivity = a;
        break;
      }
    }

    await _widgetService.updateWidget(
      nextActivity,
      completedCount: completedCount,
      remainingCount: remainingCount,
      totalCount: totalCount,
      allCompleted: allCompleted,
    );
  }

  void _reindex() {
    for (int i = 0; i < _activities.length; i++) {
      _activities[i] = _activities[i].copyWith(sortOrder: i);
    }
  }
}
