import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailycue/utils/time_utils.dart';

void main() {
  group('TimeUtils', () {
    group('format24h', () {
      test('formats morning time', () {
        expect(TimeUtils.format24h(const TimeOfDay(hour: 7, minute: 5)), '07:05');
      });

      test('formats afternoon time', () {
        expect(TimeUtils.format24h(const TimeOfDay(hour: 14, minute: 30)), '14:30');
      });

      test('formats midnight', () {
        expect(TimeUtils.format24h(const TimeOfDay(hour: 0, minute: 0)), '00:00');
      });
    });

    group('format12h', () {
      test('formats morning time', () {
        expect(TimeUtils.format12h(const TimeOfDay(hour: 7, minute: 5)), '7:05 AM');
      });

      test('formats afternoon time', () {
        expect(TimeUtils.format12h(const TimeOfDay(hour: 14, minute: 30)), '2:30 PM');
      });

      test('formats noon', () {
        expect(TimeUtils.format12h(const TimeOfDay(hour: 12, minute: 0)), '12:00 PM');
      });

      test('formats midnight', () {
        expect(TimeUtils.format12h(const TimeOfDay(hour: 0, minute: 0)), '12:00 AM');
      });
    });

    group('repeatSummary', () {
      test('returns Daily for empty list', () {
        expect(TimeUtils.repeatSummary([]), 'Daily');
      });

      test('returns Daily for all 7 days', () {
        expect(TimeUtils.repeatSummary([1, 2, 3, 4, 5, 6, 7]), 'Daily');
      });

      test('returns Weekdays for Mon-Fri', () {
        expect(TimeUtils.repeatSummary([1, 2, 3, 4, 5]), 'Weekdays');
      });

      test('returns Weekends for Sat-Sun', () {
        expect(TimeUtils.repeatSummary([6, 7]), 'Weekends');
      });

      test('returns individual day names for custom selection', () {
        expect(TimeUtils.repeatSummary([1, 3, 5]), 'Mon, Wed, Fri');
      });
    });

    group('subtractMinutes', () {
      test('subtracts within same hour', () {
        final result = TimeUtils.subtractMinutes(const TimeOfDay(hour: 7, minute: 30), 10);
        expect(result.hour, 7);
        expect(result.minute, 20);
      });

      test('subtracts crossing hour boundary', () {
        final result = TimeUtils.subtractMinutes(const TimeOfDay(hour: 7, minute: 5), 10);
        expect(result.hour, 6);
        expect(result.minute, 55);
      });

      test('wraps around midnight', () {
        final result = TimeUtils.subtractMinutes(const TimeOfDay(hour: 0, minute: 5), 10);
        expect(result.hour, 23);
        expect(result.minute, 55);
      });
    });
  });
}
