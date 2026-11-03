import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/features/auth/application/phone_auth_controller.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';

import 'fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer c;

  setUp(() {
    auth = FakeAuthRepository();
    c = ProviderContainer(overrides: fakeOverrides(auth, FakeProfileRepository()));
  });
  tearDown(() => c.dispose());

  PhoneAuthController ctrl() => c.read(phoneAuthControllerProvider.notifier);

  test('invalid phone never calls Firebase', () async {
    expect(await ctrl().sendCode('12345'), isFalse);
    expect(c.read(phoneAuthControllerProvider).error, AuthErrorCode.invalidPhone);
    expect(auth.lastPhone, isNull);
  });

  test('local number is normalized to E.164 and code is sent', () async {
    expect(await ctrl().sendCode('0917 123 4567'), isTrue);
    expect(auth.lastPhone, '+639171234567');
    expect(c.read(phoneAuthControllerProvider).codeSent, isTrue);
  });

  test('Firebase errors surface as error codes', () async {
    auth.failNext = const AuthFailure(AuthErrorCode.tooManyRequests);
    expect(await ctrl().sendCode('09171234567'), isFalse);
    expect(c.read(phoneAuthControllerProvider).error, AuthErrorCode.tooManyRequests);
  });

  test('wrong code shows error; right code signs in', () async {
    await ctrl().sendCode('09171234567');
    expect(await ctrl().verify('000000'), isFalse);
    expect(c.read(phoneAuthControllerProvider).error, AuthErrorCode.invalidCode);
    expect(await ctrl().verify('12'), isFalse);
    expect(await ctrl().verify(FakeVerification.validCode), isTrue);
    expect(auth.currentUser?.uid, 'u1');
  });
}
