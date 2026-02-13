import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  final storageService = StorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  final widgetService = WidgetService();
  await widgetService.init();

  // Notification action handling is done inside the widget tree
  // (see _NotificationActionHandler in app.dart) so it can go through
  // ActivityProvider and keep the UI in sync.

  runApp(DailyCueApp(
    storageService: storageService,
    notificationService: notificationService,
    widgetService: widgetService,
  ));
}
