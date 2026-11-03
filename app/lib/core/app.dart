import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'push/push_service.dart';
import 'router/app_router.dart';

class TimbangApp extends ConsumerWidget {
  const TimbangApp({super.key, required this.theme});

  /// Picked by entrypoint (main_app.dart / main_web.dart), never by screen width.
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushServiceProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: rootMessengerKey,
      title: 'TIMBANG',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: ref.watch(routerProvider),
      // English by default; the user picks English or Filipino on first launch.
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
