import 'package:hive_flutter/hive_flutter.dart';
import '../models/activity.dart';
import '../utils/constants.dart';

class StorageService {
  late Box<Map> _activityBox;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _activityBox = await Hive.openBox<Map>(AppConstants.hiveBoxActivities);
    _settingsBox = await Hive.openBox(AppConstants.hiveBoxSettings);
  }

  // --- Activities ---

  List<Activity> getAllActivities() {
    return _activityBox.values
        .map((raw) => Activity.fromJson(Map<String, dynamic>.from(raw)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> saveActivity(Activity activity) async {
    await _activityBox.put(activity.id, activity.toJson());
  }

  Future<void> deleteActivity(String id) async {
    await _activityBox.delete(id);
  }

  Future<void> saveAllActivities(List<Activity> activities) async {
    final map = <String, Map<String, dynamic>>{};
    for (final a in activities) {
      map[a.id] = a.toJson();
    }
    await _activityBox.putAll(map);
  }

  // --- Settings ---

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> setSetting<T>(String key, T value) async {
    await _settingsBox.put(key, value);
  }

  // Common settings accessors

  bool get use24HourFormat => getSetting<bool>('use24HourFormat', defaultValue: true) ?? true;
  Future<void> setUse24HourFormat(bool value) => setSetting('use24HourFormat', value);

  int get defaultSnooze => getSetting<int>('defaultSnooze', defaultValue: 5) ?? 5;
  Future<void> setDefaultSnooze(int value) => setSetting('defaultSnooze', value);

  List<int> get defaultReminderOffsets {
    final raw = getSetting<List>('defaultReminderOffsets');
    if (raw == null) return [5];
    return List<int>.from(raw);
  }

  Future<void> setDefaultReminderOffsets(List<int> value) =>
      setSetting('defaultReminderOffsets', value);
}
