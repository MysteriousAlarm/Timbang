import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app languages. English is the default; the user picks on first launch.
enum AppLanguage {
  english('en'),
  filipino('fil');

  const AppLanguage(this.code);
  final String code;
  Locale get locale => Locale(code);

  static AppLanguage? fromCode(String? c) {
    for (final l in values) {
      if (l.code == c) return l;
    }
    return null;
  }
}

const _prefsKey = 'timbang.language';

/// Language saved on this device (null = not chosen yet, show the chooser).
/// Loaded once at startup in bootstrap() and overridden there.
final savedLanguageProvider = Provider<AppLanguage?>((ref) => null);

class LanguageController extends Notifier<AppLanguage?> {
  @override
  AppLanguage? build() => ref.watch(savedLanguageProvider);

  Future<void> choose(AppLanguage lang) async {
    state = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, lang.code);
    } catch (_) {
      // Private browsing etc.: the choice still applies for this session.
    }
  }
}

final languageProvider = NotifierProvider<LanguageController, AppLanguage?>(LanguageController.new);

/// The locale the app renders in: the chosen language, or English by default.
final appLocaleProvider = Provider<Locale>(
  (ref) => (ref.watch(languageProvider) ?? AppLanguage.english).locale,
);

Future<AppLanguage?> loadSavedLanguage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return AppLanguage.fromCode(prefs.getString(_prefsKey));
  } catch (_) {
    return null;
  }
}
