# 🗺️ Map Not Showing - Quick Troubleshooting

## ✅ Your API Key is Already Set

I can see you have an API key in `android/local.properties`:

```
MAPS_API_KEY=AIzaSyAJTrzgxdxSqyCu9GLIr5EVJIqb4ZuhIu4
```

## 🔍 Most Common Issues

### 1. Maps SDK Not Enabled

**Check:** Go to [Google Cloud Console](https://console.cloud.google.com/)

- Navigate to **APIs & Services** → **Library**
- Search for **"Maps SDK for Android"**
- Make sure it's **ENABLED** (not just listed)

### 2. Billing Not Enabled

**Check:** Google Maps requires billing to be enabled (even for free tier)

- Go to **Billing** in Google Cloud Console
- Link a billing account
- You get $200 free credit per month, so you likely won't be charged

### 3. API Key Restrictions

**Check:** Your API key might have restrictions that block the app

- Go to **APIs & Services** → **Credentials**
- Click on your API key
- Check **Application restrictions**:
  - If set to "Android apps", make sure your package name and SHA-1 are correct
  - For testing, you can temporarily set to "None"
- Check **API restrictions**:
  - Make sure "Maps SDK for Android" is allowed
  - Or set to "Don't restrict key" for testing

### 4. Wrong Package Name

**Check:** Your API key restrictions must match your app's package name

- Package name: `com.example.green_watch`
- Check in `android/app/build.gradle.kts` → `applicationId`

### 5. Missing SHA-1 Fingerprint

**If your API key has Android restrictions, you need to add SHA-1:**

**Get SHA-1:**

```bash
cd android
./gradlew signingReport
```

**For Windows:**

```powershell
cd android
.\gradlew.bat signingReport
```

Look for the **SHA1** value under "Variant: debug" and add it to your API key restrictions.

### 6. App Not Rebuilt

**After adding/changing API key, you MUST rebuild:**

```bash
flutter clean
flutter pub get
flutter run
```

## 🔍 Check Console Logs

When you run the app, check the **Android logcat** for errors:

**Common error messages:**

- `Google Maps Android API: API key not found` → API key not in local.properties
- `Google Maps Android API: API key not valid` → API key is wrong or expired
- `This API project is not authorized` → Maps SDK not enabled
- `Billing not enabled` → Need to enable billing
- `RefererNotAllowedMapError` → API key restrictions blocking the app

**To see logs:**

```bash
flutter run
# Or check Android Studio's Logcat tab
```

## ✅ Quick Test Steps

1. **Verify API Key Works:**

   - Go to Google Cloud Console → APIs & Services → Credentials
   - Click your API key
   - Temporarily remove all restrictions (set to "None")
   - Save and test the app
   - If it works, add restrictions back one by one

2. **Check API Key in Build:**

   - The API key should be in `android/local.properties`
   - Format: `MAPS_API_KEY=AIzaSy...`
   - No spaces around the `=`

3. **Clean Rebuild:**

   ```bash
   flutter clean
   cd android
   ./gradlew clean
   cd ..
   flutter pub get
   flutter run
   ```

4. **Check AndroidManifest:**
   - File: `android/app/src/main/AndroidManifest.xml`
   - Should have: `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}" />`

## 🆘 Still Not Working?

1. **Check if API key is being read:**

   - Look in build output for any API key errors
   - Check `build/app/intermediates/merged_manifests/` - the API key should not be empty

2. **Test with a simple API call:**

   - Try accessing: `https://maps.googleapis.com/maps/api/geocode/json?address=Penang&key=YOUR_API_KEY`
   - If this fails, your API key is invalid

3. **Verify project in Google Cloud:**

   - Make sure you're using the correct Google Cloud project
   - Check that the API key belongs to the right project

4. **Check internet connection:**
   - Maps need internet to load tiles
   - Try on a different network

## 📱 What You Should See

When the map loads correctly:

- ✅ Map tiles appear (not blank/gray screen)
- ✅ You can zoom and pan
- ✅ Your location appears (if permissions granted)
- ✅ No error messages in console

## 🔧 Quick Fix Checklist

- [ ] Maps SDK for Android is **ENABLED** in Google Cloud Console
- [ ] **Billing is enabled** in Google Cloud Console
- [ ] API key has **no restrictions** OR restrictions match your app
- [ ] **SHA-1 fingerprint** is added to API key restrictions (if using Android restrictions)
- [ ] **Package name** matches in API key restrictions
- [ ] App was **cleaned and rebuilt** after adding API key
- [ ] **Internet connection** is working
- [ ] Checked **console logs** for specific error messages

---

**Most likely fix:** Enable billing and ensure Maps SDK for Android is enabled in Google Cloud Console!

