# Calorie Tracker Personal App

A comprehensive Flutter application for tracking daily meals, nutrition intake, and fitness activities with AI-powered meal analysis using Google Gemini API.

## Features

### 1. **Meal Tracker with AI Analysis**

- Analyze meals using Google Gemini AI
- Get accurate nutritional information (calories, protein, carbs, fat, fiber, sugar)
- Log meals with weight/portion size
- Add notes to meals
- View daily meal summary

### 2. **Fitness Tracker**

- Log exercises with duration and calories burned
- Track intensity levels (low, medium, high)
- View daily exercise summary
- See total calories burned per day

### 3. **Daily Logs**

- View historical meal logs with date filtering
- View historical exercise logs with date filtering
- Daily nutrition summary
- Net calories calculation (consumed - burned)

### 4. **Meal Advisor**

- Ask AI for meal prep advice
- Get nutrition-based recommendations
- Query the AI for specific dietary questions

### 5. **Dashboard**

- Real-time daily summary showing:
  - Total calories consumed
  - Total protein intake
  - Calories burned through exercise
  - Net calories (consumed - burned)
- Quick action buttons for logging meals/exercises
- Links to view historical logs

### 6. **Goals & Calendar**

Plan goals on a calendar and track your streaks. The bottom nav is three tabs —
**Squads · Health · Calendar** — and the Calendar tab is the Goals surface.

- **Goals**: manual (check off by hand) or **tracked** (auto-evaluated against
  your meals/exercises/weight — e.g. "≤ 2200 kcal/day", "gym 3×/week", "120 g
  protein/day"). Pick a category, color, priority, schedule (start date, time),
  recurrence (none / daily / weekly by weekday or N-times / monthly), an
  optional series end, a reminder, and whether to include it in the morning
  brief.
- **Views**: Month / Week / Day, with each day's logged activity (meals,
  exercises, weight) shown alongside the day's goals. Mark occurrences done /
  failed / skipped; recurring goals can be edited or deleted for "only this /
  this and future / all".
- **History**: a filterable list of past occurrences plus a per-category
  success-rate card, with retroactive override of any past day.
- **Squad goals** (optional, cloud): flip a goal **squad-visible** and squadmates
  see it on your card — today's goals + a weekly hit-rate / streak card. **Suggest
  a goal** to a squadmate; they get it in their **Goal inbox** to accept (and
  tweak), reject, or dismiss. Cloud Functions send the suggestion/accept pushes,
  an 8:00 morning brief, and goal reminders (toggle in Health → Settings).

> _Screenshots: TODO — add Calendar month/day, the goal form, the goal inbox,
> and a squadmate's goal stats card._

## Setup Instructions

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android SDK / Android Studio
- Google Gemini API Key

### Step 1: Install Dependencies

```bash
cd calorie_tracker_app
flutter pub get
```

### Step 2: Configure Gemini API Key

1. Get your API key from: https://makersuite.google.com/app/apikey
2. Open the app
3. Go to Settings (gear icon in dashboard)
4. Paste your API key in the "Enter API Key" field
5. Click "Save API Key"

**Note**: The API key is required for meal analysis to work. Without it, you can still log exercises but meal analysis will not function.

### Step 3: Run the App

#### On Android Device/Emulator:

```bash
flutter run
```

#### Run with specific device:

```bash
flutter run -d <device_id>
```

#### Build APK for distribution:

