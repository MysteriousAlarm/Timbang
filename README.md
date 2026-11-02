# Project TIMBANG

*Alamin ang presyo bago magbenta.* (Know the price before you sell.)

Verified daily vegetable price board and produce listings for farmers in Nueva Vizcaya.
Flutter (Android + web) + Firebase. See `CLAUDE.md` for scope and `docs/` for design notes.

## Layout

| Path | What |
|---|---|
| `app/` | Flutter app. `lib/main_app.dart` = mobile (Harvest Earth), `lib/main_web.dart` = website/admin (Forest and Gold) |
| `functions/` | Cloud Functions (TypeScript) |
| `firestore.rules`, `storage.rules` | Security rules (deny by default) |
| `tests/rules/` | Rules tests (`@firebase/rules-unit-testing`) |
| `scripts/` | Local-only admin scripts (first admin claim) |
| `docs/` | Data model, threat model, pilot metrics |

## Local development (emulators only, project `demo-timbang`)

Requirements: Flutter 3.47+, Node 22, Java 21, `npm i -g firebase-tools`.

```bash
npm install && npm --prefix functions install
npm run emulators            # Auth, Firestore, Functions, Storage, UI at http://localhost:4000

cd app && flutter pub get
flutter run -t lib/main_app.dart                 # mobile app (Android emulator)
flutter run -d chrome -t lib/main_web.dart       # website + admin
```

The app connects to the emulators automatically in debug builds. On the Auth emulator,
OTP codes are shown in the Emulator UI (Authentication tab) and in the emulator log.

## Tests

```bash
npm run test:rules                   # Firestore + Storage rules tests (starts emulators)
npm --prefix functions test          # Cloud Functions unit tests (Jest)
cd app && flutter analyze && flutter test
```

## First admin

Roles are custom claims set only by the admin-only `setUserRole` function. Bootstrap the very
first admin locally (emulator):

```bash
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 npm run seed:admin -- +639171234567
```

## Connecting a real Firebase project (later)

1. Create the project, upgrade to Blaze, enable Phone Auth, Firestore, Storage.
2. Edit `.firebaserc` (`default`) and run `cd app && flutterfire configure`
   (generates `lib/firebase_options.dart`; replaces the demo options).
3. `firebase deploy --only firestore,storage,functions,hosting`.
