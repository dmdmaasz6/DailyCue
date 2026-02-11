import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import 'activity_view_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer2<ActivityProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          final now = DateTime.now();
          final nowMinutes = now.hour * 60 + now.minute;
          final todayWeekday = now.weekday;

          final totalActivities = provider.activities.length;
          final enabledCount =
              provider.activities.where((a) => a.enabled).length;

          final todayActivities = provider.activities
              .where((a) =>
                  a.enabled &&
                  (a.repeatDays.isEmpty ||
                      a.repeatDays.contains(todayWeekday)))
              .toList()
            ..sort((a, b) {
              final aMin = a.timeOfDay.hour * 60 + a.timeOfDay.minute;
              final bMin = b.timeOfDay.hour * 60 + b.timeOfDay.minute;
              return aMin.compareTo(bMin);
            });

          // Count completed activities for today
          final completedCount = todayActivities
              .where((a) => a.isCompletedToday())
              .length;
          final remainingCount = todayActivities.length - completedCount;

          // Find next upcoming activity
          Activity? nextUp;
          for (final a in todayActivities) {
            if (a.timeOfDay.hour * 60 + a.timeOfDay.minute >= nowMinutes) {
              nextUp = a;
              break;
            }
          }

          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // Greeting header
              Text(_greeting(), style: AppTypography.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formattedDate(),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Progress + stats row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress ring
                  _ProgressRing(
                    completed: completedCount,
                    total: todayActivities.length,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Stat cards column
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStatCard(
                                label: 'Completed',
                                value: '$completedCount',
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MiniStatCard(
                                label: 'Remaining',
                                value: '$remainingCount',
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStatCard(
                                label: 'Today',
                                value: '${todayActivities.length}',
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MiniStatCard(
                                label: 'Active',
                                value: '$enabledCount',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // All completed card or Up next card
              if (todayActivities.isNotEmpty && completedCount == todayActivities.length)
                const _AllCompletedCard()
              else if (nextUp != null)
                _UpNextCard(
                  activity: nextUp,
                  nowMinutes: nowMinutes,
                  use24Hour: settings.use24HourFormat,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ActivityViewScreen(activity: nextUp!),
                    ),
                  ),
                ),
              if (todayActivities.isNotEmpty && completedCount == todayActivities.length)
                const SizedBox(height: AppSpacing.lg)
              else if (nextUp != null)
                const SizedBox(height: AppSpacing.lg),

              // Historical Statistics
              _buildHistoricalStats(provider.activities),
              const SizedBox(height: AppSpacing.lg),

              // Today's schedule
              Row(
                children: [
                  const Text("Today's Schedule",
                      style: AppTypography.headingLarge),
                  const Spacer(),
                  Text(
                    '$completedCount of ${todayActivities.length} done',
                    style: AppTypography.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (todayActivities.isEmpty)
                _buildEmptyToday()
              else
                ...todayActivities.asMap().entries.map((entry) {
                  final index = entry.key;
                  final activity = entry.value;
                  final isLast = index == todayActivities.length - 1;
                  return _TodayActivityTile(
                    activity: activity,
                    nowMinutes: nowMinutes,
                    isLast: isLast,
                    use24Hour: settings.use24HourFormat,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ActivityViewScreen(activity: activity),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyToday() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wb_sunny_outlined,
            size: AppIconSizes.xl,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No activities scheduled for today',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalStats(List<Activity> activities) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    // Calculate weekly completions
    int weeklyCompletions = 0;
    // Calculate monthly completions
    int monthlyCompletions = 0;

    for (final activity in activities) {
      weeklyCompletions += activity.getCompletionCount(weekAgo, now);
      monthlyCompletions += activity.getCompletionCount(monthAgo, now);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                size: AppIconSizes.md,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Activity Insights',
                style: AppTypography.headingMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _InsightCard(
                  label: 'This Week',
                  value: weeklyCompletions.toString(),
                  icon: Icons.calendar_view_week_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _InsightCard(
                  label: 'This Month',
                  value: monthlyCompletions.toString(),
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress ring
// ---------------------------------------------------------------------------

class _ProgressRing extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressRing({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;

    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$completed',
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Text(
                'of $total',
                style: AppTypography.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ---------------------------------------------------------------------------
// Mini stat card
// ---------------------------------------------------------------------------

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.headingLarge.copyWith(color: color),
          ),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Insight card
// ---------------------------------------------------------------------------

class _InsightCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppIconSizes.lg),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.headingLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Up next card
// ---------------------------------------------------------------------------

class _UpNextCard extends StatefulWidget {
  final Activity activity;
  final int nowMinutes;
  final bool use24Hour;
  final VoidCallback onTap;

  const _UpNextCard({
    required this.activity,
    required this.nowMinutes,
    required this.use24Hour,
    required this.onTap,
  });

  @override
  State<_UpNextCard> createState() => _UpNextCardState();
}

class _UpNextCardState extends State<_UpNextCard> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // Update every second for real-time countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _currentTime;
    final activityTime = DateTime(
      now.year,
      now.month,
      now.day,
      widget.activity.timeOfDay.hour,
      widget.activity.timeOfDay.minute,
    );
    final diff = activityTime.difference(now);
    final diffMinutes = diff.inMinutes;

    final timeStr = widget.use24Hour
        ? TimeUtils.format24h(widget.activity.timeOfDay)
        : TimeUtils.format12h(widget.activity.timeOfDay);

    String countdownStr;
    if (diffMinutes <= 0 && diff.inSeconds <= 0) {
      countdownStr = 'Now';
    } else if (diffMinutes < 1) {
      final seconds = diff.inSeconds;
      countdownStr = 'In ${seconds}s';
    } else if (diffMinutes < 60) {
      countdownStr = 'In $diffMinutes min';
    } else {
      final h = diffMinutes ~/ 60;
      final m = diffMinutes % 60;
      countdownStr = m > 0 ? 'In ${h}h ${m}m' : 'In ${h}h';
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadii.borderRadiusLg,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: AppRadii.borderRadiusMd,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: AppIconSizes.lg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UP NEXT',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    widget.activity.title,
                    style: AppTypography.headingMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    timeStr,
                    style: AppTypography.monoSmall.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: AppRadii.borderRadiusFull,
              ),
              child: Text(
                countdownStr,
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All completed congratulations card
// ---------------------------------------------------------------------------

class _AllCompletedCard extends StatelessWidget {
  const _AllCompletedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.success, Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'All Done!',
            style: AppTypography.displayMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "You've completed all your activities for today!",
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: AppRadii.borderRadiusFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: AppIconSizes.sm,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Great job!',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's timeline activity tile
// ---------------------------------------------------------------------------

class _TodayActivityTile extends StatelessWidget {
  final Activity activity;
  final int nowMinutes;
  final bool isLast;
  final bool use24Hour;
  final VoidCallback onTap;

  const _TodayActivityTile({
    required this.activity,
    required this.nowMinutes,
    required this.isLast,
    required this.use24Hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activityMinutes =
        activity.timeOfDay.hour * 60 + activity.timeOfDay.minute;
    final isPast = activityMinutes < nowMinutes;
    final isCompleted = activity.isCompletedToday();
    final isMissed = isPast && !isCompleted;
    final isUpcoming = !isPast;
    final timeStr = use24Hour
        ? TimeUtils.format24h(activity.timeOfDay)
        : TimeUtils.format12h(activity.timeOfDay);
    final catColor = ActivityCategories.color(activity.category);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              SizedBox(
                width: 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    timeStr,
                    style: AppTypography.monoSmall.copyWith(
                      color: isCompleted
                          ? AppColors.success
                          : (isMissed ? AppColors.textTertiary : catColor),
                    ),
                  ),
                ),
              ),

              // Timeline dot and line (category color)
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success
                            : (isMissed ? AppColors.disabled : catColor),
                        shape: BoxShape.circle,
                        border: isUpcoming
                            ? Border.all(
                                color: catColor.withOpacity(0.3),
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Activity content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withOpacity(0.04)
                        : (isMissed ? AppColors.surfaceAlt : AppColors.surface),
                    borderRadius: AppRadii.borderRadiusMd,
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.3)
                          : (isMissed
                              ? AppColors.warning.withOpacity(0.3)
                              : catColor.withOpacity(0.25)),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Category accent bar
                      Container(
                        width: 3,
                        height: 32,
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success.withOpacity(0.5)
                              : (isMissed
                                  ? AppColors.disabled
                                  : catColor.withOpacity(0.5)),
                          borderRadius: AppRadii.borderRadiusFull,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: AppTypography.headingSmall.copyWith(
                                color: isMissed
                                    ? AppColors.textTertiary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (activity.description != null &&
                                activity.description!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                activity.description!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isCompleted)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: AppIconSizes.sm,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Done',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      else if (isMissed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: AppIconSizes.xs,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Missed',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      else if (activity.alarmEnabled)
                        const Icon(
                          Icons.alarm_rounded,
                          size: AppIconSizes.xs,
                          color: AppColors.secondary,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
