import 'package:hive_flutter/hive_flutter.dart';
import '../models/activity.dart';
import '../models/chat_message.dart';
import '../utils/constants.dart';

class StorageService {
  late Box<Map> _activityBox;
  late Box _settingsBox;
  late Box<Map> _aiChatBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _activityBox = await Hive.openBox<Map>(AppConstants.hiveBoxActivities);
    _settingsBox = await Hive.openBox(AppConstants.hiveBoxSettings);
    _aiChatBox = await Hive.openBox<Map>(AppConstants.hiveBoxAiChat);
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

  Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
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

  // --- OpenAI Settings ---

  /// OpenAI API key (stored on device only).
  String? get openaiApiKey => getSetting<String>('openaiApiKey');

  Future<void> setOpenaiApiKey(String key) =>
      setSetting('openaiApiKey', key);

  Future<void> clearOpenaiApiKey() => deleteSetting('openaiApiKey');

  /// OpenAI model name (default: gpt-4o-mini).
  String get openaiModel =>
      getSetting<String>('openaiModel', defaultValue: 'gpt-4o-mini') ??
      'gpt-4o-mini';

  Future<void> setOpenaiModel(String model) =>
      setSetting('openaiModel', model);

  // --- AI Chat History ---

  List<ChatMessage> getChatHistory() {
    return _aiChatBox.values
        .map((raw) => ChatMessage.fromJson(Map<String, dynamic>.from(raw)))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    await _aiChatBox.put(message.id, message.toJson());
  }

  Future<void> saveChatMessages(List<ChatMessage> messages) async {
    final map = <String, Map<String, dynamic>>{};
    for (final m in messages) {
      map[m.id] = m.toJson();
    }
    await _aiChatBox.putAll(map);
  }

  Future<void> clearChatHistory() async {
    await _aiChatBox.clear();
  }
}
