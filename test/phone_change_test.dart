import 'dart:async';

import 'package:darna/core/api/api_client.dart' show Json;
import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/features/account/phone_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/account_harness.dart';

const _challenge = {'challengeId': 'c1', 'expiresInSeconds': 300, 'resendAfterSeconds': 30};
const _newNumber = '+970599333444';

Future<ProviderContainer> _open(WidgetTester tester, TestSession session) async {
  await tester.pumpWidget(testApp(screen: const PhoneChangeScreen(), session: session));
  await tester.pumpAndSettle();
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PhoneChangeScreen)));
}

Future<void> _sendCodeTo(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.tap(find.text('إرسال رمز التحقق'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _typeCodeAndConfirm(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text('تأكيد وتغيير الرقم'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

TestSession _session() => TestSession()..api.on('POST', '/me/phone-change/request', (_) => _challenge);

void main() {
  testWidgets('rejects a malformed number and the current number without calling the server', (tester) async {
    final session = _session();
    await _open(tester, session);

    await _sendCodeTo(tester, '123');
    expect(find.text('أدخل رقم هاتف صحيحاً، مثل 0599123456'), findsOneWidget);

    await _sendCodeTo(tester, '0599 111 222'); // the account's own number, written locally
    expect(find.text('هذا هو رقمك الحالي، أدخل الرقم الجديد'), findsOneWidget);

    expect(session.api.count('POST', '/me/phone-change/request'), 0);
  });

  testWidgets('asks for a code first and keeps the old number until it is verified', (tester) async {
    final session = _session();
    final container = await _open(tester, session);

    await _sendCodeTo(tester, '0599 333 444');
    expect(session.api.bodies.last, {'phone': _newNumber}, reason: 'the number is sent as E.164');
    expect(find.text('أكّد رقمك الجديد'), findsOneWidget);
    expect(find.text('تأكيد وتغيير الرقم'), findsOneWidget);

    // asking for the code did not touch the account
    expect(container.read(authControllerProvider).value?.phone, '+970599111222');
    expect(session.api.count('POST', '/me/phone-change/confirm'), 0);
  });

  testWidgets('a number used by another account is explained and no code step starts', (tester) async {
    final session = TestSession()
      ..api.on('POST', '/me/phone-change/request', (_) => throw apiError(409, 'PHONE_IN_USE'));
    final container = await _open(tester, session);

    await _sendCodeTo(tester, '0599 333 444');

    expect(find.textContaining('هذا الرقم مرتبط بحساب آخر'), findsOneWidget);
    expect(find.text('أكّد رقمك الجديد'), findsNothing);
    expect(find.text('إرسال رمز التحقق'), findsOneWidget, reason: 'still on the number step');
    expect(container.read(authControllerProvider).value?.phone, '+970599111222');
    // the only mention of merging is the note that accounts are never merged
    expect(find.textContaining('لا يتم دمج الحسابات'), findsOneWidget);
  });

  testWidgets('a connection failure when sending the code is reported and can be retried', (tester) async {
    var attempts = 0;
    final session = TestSession()
      ..api.on('POST', '/me/phone-change/request', (_) {
        attempts++;
        if (attempts == 1) throw networkError();
        return _challenge;
      });
    await _open(tester, session);

    await _sendCodeTo(tester, '0599 333 444');
    expect(find.textContaining('تعذر الاتصال بالخادم'), findsOneWidget);
    expect(find.text('0599 333 444'), findsOneWidget, reason: 'the number stays in the field');

    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('أكّد رقمك الجديد'), findsOneWidget);
  });

  testWidgets('a wrong code leaves the account on its old number', (tester) async {
    final session = _session()
      ..api.on('POST', '/me/phone-change/confirm', (_) => throw apiError(401, 'OTP_INVALID'));
    final container = await _open(tester, session);
    await _sendCodeTo(tester, '0599 333 444');

    await _typeCodeAndConfirm(tester, '000000');

    expect(find.text('رمز التحقق غير صحيح'), findsOneWidget);
    expect(container.read(authControllerProvider).value?.phone, '+970599111222');
    expect(session.tokens.access, 'access-1', reason: 'the session is untouched');
    expect(find.text('تم تغيير رقم هاتفك'), findsNothing);
  });

  testWidgets('a verified code moves the account, replaces the session and confirms', (tester) async {
    final session = _session()
      ..api.on('POST', '/me/phone-change/confirm', (_) => {
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
            'user': userJson(phone: _newNumber),
          });
    final container = await _open(tester, session);
    await _sendCodeTo(tester, '0599 333 444');

    await _typeCodeAndConfirm(tester, '123456');

    expect(session.api.bodies.last, {'phone': _newNumber, 'challengeId': 'c1', 'code': '123456'});
    expect(container.read(authControllerProvider).value?.phone, _newNumber);
    expect(session.tokens.access, 'access-2');
    expect(session.tokens.refresh, 'refresh-2');
    expect(find.text('تم تغيير رقم هاتفك'), findsOneWidget);

    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneChangeScreen), findsNothing);
  });

  testWidgets('tapping confirm twice sends the code once', (tester) async {
    final response = Completer<Json>();
    final session = _session()..api.on('POST', '/me/phone-change/confirm', (_) => response.future);
    await _open(tester, session);
    await _sendCodeTo(tester, '0599 333 444');

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('تأكيد وتغيير الرقم'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(session.api.count('POST', '/me/phone-change/confirm'), 1);

    response.complete({'accessToken': 'a', 'refreshToken': 'r', 'user': userJson(phone: _newNumber)});
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تم تغيير رقم هاتفك'), findsOneWidget);
  });

  testWidgets('back from the code step returns to the number instead of leaving', (tester) async {
    final session = _session();
    await _open(tester, session);
    await _sendCodeTo(tester, '0599 333 444');
    expect(find.text('أكّد رقمك الجديد'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhoneChangeScreen), findsOneWidget);
    expect(find.text('ما رقمك الجديد؟'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneChangeScreen), findsNothing);
  });
}
