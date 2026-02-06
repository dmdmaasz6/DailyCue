import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../providers/activity_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import '../widgets/activity_card.dart';
import 'activity_editor_screen.dart';
import 'settings_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Routines'),
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
      body: Consumer<ActivityProvider>(
        builder: (context, provider, _) {
          if (provider.activities.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildBody(context, provider);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ActivityProvider provider) {
    final filtered = _searchQuery.isEmpty
        ? provider.activities
        : provider.activities
            .where((a) =>
                a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (a.description?.toLowerCase().contains(
                        _searchQuery.toLowerCase()) ??
                    false))
            .toList();

    // Group by time period
    final morning = <Activity>[];
    final afternoon = <Activity>[];
    final evening = <Activity>[];

    for (final a in filtered) {
      final hour = a.timeOfDay.hour;
      if (hour < 12) {
        morning.add(a);
      } else if (hour < 17) {
        afternoon.add(a);
      } else {
        evening.add(a);
      }
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search activities...',
              prefixIcon: const Icon(Icons.search_rounded,
                  size: AppIconSizes.md),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: AppIconSizes.sm),
                      onPressed: () =>
                          setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ),

        // Activities count bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Text(
                '${filtered.length} ${filtered.length == 1 ? 'activity' : 'activities'}',
                style: AppTypography.labelMedium,
              ),
              const Spacer(),
              if (morning.isNotEmpty)
                _PeriodBadge(
                    label: 'AM', count: morning.length, icon: Icons.wb_sunny_outlined),
              if (afternoon.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                _PeriodBadge(
                    label: 'PM', count: afternoon.length, icon: Icons.wb_cloudy_outlined),
              ],
              if (evening.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                _PeriodBadge(
                    label: 'Eve', count: evening.length, icon: Icons.nights_stay_outlined),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Grouped activity list
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildFlatList(context, provider, filtered)
              : _buildGroupedList(
                  context, provider, morning, afternoon, evening),
        ),
      ],
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    ActivityProvider provider,
    List<Activity> morning,
    List<Activity> afternoon,
    List<Activity> evening,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (morning.isNotEmpty) ...[
          _SectionHeader(
            title: 'Morning',
            icon: Icons.wb_sunny_outlined,
            count: morning.length,
          ),
          ...morning.map((a) => _buildCardItem(context, provider, a)),
        ],
        if (afternoon.isNotEmpty) ...[
          _SectionHeader(
            title: 'Afternoon',
            icon: Icons.wb_cloudy_outlined,
            count: afternoon.length,
          ),
          ...afternoon.map((a) => _buildCardItem(context, provider, a)),
        ],
        if (evening.isNotEmpty) ...[
          _SectionHeader(
            title: 'Evening',
            icon: Icons.nights_stay_outlined,
            count: evening.length,
          ),
          ...evening.map((a) => _buildCardItem(context, provider, a)),
        ],
      ],
    );
  }

  Widget _buildFlatList(
    BuildContext context,
    ActivityProvider provider,
    List<Activity> filtered,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildCardItem(context, provider, filtered[index]);
      },
    );
  }

  Widget _buildCardItem(
    BuildContext context,
    ActivityProvider provider,
    Activity activity,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Dismissible(
        key: ValueKey('dismiss_${activity.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: AppRadii.borderRadiusLg,
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: AppIconSizes.lg,
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context, activity.title),
        onDismissed: (_) => provider.deleteActivity(activity.id),
        child: ActivityCard(
          activity: activity,
          onTap: () => _openEditor(context, activity: activity),
          onToggle: () => provider.toggleActivity(activity.id),
          onDelete: () async {
            final confirmed =
                await _confirmDelete(context, activity.title);
            if (confirmed == true) {
              provider.deleteActivity(activity.id);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: AppIconSizes.xl,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No activities yet',
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap the + button to build your daily routine',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, {Activity? activity}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityEditorScreen(activity: activity),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSizes.sm, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: AppRadii.borderRadiusFull,
            ),
            child: Text(
              '$count',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period badge
// ---------------------------------------------------------------------------

class _PeriodBadge extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;

  const _PeriodBadge({
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusFull,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$count',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
