import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text('app_name'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('welcome'.tr(), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: implement Google sign-in
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Sign-in placeholder')));
              },
              child: Text('${'sign_in'.tr()} (Google)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // TODO: implement Apple sign-in (iOS only)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apple Sign-in placeholder')));
              },
              child: Text('${'sign_in'.tr()} (Apple)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.goNamed('home'),
              child: Text('${'sign_in'.tr()} (Email)'),
            ),
            const Spacer(),
            Text('or'.tr()),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Guest flow: track scans locally, limited to 2 (enforced elsewhere)
                ref.read(authControllerProvider.notifier).signInAsGuest();
                context.goNamed('home');
              },
              child: Text('guest_skip'.tr()),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => {}, // TODO: open privacy / terms
              child: const Text('Privacy & Terms'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
