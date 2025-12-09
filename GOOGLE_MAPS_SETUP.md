# 🗺️ Google Maps Setup Guide

## Why the Map is Not Showing

The map is not showing because **the Google Maps API key is missing or not configured**. The app is looking for the API key but can't find it.

## ✅ Step-by-Step Fix

### Step 1: Get a Google Maps API Key

1. **Go to Google Cloud Console:**

   - Visit: https://console.cloud.google.com/
   - Sign in with your Google account

2. **Create or Select a Project:**

   - If you don't have a project, click "Create Project"
   - Name it (e.g., "Green Watch Maps")
   - Click "Create"
   - Wait for project creation (takes a few seconds)

3. **Enable Maps SDK for Android:**

   - In the left sidebar, go to **"APIs & Services"** → **"Library"**
   - Search for **"Maps SDK for Android"**
   - Click on it and click **"Enable"**

4. **Create API Key:**

   - Go to **"APIs & Services"** → **"Credentials"**
   - Click **"+ CREATE CREDENTIALS"** → **"API Key"**
   - Copy the API key that appears (it will look like: `AIzaSy...`)

5. **Restrict the API Key (Recommended for Security):**
   - Click on the API key you just created
   - Under **"Application restrictions"**, select **"Android apps"**
   - Click **"+ ADD AN ITEM"**
   - Enter:
     - **Package name:** `com.example.green_watch`
     - **SHA-1 certificate fingerprint:** (Get this from the next step)
   - Under **"API restrictions"**, select **"Restrict key"**
   - Choose **"Maps SDK for Android"**
   - Click **"Save"**

### Step 2: Get SHA-1 Certificate Fingerprint

**For Debug Build (Development):**

Run this command in your terminal (in the project root):

```bash
cd android
./gradlew signingReport
```

**For Windows (PowerShell):**

```powershell
cd android
.\gradlew.bat signingReport
```

Look for the output that shows:

```
Variant: debug
Config: debug
Store: C:\Users\...\.android\debug.keystore
Alias: AndroidDebugKey
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

Copy the **SHA1** value (the long string of letters and numbers separated by colons).

**Add this SHA-1 to your API key restrictions** in Google Cloud Console (Step 1, item 5).

### Step 3: Enable Billing (Required!)

⚠️ **Important:** Google Maps requires billing to be enabled, even for free tier usage.

1. In Google Cloud Console, go to **"Billing"**
2. Link a billing account (you can use the free tier - $200 credit per month)
3. Don't worry - you won't be charged unless you exceed the free tier limits

### Step 4: Add API Key to Your Project

1. **Open the file:** `android/local.properties`
2. **Add this line** (replace `YOUR_API_KEY_HERE` with your actual API key):

```
MAPS_API_KEY=YOUR_API_KEY_HERE
```

**Example:**

```
sdk.dir=C\:\\Users\\YourName\\AppData\\Local\\Android\\Sdk
MAPS_API_KEY=AIzaSyCIfV-IowxUSjqrlEJ6nirSYISVND-1LxI
```

3. **Save the file**

### Step 5: Clean and Rebuild

1. **Clean the project:**

   ```bash
   flutter clean
   ```

2. **Get dependencies:**

   ```bash
   flutter pub get
   ```

3. **Rebuild the app:**
   ```bash
   flutter run
   ```

## 🔍 Verify It's Working

After rebuilding, the map should:

- ✅ Display the map tiles (not a blank screen)
- ✅ Show your location (if permissions granted)
- ✅ Allow zooming and panning

## ❌ If Still Not Working

### Check Console Logs

Look for errors in your Flutter console:

- `API key not valid` → Check your API key
- `This API project is not authorized` → Enable Maps SDK for Android
- `Billing not enabled` → Enable billing in Google Cloud Console

### Common Issues:

1. **API Key Not Found:**

   - Make sure `local.properties` has `MAPS_API_KEY=...`
   - Make sure there are no spaces around the `=`
   - Rebuild the app after adding the key

2. **API Not Enabled:**

   - Go to Google Cloud Console → APIs & Services → Library
   - Make sure "Maps SDK for Android" is enabled

3. **Billing Not Enabled:**

   - Go to Google Cloud Console → Billing
   - Link a billing account (free tier is fine)

4. **Wrong Package Name:**

   - Check `android/app/build.gradle.kts` - `applicationId` should match
   - Update API key restrictions in Google Cloud Console

5. **SHA-1 Not Added:**
   - Get your SHA-1 fingerprint (Step 2)
   - Add it to API key restrictions in Google Cloud Console

## 📱 For Release Build

When building for release, you'll need to:

1. Get the release SHA-1 fingerprint
2. Add it to your API key restrictions
3. Use the same API key

## 🆘 Quick Test

To quickly test if your API key works, you can temporarily remove restrictions:

1. Go to Google Cloud Console → APIs & Services → Credentials
2. Click on your API key
3. Under "Application restrictions", select "None"
4. Under "API restrictions", select "Don't restrict key"
5. Save and test

**Remember to add restrictions back for security!**

---

**Note:** The `local.properties` file is in `.gitignore`, so your API key won't be committed to version control. This is good for security!
