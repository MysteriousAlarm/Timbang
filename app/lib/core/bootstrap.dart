import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase/firebase_init.dart';
import 'l10n/locale_controller.dart';
import 'router/app_router.dart';
import 'router/redirect.dart';

/// Shared startup for both entrypoints.
Future<void> bootstrap({required AppTarget target, required ThemeData theme}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  final language = await loadSavedLanguage();
  runApp(
    ProviderScope(
      overrides: [
        appTargetProvider.overrideWithValue(target),
        savedLanguageProvider.overrideWithValue(language),
      ],
      child: TimbangApp(theme: theme),
    ),
  );
}
