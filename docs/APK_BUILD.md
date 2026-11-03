# Building the TIMBANG APK: checklist

There are two ways to get a working APK. Do **Path A** first (about 30 minutes, no Firebase
project needed) to test on your phone today. Do **Path B** when the Firebase project exists, for
the APK you hand out for the class demo or pilot.

| | Path A: test APK (emulators) | Path B: real APK (Firebase project) |
|---|---|---|
| Firebase project / Blaze | not needed | needed |
| Login | fake OTP from the Emulator UI | real SMS, or Firebase test numbers |
| Data | your PC (demo data) | Firebase cloud |
| Works away from your Wi-Fi | no | yes |
| Command | `flutter build apk --debug ...` | `flutter build apk --release ...` |

---

## 0. One-time setup on your workstation

- [ ] **Flutter 3.47 or newer** (stable): `flutter --version`. Upgrade with `flutter upgrade`.
- [ ] **Android Studio** (latest). In *Settings → Languages & Frameworks → Android SDK*:
  - [ ] SDK Platforms: **Android 16 (API 36)** (or the newest offered)
  - [ ] SDK Tools: **Android SDK Build-Tools**, **Android SDK Command-line Tools (latest)**,
        **Android SDK Platform-Tools**, **NDK (Side by side)**, **CMake**
- [ ] **JDK 17 or 21**. Android Studio's bundled JDK is fine:
  `flutter config --jdk-dir "<Android Studio>/jbr"` if `flutter doctor` complains.
