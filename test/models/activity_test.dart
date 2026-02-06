import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailycue/models/activity.dart';

void main() {
  group('Activity', () {
    test('creates with default values', () {
      final activity = Activity(
        title: 'Test',
        timeOfDay: const TimeOfDay(hour: 7, minute: 30),
      );

      expect(activity.title, 'Test');
      expect(activity.timeOfDay.hour, 7);
      expect(activity.timeOfDay.minute, 30);
      expect(activity.isDaily, true);
      expect(activity.enabled, true);
      expect(activity.alarmEnabled, true);
      expect(activity.earlyReminderOffsets, [5]);
      expect(activity.snoozeDurationMinutes, 5);
      expect(activity.id, isNotEmpty);
    });

    test('isDaily returns true when repeatDays is empty', () {
      final activity = Activity(
        title: 'Daily',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
        repeatDays: [],
      );
      expect(activity.isDaily, true);
    });

    test('isDaily returns false when repeatDays has entries', () {
      final activity = Activity(
        title: 'Weekday',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
        repeatDays: [1, 2, 3, 4, 5],
      );
      expect(activity.isDaily, false);
    });

    test('isActiveOn returns true for daily activities on any day', () {
      final activity = Activity(
        title: 'Daily',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
      );
      for (int day = 1; day <= 7; day++) {
        expect(activity.isActiveOn(day), true);
      }
    });

    test('isActiveOn returns correct values for specific days', () {
      final activity = Activity(
        title: 'Weekday',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
        repeatDays: [1, 3, 5], // Mon, Wed, Fri
      );
      expect(activity.isActiveOn(1), true); // Mon
      expect(activity.isActiveOn(2), false); // Tue
      expect(activity.isActiveOn(3), true); // Wed
      expect(activity.isActiveOn(4), false); // Thu
      expect(activity.isActiveOn(5), true); // Fri
      expect(activity.isActiveOn(6), false); // Sat
      expect(activity.isActiveOn(7), false); // Sun
    });

    test('copyWith preserves id and createdAt', () {
      final original = Activity(
        title: 'Original',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
      );
      final copied = original.copyWith(title: 'Updated');

      expect(copied.id, original.id);
      expect(copied.createdAt, original.createdAt);
      expect(copied.title, 'Updated');
      expect(copied.timeOfDay, original.timeOfDay);
    });

    test('toJson and fromJson round-trip', () {
      final original = Activity(
        title: 'Test Activity',
        description: 'A test',
        timeOfDay: const TimeOfDay(hour: 14, minute: 30),
        repeatDays: [1, 3, 5],
        enabled: false,
        earlyReminderOffsets: [5, 10],
        alarmEnabled: true,
        snoozeDurationMinutes: 10,
        sortOrder: 2,
      );

      final json = original.toJson();
      final restored = Activity.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, 'Test Activity');
      expect(restored.description, 'A test');
      expect(restored.timeOfDay.hour, 14);
      expect(restored.timeOfDay.minute, 30);
      expect(restored.repeatDays, [1, 3, 5]);
      expect(restored.enabled, false);
      expect(restored.earlyReminderOffsets, [5, 10]);
      expect(restored.alarmEnabled, true);
      expect(restored.snoozeDurationMinutes, 10);
      expect(restored.sortOrder, 2);
    });

    test('equality is based on id', () {
      final a = Activity(
        id: 'test-id',
        title: 'A',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
      );
      final b = Activity(
        id: 'test-id',
        title: 'B',
        timeOfDay: const TimeOfDay(hour: 9, minute: 0),
      );
      final c = Activity(
        id: 'other-id',
        title: 'A',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('nextOccurrence returns future time on active day', () {
      final now = DateTime(2025, 1, 6, 10, 0); // Monday 10:00
      final activity = Activity(
        title: 'Test',
        timeOfDay: const TimeOfDay(hour: 14, minute: 0), // 14:00
      );

      final next = activity.nextOccurrence(now);
      expect(next.hour, 14);
      expect(next.minute, 0);
      expect(next.day, 6); // Same day (Monday), time hasn't passed
    });

    test('nextOccurrence skips to next active day when time has passed', () {
      final now = DateTime(2025, 1, 6, 15, 0); // Monday 15:00
      final activity = Activity(
        title: 'Test',
        timeOfDay: const TimeOfDay(hour: 14, minute: 0), // 14:00 (already passed)
      );

      final next = activity.nextOccurrence(now);
      expect(next.hour, 14);
      expect(next.minute, 0);
      expect(next.isAfter(now), true);
    });

    test('nextOccurrence finds correct day for weekday-only activity', () {
      final now = DateTime(2025, 1, 4, 10, 0); // Saturday 10:00
      final activity = Activity(
        title: 'Weekday only',
        timeOfDay: const TimeOfDay(hour: 8, minute: 0),
        repeatDays: [1, 2, 3, 4, 5], // Mon-Fri
      );

      final next = activity.nextOccurrence(now);
      expect(next.weekday, 1); // Monday
      expect(next.isAfter(now), true);
    });
  });
}
