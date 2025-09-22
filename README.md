# retainly

A Flutter application for saving and organizing notes, images, and links.

## Getting Started

This project is a starting point for a Flutter application.

## Known Issues and Fixes

### FlutterLifecycleAdapter Error in image_picker_android

If you encounter the following error:
```
error: cannot find symbol
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter;
```

See the detailed fix instructions in [android/README.md](android/README.md).

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## YouTube API Key

This app integrates with the YouTube Data API v3. Provide your API key via a compile-time define:

```
flutter run --dart-define=YT_API_KEY=your_api_key_here
```

For release builds:

```
flutter build apk --dart-define=YT_API_KEY=your_api_key_here
flutter build ios --dart-define=YT_API_KEY=your_api_key_here
```

Notes:
- A sample `.env.example` is provided. Flutter does not automatically read `.env`; use `--dart-define` or configure CI to inject it.
- `YouTubeService` reads the key using `const String.fromEnvironment('YT_API_KEY')`.