- [ ] Accept licenses: `flutter doctor --android-licenses` (answer `y` to all).
- [ ] `flutter doctor` shows ✓ for **Flutter** and **Android toolchain**. (Chrome, Visual
      Studio and Xcode rows don't matter for the APK.)
- [ ] **Node.js 22** and **Java 21** (for the Firebase emulators in Path A): `node -v`, `java -version`.
- [ ] Firebase CLI: `npm i -g firebase-tools`.
- [ ] Phone: *Settings → About phone →* tap **Build number** 7 times → *Developer options →*
      **USB debugging** on. Android **7.0 or newer** (the app's minimum).

Get the code and dependencies:

```bash
git clone https://github.com/MysteriousAlarm/Timbang.git
cd Timbang
git checkout ccr-ff30ad89-k9lh01      # or main, once this branch is merged
npm install
npm --prefix functions install
cd app && flutter pub get && cd ..
```

Sanity check (should all pass):

```bash
cd app && flutter analyze && flutter test && cd ..
```

---

## Path A: test APK against the emulators on your PC

The phone talks to the Firebase emulators running on your PC over Wi-Fi.

1. **Find your PC's Wi-Fi IP address**
   - Windows: `ipconfig` → *Wireless LAN adapter Wi-Fi* → **IPv4 Address** (e.g. `192.168.1.23`)
   - macOS: `ipconfig getifaddr en0` · Linux: `hostname -I`
2. **Allow the emulator ports through the firewall** (Windows will usually pop up a dialog the
   first time: tick **Private networks** and Allow). Ports: `9099` (Auth), `8080` (Firestore),
   `5001` (Functions), `9199` (Storage), `4000` (Emulator UI).
3. **Start the emulators for the LAN** (terminal 1, keep it open):
   ```bash
   npm run emulators:lan
   ```
4. **Load demo data** (terminal 2):
   - macOS / Linux / Git Bash:
     ```bash
     FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run seed:demo
     ```
   - Windows PowerShell:
     ```powershell
     $env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"; npm run seed:demo
     ```
5. **Build the debug APK** with your PC's IP:
   ```bash
   cd app
   flutter build apk --debug -t lib/main_app.dart --dart-define=EMULATOR_HOST=192.168.1.23
   ```
   Output: `app/build/app/outputs/flutter-apk/app-debug.apk`.
   (Or plug the phone in and run `flutter run -t lib/main_app.dart --dart-define=EMULATOR_HOST=192.168.1.23`
   to install and watch logs in one step.)
6. **Install**: copy the APK to the phone and open it (allow "Install unknown apps"), or
   `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
7. **Log in**: enter any PH number (e.g. `0917 123 4567`), tap *Ipadala ang code*, then open
   `http://<PC IP>:4000/auth` (or `http://127.0.0.1:4000/auth` on the PC) → the OTP code is shown
   there. No SMS is sent.
8. **Become admin** (to see admin features on the website): after logging in once,
   - bash: `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run seed:admin -- +639171234567`
   - PowerShell: `$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"; $env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"; npm run seed:admin -- +639171234567`

   Then sign out and in again. Website with admin: `flutter run -d chrome -t lib/main_web.dart`.

### Testing on your own phone: tips for finding bugs and UI/UX issues

- **Best for UI work: run over USB with hot reload.** Plug in the phone (USB debugging on), then:
  ```bash
  cd app
  flutter run -t lib/main_app.dart --dart-define=EMULATOR_HOST=192.168.1.23
  ```
  Press `r` in the terminal to reload after pulling changes, `R` to restart. Errors and
  overflow warnings appear in the terminal. Copy them to Claude together with a screenshot.
- **Judging smoothness/speed:** debug builds are always slower and can stutter. For a realistic
  feel, use a profile build (still connects to your PC's emulators):
  ```bash
  flutter run --profile -t lib/main_app.dart --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=192.168.1.23
  ```
- **Things to try:** large text (Settings → Display → Font size), outdoor brightness, a slow or
  no connection (airplane mode: the price board should stay readable with the offline banner),
  both roles (sign up a second number as a buyer), rotating the phone, the back button.
- **Two test numbers:** use one number as a farmer and another as a buyer (any PH number works on
  the emulator) to test listings → inquiries → inbox end to end.
- **Screenshots for bug reports:** power + volume down on the phone, or
  `adb exec-out screencap -p > shot.png` on the PC.

Notes: phone and PC must be on the **same Wi-Fi** (not a guest network with client isolation).
Data is kept when you stop the emulators with Ctrl+C (saved to `emulator-data/`). Push
notifications don't work on emulators (they are only logged); the inbox still updates.

---

## Path B: real release APK (Firebase project)

Follow `docs/BUILD.md` steps 1–4 first (create project → Blaze → enable Phone sign-in → Firestore
in `asia-southeast1` → Storage → `flutterfire configure` → deploy). The APK-specific parts:

1. **Connect the app to the project** (from `app/`):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<project-id> --platforms=android,web \
     --android-package-name=ph.timbang.timbang --out=lib/core/firebase/firebase_options.dart
   ```
   This writes `lib/core/firebase/firebase_options.dart` and `android/app/google-services.json`
   (gitignored) and adds the Google Services Gradle plugin.
2. **Add the signing fingerprints** (phone sign-in fails without them):
   ```bash
   cd android
   ./gradlew signingReport        # Windows: gradlew signingReport
   ```
   Copy **SHA1** and **SHA-256** of `Variant: debug` (the release build uses the debug key for
   now). Firebase console → Project settings → Your apps → Android → **Add fingerprint** (both).
   Google Cloud console → enable **Play Integrity API**.
3. **Test numbers for demos** (no SMS cost): Authentication → Sign-in method → Phone →
   *Phone numbers for testing*: e.g. `+63 917 000 0001` / `123456`.
4. **Build**:
   ```bash
   cd app
   flutter build apk --release -t lib/main_app.dart
   ```
   Output: `app/build/app/outputs/flutter-apk/app-release.apk` (about 25–35 MB).
   Smaller per-phone files: `flutter build apk --release --split-per-abi -t lib/main_app.dart`
   (use `app-arm64-v8a-release.apk` for most phones).
5. **Install** on the phone and log in with a real number or a test number.
6. **First admin**: see `docs/BUILD.md` step 6 (service-account key outside the repo + `seed:admin`).

### Before giving the APK to other people (pilot)

- [ ] Create a real **upload keystore** instead of the debug key:
  ```bash
  keytool -genkey -v -keystore ~/timbang-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
  Keep it **outside the repo** and back it up (losing it means you cannot update the app).
  Ask me to wire `key.properties` into `android/app/build.gradle.kts` when you get to this step,
  then add the keystore's SHA-1/SHA-256 in Firebase too.
- [ ] Bump the version in `app/pubspec.yaml` (`0.1.0+1` → `0.1.1+2`) for each new APK.
- [ ] App Check, API key restrictions: `docs/BUILD.md` step 7.

---

## Troubleshooting

| Error / symptom | Fix |
|---|---|
| `flutter doctor`: *Android license status unknown* | `flutter doctor --android-licenses` |
| `No Android SDK found` | Android Studio → SDK Manager → install the SDK; or `flutter config --android-sdk <path>` |
| `Unsupported class file major version` / Gradle JDK errors | Use JDK 17/21: `flutter config --jdk-dir "<Android Studio>/jbr"` |
| `NDK ... did not have a source.properties file` | SDK Manager → SDK Tools → install **NDK (Side by side)**; then `flutter clean` |
| `uses-sdk:minSdkVersion ... cannot be smaller than 24` | Already fixed in the repo (minSdk 24). Pull the latest code |
| `Execution failed for task ':app:processDebugGoogleServices'` / `File google-services.json is missing` | Run `flutterfire configure` (Path B) or remove the Google Services plugin line it added if you went back to Path A |
| Build is very slow the first time | Normal: Gradle downloads ~1–2 GB once. Use a stable connection |
| *Could not reserve enough space for object heap* / out of memory | `app/android/gradle.properties` asks Gradle for 8 GB (`-Xmx8G`). On a PC with 8 GB RAM or less, change it to `-Xmx4G -XX:MaxMetaspaceSize=1G` and close other apps |
| Path A: app stuck on loading / *network error* | Wrong IP in `EMULATOR_HOST`, different Wi-Fi, or firewall blocking ports 9099/8080/5001/9199. Test in the phone's browser: `http://<PC IP>:4000` should open |
| Path A: OTP never arrives | Expected: read the code in the Emulator UI → Authentication |
| Path B: *This app is not authorized to use Firebase Authentication* / *missing app identifier* | Add SHA-1 and SHA-256 (step 2), enable Play Integrity, wait 5 minutes, reinstall |
| Path B: *We have blocked all requests from this device* | Too many OTP attempts. Use a Firebase test number |
| Path B: price board error right after deploy | Firestore indexes still building (Firestore → Indexes) |
| Installed APK shows "App not installed" | Uninstall the older TIMBANG first (different signing key) |

If a build fails, copy the **last 40 lines** of the error and send them to me.
