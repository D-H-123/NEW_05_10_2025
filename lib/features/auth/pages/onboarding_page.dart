import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // For step 1 we go straight to auth page per requirement
    Future.microtask(() => context.goNamed('sign'));
    return const Scaffold(
      body: Center(
        child: Text('Welcome — preparing auth...'),
      ),
    );
  }
}
