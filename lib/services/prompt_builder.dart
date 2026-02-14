import '../utils/constants.dart';

class PromptBuilder {
  /// Core system prompt (persona + guidelines).
  static const String coreSystemPrompt =
      '''You are DailyCue AI Coach, a helpful life balance assistant embedded in a daily activity planner app. You help users understand their habits, improve their routines, and build a balanced life across these categories: General, Health, Work, Personal, Fitness, Family, Errands, and Learning.

You have access to tools to read and modify the user's activity data. Always check the user's data before giving advice.

## Guidelines
- Be concise, warm, and encouraging
- Ground all advice in the user's actual data — never guess
- When suggesting new activities, use the create_activity tool
- Always check statistics before making claims about patterns
- Ask before making changes to existing activities
- For write operations (create/update), explain what you want to do first
- Keep responses to 2-3 short paragraphs maximum
- Use simple language, no jargon''';

  String buildContextSnapshot({
    required DateTime now,
    required int todayActivityCount,
    required int todayCompletedCount,
  }) {
    final dayName = AppConstants.weekdayFullLabels[now.weekday] ?? '';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return 'Current time: $timeStr on $dayName, '
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}. '
        "Today's progress: $todayCompletedCount/$todayActivityCount activities completed.";
  }
}
