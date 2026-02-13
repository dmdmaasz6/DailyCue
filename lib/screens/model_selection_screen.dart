import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_model_config.dart';
import '../models/device_capabilities.dart';
import '../services/device_info_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  DeviceCapabilities? _capabilities;
  AiModelConfig? _recommendedModel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoService();
    final capabilities = await deviceInfo.getDeviceCapabilities();
    final recommended = capabilities.getRecommendedModel();

    setState(() {
      _capabilities = capabilities;
      _recommendedModel = recommended;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<StorageService>(context);
    final currentModel = storage.selectedModel;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select AI Model')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Select AI Model')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildDeviceInfoCard(),
          const SizedBox(height: AppSpacing.lg),
          Text('Available Models', style: AppTypography.headingMedium),
          const SizedBox(height: AppSpacing.md),

          ...AppConstants.availableModels.map((model) {
            final isRecommended = model.id == _recommendedModel?.id;
            final isSelected = model.id == currentModel.id;
            final isCompatible = _capabilities!.canRunModel(model);

            return _buildModelCard(
              model: model,
              isRecommended: isRecommended,
              isSelected: isSelected,
              isCompatible: isCompatible,
              onSelect: isCompatible ? () => _selectModel(model) : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Device', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow(
            icon: Icons.memory,
            label: 'RAM',
            value: '${(_capabilities!.totalRamMb / 1024).toStringAsFixed(1)} GB',
          ),
          _buildInfoRow(
            icon: Icons.phone_android,
            label: 'Device',
            value: _capabilities!.deviceModel,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text('$label:', style: AppTypography.bodySmall),
          const Spacer(),
          Text(value, style: AppTypography.labelMedium),
        ],
      ),
    );
  }

  Widget _buildModelCard({
    required AiModelConfig model,
    required bool isRecommended,
    required bool isSelected,
    required bool isCompatible,
    required VoidCallback? onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Opacity(
        opacity: isCompatible ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: AppRadii.borderRadiusMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(model.displayName, style: AppTypography.headingSmall),
                  const Spacer(),
                  if (isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: AppRadii.borderRadiusSm,
                      ),
                      child: Text(
                        'RECOMMENDED',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(model.description, style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.storage_outlined,
                       size: 16,
                       color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '~${(model.approxSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(Icons.memory, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Min ${(model.minimumRamMb / 1024).toStringAsFixed(0)} GB RAM',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              if (!isCompatible) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: AppRadii.borderRadiusSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_outlined,
                                 size: 16,
                                 color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Requires ${(model.minimumRamMb / 1024).toStringAsFixed(0)}GB RAM',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isCompatible && !isSelected) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSelect,
                    child: const Text('Select Model'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectModel(AiModelConfig model) async {
    final storage = context.read<StorageService>();
    final currentModel = storage.selectedModel;

    if (model.id == currentModel.id) return;

    // Confirm model switch
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch AI Model'),
        content: Text(
          'Switching to ${model.displayName} will require downloading '
          '~${(model.approxSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Save selection
    await storage.setSelectedModelId(model.id);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected ${model.displayName}. Go to AI Coach to download.',
          ),
        ),
      );
    }
  }
}
