import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../utils/constants.dart';
import '../widgets/activity_card.dart';
import 'activity_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
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
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No activities yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first daily activity',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(BuildContext context, ActivityProvider provider) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: provider.activities.length,
      onReorder: (oldIndex, newIndex) {
        provider.reorderActivities(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final activity = provider.activities[index];
        return Dismissible(
          key: ValueKey(activity.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(context, activity.title),
          onDismissed: (_) => provider.deleteActivity(activity.id),
          child: ActivityCard(
            activity: activity,
            onTap: () => _openEditor(context, activity: activity),
            onToggle: () => provider.toggleActivity(activity.id),
            onDelete: () async {
              final confirmed = await _confirmDelete(context, activity.title);
              if (confirmed == true) {
                provider.deleteActivity(activity.id);
              }
            },
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
