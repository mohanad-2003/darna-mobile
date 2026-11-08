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

Still to set before publishing: the final `applicationId` in `android/app/build.gradle.kts`
(still the `com.example.darna` placeholder; the build warns about it) and the iOS bundle identifier.

## Layout

```text
lib/
  app/         theme, router
  core/        API client, auth/session, shared helpers
  features/    auth, properties, listings, inquiries, notifications, admin, account
test/          unit tests
```

State is managed with Riverpod, navigation with go_router. The API client refreshes the
session automatically and retries the request once.

```bash
flutter analyze
flutter test
```

## Notes

No secrets live in this repository: the app only knows the backend's public address.
