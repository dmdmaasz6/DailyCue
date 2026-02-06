import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../services/storage_service.dart';
import '../services/scheduler_service.dart';

class ActivityProvider extends ChangeNotifier {
  final StorageService _storage;
  final SchedulerService _scheduler;

  List<Activity> _activities = [];
  List<Activity> get activities => List.unmodifiable(_activities);

  ActivityProvider({
    required StorageService storage,
    required SchedulerService scheduler,
  })  : _storage = storage,
        _scheduler = scheduler;

  /// Load all activities from storage.
  Future<void> loadActivities() async {
    _activities = _storage.getAllActivities();
    notifyListeners();
  }

  /// Add a new activity.
  Future<void> addActivity(Activity activity) async {
    final withOrder = activity.copyWith(sortOrder: _activities.length);
    _activities.add(withOrder);
    await _storage.saveActivity(withOrder);
    await _scheduler.scheduleActivity(withOrder);
    notifyListeners();
  }

  /// Update an existing activity.
  Future<void> updateActivity(Activity activity) async {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index == -1) return;
    _activities[index] = activity;
    await _storage.saveActivity(activity);
    await _scheduler.scheduleActivity(activity);
    notifyListeners();
  }

  /// Delete an activity.
  Future<void> deleteActivity(String id) async {
    final activity = _activities.firstWhere((a) => a.id == id);
    _activities.removeWhere((a) => a.id == id);
    await _storage.deleteActivity(id);
    await _scheduler.cancelActivity(activity);
    _reindex();
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

  void _reindex() {
    for (int i = 0; i < _activities.length; i++) {
      _activities[i] = _activities[i].copyWith(sortOrder: i);
    }
  }
}
