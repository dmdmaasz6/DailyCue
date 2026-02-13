class AiModelConfig {
  final String id;                    // 'phi-3.5' or 'phi-4'
  final String displayName;           // 'PHI-3.5 Mini (INT4)'
  final String directoryName;         // 'phi-3.5-mini-instruct-int4-cpu'
  final String downloadBaseUrl;       // HuggingFace URL
  final List<String> modelFiles;      // Required files list
  final int approxSizeBytes;          // Download size
  final int minimumRamMb;             // 6144 for PHI-3.5, 8192 for PHI-4
  final String description;           // User-facing description

  const AiModelConfig({
    required this.id,
    required this.displayName,
    required this.directoryName,
    required this.downloadBaseUrl,
    required this.modelFiles,
    required this.approxSizeBytes,
    required this.minimumRamMb,
    required this.description,
  });
}
