import 'package:flutter/material.dart';
import 'src/ui/widgets/youtube_details_tester.dart';
import 'src/ui/theme/app_theme.dart';

/// This is a standalone main file for testing the YouTube details screen
/// To use this tester, temporarily rename the original main.dart file
/// and rename this file to main.dart, then run the app.
void main() {
  runApp(const YouTubeDetailsTesterApp());
}

class YouTubeDetailsTesterApp extends StatelessWidget {
  const YouTubeDetailsTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Details Tester',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const YouTubeDetailsTester(),
    );
  }
}
