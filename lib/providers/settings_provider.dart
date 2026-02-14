import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  SettingsProvider({required StorageService storage}) : _storage = storage;

  bool get use24HourFormat => _storage.use24HourFormat;
  int get defaultSnooze => _storage.defaultSnooze;
  List<int> get defaultReminderOffsets => _storage.defaultReminderOffsets;

  Future<void> setUse24HourFormat(bool value) async {
    await _storage.setUse24HourFormat(value);
    notifyListeners();
  }

  Future<void> setDefaultSnooze(int value) async {
    await _storage.setDefaultSnooze(value);
    notifyListeners();
  }

  Future<void> setDefaultReminderOffsets(List<int> value) async {
    await _storage.setDefaultReminderOffsets(value);
    notifyListeners();
  }

  // --- OpenAI Settings ---

  String? get openaiApiKey => _storage.openaiApiKey;
  String get openaiModel => _storage.openaiModel;

  Future<void> setOpenaiApiKey(String key) async {
    await _storage.setOpenaiApiKey(key);
    notifyListeners();
  }

  Future<void> clearOpenaiApiKey() async {
    await _storage.clearOpenaiApiKey();
    notifyListeners();
  }

  Future<void> setOpenaiModel(String model) async {
    await _storage.setOpenaiModel(model);
    notifyListeners();
  }

  /// Whether the OpenAI integration is fully configured.
  bool get isOpenaiConfigured =>
      _storage.openaiApiKey != null && _storage.openaiApiKey!.isNotEmpty;
}
