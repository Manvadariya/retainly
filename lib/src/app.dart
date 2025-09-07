import 'package:flutter/material.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/landing_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/card_detail_screen.dart';
import 'ui/theme/app_theme.dart';

class RetainlyApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  const RetainlyApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Retainly',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/landing': (context) => const LandingScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/cardDetail') {
          final cardId = settings.arguments as int;
          return AppTheme.slideAndFadeTransition<dynamic>(
            settings: settings,
            page: CardDetailScreen(cardId: cardId),
          );
        }
        return null;
      },
    );
  }
}
