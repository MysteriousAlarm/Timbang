# Building and deploying TIMBANG (first build, v0.1.0)

Do this on your own computer. Expect about 1 to 2 hours the first time.

## 0. Tools

| Tool | Version | Check |
|---|---|---|
| Flutter | 3.47 or newer (stable) | `flutter --version` |
| Android Studio + Android SDK | latest, with an emulator or a phone in USB debugging | `flutter doctor` |
| Node.js | 22 | `node -v` |
| Java | 21 (needed by the Firebase emulators) | `java -version` |
| Firebase CLI | latest | `npm i -g firebase-tools` then `firebase login` |
| FlutterFire CLI | latest | `dart pub global activate flutterfire_cli` |

```bash
git clone <repo> && cd Timbang
npm install && npm --prefix functions install
cd app && flutter pub get && cd ..
```

Sanity check everything locally first (no Firebase project needed):

```bash
npm run test:rules && npm run test:integration && npm --prefix functions test
cd app && flutter test && cd ..
```

## 1. Create the Firebase project (console.firebase.google.com)

1. **Add project** (e.g. `timbang-nv`). Analytics: off (no PII in analytics, Section 10).
2. **Upgrade to Blaze** (pay as you go). Cloud Functions need it. Set a **budget alert**
   (e.g. ₱500) under Google Cloud Billing → Budgets. Pilot usage should be close to free.
3. **Authentication → Sign-in method → Phone: enable.**
   - Add **test phone numbers** (Authentication → Phone → "Phone numbers for testing"),
     e.g. `+63 917 000 0001` with code `123456`. Use these in class demos: no SMS is sent and
     nothing is billed.
4. **Firestore Database → Create database → Production mode → location `asia-southeast1`**
   (Singapore). It must match the functions region.
5. **Storage → Get started** (same location).

## 2. Connect the code to the project

```bash
# from the repo root
firebase use --add            # pick the new project, alias "default"
cd app
flutterfire configure \
  --project=<project-id> \
  --platforms=android,web \
  --android-package-name=ph.timbang.timbang \
  --out=lib/core/firebase/firebase_options.dart
cd ..
```

This replaces the demo placeholder options. The generated file only holds public identifiers,
not secrets. Restrict the API keys later in Google Cloud → Credentials (Step 10 hardening).

## 3. Deploy the backend

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

The first functions deploy can take 5 to 10 minutes and may ask to enable APIs. Say yes.
Indexes take a few minutes to build. The board may error until they are ready.

## 4. Android: phone sign-in needs your app fingerprints

```bash
cd app/android && ./gradlew signingReport   # copy SHA1 and SHA-256 of the "debug" variant
```

Firebase console → Project settings → Your apps → Android (`ph.timbang.timbang`) →
**Add fingerprint** (both SHA-1 and SHA-256). Then in Google Cloud, enable the **Play Integrity API**.
Re-run `flutterfire configure` if you added the Android app after step 2.

## 5. Build

```bash
cd app

# Mobile app (Harvest Earth). Release builds talk to the real project, not the emulators.
flutter build apk --release -t lib/main_app.dart
# -> build/app/outputs/flutter-apk/app-release.apk  (install on a phone)
# First build note: release uses the debug signing key, fine for a class prototype.

# Website + admin (Forest and Gold)
flutter build web --release -t lib/main_web.dart
cd ..
firebase deploy --only hosting      # -> https://<project-id>.web.app
```

## 6. First admin, then data

1. Open the app or website and **sign in once** with your number (or a test number).
2. Firebase console → Project settings → Service accounts → **Generate new private key**.
   Save it **outside the repo** (never commit it).
3. Grant yourself admin:
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=~/keys/timbang-sa.json GCLOUD_PROJECT=<project-id> \
     npm run seed:admin -- +639XXXXXXXXX
   ```
   Sign out and in again. The website now opens the **Admin dashboard**.
4. Data, either:
   - **Real lists** (when DA / DAR / NVAT data arrives): Admin → Mga bilihin / Mga palengke →
     *I-import ang CSV*, then Admin → Mga presyo → *I-import ang opisyal na presyo*; or
   - **Demo data** for presentations (everything labeled DEMO, never shown as real):
     ```bash
     GOOGLE_APPLICATION_CREDENTIALS=~/keys/timbang-sa.json SEED_REAL_PROJECT=<project-id> \
       npm run seed:demo
     ```
     Later: Admin → *Alisin ang demo data*.

## Day-to-day development (no real project needed)

```bash
npm run emulators                                   # terminal 1
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run seed:demo
cd app && flutter run -t lib/main_app.dart          # Android emulator; uses the emulators
flutter run -d chrome -t lib/main_web.dart          # website
```

Debug builds use the emulators by default. To point a debug build at the real project:
`--dart-define=USE_EMULATORS=false`. On a real phone with emulators:
`--dart-define=EMULATOR_HOST=<your PC's LAN IP>`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Phone sign-in fails on Android with "missing app identifier" | Add SHA-1/SHA-256 (step 4), enable Play Integrity, rebuild |
| Web sign-in: reCAPTCHA / unauthorized domain | Authentication → Settings → Authorized domains: add your domain (web.app is added by default) |
| Board shows "Hindi ma-load ang presyo" right after deploy | Firestore indexes still building (console → Firestore → Indexes) |
| Functions deploy: region / database location error | Firestore must be in `asia-southeast1` |
| Admin dashboard not showing after seed:admin | Sign out and sign in again (refreshes the role claim) |
