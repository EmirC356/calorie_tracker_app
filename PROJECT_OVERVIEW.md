# Calorie Tracker - Project Overview

## 📱 App Summary

**Calorie Tracker** is a comprehensive Flutter mobile application designed for personal health and fitness tracking. The app leverages Google's Gemini AI to provide accurate nutritional analysis of meals while maintaining a complete history of both meals and exercises.

## 🎯 Key Features

### 1. AI-Powered Meal Analysis
- **Smart Nutrition Calculation**: Uses Gemini AI to analyze meals and provide accurate nutritional information
- **Multiple Nutrients**: Tracks calories, protein, carbohydrates, fat, fiber, sugar, and minerals
- **Flexible Input**: Users can describe meals verbally (e.g., "Grilled chicken with rice and vegetables")
- **Weight/Portion Tracking**: Log approximate weights when exact measurements aren't available

### 2. Daily Calorie & Nutrient Tracking
- **Real-time Dashboard**: Shows today's calorie intake, protein, and net calories
- **Daily Summary**: Aggregated nutrition data for quick overview
- **Net Calorie Calculation**: Automatically calculates consumed calories minus burned calories

### 3. Fitness Exercise Logging
- **Exercise Database**: Log any type of exercise
- **Calorie Burn Tracking**: Record calories burned during workouts
- **Intensity Levels**: Mark workouts as low, medium, or high intensity
- **Duration Tracking**: Log workout duration in minutes

### 4. Historical Data Tracking
- **Meal History**: View all logged meals with date filtering
- **Exercise History**: Track past workouts with historical comparison
- **Daily Reports**: See aggregated daily summaries for nutrition and fitness
- **Date Selection**: Easy date picker to view any past date

### 5. AI Meal Advisor
- **Nutrition Questions**: Ask the AI about nutrition and diet
- **Meal Prep Advice**: Get recommendations for meal preparation
- **Custom Queries**: Ask specific nutrition questions
- **Evidence-Based Responses**: AI provides science-based nutritional advice

### 6. Local Data Storage
- **SQLite Database**: All data stored locally on device
- **Privacy-First**: No cloud storage by default (optional future feature)
- **Persistent Storage**: Data survives app closure
- **Fast Access**: Local database provides instant data retrieval

## 🏗️ Technical Architecture

### Frontend Stack
- **Flutter 3.35.7**: Cross-platform mobile framework
- **Dart 3.9.2**: Programming language
- **Provider**: State management
- **Material Design 3**: UI framework

### Backend Services
- **SQLite**: Local database
- **Google Gemini API**: AI-powered meal analysis and advice
- **RESTful Integration**: Async communication with AI service

### Database Schema

**Meals Table**
```
- id (INT, PRIMARY KEY)
- name (TEXT)
- weight (REAL)
- nutrients (JSON)
- timestamp (TEXT)
- notes (TEXT)
```

**Exercises Table**
```
- id (INT, PRIMARY KEY)
- name (TEXT)
- durationMinutes (INT)
- caloriesBurned (REAL)
- timestamp (TEXT)
- notes (TEXT)
- intensity (TEXT)
```

## 🎨 UI/UX Structure

