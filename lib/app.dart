import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/activity_provider.dart';
import 'providers/ai_chat_provider.dart';
import 'providers/settings_provider.dart';
import 'app_shell.dart';
import 'services/llm_service.dart';
import 'services/model_manager.dart';
import 'services/notification_service.dart';
import 'services/onnx_channel.dart';
import 'services/prompt_builder.dart';
import 'services/scheduler_service.dart';
import 'services/storage_service.dart';
import 'services/tool_executor.dart';
import 'services/widget_service.dart';
import 'utils/constants.dart';

class DailyCueApp extends StatelessWidget {
  final StorageService storageService;
  final NotificationService notificationService;
  final WidgetService widgetService;

  const DailyCueApp({
    super.key,
    required this.storageService,
    required this.notificationService,
    required this.widgetService,
  });

  @override
  Widget build(BuildContext context) {
    final schedulerService = SchedulerService(notificationService);

    final modelManager = ModelManager();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storage: storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityProvider(
            storage: storageService,
            scheduler: schedulerService,
            widgetService: widgetService,
          )..loadActivities(),
        ),
        ChangeNotifierProxyProvider<ActivityProvider, AiChatProvider>(
          create: (context) {
            final activityProvider = context.read<ActivityProvider>();
            final toolExecutor =
                ToolExecutor(activityProvider: activityProvider);
            final llmService = LlmService(
              onnx: OnnxChannel(),
              toolExecutor: toolExecutor,
              promptBuilder: PromptBuilder(),
              modelManager: modelManager,
            );
            return AiChatProvider(
              llmService: llmService,
              modelManager: modelManager,
              storage: storageService,
            );
          },
          update: (context, activityProvider, previous) {
            // AiChatProvider is long-lived; the ToolExecutor inside
            // LlmService holds a reference to ActivityProvider which
            // stays current via Provider's proxy mechanism.
            return previous!;
          },
        ),
      ],
      child: _NotificationActionHandler(
        notificationService: notificationService,
        storageService: storageService,
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          home: const AppShell(),
        ),
      ),
    );
  }

  ThemeData _buildTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textOnSecondary,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: AppColors.secondaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceAlt,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      // AppBar
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.headingMedium,
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: AppIconSizes.md,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderRadiusLg,
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderRadiusXl,
        ),
        titleTextStyle: AppTypography.headingMedium,
        contentTextStyle: AppTypography.bodyMedium,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
        ),
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
        focusElevation: 4,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderRadiusLg,
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.disabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight.withOpacity(0.4);
          }
          return AppColors.surfaceAlt;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return AppColors.border;
        }),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.primary.withOpacity(0.12),
        disabledColor: AppColors.surfaceAlt,
        labelStyle: AppTypography.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderRadiusSm,
        ),
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderRadiusSm,
          ),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderRadiusMd,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // List tiles
      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listItemPadding,
        titleTextStyle: AppTypography.bodyLarge,
        subtitleTextStyle: AppTypography.bodySmall,
        iconColor: AppColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderRadiusMd,
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textOnPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderRadiusMd,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Bottom navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
      ),
    );
  }
}

/// Sits inside the Provider tree so it can route notification actions
/// through [ActivityProvider], keeping the UI in sync.
class _NotificationActionHandler extends StatefulWidget {
  final NotificationService notificationService;
  final StorageService storageService;
  final Widget child;

  const _NotificationActionHandler({
    required this.notificationService,
    required this.storageService,
    required this.child,
  });

  @override
  State<_NotificationActionHandler> createState() =>
      _NotificationActionHandlerState();
}

class _NotificationActionHandlerState
    extends State<_NotificationActionHandler> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to guarantee the Provider tree is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.notificationService.onAction = _handleAction;
    });
  }

  @override
  void dispose() {
    widget.notificationService.onAction = null;
    super.dispose();
  }

  void _handleAction(String actionId, String? payload) {
    if (payload == null) return;
    final parts = payload.split('|');
    if (parts.isEmpty) return;
    final activityId = parts[0];

    final provider = context.read<ActivityProvider>();

    if (actionId == AppConstants.actionComplete) {
      provider.markActivityComplete(activityId);
    } else if (actionId == AppConstants.actionSnooze) {
      final activity = provider.getActivity(activityId);
      if (activity != null) {
        final snoozeMinutes = activity.snoozeDurationMinutes > 0
            ? activity.snoozeDurationMinutes
            : widget.storageService.defaultSnooze;
        provider.snoozeActivity(activityId, snoozeMinutes);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