```bash
flutter build apk --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point with Provider setup
├── models/
│   ├── nutrient.dart        # NutrientInfo model
│   ├── meal.dart            # Meal model
│   ├── exercise.dart        # Exercise model
│   ├── daily_summary.dart   # DailySummary model
│   └── index.dart           # Model exports
├── services/
│   ├── database_service.dart # SQLite database management
│   ├── ai_service.dart      # Gemini API integration
├── providers/
│   ├── meal_provider.dart   # Meal state management
│   ├── exercise_provider.dart # Exercise state management
├── screens/
│   ├── home_screen.dart     # Main navigation screen
│   ├── meal_analysis_screen.dart # Meal analysis with AI
│   ├── exercise_logging_screen.dart # Exercise logging
│   ├── meal_logs_screen.dart # View meal history
│   ├── exercise_logs_screen.dart # View exercise history
│   ├── meal_advice_screen.dart # AI meal advisor
│   ├── settings_screen.dart # API key configuration
│   └── index.dart           # Screen exports
└── widgets/                 # Reusable UI components
```

## Dependencies

- **google_generative_ai**: Google Gemini API integration
- **sqflite**: Local SQLite database
- **provider**: State management
- **intl**: Date/time formatting
- **fl_chart**: Charts and visualizations (future use)
- **path_provider**: File system paths

## How to Use

### Logging a Meal

1. Tap the **"Log Meal"** button on the dashboard or bottom navigation
2. Enter meal name (e.g., "Chicken with Rice")
3. Enter weight in grams
4. Add optional notes
5. Tap **"Analyze with AI"** to get nutritional information
6. Review the results and tap **"Save Meal"**

### Logging an Exercise

1. Tap the **"Log Exercise"** button on the dashboard or bottom navigation
2. Enter exercise name
3. Enter duration in minutes
4. Enter calories burned (estimate or from fitness tracker)
5. Select intensity level
6. Add optional notes
7. Tap **"Save Exercise"**

### Viewing Meal Logs

1. From dashboard, tap **"Meal Logs"** or navigate to Meals tab and scroll down
2. Select a date to view meals from that day
3. See daily summary with totals for calories, protein, carbs, fat

### Viewing Exercise Logs

1. From dashboard, tap **"Exercise Logs"** or navigate to Fitness tab
2. Select a date to view exercises from that day
3. See daily summary with total duration and calories burned

### Getting Meal Advice

1. Navigate to the **"Advisor"** tab
2. Ask any nutrition or meal prep question
3. Get AI-powered advice based on your query

## Android Compatibility

The app is fully compatible with Android and has been built with Material Design 3. Tested on:

- Android 6.0+ (API 21+)
- All screen sizes

### Building for Android

**Debug APK:**

```bash
flutter build apk --debug
```

**Release APK:**

```bash
flutter build apk --release
```

**Release Bundle (for Google Play):**

```bash
flutter build appbundle --release
```

## Data Storage

- All meal and exercise data is stored locally on the device using SQLite
- No data is sent to external servers (except for Gemini API requests during meal analysis)
- Data persists even after app closure

## API Rate Limits

Google Gemini API has usage limits. Check your API quota at:
https://console.cloud.google.com/

## Troubleshooting

### "API Key not configured" message

- Go to Settings and enter your Gemini API key
- Make sure the key is valid and has appropriate permissions

### Meal analysis not working

- Verify API key is set correctly
- Check internet connection
- Review API usage limits on Google Cloud Console

### Database errors

- Clear app data and restart
- Reinstall the app if issues persist

### Build errors

- Run `flutter clean`
- Run `flutter pub get`
- Ensure all dependencies are correctly installed

## Future Enhancements

- [ ] Graphs and charts for nutrition trends
- [ ] Weekly/monthly reports
- [ ] Custom nutrition goals
- [ ] Barcode scanning for meals
- [ ] Recipe suggestions based on nutrients
- [ ] Social sharing features
- [ ] Cloud backup of data
- [ ] Offline meal database
- [ ] Apple Health integration
- [ ] Google Fit integration

## License

This is a personal project. Feel free to use and modify as needed.

## Support

For issues or questions, please check:

- Flutter documentation: https://docs.flutter.dev/
- Google Gemini API docs: https://ai.google.dev/
- Android development: https://developer.android.com/

---

**Note**: Remember to keep your Gemini API key secure and never share it publicly!
