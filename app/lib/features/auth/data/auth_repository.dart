import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/models/role.dart';

/// Minimal signed-in user view, so UI and tests do not depend on FirebaseAuth types.
class AuthUser {
  const AuthUser({required this.uid, required this.phone});
  final String uid;
  final String? phone;
}

/// A pending phone verification; call [confirm] with the SMS code.
abstract class PhoneVerification {
  Future<void> confirm(String code);
}

/// Error codes surfaced to the UI (mapped to l10n strings there).
enum AuthErrorCode { invalidPhone, invalidCode, codeExpired, tooManyRequests, network, generic }

class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final AuthErrorCode code;

  static AuthFailure fromFirebase(FirebaseAuthException e) => AuthFailure(switch (e.code) {
    'invalid-phone-number' || 'missing-phone-number' => AuthErrorCode.invalidPhone,
    'invalid-verification-code' || 'missing-verification-code' => AuthErrorCode.invalidCode,
    'session-expired' || 'code-expired' => AuthErrorCode.codeExpired,
    'too-many-requests' || 'quota-exceeded' => AuthErrorCode.tooManyRequests,
    'network-request-failed' => AuthErrorCode.network,
    _ => AuthErrorCode.generic,
  });

  @override
  String toString() => 'AuthFailure($code)';
}

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;

  /// Starts phone OTP. Returns null if Android auto-verified and signed in already.
  Future<PhoneVerification?> startPhoneVerification(String e164);

  /// Role from the verified ID token custom claim (never from Firestore).
  Future<Role?> roleClaim({bool forceRefresh = false});

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;

  AuthUser? _map(User? u) => u == null ? null : AuthUser(uid: u.uid, phone: u.phoneNumber);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<PhoneVerification?> startPhoneVerification(String e164) async {
    try {
      if (kIsWeb) {
        // Web uses an invisible reCAPTCHA verifier managed by the SDK.
        final result = await _auth.signInWithPhoneNumber(e164);
        return _WebVerification(result);
      }
      return await _startNative(e164);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebase(e);
    }
  }

  Future<PhoneVerification?> _startNative(String e164) {
    final completer = Completer<PhoneVerification?>();
    _auth.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android SMS auto-retrieval.
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete(null);
        } on FirebaseAuthException catch (e) {
          if (!completer.isCompleted) completer.completeError(AuthFailure.fromFirebase(e));
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(AuthFailure.fromFirebase(e));
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(_NativeVerification(_auth, verificationId));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  @override
  Future<Role?> roleClaim({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final token = await user.getIdTokenResult(forceRefresh);
    return Role.tryParse(token.claims?['role']);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class _NativeVerification implements PhoneVerification {
  _NativeVerification(this._auth, this._verificationId);
  final FirebaseAuth _auth;
  final String _verificationId;

  @override
  Future<void> confirm(String code) async {
    try {
      await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: code),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebase(e);
    }
  }
}

class _WebVerification implements PhoneVerification {
  _WebVerification(this._result);
  final ConfirmationResult _result;

  @override
  Future<void> confirm(String code) async {
    try {
      await _result.confirm(code);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebase(e);
    }
  }
}
