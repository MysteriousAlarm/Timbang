import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase/firebase_init.dart';
import 'router/app_router.dart';
import 'router/redirect.dart';

/// Shared startup for both entrypoints.
Future<void> bootstrap({required AppTarget target, required ThemeData theme}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  runApp(
    ProviderScope(
      overrides: [appTargetProvider.overrideWithValue(target)],
      child: TimbangApp(theme: theme),
    ),
  );
}
