# DailyCue

A Flutter mobile app for managing a fixed, repeatable daily routine with reminders and alarms. Unlike a calendar app, DailyCue is built for the same activities happening every day (or on selected weekdays).

## Features

- **Static daily schedule** — set your routine once, get nudged every day
- **Activity management** — create, edit, delete, reorder, and enable/disable activities
- **Configurable time** — set exact time-of-day for each activity
- **Repeat rules** — daily or specific weekdays (Mon–Sun)
- **Early reminders** — get notified 1–30 minutes before an activity (multiple offsets supported)
- **Due-time alarms** — high-priority alarm with full-screen intent when it's time
- **Snooze & dismiss** — configurable snooze intervals (1–15 min)
- **Offline-first** — all data stored locally with Hive
- **Timezone-aware** — scheduling respects local timezone

## Tech Stack

- **Flutter** (Dart)
- **Hive** — local key-value storage
- **Provider** — state management
- **flutter_local_notifications** — notification scheduling and alarm channels
- **timezone / flutter_timezone** — timezone-aware scheduling

## Project Structure

```
lib/
├── main.dart                  # Entry point, service initialization
├── app.dart                   # MaterialApp with providers
├── models/
│   └── activity.dart          # Activity data model with JSON serialization
├── services/
│   ├── storage_service.dart   # Hive-based persistence
│   ├── notification_service.dart  # Notification/alarm channel setup
│   └── scheduler_service.dart     # Activity → notification scheduling
├── providers/
│   ├── activity_provider.dart # Activity CRUD state management
│   └── settings_provider.dart # App settings state
├── screens/
│   ├── home_screen.dart       # Main activity list (reorderable)
│   ├── activity_editor_screen.dart  # Create/edit activity form
│   └── settings_screen.dart   # App preferences
├── widgets/
│   ├── activity_card.dart     # Activity list item
│   ├── weekday_selector.dart  # Day-of-week picker
│   └── reminder_offset_picker.dart  # Early reminder chip selector
└── utils/
    ├── constants.dart         # App-wide constants and colors
    └── time_utils.dart        # Time formatting and calculation helpers
```

## Getting Started

### Prerequisites

- Flutter SDK (3.1+)
- Android Studio / Xcode configured for Flutter

### Setup

```bash
# Clone the repo
git clone <repo-url>
cd DailyCue

# Generate platform directories (if not present)
flutter create .

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Running Tests

```bash
flutter test
```

## Platform Notes

### Android

- Exact alarms require the `SCHEDULE_EXACT_ALARM` permission on Android 12+. The app guides users to enable this in system settings.
- Two notification channels are created:
  - **Routine Reminders** (high importance) — standard early reminders
  - **Routine Alarms** (max importance) — due-time alarms with full-screen intent

### iOS

- Local notifications with sound and critical alert support (where entitled)
- Best-effort high-priority notifications for alarm behavior

## Data Model

| Field | Type | Description |
|---|---|---|
| id | UUID | Unique identifier |
| title | String | Activity name |
| description | String? | Optional details |
| timeOfDay | HH:mm | When the activity is due |
| repeatDays | List\<int\> | 1=Mon..7=Sun; empty = daily |
| enabled | bool | Active/inactive toggle |
| earlyReminderOffsets | List\<int\> | Minutes before due time |
| alarmEnabled | bool | High-priority alarm at due time |
| snoozeDurationMinutes | int | Snooze interval |
| sortOrder | int | Display order |
