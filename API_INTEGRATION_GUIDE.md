# Gemini API Integration Guide

## 🔑 Getting Your API Key

### Step 1: Visit Google AI Studio

Go to: **https://makersuite.google.com/app/apikey**

You'll see the Google AI Studio interface with an option to create or view API keys.

### Step 2: Create API Key

1. Click **"Create API key"** button
2. Choose whether to create in a new project or existing project
3. The key will be generated automatically
4. You'll see a dialog with your new API key

### Step 3: Copy the Key

- Click the **copy button** or manually select and copy the API key
- The key looks like: `AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
- **Keep this key secure!** Don't share it or commit it to version control

## ⚙️ Configuring in the App

### Method 1: Via Settings Screen (Easiest)

1. **Open the Calorie Tracker app**
2. **Go to Home tab** → Click **⚙️ Settings** icon (top-right corner)
3. **Look for "API Configuration" section**
4. **Paste your API key** in the text field labeled "Enter API Key"
5. **Click "Save API Key"** button
6. **Verify**: You should see a green checkmark: ✓ "API Key is configured"

### Method 2: Manual Configuration (Alternative)

If the Settings screen isn't working:

1. Edit `lib/main.dart` or app initialization code
2. Add this during app startup:
   ```dart
   aiService.initialize('YOUR_API_KEY_HERE');
   ```

**Note**: This method requires app recompilation, so use Method 1 instead.

## 🔍 Verifying Your API Key Works

### Test Meal Analysis

1. Go to **"Home"** tab → Click **"Log Meal"**
2. Enter test meal: `"100g Chicken Breast"`
3. Click **"Analyze with AI"**
4. Wait 3-5 seconds
5. If you see nutritional info, your API key works! ✓

### If It Doesn't Work

**Error: "API Service not initialized"**
- Solution: Go to Settings and save your API key again

**Error: "Invalid API Key"**
- Check if the key is copied completely without spaces
- Verify the key at: https://makersuite.google.com/app/apikey
- Try generating a new key

**Error: "Rate limit exceeded"**
- You've hit the free tier limit (1500 requests/day)
- Check usage at: https://console.cloud.google.com/
- Wait until tomorrow or upgrade your quota

## 📊 Understanding API Quotas

### Free Tier Limits

| Metric | Limit |
|--------|-------|
| Requests per minute | 60 |
| Requests per day | 1500 |
| Concurrent requests | 1 |

### Checking Your Usage

1. Go to: **https://console.cloud.google.com/**
2. Select your project
3. Go to **"APIs & Services"** → **"Quotas"**
4. Search for "Generative AI"
5. See your current usage

### Example Usage

- 1 meal analysis = 1 request
- 1 advice query = 1 request
- 100 meals per day = 100 requests = Well within quota

## 🛡️ API Key Security

### DO ✅

- Keep your API key private
- Rotate keys regularly
- Use API key restrictions
- Monitor API usage
- Delete unused keys

### DON'T ❌

- Share API key with others
- Commit API key to GitHub
- Post API key in forums/chat
- Use in client-side code for production (this is for personal use only)
- Hardcode the key in the app source

### If Compromised

If your API key is exposed:

1. **Immediately go to**: https://console.cloud.google.com/
2. **Delete the compromised key**
3. **Create a new API key**
4. **Update the app with new key**
5. **Check usage history for abuse**

## 🔧 API Integration Architecture

```
App Start
    ↓
User Goes to Settings
    ↓
Enters API Key
    ↓
Saves Key (triggers aiService.initialize())
    ↓
AIService Initialized
    ↓
User Logs Meal
    ↓
MealAnalysisScreen Calls: aiService.analyzeMeal()
    ↓
GenerativeModel Makes API Request to Google
    ↓
Returns Nutrient Data
    ↓
App Saves to Local Database
```

## 📝 API Request Examples

### Meal Analysis Request

**Input**:
```
Meal: "Grilled Chicken Breast"
Weight: 200g
```

**Prompt to Gemini**:
```
Analyze the nutritional content of the following meal:
Meal: Grilled Chicken Breast
Weight/Portion: 200g

