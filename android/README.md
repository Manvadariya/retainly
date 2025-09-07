# FlutterLifecycleAdapter Issue Fix

If you're experiencing build errors related to `FlutterLifecycleAdapter` in the image_picker_android plugin, you have two options to fix it:

## Option 1: Add lifecycle dependency (Recommended)

1. This has already been added to your `app/build.gradle.kts` file:
   ```kotlin
   dependencies {
       implementation("androidx.lifecycle:lifecycle-common:2.6.2")
   }
   ```

2. Clean and rebuild:
   ```
   flutter clean
   flutter pub get
   flutter run
   ```

## Option 2: Apply patch to the plugin (Manual fix)

If the dependency approach doesn't work, use the provided patch script:

### Windows:
```
cd android
apply_patches.bat
```

### macOS/Linux:
```
cd android
chmod +x apply_patches.sh
./apply_patches.sh
```

Then rebuild the app:
```
flutter clean
flutter pub get
flutter run
```

## What the patch does

The patch modifies the image_picker_android plugin code to:
1. Comment out the import for the missing FlutterLifecycleAdapter
2. Replace the FlutterLifecycleAdapter usage with direct casting of HiddenLifecycleReference

This is a temporary solution until the plugin is updated by the maintainers.
