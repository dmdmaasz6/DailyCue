import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/llm_tool.dart';
import '../providers/activity_provider.dart';
import '../utils/constants.dart';
import '../utils/statistics_calculator.dart';

class ToolExecutor {
  final ActivityProvider _activityProvider;

  ToolExecutor({required ActivityProvider activityProvider})
      : _activityProvider = activityProvider;

  List<LlmTool> get tools => [
        _getTodaySchedule,
        _getAllActivities,
        _getActivity,
        _getStatistics,
        _getBalanceSummary,
        _createActivity,
        _updateActivity,
        _markComplete,
      ];

  /// Execute a tool by name with given arguments.
  /// Returns JSON string result.
  Future<String> execute(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    try {
      switch (toolName) {
        case 'get_today_schedule':
          return _executeTodaySchedule();
        case 'get_all_activities':
          return _executeGetAllActivities();
        case 'get_activity':
          return _executeGetActivity(arguments);
        case 'get_statistics':
          return _executeGetStatistics(arguments);
        case 'get_balance_summary':
          return _executeBalanceSummary();
        case 'create_activity':
          return await _executeCreateActivity(arguments);
        case 'update_activity':
          return await _executeUpdateActivity(arguments);
        case 'mark_complete':
          return await _executeMarkComplete(arguments);
        default:
          return jsonEncode({'error': 'Unknown tool: $toolName'});
      }
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }

  /// Check if a tool requires user confirmation before executing.
  bool requiresConfirmation(String toolName) {
    switch (toolName) {
      case 'create_activity':
      case 'update_activity':
        return true;
      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Tool Definitions
  // ---------------------------------------------------------------------------

  static final LlmTool _getTodaySchedule = LlmTool(
    name: 'get_today_schedule',
    description:
        "Get today's activity schedule with completion status, times, and categories.",
    parameters: {},
  );

  static final LlmTool _getAllActivities = LlmTool(
    name: 'get_all_activities',
    description:
        'Get the full list of all activities with their details, categories, and schedules.',
    parameters: {},
  );

  static final LlmTool _getActivity = LlmTool(
    name: 'get_activity',
    description: 'Get detailed information about a specific activity by ID.',
    parameters: {
      'id': const LlmToolParam(
        type: 'string',
        description: 'The activity ID',
        required: true,
      ),
    },
  );

  static final LlmTool _getStatistics = LlmTool(
    name: 'get_statistics',
    description:
        'Get completion statistics for a time period including rates, trends, and category breakdown.',
    parameters: {
      'period': const LlmToolParam(
        type: 'string',
        description: 'Time period to analyze',
        required: true,
        enumValues: ['week', 'month', 'quarter'],
      ),
    },
  );

  static final LlmTool _getBalanceSummary = LlmTool(
    name: 'get_balance_summary',
    description:
        'Get a life balance summary showing time distribution across categories, gaps, and overloaded areas.',
    parameters: {},
  );

  static final LlmTool _createActivity = LlmTool(
    name: 'create_activity',
    description:
        'Create a new activity. Requires user confirmation before executing.',
    parameters: {
      'title': const LlmToolParam(
        type: 'string',
        description: 'Activity title',
        required: true,
      ),
      'hour': const LlmToolParam(
        type: 'integer',
        description: 'Hour of day (0-23)',
        required: true,
      ),
      'minute': const LlmToolParam(
        type: 'integer',
        description: 'Minute (0-59)',
        required: true,
      ),
      'category': const LlmToolParam(
        type: 'string',
        description: 'Activity category',
        required: false,
        enumValues: [
          'general',
          'health',
          'work',
          'personal',
          'fitness',
          'family',
          'errands',
          'learning'
        ],
      ),
      'description': const LlmToolParam(
        type: 'string',
        description: 'Optional description',
        required: false,
      ),
      'repeatDays': const LlmToolParam(
        type: 'string',
        description:
            'Comma-separated weekday numbers (1=Mon..7=Sun). Empty for daily.',
        required: false,
      ),
    },
    requiresConfirmation: true,
  );

  static final LlmTool _updateActivity = LlmTool(
    name: 'update_activity',
    description:
        'Update an existing activity. Requires user confirmation before executing.',
    parameters: {
      'id': const LlmToolParam(
        type: 'string',
        description: 'The activity ID to update',
        required: true,
      ),
      'title': const LlmToolParam(
        type: 'string',
        description: 'New title',
        required: false,
      ),
      'hour': const LlmToolParam(
        type: 'integer',
        description: 'New hour (0-23)',
        required: false,
      ),
      'minute': const LlmToolParam(
        type: 'integer',
        description: 'New minute (0-59)',
        required: false,
      ),
      'category': const LlmToolParam(
        type: 'string',
        description: 'New category',
        required: false,
        enumValues: [
          'general',
          'health',
          'work',
          'personal',
          'fitness',
          'family',
          'errands',
          'learning'
        ],
      ),
      'description': const LlmToolParam(
        type: 'string',
        description: 'New description',
        required: false,
      ),
      'enabled': const LlmToolParam(
        type: 'boolean',
        description: 'Enable or disable',
        required: false,
      ),
    },
    requiresConfirmation: true,
  );

  static final LlmTool _markComplete = LlmTool(
    name: 'mark_complete',
    description: "Mark an activity as completed for today.",
    parameters: {
      'id': const LlmToolParam(
        type: 'string',
        description: 'The activity ID to mark complete',
        required: true,
      ),
    },
  );

  // ---------------------------------------------------------------------------
  // Tool Implementations
  // ---------------------------------------------------------------------------

  String _executeTodaySchedule() {
    final now = DateTime.now();
    final activities = _activityProvider.activities;
    final todayActivities = activities
        .where((a) => a.enabled && a.isActiveOn(now.weekday))
        .toList()
      ..sort((a, b) {
        final aMin = a.timeOfDay.hour * 60 + a.timeOfDay.minute;
        final bMin = b.timeOfDay.hour * 60 + b.timeOfDay.minute;
        return aMin.compareTo(bMin);
      });

    final schedule = todayActivities.map((a) {
      return {
        'id': a.id,
        'title': a.title,
        'time':
            '${a.timeOfDay.hour.toString().padLeft(2, '0')}:${a.timeOfDay.minute.toString().padLeft(2, '0')}',
        'category': a.category,
        'completed': a.isCompletedToday(),
        if (a.description != null) 'description': a.description,
      };
    }).toList();

    final completed = todayActivities.where((a) => a.isCompletedToday()).length;

    return jsonEncode({
      'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'day': AppConstants.weekdayFullLabels[now.weekday],
      'total': todayActivities.length,
      'completed': completed,
      'remaining': todayActivities.length - completed,
      'activities': schedule,
    });
  }

  String _executeGetAllActivities() {
    final activities = _activityProvider.activities;
    final list = activities.map((a) {
      return {
        'id': a.id,
        'title': a.title,
        'time':
            '${a.timeOfDay.hour.toString().padLeft(2, '0')}:${a.timeOfDay.minute.toString().padLeft(2, '0')}',
        'category': a.category,
        'enabled': a.enabled,
        'schedule': a.isDaily
            ? 'daily'
            : a.repeatDays
                .map((d) => AppConstants.weekdayLabels[d] ?? '$d')
                .join(', '),
        'completedToday': a.isCompletedToday(),
        if (a.description != null) 'description': a.description,
      };
    }).toList();

    return jsonEncode({
      'totalActivities': activities.length,
      'activities': list,
    });
  }

  String _executeGetActivity(Map<String, dynamic> args) {
    final id = args['id'] as String?;
    if (id == null) return jsonEncode({'error': 'id is required'});

    final activity = _activityProvider.getActivity(id);
    if (activity == null) {
      return jsonEncode({'error': 'Activity not found'});
    }

    return jsonEncode({
      'id': activity.id,
      'title': activity.title,
      'description': activity.description,
      'time':
          '${activity.timeOfDay.hour.toString().padLeft(2, '0')}:${activity.timeOfDay.minute.toString().padLeft(2, '0')}',
      'category': activity.category,
      'enabled': activity.enabled,
      'schedule': activity.isDaily
          ? 'daily'
          : activity.repeatDays
              .map((d) => AppConstants.weekdayFullLabels[d] ?? '$d')
              .join(', '),
      'alarmEnabled': activity.alarmEnabled,
      'completedToday': activity.isCompletedToday(),
      'totalCompletions': activity.completionHistory.length,
      'createdAt': activity.createdAt.toIso8601String(),
    });
  }

  String _executeGetStatistics(Map<String, dynamic> args) {
    final periodStr = args['period'] as String? ?? 'week';
    final period = StatsPeriod.values.firstWhere(
      (p) => p.name == periodStr,
      orElse: () => StatsPeriod.week,
    );

    final stats = StatisticsCalculator.calculate(
      activities: _activityProvider.activities,
      period: period,
    );

    final categoryBreakdown = <String, dynamic>{};
    for (final entry in stats.categoryStats.entries) {
      final cs = entry.value;
      categoryBreakdown[entry.key] = {
        'scheduled': cs.scheduled,
        'completed': cs.completed,
        'completionRate': '${(cs.completionRate * 100).round()}%',
      };
    }

    return jsonEncode({
      'period': period.label,
      'totalScheduled': stats.totalScheduled,
      'totalCompleted': stats.totalCompleted,
      'completionRate': '${(stats.completionRate * 100).round()}%',
      'previousPeriodRate':
          '${(stats.previousCompletionRate * 100).round()}%',
      'trend': stats.trendDelta > 0
          ? '+${(stats.trendDelta * 100).round()}%'
          : '${(stats.trendDelta * 100).round()}%',
      'strongestCategory': stats.strongestCategory,
      'weakestCategory': stats.weakestCategory,
      'categoryBreakdown': categoryBreakdown,
    });
  }

  String _executeBalanceSummary() {
    final activities = _activityProvider.activities;
    final enabledActivities = activities.where((a) => a.enabled).toList();

    // Count activities per category
    final categoryCounts = <String, int>{};
    for (final category in ActivityCategories.all) {
      categoryCounts[category] = 0;
    }
    for (final a in enabledActivities) {
      categoryCounts[a.category] = (categoryCounts[a.category] ?? 0) + 1;
    }

    // Identify gaps (categories with 0 activities)
    final gaps = categoryCounts.entries
        .where((e) => e.value == 0)
        .map((e) => ActivityCategories.labels[e.key] ?? e.key)
        .toList();

    // Identify overloaded (categories with > 30% of total)
    final total = enabledActivities.length;
    final overloaded = <String>[];
    if (total > 0) {
      for (final entry in categoryCounts.entries) {
        if (entry.value / total > 0.3 && entry.value > 2) {
          overloaded.add(ActivityCategories.labels[entry.key] ?? entry.key);
        }
      }
    }

    // Get weekly stats for trends
    final weekStats = StatisticsCalculator.calculate(
      activities: activities,
      period: StatsPeriod.week,
    );

    final distribution = <String, dynamic>{};
    for (final entry in categoryCounts.entries) {
      if (entry.value > 0) {
        distribution[ActivityCategories.labels[entry.key] ?? entry.key] = {
          'count': entry.value,
          'percentage':
              total > 0 ? '${(entry.value / total * 100).round()}%' : '0%',
        };
      }
    }

    return jsonEncode({
      'totalActiveActivities': total,
      'distribution': distribution,
      'missingCategories': gaps,
      'overloadedCategories': overloaded,
      'weeklyCompletionRate':
          '${(weekStats.completionRate * 100).round()}%',
      'strongestArea': weekStats.strongestCategory,
      'weakestArea': weekStats.weakestCategory,
      'trendDirection': weekStats.trendDelta > 0.02
          ? 'improving'
          : weekStats.trendDelta < -0.02
              ? 'declining'
              : 'stable',
    });
  }

  Future<String> _executeCreateActivity(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    final hour = args['hour'] as int?;
    final minute = args['minute'] as int?;

    if (title == null || hour == null || minute == null) {
      return jsonEncode({'error': 'title, hour, and minute are required'});
    }

    final repeatDaysStr = args['repeatDays'] as String?;
    List<int> repeatDays = [];
    if (repeatDaysStr != null && repeatDaysStr.isNotEmpty) {
      repeatDays = repeatDaysStr
          .split(',')
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .where((d) => d >= 1 && d <= 7)
          .toList();
    }

    final activity = Activity(
      title: title,
      timeOfDay: TimeOfDay(hour: hour, minute: minute),
      category: args['category'] as String? ?? 'general',
      description: args['description'] as String?,
      repeatDays: repeatDays,
    );

    await _activityProvider.addActivity(activity);

    return jsonEncode({
      'success': true,
      'message': 'Activity "$title" created successfully',
      'id': activity.id,
    });
  }

  Future<String> _executeUpdateActivity(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) return jsonEncode({'error': 'id is required'});

    final activity = _activityProvider.getActivity(id);
    if (activity == null) {
      return jsonEncode({'error': 'Activity not found'});
    }

    TimeOfDay? newTime;
    if (args.containsKey('hour') || args.containsKey('minute')) {
      newTime = TimeOfDay(
        hour: args['hour'] as int? ?? activity.timeOfDay.hour,
        minute: args['minute'] as int? ?? activity.timeOfDay.minute,
      );
    }

    final updated = activity.copyWith(
      title: args['title'] as String?,
      timeOfDay: newTime,
      category: args['category'] as String?,
      description: args['description'] as String?,
      enabled: args['enabled'] as bool?,
    );

    await _activityProvider.updateActivity(updated);

    return jsonEncode({
      'success': true,
      'message': 'Activity "${updated.title}" updated successfully',
    });
  }

  Future<String> _executeMarkComplete(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) return jsonEncode({'error': 'id is required'});

    final activity = _activityProvider.getActivity(id);
    if (activity == null) {
      return jsonEncode({'error': 'Activity not found'});
    }

    if (activity.isCompletedToday()) {
      return jsonEncode({
        'success': true,
        'message': '"${activity.title}" was already completed today',
      });
    }

    await _activityProvider.markActivityComplete(id);

    return jsonEncode({
      'success': true,
      'message': '"${activity.title}" marked as completed',
    });
  }
}