Please provide the nutritional information in JSON format...
```

**Expected Response**:
```json
{
  "calories": 330,
  "protein": 62.4,
  "carbohydrates": 0,
  "fat": 6.8,
  "fiber": 0,
  "sugar": 0,
  "minerals": {
    "sodium": 70,
    "potassium": 420,
    "calcium": 25,
    "iron": 1.3
  }
}
```

### Meal Advice Request

**Input**:
```
"What are good high-protein low-fat meals?"
```

**Response**:
```
The AI returns practical meal suggestions with nutritional info...
```

## 🚨 Common Issues & Solutions

### Issue 1: "No API Key"
```
Error: API Service not initialized. Please set API key.
```
**Solution**:
- Go to Settings ⚙️
- Enter API key
- Click Save

### Issue 2: "Invalid API Key"
```
Error: 400 Invalid API Key
```
**Solution**:
- Copy API key again from https://makersuite.google.com/app/apikey
- Ensure no extra spaces
- Check key starts with "AIzaSy"

### Issue 3: "Rate Limit"
```
Error: 429 Too Many Requests
```
**Solution**:
- Wait a minute or until next day
- Check usage at console.cloud.google.com
- Reduce number of meal analyses

### Issue 4: "Network Error"
```
Error: Failed to connect
```
**Solution**:
- Check internet connection
- Verify Google API server status
- Try meal analysis again

## 📊 Monitoring API Usage

### In Google Cloud Console

1. Navigate to: https://console.cloud.google.com/
2. Select your project
3. View **"Quotas"** for real-time usage
4. View **"APIs"** for enabled services
5. Check **"Billing"** for account status

### In the App

Future enhancement: App will show API usage statistics in Settings

## 💡 Tips for Efficient API Usage

1. **Cache Repeated Meals**
   - Don't re-analyze the same meal
   - Add it to a favorites list

2. **Batch Operations**
   - Analyze multiple meals at once
   - Save time and requests

3. **Clear Descriptions**
   - "Grilled chicken breast 200g" (clear)
   - VS "chicken" (vague)
   - Better descriptions = better analysis

4. **Regular Monitoring**
   - Check quota daily
   - Monitor for unusual activity
   - Keep track of usage patterns

## 🔄 API Response Handling

### Success Response
```dart
final nutrients = await aiService.analyzeMeal(mealName, weight);
// Returns NutrientInfo object with all data populated
```

### Error Response
```dart
catch (e) {
  // Error automatically caught and shown to user
  // Examples: Invalid key, rate limit, network error
}
```

### Response Caching

The app doesn't cache API responses (future enhancement):
- Each analysis makes a new request
- Could implement local cache for common meals

## 🎓 API Documentation

**Official Resources**:
- [Google Generative AI docs](https://ai.google.dev/)
- [Gemini API Reference](https://ai.google.dev/api)
- [Models Guide](https://ai.google.dev/models/)

**Models Available**:
- `gemini-1.5-flash` (Used in this app) - Fast, efficient
- `gemini-1.5-pro` - More powerful
- `gemini-2.0-flash` - Latest and fastest

## ✅ Verification Checklist

- [ ] Got API key from Google AI Studio
- [ ] Copied key correctly (no spaces)
- [ ] Entered key in app Settings
- [ ] See "API Key is configured" message
- [ ] Analyzed a test meal successfully
- [ ] Got nutrition data back
- [ ] No error messages
- [ ] API usage shows in console (optional)

---

## 🆘 Need Help?

**API Issues?**
- Check: https://ai.google.dev/docs
- Status: https://status.cloud.google.com/

**App Issues?**
- See: SETUP_GUIDE.md
- See: PROJECT_OVERVIEW.md

**Security Issues?**
- Regenerate key immediately
- Monitor usage for abuse

---

**Note**: This app uses the free tier of Google's Generative AI. For production apps, implement proper API key management and consider upgrading to a paid plan.
