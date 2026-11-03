import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/phone.dart';
import '../data/auth_repository.dart';
import 'session.dart';

class PhoneAuthState {
  const PhoneAuthState({this.phone, this.verification, this.loading = false, this.error});

  final String? phone;
  final PhoneVerification? verification;
  final bool loading;
  final AuthErrorCode? error;

  bool get codeSent => verification != null;

  PhoneAuthState copyWith({
    String? phone,
    PhoneVerification? verification,
    bool? loading,
    AuthErrorCode? error,
    bool clearError = false,
  }) => PhoneAuthState(
    phone: phone ?? this.phone,
    verification: verification ?? this.verification,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  /// Returns true if an OTP was sent (go to the code screen).
  Future<bool> sendCode(String rawPhone) async {
    final e164 = normalizePhMobile(rawPhone);
    if (e164 == null) {
      state = const PhoneAuthState(error: AuthErrorCode.invalidPhone);
      return false;
    }
    state = PhoneAuthState(phone: e164, loading: true);
    try {
      final v = await ref.read(authRepositoryProvider).startPhoneVerification(e164);
      state = PhoneAuthState(phone: e164, verification: v);
      return v != null;
    } on AuthFailure catch (f) {
      state = PhoneAuthState(phone: e164, error: f.code);
      return false;
    }
  }

  Future<bool> verify(String code) async {
    final v = state.verification;
    final trimmed = code.trim();
    if (v == null || !RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      state = state.copyWith(error: AuthErrorCode.invalidCode);
      return false;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      await v.confirm(trimmed);
      state = const PhoneAuthState();
      return true;
    } on AuthFailure catch (f) {
      state = state.copyWith(loading: false, error: f.code);
      return false;
    }
  }

  void reset() => state = const PhoneAuthState();
}

final phoneAuthControllerProvider = NotifierProvider<PhoneAuthController, PhoneAuthState>(
  PhoneAuthController.new,
);
