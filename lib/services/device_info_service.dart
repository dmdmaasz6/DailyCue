import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/device_capabilities.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const MethodChannel _channel =
      MethodChannel('com.dailycue/device_info');

  Future<DeviceCapabilities> getDeviceCapabilities() async {
    if (Platform.isAndroid) {
      return _getAndroidCapabilities();
    } else if (Platform.isIOS) {
      return _getIosCapabilities();
    }
    // Fallback for unsupported platforms
    return const DeviceCapabilities(
      totalRamMb: 8192, // Conservative default
      availableStorageMb: 10000,
      osVersion: 'Unknown',
      deviceModel: 'Unknown',
    );
  }

  Future<DeviceCapabilities> _getAndroidCapabilities() async {
    final info = await _deviceInfo.androidInfo;

    // Get actual RAM from native Android
    int totalRamMb = 8192; // Default
    try {
      final ramBytes = await _channel.invokeMethod<int>('getTotalRam');
      if (ramBytes != null) {
        totalRamMb = (ramBytes / (1024 * 1024)).round();
      }
    } catch (e) {
      // Fall back to default
    }

    return DeviceCapabilities(
      totalRamMb: totalRamMb,
      availableStorageMb: 10000, // Simplified for now
      osVersion: info.version.release,
      deviceModel: '${info.manufacturer} ${info.model}',
    );
  }

  Future<DeviceCapabilities> _getIosCapabilities() async {
    final info = await _deviceInfo.iosInfo;

    // iOS doesn't expose RAM easily, use model-based heuristics
    final totalRamMb = _estimateIosRamFromModel(info.model);

    return DeviceCapabilities(
      totalRamMb: totalRamMb,
      availableStorageMb: 10000, // Simplified
      osVersion: info.systemVersion,
      deviceModel: info.model,
    );
  }

  int _estimateIosRamFromModel(String model) {
    // Heuristic mapping for common iOS devices
    final ramMap = {
      'iPhone SE': 3072,
      'iPhone 11': 4096,
      'iPhone 12': 4096,
      'iPhone 13': 6144,
      'iPhone 14': 6144,
      'iPhone 15': 8192,
      'iPad Pro': 8192,
      'iPad Air': 8192,
    };

    // Try to match model string
    for (final entry in ramMap.entries) {
      if (model.contains(entry.key)) {
        return entry.value;
      }
    }

    return 6144; // Conservative default (6GB)
  }
}
