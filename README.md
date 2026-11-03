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
| `docs/` | `BUILD.md` (build & deploy), `data-model.md`, `threat-model.md` (STRIDE), `security-checklist.md` (MASVS), `sms.md`, `pilot-metrics.md`, `usability-sus.md` |

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
npm run test:integration             # callable functions against Auth/Firestore/Functions emulators
cd app && flutter analyze && flutter test
```

Typeface: Public Sans (SIL Open Font License), bundled in `app/assets/fonts` so it works offline.

## Demo data and the official lists

The official commodity / market lists (DA, DAR, NVAT via the Governor's office) are pending.
Until then, seed illustrative items and price reports (all marked `isDemo`, shown with a DEMO
badge; run while the emulators are up so the board trigger computes the demo price board):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run seed:demo
```

When the official lists arrive: Admin dashboard → Mga bilihin / Mga palengke → **I-import ang CSV**
(templates in `docs/templates/`), then **Alisin ang demo data**. Official prices go in through
**Mga presyo → I-import ang opisyal na presyo** (columns `commodityId, marketId, price, date`;
Filipino aliases like `Bilihin, Palengke, Presyo` also work). No code changes needed.

## First admin

Roles are custom claims set only by the admin-only `setUserRole` function. Bootstrap the very
first admin locally (emulator):

```bash
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 npm run seed:admin -- +639171234567
```

## Connecting a real Firebase project

Full step-by-step guide: **[docs/BUILD.md](docs/BUILD.md)**. Building the APK: **[docs/APK_BUILD.md](docs/APK_BUILD.md)**. Short version:

1. Create the project, upgrade to Blaze, enable Phone Auth, Firestore (location
   `asia-southeast1`, to match the functions region), Storage.
2. Edit `.firebaserc` (`default`) and run `cd app && flutterfire configure`
   (generates `lib/firebase_options.dart`; replaces the demo options).
3. `firebase deploy --only firestore,storage,functions,hosting`.
