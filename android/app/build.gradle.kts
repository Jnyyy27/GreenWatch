plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read API key from `local.properties` (project property) or environment variable.
// Add your `MAPS_API_KEY=...` to `local.properties` or set the `MAPS_API_KEY` env var.
val mapsApiKey: String? = (project.findProperty("MAPS_API_KEY") as? String)
    ?: System.getenv("MAPS_API_KEY")

android {
    namespace = "com.example.green_watch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Enable BuildConfig generation so `buildConfigField` works
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.green_watch"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Expose API key to AndroidManifest via manifest placeholder
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey ?: ""
        // Optionally expose to BuildConfig for native Android code usage
        buildConfigField("String", "MAPS_API_KEY", "\"${mapsApiKey ?: ""}\"")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
