import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../utils/constants.dart';
import '../widgets/activity_card.dart';
import 'activity_editor_screen.dart';
import 'settings_screen.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

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
          return _buildActivityList(context, provider);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
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

  Widget _buildActivityList(BuildContext context, ActivityProvider provider) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: 80,
        left: AppSpacing.md,
        right: AppSpacing.md,
      ),
      itemCount: provider.activities.length,
      onReorder: (oldIndex, newIndex) {
        provider.reorderActivities(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              color: Colors.transparent,
              elevation: 4,
              borderRadius: AppRadii.borderRadiusLg,
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final activity = provider.activities[index];
        return Padding(
          key: ValueKey(activity.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
      },
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

  void _openEditor(BuildContext context, {dynamic activity}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityEditorScreen(activity: activity),
      ),
    );
  }
}
