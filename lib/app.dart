import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/activity_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart';
import 'services/storage_service.dart';
import 'utils/constants.dart';

class DailyCueApp extends StatelessWidget {
  final StorageService storageService;
  final NotificationService notificationService;

  const DailyCueApp({
    super.key,
    required this.storageService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    final schedulerService = SchedulerService(notificationService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storage: storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityProvider(
            storage: storageService,
            scheduler: schedulerService,
          )..loadActivities(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
          ),
          cardTheme: CardTheme(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
