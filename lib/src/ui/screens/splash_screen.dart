import 'package:flutter/material.dart';
import 'dart:async';
import 'landing_screen.dart';
import '../../share_flow.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // React to share state changes; navigate after 2s when idle
    ShareFlow.active.addListener(_onShareStateChanged);
    ShareFlow.pendingInitial.addListener(_onShareStateChanged);

    // Evaluate immediately in case there is no share flow
    _scheduleMaybeNavigate();
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    ShareFlow.active.removeListener(_onShareStateChanged);
    ShareFlow.pendingInitial.removeListener(_onShareStateChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onShareStateChanged() {
    _scheduleMaybeNavigate();
  }

  void _scheduleMaybeNavigate() {
    if (!mounted || _navigated) return;

    // If share flow is active or still detecting initial share, wait.
    if (ShareFlow.active.value || ShareFlow.pendingInitial.value) {
      _navTimer?.cancel();
      return;
    }

    // Otherwise, ensure we navigate after showing splash for ~2 seconds
    _navTimer?.cancel();
    _navTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _navigated) return;
      _navigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          settings: const RouteSettings(name: '/landing'),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LandingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Image(
                image: AssetImage('assets/images/brain_logo.png'),
                width: 180,
                height: 180,
              ),
              SizedBox(height: 16),
              Text('Retainly', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
