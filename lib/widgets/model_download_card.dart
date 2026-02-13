import 'package:flutter/material.dart';
import '../providers/ai_chat_provider.dart';
import '../utils/constants.dart';

class ModelDownloadCard extends StatelessWidget {
  final ModelDownloadState downloadState;
  final double downloadProgress;
  final String? downloadError;
  final String currentFile;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;

  const ModelDownloadCard({
    super.key,
    required this.downloadState,
    required this.downloadProgress,
    this.downloadError,
    this.currentFile = '',
    required this.onDownload,
    required this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.borderRadiusXl,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.md,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadii.borderRadiusFull,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Title
                Text(
                  'AI Coach',
                  style: AppTypography.headingMedium,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Description
                Text(
                  'Download the AI model to get personalized insights about your habits and life balance. All processing happens on your device.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),

                // Model info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppRadii.borderRadiusMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storage_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phi-3.5 Mini (INT4)',
                              style: AppTypography.labelLarge,
                            ),
                            Text(
                              '~2.3 GB download · Runs offline',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Action based on state
                _buildAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction() {
    switch (downloadState) {
      case ModelDownloadState.notStarted:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Download Model'),
          ),
        );

      case ModelDownloadState.downloading:
        return Column(
          children: [
            ClipRRect(
              borderRadius: AppRadii.borderRadiusFull,
              child: LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    currentFile.isNotEmpty
                        ? 'Downloading $currentFile...'
                        : 'Downloading...',
                    style: AppTypography.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(downloadProgress * 100).round()}%',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        );

      case ModelDownloadState.downloaded:
        return const SizedBox.shrink(); // Shouldn't show card when downloaded

      case ModelDownloadState.failed:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: AppRadii.borderRadiusMd,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      downloadError ?? 'Download failed',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry ?? onDownload,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Try Again'),
              ),
            ),
          ],
        );
    }
  }
}
