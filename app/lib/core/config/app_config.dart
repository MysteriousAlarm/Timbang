import 'package:flutter/foundation.dart';

/// All tunable client numbers and allowed values. Keep in sync with
/// functions/src/config.ts and firestore.rules.
abstract final class AppConfig {
  /// Shown in footers. Keep in sync with pubspec.yaml `version`.
  static const appVersion = '0.1.0';

  /// Use the Firebase Emulator Suite. Defaults to on in debug builds.
  /// Override: --dart-define=USE_EMULATORS=false
  static const useEmulators = bool.fromEnvironment('USE_EMULATORS', defaultValue: kDebugMode);

  /// Emulator host. Android emulator reaches the host machine at 10.0.2.2.
  /// For a real phone on the same Wi-Fi: --dart-define=EMULATOR_HOST=192.168.x.x
  static const _emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');
  static String get emulatorHost {
    if (_emulatorHostOverride.isNotEmpty) return _emulatorHostOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return '127.0.0.1';
  }

  static const authPort = 9099;
  static const firestorePort = 8080;
  static const functionsPort = 5001;
  static const storagePort = 9199;

  static const functionsRegion = 'asia-southeast1';

  static const nameMinLength = 2;
  static const nameMaxLength = 80;
  static const otpLength = 6;

  /// The 15 municipalities of Nueva Vizcaya.
  static const municipalities = <String>[
    'Alfonso Castañeda',
    'Ambaguio',
    'Aritao',
    'Bagabag',
    'Bambang',
    'Bayombong',
    'Diadi',
    'Dupax del Norte',
    'Dupax del Sur',
    'Kasibu',
    'Kayapa',
    'Quezon',
    'Santa Fe',
    'Solano',
    'Villaverde',
  ];

  // Catalog (Step 2). The lists themselves are admin-managed data in Firestore;
  // only their shape lives here. Keep in sync with functions/src/config.ts.
  static const units = <String>['kg', 'bundle', 'piece'];
  static const marketTypes = <String>['public_market', 'trading_post', 'farmgate_area'];
  static final catalogIdPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,48}$');
  static const catalogMaxItemsPerImport = 500;

  // Price reports (Step 3). Keep in sync with functions/src/config.ts.
  static const priceMin = 0.01;
  static const priceMax = 100000.0;
  static const officialImportMaxRows = 500;

  // Price board (Step 4). Must match PRICE_WINDOW_HOURS in functions/src/config.ts.
  static const priceWindow = Duration(hours: 24);
}
