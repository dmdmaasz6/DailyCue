import 'package:flutter/material.dart';
import '../models/ai_model_config.dart';

// ---------------------------------------------------------------------------
// App‑wide constants (non‑visual)
// ---------------------------------------------------------------------------

class AppConstants {
  AppConstants._();

  static const String appName = 'DailyCue';
  static const String hiveBoxActivities = 'activities';
  static const String hiveBoxSettings = 'settings';

  // Notification channel IDs (Android)
  static const String reminderChannelId = 'dailycue_reminders';
  static const String reminderChannelName = 'Routine Reminders';
  static const String reminderChannelDescription =
      'Standard reminders before activities';

  static const String alarmChannelId = 'dailycue_alarms';
  static const String alarmChannelName = 'Routine Alarms';
  static const String alarmChannelDescription =
      'High-priority alarms when activities are due';

  // Notification action IDs
  static const String actionDismiss = 'dismiss';
  static const String actionSnooze = 'snooze';
  static const String actionComplete = 'complete';

  // Default settings
  static const int defaultSnoozeDuration = 5; // minutes
  static const List<int> availableSnoozeDurations = [1, 3, 5, 10, 15];
  static const List<int> availableReminderOffsets = [1, 2, 3, 5, 10, 15, 20, 30];

  // Weekday labels (Mon=1 .. Sun=7, matching DateTime.weekday)
  static const Map<int, String> weekdayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static const Map<int, String> weekdayFullLabels = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  // AI Coach constants
  static const String hiveBoxAiChat = 'ai_chat_history';

  // Available AI Models
  static const AiModelConfig phi35Model = AiModelConfig(
    id: 'phi-3.5',
    displayName: 'PHI-3.5 Mini',
    directoryName: 'phi-3.5-mini-instruct-int4-cpu',
    downloadBaseUrl: 'https://huggingface.co/microsoft/Phi-3.5-mini-instruct-onnx/resolve/main/cpu_and_mobile/cpu-int4-awq-block-128-acc-level-4',
    modelFiles: [
      'config.json',
      'configuration_phi3.py',
      'genai_config.json',
      'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx',
      'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx.data',
      'special_tokens_map.json',
      'tokenizer.json',
      'tokenizer_config.json',
    ],
    approxSizeBytes: 2780000000, // ~2.78 GB (actual size)
    minimumRamMb: 6144, // 6 GB
    description: 'Faster, smaller model for devices with 6GB+ RAM',
  );

  static const AiModelConfig phi4Model = AiModelConfig(
    id: 'phi-4',
    displayName: 'PHI-4 Mini',
    directoryName: 'phi-4-mini-instruct-int4-cpu',
    downloadBaseUrl: 'https://huggingface.co/microsoft/Phi-4-mini-instruct-onnx/resolve/main/cpu_and_mobile/cpu-int4-rtn-block-32-acc-level-4',
    modelFiles: [
      'added_tokens.json',
      'config.json',
      'configuration_phi3.py',
      'genai_config.json',
      'merges.txt',
      'model.onnx',
      'model.onnx.data',
      'special_tokens_map.json',
      'tokenizer.json',
      'tokenizer_config.json',
      'vocab.json',
    ],
    approxSizeBytes: 4930000000, // ~4.93 GB
    minimumRamMb: 8192, // 8 GB
    description: 'More capable model for devices with 8GB+ RAM',
  );

  static const List<AiModelConfig> availableModels = [phi35Model, phi4Model];

  static AiModelConfig getModelById(String id) {
    return availableModels.firstWhere(
      (m) => m.id == id,
      orElse: () => phi35Model,
    );
  }

  // Model runtime constants
  static const int maxConversationTurns = 20;
  static const int maxGenerationTokens = 512;
  static const double modelTemperature = 0.7;
  static const double modelTopP = 0.9;
  static const String onnxMethodChannel = 'com.dailycue/onnx_inference';
  static const String onnxEventChannel = 'com.dailycue/onnx_inference_stream';
}

// ---------------------------------------------------------------------------
// Activity Categories
// ---------------------------------------------------------------------------

class ActivityCategories {
  ActivityCategories._();