### Navigation
- **Bottom Navigation Bar**: 4 main tabs
  1. Home (Dashboard)
  2. Meals (Today's meals)
  3. Fitness (Today's exercises)
  4. Advisor (AI meal advisor)

### Key Screens

**Dashboard (Home)**
- Daily summary cards
- Quick action buttons
- Navigation to logs and trackers
- Settings access

**Meal Tracker**
- List of today's meals
- Add meal button
- Nutritional breakdown

**Fitness Tracker**
- List of today's exercises
- Add exercise button
- Duration and calories display

**Meal Analysis**
- Meal name input
- Weight/portion input
- AI analysis button
- Nutritional breakdown display
- Save meal button

**Exercise Logging**
- Exercise name input
- Duration input
- Calories burned input
- Intensity dropdown
- Notes field
- Save button

**Meal Logs**
- Date picker
- Historical meals for selected date
- Delete buttons
- Daily summary statistics

**Exercise Logs**
- Date picker
- Historical exercises for selected date
- Delete buttons
- Daily summary statistics

**Meal Advisor**
- Question input field
- AI response display
- Get advice button

**Settings**
- API key configuration
- API status indicator
- About section

## 📊 Data Flow

```
User Input (Meal) 
    ↓
[MealAnalysisScreen]
    ↓
[AIService] ← API Call → [Gemini API]
    ↓
[Nutrient Data]
    ↓
[MealProvider] (State Management)
    ↓
[DatabaseService] 
    ↓
[SQLite Database]
```

## 🔄 State Management

**Provider Pattern Implementation**

```
MealProvider
├── List<Meal> meals
├── List<Meal> todaysMeals
├── todaysTotalCalories
├── todaysTotalProtein
├── todaysTotalCarbs
├── todaysTotalFat
└── Methods: addMeal(), deleteMeal(), getMealsByDate()

ExerciseProvider
├── List<Exercise> exercises
├── List<Exercise> todaysExercises
├── todaysTotalCaloriesBurned
├── todaysTotalDuration
└── Methods: addExercise(), deleteExercise(), getExercisesByDate()
```

## 🔐 Security & Privacy

- **Local Storage Only**: All user data stored on device
- **API Key Secure**: Stored in app memory only (not persisted)
- **No Cloud Sync**: Optional future enhancement
- **No Personal Data**: App doesn't collect user information
- **API-Only Communication**: Only meal analysis requests sent externally

## 📦 Dependencies

```
Dependencies:
├── google_generative_ai (0.4.0) - Gemini API
├── sqflite (2.3.3) - SQLite database
├── path (1.9.0) - File paths
├── path_provider (2.1.1) - App directories
├── provider (6.1.0) - State management
├── intl (0.20.0) - Internationalization
└── fl_chart (0.67.0) - Charts (future use)

Dev Dependencies:
├── flutter_test - Testing framework
└── flutter_lints - Linting
```

## 🚀 Performance Considerations

- **Lazy Loading**: Lists only load visible items
- **Async Operations**: AI calls don't block UI
- **Local Caching**: Database queries are instant
- **Efficient Queries**: Date-based filtering for quick retrieval
- **Memory Optimization**: Proper disposal of resources

## 📈 Scalability & Future Features

**Phase 2 Enhancements**
- [ ] Nutrition charts and visualizations
- [ ] Weekly/monthly reports
- [ ] Custom nutrition goals
- [ ] Recipe suggestions
- [ ] Barcode scanning
- [ ] Social features
- [ ] Cloud backup

**Phase 3 Features**
- [ ] Wearable integration (Google Fit, Apple Health)
- [ ] Water intake tracking
- [ ] Sleep tracking
- [ ] Weight tracking
- [ ] Progress photos
- [ ] Community features

## 🧪 Testing

### Manual Testing Checklist
- [ ] App launches without errors
- [ ] API key configuration works
- [ ] Meal analysis returns correct nutrients
- [ ] Meals save to database
- [ ] Exercises save to database
- [ ] Daily logs display correctly
- [ ] Date filtering works
- [ ] Delete operations work
- [ ] Advisor provides responses
- [ ] Navigation between tabs works

### Unit Tests (Future)
- Database CRUD operations
- Nutrient calculations
- Date filtering logic
- Provider state management

## 📱 Platform Compatibility

**Supported Platforms**
- Android 6.0+ (API 21+)
- Tablet and phone layouts
- Landscape and portrait modes
- All screen sizes supported

**Device Specifications**
- Minimum RAM: 2GB
- Minimum Storage: 50MB
- Network: Required only for API calls

## 🎓 Architecture Pattern

**Clean Architecture Implementation**
```
Presentation Layer (Screens)
    ↓
Business Logic Layer (Providers)
    ↓
Data Layer (Services)
    ├── AIService (External API)
    └── DatabaseService (Local Storage)
```

## 📊 Database Relationships

**Meal-Nutrient Relationship**
- Each Meal contains one NutrientInfo object
- NutrientInfo is serialized as JSON and stored in Meal

**Daily Aggregation**
- DailySummary calculated from:
  - All Meals from a specific date
  - All Exercises from a specific date

## 🔄 API Integration

**Gemini API Integration**
- **Endpoint**: google_generative_ai package
- **Model**: gemini-1.5-flash
- **Features**:
  - Meal analysis
  - Nutrition advice
- **Rate Limits**: 60 req/min, 1500 req/day (free tier)

## 💾 Data Persistence Strategy

1. **On App Start**: Load today's meals and exercises
2. **On Add**: Insert to database → Refresh provider
3. **On Delete**: Remove from database → Refresh provider
4. **On Query**: Fetch from database based on date range
5. **On Close**: Database connection properly closed

## 🎯 Success Metrics

- ✅ Accurate nutritional analysis (±10% error tolerance)
- ✅ Fast meal analysis (<5 seconds)
- ✅ All data persists correctly
- ✅ Smooth UI with no lag
- ✅ API integration reliable
- ✅ Empty gracefully when no data

---

**Version**: 1.0.0  
**Last Updated**: May 2026  
**Flutter Version**: 3.35.7  
**Dart Version**: 3.9.2
