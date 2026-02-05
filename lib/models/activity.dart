import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Activity {
  final String id;
  String title;
  String? description;
  TimeOfDay timeOfDay;
  List<int> repeatDays; // 1=Mon..7=Sun; empty means daily
  bool enabled;
  List<int> earlyReminderOffsets; // minutes before activity time
  bool alarmEnabled;
  int snoozeDurationMinutes;
  int sortOrder;
  DateTime createdAt;
  DateTime updatedAt;

  Activity({
    String? id,
    required this.title,
    this.description,
    required this.timeOfDay,
    List<int>? repeatDays,
    this.enabled = true,
    List<int>? earlyReminderOffsets,
    this.alarmEnabled = true,
    this.snoozeDurationMinutes = 5,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        repeatDays = repeatDays ?? [],
        earlyReminderOffsets = earlyReminderOffsets ?? [5],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isDaily => repeatDays.isEmpty;

  /// Whether this activity is active on the given weekday (1=Mon..7=Sun).
  bool isActiveOn(int weekday) {
    if (isDaily) return true;
    return repeatDays.contains(weekday);
  }

  /// Returns the next DateTime this activity should fire, starting from [now].
  DateTime nextOccurrence(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);

    // If the time hasn't passed today and this day is active, use today
    if (today.isAfter(now) && isActiveOn(now.weekday)) {
      return today;
    }

    // Otherwise look ahead up to 7 days
    for (int i = 1; i <= 7; i++) {
      final candidate = today.add(Duration(days: i));
      if (isActiveOn(candidate.weekday)) {
        return candidate;
      }
    }

    // Fallback (should not happen if at least one day is selected or isDaily)
    return today.add(const Duration(days: 1));
  }

  Activity copyWith({
    String? title,
    String? description,
    TimeOfDay? timeOfDay,
    List<int>? repeatDays,
    bool? enabled,
    List<int>? earlyReminderOffsets,
    bool? alarmEnabled,
    int? snoozeDurationMinutes,
    int? sortOrder,
  }) {
    return Activity(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      repeatDays: repeatDays ?? List.from(this.repeatDays),
      enabled: enabled ?? this.enabled,
      earlyReminderOffsets: earlyReminderOffsets ?? List.from(this.earlyReminderOffsets),
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'hour': timeOfDay.hour,
      'minute': timeOfDay.minute,
      'repeatDays': repeatDays,
      'enabled': enabled,
      'earlyReminderOffsets': earlyReminderOffsets,
      'alarmEnabled': alarmEnabled,
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      timeOfDay: TimeOfDay(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      ),
      repeatDays: List<int>.from(json['repeatDays'] as List),
      enabled: json['enabled'] as bool,
      earlyReminderOffsets: List<int>.from(json['earlyReminderOffsets'] as List),
      alarmEnabled: json['alarmEnabled'] as bool,
      snoozeDurationMinutes: json['snoozeDurationMinutes'] as int,
      sortOrder: json['sortOrder'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Activity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Activity(id: $id, title: $title, time: ${timeOfDay.hour}:${timeOfDay.minute.toString().padLeft(2, '0')})';
}
