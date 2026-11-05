import 'dart:async';

import 'package:darna/core/api/api_client.dart' show Json;
import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/features/account/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/account_harness.dart';

const _challenge = {'challengeId': 'c9', 'expiresInSeconds': 300, 'resendAfterSeconds': 30};
const _continue = 'متابعة وإرسال رمز التحقق';
const _deleteNow = 'حذف حسابي نهائياً';

Future<ProviderContainer> _open(WidgetTester tester, TestSession session) async {
  await tester.pumpWidget(testApp(screen: const DeleteAccountScreen(), session: session));
  await tester.pumpAndSettle();
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeleteAccountScreen)));
}

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label)).onPressed != null;

Future<void> _acknowledgeAndContinue(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.ensureVisible(find.text(_continue));
  await tester.tap(find.text(_continue));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _enterCodeAndDelete(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text(_deleteNow));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

TestSession _session() => TestSession()..api.on('POST', '/me/account-deletion/request', (_) => _challenge);

void main() {
  testWidgets('explains what happens and needs an explicit acknowledgement before anything is sent', (tester) async {
    final session = _session();
    await _open(tester, session);

    expect(find.text('حذف حسابك نهائياً'), findsOneWidget);
    expect(find.text('ما سيُحذف أو يتوقف'), findsOneWidget);
    expect(find.text('ما سيبقى'), findsOneWidget);
    expect(find.textContaining('إعلاناتك: تُؤرشف'), findsOneWidget);

    await tester.ensureVisible(find.text(_continue));
    expect(_enabled(tester, _continue), isFalse, reason: 'disabled until the box is ticked');
    await tester.tap(find.text(_continue), warnIfMissed: false);
    await tester.pump();
    expect(session.api.count('POST', '/me/account-deletion/request'), 0);

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(_enabled(tester, _continue), isTrue);
    expect(session.api.count('POST', '/me/account-deletion/confirm'), 0, reason: 'nothing deleted yet');
  });

  testWidgets('does not delete with a wrong code and keeps the account and session', (tester) async {
    final session = _session()
      ..api.on('POST', '/me/account-deletion/confirm', (_) => throw apiError(401, 'OTP_INVALID'));
    final container = await _open(tester, session);
    await _acknowledgeAndContinue(tester);
    expect(find.text('أكّد هويتك'), findsOneWidget);

    await _enterCodeAndDelete(tester, '000000');

    expect(find.text('رمز التحقق غير صحيح'), findsOneWidget);
    expect(find.text('تم حذف حسابك'), findsNothing);
    expect(container.read(authControllerProvider).value, isNotNull);
    expect(session.tokens.refresh, 'refresh-1');
  });

  testWidgets('a server failure never shows success and keeps the local session', (tester) async {
    final session = _session()
      ..api.on('POST', '/me/account-deletion/confirm', (_) => throw networkError());
    final container = await _open(tester, session);
    await _acknowledgeAndContinue(tester);

    await _enterCodeAndDelete(tester, '123456');

    expect(find.textContaining('تعذر الاتصال بالخادم'), findsOneWidget);
    expect(find.text('تم حذف حسابك'), findsNothing);
    expect(container.read(authControllerProvider).value, isNotNull);
    expect(session.tokens.access, 'access-1');
    expect(session.tokens.refresh, 'refresh-1');
  });

  testWidgets('the only admin is told to hand over the role', (tester) async {
    final session = _session()
      ..api.on('POST', '/me/account-deletion/confirm', (_) => throw apiError(409, 'LAST_ADMIN'));
    await _open(tester, session);
    await _acknowledgeAndContinue(tester);

    await _enterCodeAndDelete(tester, '123456');

    expect(find.textContaining('سلّم دور المدير'), findsOneWidget);
    expect(find.text('تم حذف حسابك'), findsNothing);
  });

  testWidgets('after the server confirms, the session is cleared and the result is shown', (tester) async {
    final session = _session()..api.on('POST', '/me/account-deletion/confirm', (_) => <String, dynamic>{});
    final container = await _open(tester, session);
    await _acknowledgeAndContinue(tester);

    await _enterCodeAndDelete(tester, '123456');

    expect(session.api.bodies.last, {'challengeId': 'c9', 'code': '123456'});
    expect(container.read(authControllerProvider).value, isNull, reason: 'signed out');
    expect(session.tokens.access, isNull);
    expect(session.tokens.refresh, isNull);
    expect(find.text('تم حذف حسابك'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing, reason: 'nothing to go back to');
  });

  testWidgets('a double tap sends one deletion request', (tester) async {
    final response = Completer<Json>();
    final session = _session()..api.on('POST', '/me/account-deletion/confirm', (_) => response.future);
    await _open(tester, session);
    await _acknowledgeAndContinue(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text(_deleteNow));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(session.api.count('POST', '/me/account-deletion/confirm'), 1);

    response.complete(<String, dynamic>{});
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تم حذف حسابك'), findsOneWidget);
  });

  testWidgets('back from the code step returns to the explanation', (tester) async {
    final session = _session();
    await _open(tester, session);
    await _acknowledgeAndContinue(tester);
    expect(find.text('أكّد هويتك'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('حذف حسابك نهائياً'), findsOneWidget);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('fits a small screen with large text (${mode.name})', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(640, 1136);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(testApp(
        screen: const DeleteAccountScreen(),
        session: _session(),
        themeMode: mode,
        textScale: 2,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
