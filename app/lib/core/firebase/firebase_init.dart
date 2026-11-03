import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline-first: cached price board and drafts survive without signal.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await _activateAppCheck();

  if (AppConfig.useEmulators) {
    final host = AppConfig.emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, AppConfig.authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, AppConfig.firestorePort);
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
        .useFunctionsEmulator(host, AppConfig.functionsPort);
    await FirebaseStorage.instance.useStorageEmulator(host, AppConfig.storagePort);
    debugPrint('TIMBANG: using Firebase emulators at $host');
  }
}

/// App Check (Section 10): proves requests come from the real TIMBANG app.
/// Android release: Play Integrity. Debug builds: debug provider (register the printed token in
/// the console). Web: reCAPTCHA v3, only when --dart-define=RECAPTCHA_SITE_KEY=... is given.
/// Enforcement is switched on server-side (ENFORCE_APP_CHECK) once tokens are registered.
Future<void> _activateAppCheck() async {
  if (AppConfig.useEmulators) return;
  const siteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
  try {
    if (kIsWeb) {
      if (siteKey.isEmpty) return;
      await FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaV3Provider(siteKey));
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
      );
    }
  } catch (e) {
    debugPrint('TIMBANG: App Check not active: $e');
  }
}
