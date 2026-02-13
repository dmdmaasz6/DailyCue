import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../utils/constants.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case ChatRole.user:
        return _UserBubble(message: message);
      case ChatRole.assistant:
        return _AssistantBubble(message: message);
      case ChatRole.toolCall:
        return _ToolCallIndicator(message: message);
      case ChatRole.toolResult:
        return const SizedBox.shrink(); // Hidden — results feed into assistant response
      case ChatRole.system:
        return const SizedBox.shrink();
    }
  }
}

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 48,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadii.lg),
              topRight: const Radius.circular(AppRadii.lg),
              bottomLeft: const Radius.circular(AppRadii.lg),
              bottomRight: const Radius.circular(AppRadii.sm),
            ),
          ),
          child: Text(
            message.content,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final ChatMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: 48,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: AppRadii.borderRadiusFull,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadii.sm),
                  topRight: const Radius.circular(AppRadii.lg),
                  bottomLeft: const Radius.circular(AppRadii.lg),
                  bottomRight: const Radius.circular(AppRadii.lg),
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                message.content,
                style: AppTypography.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCallIndicator extends StatelessWidget {
  final ChatMessage message;
  const _ToolCallIndicator({required this.message});

  String get _toolLabel {
    switch (message.toolName) {
      case 'get_today_schedule':
        return 'Checking your schedule...';
      case 'get_all_activities':
        return 'Reading your activities...';
      case 'get_activity':
        return 'Looking up activity details...';
      case 'get_statistics':
        return 'Analyzing your statistics...';
      case 'get_balance_summary':
        return 'Reviewing your life balance...';
      case 'create_activity':
        return 'Creating a new activity...';
      case 'update_activity':
        return 'Updating activity...';
      case 'mark_complete':
        return 'Marking as complete...';
      default:
        return message.content;
    }
  }

  IconData get _toolIcon {
    switch (message.toolName) {
      case 'get_today_schedule':
        return Icons.calendar_today_outlined;
      case 'get_all_activities':
        return Icons.list_alt_outlined;
      case 'get_activity':
        return Icons.info_outline;
      case 'get_statistics':
        return Icons.insights_outlined;
      case 'get_balance_summary':
        return Icons.balance_outlined;
      case 'create_activity':
        return Icons.add_circle_outline;
      case 'update_activity':
        return Icons.edit_outlined;
      case 'mark_complete':
        return Icons.check_circle_outline;
      default:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          const SizedBox(width: 36), // Align with assistant bubble content
          Icon(
            _toolIcon,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _toolLabel,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class ToolConfirmationCard extends StatelessWidget {
  final String toolName;
  final Map<String, dynamic> arguments;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const ToolConfirmationCard({
    super.key,
    required this.toolName,
    required this.arguments,
    required this.onApprove,
    required this.onDecline,
  });

  String get _actionTitle {
    if (toolName == 'create_activity') {
      return 'Create Activity';
    } else if (toolName == 'update_activity') {
      return 'Update Activity';
    }
    return 'Confirm Action';
  }

  IconData get _actionIcon {
    if (toolName == 'create_activity') return Icons.add_circle_outline;
    if (toolName == 'update_activity') return Icons.edit_outlined;
    return Icons.build_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.borderRadiusLg,
          border: Border.all(color: AppColors.secondary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.lg - 1),
                  topRight: Radius.circular(AppRadii.lg - 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(_actionIcon, size: 18, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _actionTitle,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (arguments['title'] != null)
                    _DetailRow(
                      label: 'Title',
                      value: arguments['title'].toString(),
                    ),
                  if (arguments['hour'] != null)
                    _DetailRow(
                      label: 'Time',
                      value:
                          '${arguments['hour'].toString().padLeft(2, '0')}:${(arguments['minute'] ?? 0).toString().padLeft(2, '0')}',
                    ),
                  if (arguments['category'] != null)
                    _DetailRow(
                      label: 'Category',
                      value: ActivityCategories.labels[arguments['category']] ??
                          arguments['category'].toString(),
                    ),
                  if (arguments['description'] != null)
                    _DetailRow(
                      label: 'Description',
                      value: arguments['description'].toString(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onDecline,
                        child: Text(
                          'Decline',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: onApprove,
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.labelMedium,
            ),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}
