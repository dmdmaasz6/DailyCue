import '../utils/constants.dart';
import 'ai_model_config.dart';

class DeviceCapabilities {
  final int totalRamMb;
  final int availableStorageMb;
  final String osVersion;
  final String deviceModel;

  const DeviceCapabilities({
    required this.totalRamMb,
    required this.availableStorageMb,
    required this.osVersion,
    required this.deviceModel,
  });

  List<AiModelConfig> getCompatibleModels() {
    return AppConstants.availableModels
        .where((model) => totalRamMb >= model.minimumRamMb)
        .toList();
  }

  AiModelConfig getRecommendedModel() {
    final compatible = getCompatibleModels();
    if (compatible.isEmpty) return AppConstants.phi35Model;

    // Recommend the most capable model that fits
    compatible.sort((a, b) => b.minimumRamMb.compareTo(a.minimumRamMb));
    return compatible.first;
  }

  bool canRunModel(AiModelConfig model) {
    final requiredStorageMb = model.approxSizeBytes / 1024 / 1024;
    return totalRamMb >= model.minimumRamMb &&
           availableStorageMb >= requiredStorageMb;
  }
}
