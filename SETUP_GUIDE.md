# Calorie Tracker - Complete Setup Guide

## 📋 Prerequisites

Before you start, make sure you have:

1. **Flutter SDK** - Version 3.9.2 or higher
   - Download from: https://flutter.dev/docs/get-started/install

2. **Android Setup** (for Android development)
   - Android SDK
   - Android Studio (recommended)
   - Minimum API Level: 21 (Android 5.0)

3. **Google Gemini API Key**
   - Free tier available at: https://ai.google.dev/

## 🚀 Step-by-Step Setup

### 1. Verify Flutter Installation

```bash
flutter --version
```

You should see output like:

```
Flutter 3.35.7 • channel stable
Dart 3.9.2
```

### 2. Create/Navigate to Project

```bash
cd "C:\Users\YourUsername\OneDrive\Desktop\Testing"
cd calorie_tracker_app
```

### 3. Install Dependencies

```bash
flutter pub get
```

This will download and install all required packages.

### 4. Get Your Google Gemini API Key

#### Step 4.1: Visit Google AI Studio

- Open: https://ai.google.dev/
- Click on "Get API key" or go to https://makersuite.google.com/app/apikey

#### Step 4.2: Create API Key

- Click "Create API Key"
- Select "Create API key in new project" or use existing project
- The key will be generated and displayed
- Copy the API key (keep it secure!)

#### Step 4.3: (Optional) Verify Key in Cloud Console

- Go to: https://console.cloud.google.com/
- Select the project
- Check billing is enabled
- View API usage and quotas

### 5. Run the App

#### Option A: Using Android Emulator

```bash
# Start emulator first via Android Studio, then:
flutter run
```

#### Option B: Using Physical Android Device

1. Enable Developer Mode on device
2. Enable USB Debugging
3. Connect device via USB
4. Run:

```bash
flutter run
```

#### Option C: List Available Devices

```bash
flutter devices
```

### 6. Set API Key in App

1. **App starts on home screen** (Dashboard)
2. **Tap the settings icon** (gear) in top-right corner
3. **On Settings screen:**
   - Scroll to "API Configuration" section
   - Paste your Gemini API key in the text field
   - Click "Save API Key"
   - You should see: "✓ API Key is configured"

## 📱 Features Tour

### Dashboard (Home Tab)

- Real-time calorie and nutrition summary
- Quick action buttons to log meals/exercises
- Access to meal and exercise history

### Meals Tab

- View today's logged meals
- Add new meal with AI analysis
- See nutritional breakdown

### Fitness Tab

- View today's logged exercises
- Log new exercise with calories burned
- Track intensity levels

### Advisor Tab

- Ask nutrition questions
- Get meal prep advice
- AI-powered recommendations

## 🔧 Common Issues & Solutions

### Issue: "Flutter command not found"

**Solution:** Add Flutter to PATH

- Windows: Edit Environment Variables
  - Add Flutter bin folder to PATH
  - Restart terminal

### Issue: "No connected devices"

**Solution:**

1. Ensure device/emulator is connected
2. Run: `flutter devices`
3. Try: `flutter run -d emulator-5554`

### Issue: "Build fails"

**Solution:**

```bash
flutter clean
flutter pub get
flutter pub upgrade
flutter run
```

### Issue: "API Key not working"

1. Verify key is correctly copied (no spaces)
2. Check API is enabled in Cloud Console
3. Verify billing is enabled
4. Try generating a new key

### Issue: Symlink/Developer Mode error

**Solution (Windows):**

1. Press `Win + R`
2. Type: `ms-settings:developers`
3. Enable "Developer Mode"
4. Restart if prompted

## 🛠️ Development Commands

```bash
# Clean build
flutter clean

# Get/Update dependencies
flutter pub get
flutter pub upgrade

# Run app with debug info
flutter run --verbose

# Build release APK
flutter build apk --release

# Run tests
flutter test

# Format code
dart format .

# Analyze code
dart analyze
```

## 📦 Building for Distribution

### Create Release APK

```bash
flutter build apk --release
```

Located at: `build/app/outputs/flutter-apk/app-release.apk`

### Create Release Bundle (for Google Play)

```bash
flutter build appbundle --release
```

Located at: `build/app/outputs/bundle/release/app-release.aab`

## 🗄️ Database Information

**Local SQLite Database:** `calorie_tracker.db`

- Stored in device's app data directory
- Automatically created on first run
- Contains tables for meals and exercises

**To Reset Database:**

1. Uninstall app
2. Reinstall app
3. Or clear app data in device settings

## 📊 API Quotas

Google Gemini API Free Tier:

- 60 requests per minute
- 1500 requests per day
- Check usage: https://console.cloud.google.com/

Monitor your usage to avoid hitting limits!

## 🔒 Security Notes

1. **API Key Security:**
   - Never commit API key to version control
   - Don't share your API key
   - Regenerate if accidentally exposed
   - Use environment variables in production

2. **Data Privacy:**
   - All data stored locally on device
   - Only meal analysis data sent to Google
   - No personal data collected

## 🎯 Usage Tips

1. **For Meal Analysis:**
   - Be specific about meals (e.g., "Grilled chicken breast with brown rice")
   - Include preparation method if possible
   - Weight estimates are fine if exact weight unavailable

2. **For Exercise Tracking:**
   - Use standard calorie calculators for burned calories
   - Or use fitness trackers/smartwatches for accuracy
   - Update intensity level for accurate calculations

3. **For Meal Advice:**
   - Ask specific questions
   - Examples:
     - "How to meal prep for the week?"
     - "What are high-protein low-calorie snacks?"
     - "Best carbs for post-workout?"

## 📞 Getting Help

1. **Flutter Issues:** https://flutter.dev/docs
2. **Gemini API Issues:** https://ai.google.dev/docs
3. **Android Issues:** https://developer.android.com/
4. **Check logs:** `flutter logs`

## ✅ Verification Checklist

Before deploying:

- [ ] Flutter version 3.9.2+
- [ ] Android SDK installed
- [ ] Gemini API key obtained
- [ ] App runs without errors
- [ ] Settings page shows "API Key is configured"
- [ ] Can analyze a test meal
- [ ] Can log an exercise
- [ ] Can view logs
- [ ] Can get meal advice

## 🎉 Ready to Go!

Your Calorie Tracker app is now set up and ready to use. Start tracking your meals and fitness journey!

### Quick Start:

1. Open app → Settings → Enter API key
2. Dashboard → "Log Meal" → Analyze with AI
3. "Log Exercise" → Save exercise
4. View your daily summary and historical logs

Happy tracking! 💪
