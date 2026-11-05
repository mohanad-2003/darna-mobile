import 'package:darna/core/api/api_client.dart';
import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/features/account/account_screen.dart';
import 'package:darna/features/account/support_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/account_harness.dart';

final _packageInfo = packageInfoProvider.overrideWith(
  (ref) async => PackageInfo(appName: 'darna', packageName: 'ps.darna', version: '1.2.3', buildNumber: '45'),
);

Future<ProviderContainer> _open(
  WidgetTester tester,
  TestSession session, {
  List<Override> overrides = const [],
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size? size,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size ?? const Size(800, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(
    screen: const AccountScreen(),
    session: session,
    extraOverrides: [_packageInfo, ...overrides],
    themeMode: themeMode,
    textScale: textScale,
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AccountScreen)));
}

void main() {
  group('signed in', () {
    testWidgets('shows the profile card and the grouped options', (tester) async {
      await _open(tester, TestSession(user: userJson(fullName: 'سامي خليل', phone: '+970599111222')));

      expect(find.text('سامي خليل'), findsOneWidget);
      expect(find.text('+970599111222'), findsOneWidget);
      expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
      for (final title in ['نشاطي', 'إعدادات الحساب', 'المساعدة والمعلومات']) {
        expect(find.text(title), findsOneWidget);
      }
      for (final row in ['إعلاناتي', 'الاستفسارات', 'المظهر', 'تغيير رقم الهاتف', 'حذف الحساب', 'عن التطبيق', 'تسجيل الخروج']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('تلقائي (حسب الجهاز)'), findsOneWidget, reason: 'the current appearance is shown');
      expect(find.text('دارنا · الإصدار 1.2.3 (45)'), findsOneWidget);
      expect(find.text('أدوات الإشراف'), findsNothing, reason: 'not for ordinary users');
    });

    testWidgets('an account without a name is invited to add one', (tester) async {
      await _open(tester, TestSession(user: userJson(fullName: null)));
      expect(find.text('أضف اسمك'), findsOneWidget);
    });

    testWidgets('moderators and admins get the moderation tools', (tester) async {
      for (final role in ['MODERATOR', 'ADMIN']) {
        await _open(tester, TestSession(user: userJson(role: role)));
        expect(find.text('أدوات الإشراف'), findsOneWidget, reason: role);
        expect(find.text('مراجعة الإعلانات'), findsOneWidget);
        expect(find.text('البلاغات'), findsOneWidget);
        expect(find.text(role == 'ADMIN' ? 'مدير' : 'مشرف'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the options lead to their screens', (tester) async {
      Future<void> opens(String row, String page) async {
        await _open(tester, TestSession());
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
        expect(find.text(page), findsOneWidget, reason: row);
        await tester.pumpWidget(const SizedBox());
      }

      await opens('تعديل الملف الشخصي', 'profile-page');
      await opens('إعلاناتي', 'my-listings-page');
      await opens('الاستفسارات', 'inquiries-page');
      await opens('تغيير رقم الهاتف', 'phone-page');
      await opens('حذف الحساب', 'delete-page');
      await opens('عن التطبيق', 'about-page');
    });

    testWidgets('signing out calls the server and clears the session', (tester) async {
      final session = TestSession()..api.on('POST', '/auth/logout', (_) => <String, dynamic>{});
      final container = await _open(tester, session);

      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();

      expect(session.api.bodies.last, {'refreshToken': 'refresh-1'});
      expect(session.tokens.refresh, isNull);
      expect(container.read(authControllerProvider).value, isNull);
      expect(find.text('أهلاً بك في دارنا'), findsOneWidget, reason: 'the visitor view takes over');
    });
  });

  group('visitor', () {
    testWidgets('is invited to sign in and keeps the public options', (tester) async {
      await _open(tester, TestSession(signedIn: false));

      expect(find.text('أهلاً بك في دارنا'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('عن التطبيق'), findsOneWidget);
      for (final hidden in ['تعديل الملف الشخصي', 'تغيير رقم الهاتف', 'حذف الحساب', 'إعلاناتي', 'تسجيل الخروج']) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }

      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();
      expect(find.text('login-page'), findsOneWidget);
    });
  });

  group('help and information', () {
    testWidgets('shows only what the build is configured with', (tester) async {
      await _open(tester, TestSession());
      for (final absent in ['سياسة الخصوصية', 'شروط الاستخدام', 'الدعم والتواصل']) {
        expect(find.text(absent), findsNothing, reason: '$absent has no configured link');
      }
      expect(find.text('عن التطبيق'), findsOneWidget);
    });

    testWidgets('opens the configured links, and says so when nothing can open them', (tester) async {
      final opened = <Uri>[];
      var canOpen = true;
      final links = SupportLinks.parse(
        privacy: 'https://example.org/privacy',
        terms: 'https://example.org/terms',
        email: 'help@example.org',
        phone: '+970591234567',
        whatsapp: '0591234567',
      );
      await _open(tester, TestSession(), overrides: [
        supportLinksProvider.overrideWithValue(links),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return canOpen;
        }),
      ]);

      await tester.tap(find.text('سياسة الخصوصية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شروط الاستخدام'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://example.org/privacy'), Uri.parse('https://example.org/terms')]);

      // support: a sheet with each configured channel
      await tester.tap(find.text('الدعم والتواصل'));
      await tester.pumpAndSettle();
      expect(find.text('واتساب'), findsOneWidget);
      expect(find.text('اتصال هاتفي'), findsOneWidget);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      await tester.tap(find.text('واتساب'));
      await tester.pumpAndSettle();
      expect(opened.last, Uri.parse('https://wa.me/970591234567'));

      canOpen = false;
      await tester.tap(find.text('شروط الاستخدام'));
      await tester.pumpAndSettle();
      expect(find.text('تعذر فتح الرابط على هذا الجهاز'), findsOneWidget);
    });

    testWidgets('a partially configured support entry lists only the channels that exist', (tester) async {
      await _open(tester, TestSession(), overrides: [
        supportLinksProvider.overrideWithValue(SupportLinks.parse(email: 'help@example.org')),
      ]);
      await tester.tap(find.text('الدعم والتواصل'));
      await tester.pumpAndSettle();
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('واتساب'), findsNothing);
      expect(find.text('اتصال هاتفي'), findsNothing);
    });
  });

  group('configuration', () {
    test('keeps only usable values', () {
      final links = SupportLinks.parse(
        privacy: 'http://insecure.example.org/privacy',
        terms: 'not a url',
        email: 'nope',
        phone: '12',
        whatsapp: '',
      );
      expect(links.privacyPolicy, isNull, reason: 'https only');
      expect(links.terms, isNull);
      expect(links.email, isNull);
      expect(links.phone, isNull);
      expect(links.whatsapp, isNull);
      expect(links.hasContact, isFalse);
    });

    test('builds the launch links', () {
      final links = SupportLinks.parse(email: 'help@example.org', phone: '0591234567', whatsapp: '+970591234567');
      expect(links.emailUri.toString(), 'mailto:help@example.org');
      expect(links.phoneUri.toString(), 'tel:+970591234567');
      expect(links.whatsappUri.toString(), 'https://wa.me/970591234567');
    });

    test('nothing is configured by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final links = container.read(supportLinksProvider);
      expect(links.privacyPolicy, isNull);
      expect(links.terms, isNull);
      expect(links.hasContact, isFalse);
    });
  });

  group('layout', () {
    for (final signedIn in [true, false]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('fits a small screen with large text (${signedIn ? 'signed in' : 'visitor'}, ${mode.name})',
            (tester) async {
          await _open(
            tester,
            TestSession(signedIn: signedIn, user: userJson(role: 'ADMIN', fullName: 'اسم طويل جداً لاختبار تكبير الخط')),
            themeMode: mode,
            textScale: 2,
            size: const Size(320, 568),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('session handling for one-time-code failures', () {
    DioException unauthorized(Object? body) => DioException(
          requestOptions: RequestOptions(path: '/me/account-deletion/confirm'),
          response: Response(
            requestOptions: RequestOptions(path: '/me/account-deletion/confirm'),
            statusCode: 401,
            data: body,
          ),
        );

    test('a rejected access token is refreshed, a wrong code is not retried', () {
      expect(isRejectedAccessToken(unauthorized({'error': {'code': 'UNAUTHORIZED'}})), isTrue);
      expect(isRejectedAccessToken(unauthorized(null)), isTrue);
      for (final code in ['OTP_INVALID', 'OTP_EXPIRED', 'OTP_ATTEMPTS_EXCEEDED']) {
        expect(isRejectedAccessToken(unauthorized({'error': {'code': code}})), isFalse, reason: code);
      }
      expect(
        isRejectedAccessToken(DioException(
          requestOptions: RequestOptions(path: '/me'),
          response: Response(requestOptions: RequestOptions(path: '/me'), statusCode: 403),
        )),
        isFalse,
      );
    });
  });
}