  static const String general = 'general';
  static const String health = 'health';
  static const String work = 'work';
  static const String personal = 'personal';
  static const String fitness = 'fitness';
  static const String family = 'family';
  static const String errands = 'errands';
  static const String learning = 'learning';

  static const List<String> all = [
    general, health, work, personal, fitness, family, errands, learning,
  ];

  static const Map<String, String> labels = {
    general: 'General',
    health: 'Health',
    work: 'Work',
    personal: 'Personal',
    fitness: 'Fitness',
    family: 'Family',
    errands: 'Errands',
    learning: 'Learning',
  };

  static const Map<String, IconData> icons = {
    general: Icons.circle_outlined,
    health: Icons.favorite_outline,
    work: Icons.work_outline,
    personal: Icons.person_outline,
    fitness: Icons.fitness_center_outlined,
    family: Icons.family_restroom_outlined,
    errands: Icons.shopping_bag_outlined,
    learning: Icons.school_outlined,
  };

  static Color color(String category) => _colors[category] ?? _colors[general]!;

  static String label(String category) => labels[category] ?? labels[general]!;

  static IconData icon(String category) => icons[category] ?? icons[general]!;

  static const Map<String, Color> _colors = {
    general: Color(0xFF0D7377),  // teal (primary)
    health: Color(0xFFE5484D),   // red
    work: Color(0xFF3E63DD),     // blue
    personal: Color(0xFF8E4EC6),  // purple
    fitness: Color(0xFFE8836B),   // warm coral
    family: Color(0xFFF76B15),    // orange
    errands: Color(0xFF30A46C),   // green
    learning: Color(0xFFE5A500),  // amber
  };

  static Color lightColor(String category) {
    final c = color(category);
    return c.withOpacity(0.12);
  }
}

// ---------------------------------------------------------------------------
// Design System – Colors
// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Brand palette
  static const Color primary = Color(0xFF0D7377);
  static const Color primaryLight = Color(0xFF4DA8AB);
  static const Color primaryDark = Color(0xFF095153);
  static const Color secondary = Color(0xFFF5A623);
  static const Color secondaryLight = Color(0xFFFFC965);
  static const Color secondaryDark = Color(0xFFC88514);

  // Neutrals
  static const Color background = Color(0xFFFAFBFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFF1E293B);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Component‑specific
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color disabledText = Color(0xFF94A3B8);
  static const Color shimmer = Color(0xFFE2E8F0);
  static const Color cardShadow = Color(0x0A000000);
}

// ---------------------------------------------------------------------------
// Design System – Typography
// ---------------------------------------------------------------------------

class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Roboto';

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  // Headings
  static const TextStyle headingLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.4,
    color: AppColors.textTertiary,
  );

  // Monospaced (for times / numbers)
  static const TextStyle mono = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.primary,
  );

  static const TextStyle monoSmall = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.primary,
  );
}

// ---------------------------------------------------------------------------
// Design System – Spacing
// ---------------------------------------------------------------------------

class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Common paddings
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: 14);
  static const EdgeInsets sectionPadding =
      EdgeInsets.only(left: md, right: md, top: lg, bottom: xs);
  static const EdgeInsets listItemPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: sm);
}

// ---------------------------------------------------------------------------
// Design System – Radii
// ---------------------------------------------------------------------------

class AppRadii {
  AppRadii._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double full = 999;

  static final BorderRadius borderRadiusSm = BorderRadius.circular(sm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(md);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(lg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(xl);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(full);
}

// ---------------------------------------------------------------------------
// Design System – Shadows
// ---------------------------------------------------------------------------

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: AppColors.cardShadow,
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: AppColors.cardShadow,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: AppColors.cardShadow,
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Design System – Durations
// ---------------------------------------------------------------------------

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

// ---------------------------------------------------------------------------
// Design System – Icon Sizes
// ---------------------------------------------------------------------------

class AppIconSizes {
  AppIconSizes._();

  static const double xs = 14;
  static const double sm = 18;
  static const double md = 22;
  static const double lg = 28;
  static const double xl = 40;
  static const double xxl = 64;
}
