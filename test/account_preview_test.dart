// Renders the account screens to PNG files for design review. Skipped in normal runs:
//
//   WRITE_PREVIEWS=1 flutter test --no-pub --update-goldens test/account_preview_test.dart
//
// The images land in test/previews/. Links and numbers shown in them are sample values.
import 'dart:io';

import 'package:darna/features/account/about_screen.dart';
import 'package:darna/features/account/account_screen.dart';
import 'package:darna/features/account/delete_account_screen.dart';
import 'package:darna/features/account/phone_change_screen.dart';
import 'package:darna/features/account/profile_edit_screen.dart';
import 'package:darna/features/account/support_links.dart';
import 'package:darna/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/account_harness.dart';

final _enabled = Platform.environment['WRITE_PREVIEWS'] == '1';

final _packageInfo = packageInfoProvider.overrideWith(
  (ref) async => PackageInfo(appName: 'darna', packageName: 'ps.darna', version: '1.0.0', buildNumber: '1'),
);

final _sampleLinks = supportLinksProvider.overrideWithValue(SupportLinks.parse(
  privacy: 'https://example.org/privacy',
  terms: 'https://example.org/terms',
  email: 'help@example.org',
  phone: '+970591234567',
  whatsapp: '+970591234567',
));

Future<void> _loadFonts() async {
  final tajawal = FontLoader('Tajawal');
  for (final file in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('assets/fonts/Tajawal-$file.ttf').readAsBytesSync();
    tajawal.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await tajawal.load();
  // The Material icon font ships with the Flutter SDK, not with the app.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = flutterRoot == null
      ? null
      : File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

Future<void> _settle(WidgetTester tester) async {
  // Let image assets decode (real async work), then finish animations.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget screen, {
  required ThemeMode mode,
  required TestSession session,
  Size size = const Size(390, 844),
  List<Override> overrides = const [],
  Future<void> Function()? interact,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = size * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(
    screen: screen,
    session: session,
    themeMode: mode,
    extraOverrides: [_packageInfo, ...overrides],
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  await interact?.call();
  await _settle(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('previews/$name.png'));
}

void main() {
  setUpAll(_loadFonts);

  const modes = {'light': ThemeMode.light, 'dark': ThemeMode.dark};

  for (final entry in modes.entries) {
    final suffix = entry.key;
    final mode = entry.value;

    testWidgets('account signed in ($suffix)', (tester) async {
      await _shot(tester, 'account_signed_in_$suffix', const AccountScreen(),
          mode: mode, session: TestSession(), size: const Size(390, 1180));
    }, skip: !_enabled);

    testWidgets('account signed in with links ($suffix)', (tester) async {
      await _shot(tester, 'account_signed_in_configured_$suffix', const AccountScreen(),
          mode: mode,
          session: TestSession(user: userJson(role: 'MODERATOR')),
          overrides: [_sampleLinks],
          size: const Size(390, 1500));
    }, skip: !_enabled);

    testWidgets('account visitor ($suffix)', (tester) async {
      await _shot(tester, 'account_visitor_$suffix', const AccountScreen(),
          mode: mode, session: TestSession(signedIn: false), size: const Size(390, 900));
    }, skip: !_enabled);

    testWidgets('profile edit ($suffix)', (tester) async {
      await _shot(tester, 'profile_edit_$suffix', const ProfileEditScreen(),
          mode: mode, session: TestSession(user: userJson(email: 'sami@example.com')), interact: () async {
        await tester.enterText(find.byType(TextFormField).at(0), 'سامي أحمد خليل');
        await tester.pump();
      });
    }, skip: !_enabled);

    testWidgets('profile edit with errors ($suffix)', (tester) async {
      final session = TestSession();
      session.api.on('PATCH', '/me', (_) => throw networkError());
      await _shot(tester, 'profile_edit_errors_$suffix', const ProfileEditScreen(), mode: mode, session: session,
          interact: () async {
        await tester.enterText(find.byType(TextFormField).at(0), 'سامي أحمد');
        await tester.enterText(find.byType(TextFormField).at(1), 'sami@');
        await tester.pump();
        await tester.tap(find.byType(TextFormField).at(1));
        await tester.pump();
      });
    }, skip: !_enabled);

    testWidgets('phone change ($suffix)', (tester) async {
      final session = TestSession();
      session.api.on('POST', '/me/phone-change/request',
          (_) => {'challengeId': 'c1', 'expiresInSeconds': 300, 'resendAfterSeconds': 30});
      await _shot(tester, 'phone_change_number_$suffix', const PhoneChangeScreen(), mode: mode, session: session);
      await _shot(tester, 'phone_change_code_$suffix', const PhoneChangeScreen(), mode: mode, session: session,
          interact: () async {
        await tester.enterText(find.byType(TextField), '0599 333 444');
        await tester.tap(find.text('إرسال رمز التحقق'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pump();
      });
    }, skip: !_enabled);

    testWidgets('delete account ($suffix)', (tester) async {
      final session = TestSession();
      session.api.on('POST', '/me/account-deletion/request',
          (_) => {'challengeId': 'c9', 'expiresInSeconds': 300, 'resendAfterSeconds': 30});
      await _shot(tester, 'delete_account_explain_$suffix', const DeleteAccountScreen(),
          mode: mode, session: session, size: const Size(390, 1100));
      await _shot(tester, 'delete_account_code_$suffix', const DeleteAccountScreen(), mode: mode, session: session,
          size: const Size(390, 844), interact: () async {
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.ensureVisible(find.text('متابعة وإرسال رمز التحقق'));
        await tester.tap(find.text('متابعة وإرسال رمز التحقق'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(find.byType(TextField), '12');
        await tester.pump();
      });
    }, skip: !_enabled);
  }

  for (final entry in modes.entries) {
    testWidgets('login (${entry.key})', (tester) async {
      await _shot(tester, 'login_${entry.key}', const LoginScreen(), mode: entry.value, session: TestSession(signedIn: false));
    }, skip: !_enabled);
  }

  testWidgets('about', (tester) async {
    await _shot(tester, 'about_light', const AboutScreen(),
        mode: ThemeMode.light, session: TestSession(), overrides: [_sampleLinks]);
  }, skip: !_enabled);
}
