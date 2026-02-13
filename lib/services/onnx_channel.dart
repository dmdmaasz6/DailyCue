import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class OnnxChannel {
  static const _method = MethodChannel(AppConstants.onnxMethodChannel);
  static const _event = EventChannel(AppConstants.onnxEventChannel);

  Future<bool> loadModel(String modelPath) async {
    try {
      final result = await _method.invokeMethod<bool>(
        'loadModel',
        {'modelPath': modelPath},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<String> generate(
    String prompt, {
    int maxTokens = AppConstants.maxGenerationTokens,
    double temperature = AppConstants.modelTemperature,
    double topP = AppConstants.modelTopP,
    List<String>? stopSequences,
  }) async {
    try {
      final result = await _method.invokeMethod<String>(
        'generate',
        {
          'prompt': prompt,
          'maxTokens': maxTokens,
          'temperature': temperature,
          'topP': topP,
          if (stopSequences != null) 'stopSequences': stopSequences,
        },
      );
      return result ?? '';
    } on PlatformException catch (e) {
      throw Exception('ONNX generation failed: ${e.message}');
    }
  }

  Stream<String> generateStream(
    String prompt, {
    int maxTokens = AppConstants.maxGenerationTokens,
    double temperature = AppConstants.modelTemperature,
    double topP = AppConstants.modelTopP,
    List<String>? stopSequences,
  }) {
    // Set params first, then listen to event stream
    _method.invokeMethod('startGeneration', {
      'prompt': prompt,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
      if (stopSequences != null) 'stopSequences': stopSequences,
    });

    return _event.receiveBroadcastStream().map((event) => event as String);
  }

  Future<void> stopGeneration() async {
    try {
      await _method.invokeMethod('stopGeneration');
    } on PlatformException {
      // Ignore if not generating
    }
  }

  Future<void> unloadModel() async {
    try {
      await _method.invokeMethod('unloadModel');
    } on PlatformException {
      // Ignore if not loaded
    }
  }

  Future<bool> isModelLoaded() async {
    try {
      final result = await _method.invokeMethod<bool>('isModelLoaded');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
