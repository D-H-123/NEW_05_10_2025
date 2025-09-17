import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/pages/onboarding_page.dart';
//import 'features/auth/pages/auth_page.dart';
import 'features/home/home_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'features/auth/pages/sign_up_page.dart';
import 'package:smart_receipt/features/camera/camera_page.dart';
import 'features/storage/bill/bill_page.dart';
import 'features/settings/settings_page.dart';
import 'features/camera/post_capture_page.dart';
import 'features/analysis/analysis.dart';




// App-level router using GoRouter with route names as requested.
final _router = GoRouter(routes: [
  GoRoute(path: '/', name: 'splash', builder: (context, state) => const SignupPage()),
  GoRoute(path: '/onboarding', name: 'onboarding', builder: (context, state) => const OnboardingPage()),
  GoRoute(path: '/sign', name: 'sign', builder: (context, state) => const SignupPage()),
  GoRoute(path: '/home', name: 'home', builder: (context, state) => const HomePage(growthPercentage: 12, achievementsCount: 10,)),
  GoRoute(
  path: '/sign-up',
  name: 'sign_up',
  builder: (context, state) => const SignupPage(),
),
GoRoute(
  path: '/scan',
  name: 'scan',
  builder: (context, state) => const CameraPage(),
),
GoRoute(
  path: '/bills',
  builder: (context, state) => const BillsPage(),
),
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsPage(),
),
GoRoute(
  path: '/analysis',
  builder: (context, state) => const AnalysisPage(),
),
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsPage(),
),
GoRoute(path: '/post-capture', builder: (context, state) {
  final args = state.extra;
  // print('🔍 MAGIC ROUTE: Post-capture route called');
  // print('🔍 MAGIC ROUTE: Args type: ${args.runtimeType}');
  // print('🔍 MAGIC ROUTE: Args: $args');
  
  if (args is Map) {
    // print('🔍 MAGIC ROUTE: Creating PostCapturePage with:');
    // print('  Image path: ${args['imagePath']}');
    // print('  Detected title: ${args['detectedTitle']}');
    // print('  Detected total: ${args['detectedTotal']}');
    // print('  Detected currency: ${args['detectedCurrency']}');
    // print('  Is editing: ${args['isEditing']}');
    // print('  Bill ID: ${args['billId']}');
    // print('  Existing bill: ${args['existingBill']}');
    
    return PostCapturePage(
      imagePath: args['imagePath'] ?? '',
      detectedTitle: args['detectedTitle'],
      detectedTotal: args['detectedTotal'],
      detectedCurrency: args['detectedCurrency'],
      detectedDate: args['detectedDate'],
      isEditing: args['isEditing'] ?? false,
      existingBill: args['existingBill'],
    );
  }
  // print('🔍 MAGIC ROUTE: Args is not Map, creating default PostCapturePage');
  return const PostCapturePage(imagePath: '');
}),

]);

class smart_receipt extends StatelessWidget {
  const smart_receipt({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SmartReceipt',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // Minimal theme following neutral modern style.
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
