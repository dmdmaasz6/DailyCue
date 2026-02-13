import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/ai_model_config.dart';
import '../utils/constants.dart';

class DownloadProgress {
  final int bytesReceived;
  final int totalBytes;
  final String? currentFile;

  const DownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
    this.currentFile,
  });

  double get fraction => totalBytes > 0 ? bytesReceived / totalBytes : 0;
  int get percentage => (fraction * 100).round();
}

enum ModelStatus { notDownloaded, downloading, downloaded, corrupted }

class ModelManager {
  bool _cancelRequested = false;

  Future<String> _getModelDirectory(AiModelConfig model) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/models/${model.directoryName}';
  }

  Future<ModelStatus> getModelStatus(AiModelConfig model) async {
    final dir = Directory(await _getModelDirectory(model));
    if (!dir.existsSync()) return ModelStatus.notDownloaded;

    // Check if all required files exist
    for (final fileName in model.modelFiles) {
      final file = File('${dir.path}/$fileName');
      if (!file.existsSync()) return ModelStatus.corrupted;
    }

    // Check genai_config.json is valid (basic check)
    final configFile = File('${dir.path}/genai_config.json');
    if (configFile.lengthSync() < 10) return ModelStatus.corrupted;

    return ModelStatus.downloaded;
  }

  // NEW: Detect which model is already downloaded (for migration)
  Future<AiModelConfig?> getDownloadedModel() async {
    for (final model in AppConstants.availableModels) {
      final status = await getModelStatus(model);
      if (status == ModelStatus.downloaded) {
        return model;
      }
    }
    return null;
  }

  Future<bool> isModelDownloaded(AiModelConfig model) async {
    return await getModelStatus(model) == ModelStatus.downloaded;
  }

  Future<String> getModelPath(AiModelConfig model) async {
    return _getModelDirectory(model);
  }

  Future<int> getModelSizeOnDisk(AiModelConfig model) async {
    final dir = Directory(await _getModelDirectory(model));
    if (!dir.existsSync()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  Stream<DownloadProgress> downloadModel(AiModelConfig model) async* {
    _cancelRequested = false;
    final dirPath = await _getModelDirectory(model);
    final dir = Directory(dirPath);

    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    int totalDownloaded = 0;
    final totalEstimate = model.approxSizeBytes;

    for (final fileName in model.modelFiles) {
      if (_cancelRequested) {
        yield DownloadProgress(
          bytesReceived: totalDownloaded,
          totalBytes: totalEstimate,
          currentFile: fileName,
        );
        return;
      }

      final filePath = '$dirPath/$fileName';
      final file = File(filePath);

      // Skip if already downloaded
      if (file.existsSync() && file.lengthSync() > 0) {
        totalDownloaded += file.lengthSync();
        yield DownloadProgress(
          bytesReceived: totalDownloaded,
          totalBytes: totalEstimate,
          currentFile: fileName,
        );
        continue;
      }

      final url = '${model.downloadBaseUrl}/$fileName';

      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await http.Client().send(request);

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to download $fileName: HTTP ${response.statusCode}',
          );
        }

        final sink = file.openWrite();
        int fileDownloaded = 0;

        await for (final chunk in response.stream) {
          if (_cancelRequested) {
            await sink.close();
            file.deleteSync();
            return;
          }
          sink.add(chunk);
          fileDownloaded += chunk.length;
          totalDownloaded += chunk.length;

          yield DownloadProgress(
            bytesReceived: totalDownloaded,
            totalBytes: totalEstimate,
            currentFile: fileName,
          );
        }

        await sink.flush();
        await sink.close();
      } catch (e) {
        // Clean up partial file
        if (file.existsSync()) {
          file.deleteSync();
        }
        rethrow;
      }
    }

    yield DownloadProgress(
      bytesReceived: totalDownloaded,
      totalBytes: totalDownloaded, // Final: set total = received
    );
  }

  void cancelDownload() {
    _cancelRequested = true;
  }

  Future<void> deleteModel(AiModelConfig model) async {
    final dir = Directory(await _getModelDirectory(model));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
