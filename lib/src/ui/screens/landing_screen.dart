import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Image(
                image: AssetImage('assets/images/brain_logo.png'),
                width: 216,
                height: 216,
              ),
              const SizedBox(height: 24),
              Text(
                'Retainly',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'An extension of your mind',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/home'),
                  child: const Text('Open Memories'),
                ),
              ),
              const SizedBox(height: 12),
              // Version info
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
