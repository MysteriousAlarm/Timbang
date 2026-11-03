import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
