# دارنا · Darna (mobile)

Flutter app for a Palestinian property marketplace (sale and rent). Arabic, right-to-left.
Android first; iOS builds from the same code.

## What it does

- Browse and filter listings without an account
- Sign in with a phone number and a one-time code (no passwords)
- Favorites, contact reveal and in-app inquiries
- Create a listing with photos, submit it for review, and manage it afterwards
- Notifications (review decisions, new inquiries)
- Review queue for moderators

## Run it

Requires Flutter 3.x and a running Darna backend (a separate, private repository).

```bash
flutter pub get

# Android emulator: the host machine is 10.0.2.2 (this is the default)
flutter run

# Real device on the same network: use the computer's LAN address
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1
```

## Release builds (Android)

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<public host>/api/v1
```

A release build is refused unless all of this holds:

- `API_BASE_URL` is an `https://` address on a public host. There is no default in release:
  the emulator address (`10.0.2.2`), `localhost`, private LAN ranges, `http://` and URLs with
  credentials are rejected by the Gradle build (`verifyReleaseConfig` in
  `android/app/build.gradle.kts`) and, as a backstop on every platform, when the app starts
  (`AppConfig.ensureValid`).
- `android/key.properties` exists with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`
  (`storeFile` is relative to `android/app` or absolute). The file and the keystore are git-ignored;
  never commit them. Release builds are never signed with the debug key.

Android permissions: the main manifest declares `INTERNET` and `usesCleartextTraffic="false"`;
only the debug manifest allows plain HTTP, for the local backend.

Android `applicationId` is `com.darna.app` (`android/app/build.gradle.kts`); it cannot change once the
app is published on Google Play. The code package (`namespace`, `MainActivity`) is still `com.example.darna`
on purpose. Still to set before an iOS release: the bundle identifier, which is still `com.example.darna`.
