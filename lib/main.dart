import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';
import 'package:smart_receipt/core/services/premium_service.dart';
import 'package:smart_receipt/core/services/subscription_reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable edge-to-edge UI and make system bars transparent so the gradient
  // shows behind the Android navigation area instead of a black strip.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await EasyLocalization.ensureInitialized();
  await LocalStorageService.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PremiumService.initialize();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('de')],
        path: 'assets/translations', // TODO: create this folder & files
        fallbackLocale: const Locale('en'),
        child: const smart_receipt(),
      ),
    ),
  );
}
