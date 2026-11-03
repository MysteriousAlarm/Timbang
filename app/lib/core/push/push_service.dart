import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/session.dart';
import '../config/app_config.dart';

/// Lets non-widget code show a snackbar (foreground push messages).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Registers this device for push and stores its token on the user's profile
/// (users.fcmTokens; one device per user for the pilot). Skipped on the emulators
/// (FCM is not emulated) and on web unless a VAPID key is provided:
///   --dart-define=FCM_VAPID_KEY=...
class PushService {
  PushService();
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;
  String? _uid;

  static const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  bool get _supported => !AppConfig.useEmulators && (!kIsWeb || _vapidKey.isNotEmpty);

  Future<void> onSignedIn(String uid) async {
    if (!_supported || _uid == uid) return;
    _uid = uid;
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // Registration tokens are what the Admin SDK's sendEachForMulticast expects.
      // ignore: deprecated_member_use
      final token = await fm.getToken(vapidKey: kIsWeb ? _vapidKey : null);
      if (token != null) await _save(uid, token);
      // ignore: deprecated_member_use
      _refresh = fm.onTokenRefresh.listen((t) => _save(uid, t));
      _foreground = FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text([n.title, n.body].whereType<String>().join('\n'))),
        );
      });
    } catch (e) {
      debugPrint('TIMBANG push setup skipped: $e');
    }
  }

  Future<void> _save(String uid, String token) =>
      FirebaseFirestore.instance.doc('users/$uid').update({
        'fcmTokens': [token],
      });

  Future<void> onSignedOut() async {
    await _refresh?.cancel();
    await _foreground?.cancel();
    _uid = null;
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final svc = PushService();
  ref.listen(sessionProvider, (_, s) {
    if (s is SignedIn) {
      svc.onSignedIn(s.user.uid);
    } else if (s is SignedOut) {
      svc.onSignedOut();
    }
  }, fireImmediately: true);
  return svc;
});
