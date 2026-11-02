// PLACEHOLDER options for the emulator-only demo project `demo-timbang`.
// Replace this file by running `flutterfire configure` once the real Firebase
// project exists. These values are not secrets and only work with the emulators.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  static const web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-timbang',
    authDomain: 'demo-timbang.firebaseapp.com',
    storageBucket: 'demo-timbang.appspot.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-timbang',
    storageBucket: 'demo-timbang.appspot.com',
  );
}
