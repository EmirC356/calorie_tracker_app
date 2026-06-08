# Quick Start Guide - Calorie Tracker App

## 🎯 5-Minute Quick Setup

### Prerequisites Check
✅ Have Flutter 3.9.2+ installed  
✅ Have Android SDK/Emulator ready  
✅ Have Gemini API key (get free at https://ai.google.dev/)  

### Step 1: Project Location
Your app is located at:
```
C:\Users\lorda\OneDrive\Masaüstü\Testing\calorie_tracker_app
```

### Step 2: Install Dependencies (1 min)
```bash
cd "C:\Users\lorda\OneDrive\Masaüstü\Testing\calorie_tracker_app"
flutter pub get
```

### Step 3: Run the App (2 min)
```bash
flutter run
```

### Step 4: Configure API Key (1 min)
1. Wait for app to open
2. Click ⚙️ settings icon (top right)
3. Paste your Gemini API key
4. Click "Save API Key"
5. Done! ✓

## 📱 Using the App

### 🍽️ Log Your First Meal
1. Go to **"Home"** tab → Click **"Log Meal"**
2. Enter: "Chicken Breast 200g with Rice 150g"
3. Click **"Analyze with AI"**
4. Wait for AI analysis
5. Review nutrition info
6. Click **"Save Meal"**
✅ Meal is logged!

### 🏃 Log Your First Exercise
1. Go to **"Fitness"** tab → Click **"Log Exercise"** or FAB button
2. Enter: "Running" | 30 min | 350 kcal
3. Select intensity: "Medium"
4. Click **"Save Exercise"**
✅ Exercise is logged!

### 📊 View Your Dashboard
- Go to **"Home"** tab
- See today's summary:
  - Total Calories
  - Protein Intake
  - Calories Burned
  - Net Calories

### 🧠 Get Meal Advice
1. Go to **"Advisor"** tab
2. Ask: "What are good high-protein meals?"
3. Get AI recommendations

### 📈 View History
1. From Dashboard → Click **"Meal Logs"** or **"Exercise Logs"**
2. Select a date
3. See all entries for that day

## 🔧 Common Tasks

### Change API Key
Settings ⚙️ → Enter new key → Save

### View Old Meals
Meals tab or Dashboard → "Meal Logs" → Pick date

### Reset All Data
Settings → Delete app → Reinstall (data stored locally)

## 📚 Full Documentation

- **README.md** - Full feature list and structure
- **SETUP_GUIDE.md** - Detailed setup instructions
- **troubleshooting** - Common issues and solutions

## 🎮 Top Tips

1. **Meal Analysis Works Best When You:**
   - Be specific: "Grilled chicken" not just "chicken"
   - Include portions: "200g" or "1 cup"
   - Mention preparation: "fried", "grilled", "baked"

2. **Tracking Calories Burned:**
   - Use smartwatch/fitness tracker for accuracy
   - Or use online calculators
   - Standard estimates: Walk = 300-400, Run = 500-800, Gym = 300-600

3. **Pro Tips:**
   - Log meals immediately while eating
   - Check API key is saved before logging meals
   - Review daily logs weekly for progress

## 🚀 Build for Distribution (Optional)

### Create APK for Android Phone
```bash
flutter build apk --release
```
APK location: `build/app/outputs/flutter-apk/app-release.apk`

### Install on Phone
```bash
flutter install
```

## ❓ Quick Troubleshooting

**App won't run?**
```bash
flutter clean
flutter pub get
flutter run
```

**No devices found?**
```bash
flutter devices
flutter run -d emulator-5554
```

**API Key not working?**
- Check key is copied correctly
- Go to https://console.cloud.google.com/
- Verify billing is enabled

**Database issues?**
- Uninstall app
- Clear app data
- Reinstall

## 📞 Support Resources

- Flutter: https://flutter.dev/docs
- Gemini API: https://ai.google.dev/docs
- Android: https://developer.android.com/
- Check file: `flutter logs`

## ✅ Verification Checklist

- [ ] App installed and running
- [ ] API key configured in Settings
- [ ] Can log a meal and see nutrition
- [ ] Can log an exercise
- [ ] Dashboard shows data
- [ ] Can view historical logs

---

## 🎉 You're All Set!

Your Calorie Tracker app is ready to use. Start tracking your nutrition and fitness journey!

For detailed features and advanced setup, check **README.md** and **SETUP_GUIDE.md**

**Questions?** Read SETUP_GUIDE.md for comprehensive help.
