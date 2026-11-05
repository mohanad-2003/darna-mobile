import 'dart:async';

import 'package:darna/core/api/api_client.dart' show Json;
import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/features/account/profile_edit_screen.dart';
import 'package:darna/features/account/profile_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/account_harness.dart';

const _save = 'حفظ التغييرات';

Future<ProviderContainer> _open(
  WidgetTester tester,
  TestSession session, {
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(testApp(
    screen: const ProfileEditScreen(),
    session: session,
    themeMode: themeMode,
    textScale: textScale,
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ProfileEditScreen)));
}

Finder get _nameField => find.byType(TextFormField).at(0);
Finder get _emailField => find.byType(TextFormField).at(1);
Finder get _saveButton => find.widgetWithText(FilledButton, _save);
bool _saveEnabled(WidgetTester tester) => tester.widget<FilledButton>(_saveButton).onPressed != null;

void main() {
  group('validation', () {
    test('name: 2 to 120 characters after trimming', () {
      expect(validateFullName(''), isNotNull);
      expect(validateFullName('   '), isNotNull);
      expect(validateFullName(' ا '), isNotNull);
      expect(validateFullName('سامي'), isNull);
      expect(validateFullName('  سامي  '), isNull);
      expect(validateFullName('ا' * 120), isNull);
      expect(validateFullName('ا' * 121), isNotNull);
    });

    test('email: optional, but must look like one', () {
      expect(validateEmail(''), isNull);
      expect(validateEmail('   '), isNull);
      expect(validateEmail('name@example.com'), isNull);
      expect(validateEmail(' Name.Last+tag@Example.co.ps '), isNull);
      expect(validateEmail('name'), isNotNull);
      expect(validateEmail('name@'), isNotNull);
      expect(validateEmail('name@example'), isNotNull);
      expect(validateEmail('na me@example.com'), isNotNull);
      expect(validateEmail('a..b@example.com'), isNotNull);
      expect(validateEmail('${'a' * 250}@b.co'), isNotNull);
    });
  });

  testWidgets('starts with the current data and saves only valid changes', (tester) async {
    final session = TestSession(user: userJson(email: 'sami@example.com'));
    await _open(tester, session);

    expect(find.text('سامي خليل'), findsWidgets);
    expect(find.text('sami@example.com'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse, reason: 'nothing changed yet');

    // a different but invalid name: the message appears beside the field
    await tester.enterText(_nameField, ' ا ');
    await tester.pump();
    expect(find.text('الاسم قصير جداً، أدخل حرفين على الأقل'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(_nameField, 'سامي أحمد');
    await tester.pump();
    expect(find.text('الاسم قصير جداً، أدخل حرفين على الأقل'), findsNothing);
    expect(_saveEnabled(tester), isTrue);

    await tester.enterText(_emailField, 'not-an-email');
    await tester.pump();
    expect(find.text('صيغة البريد الإلكتروني غير صحيحة، مثل name@example.com'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);

    // typing the same values back means there is nothing to save again
    await tester.enterText(_nameField, 'سامي خليل');
    await tester.enterText(_emailField, 'SAMI@example.com');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('saving sends one request, shows progress, then updates the account everywhere', (tester) async {
    final session = TestSession();
    final response = Completer<Json>();
    session.api.on('PATCH', '/me', (_) => response.future);
    final container = await _open(tester, session);

    await tester.enterText(_nameField, 'سامي أحمد');
    await tester.pump();
    await tester.tap(_saveButton);
    await tester.pump();

    // in flight: progress is shown and a second tap cannot send a duplicate
    expect(find.text('جارٍ الحفظ…'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
    await tester.tap(find.text('جارٍ الحفظ…'), warnIfMissed: false);
    await tester.pump();
    expect(session.api.count('PATCH', '/me'), 1);
    expect(session.api.bodies.last, {'fullName': 'سامي أحمد'}, reason: 'only what changed is sent');

    response.complete({'data': userJson(fullName: 'سامي أحمد')});
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider).value?.fullName, 'سامي أحمد');
    expect(find.byType(ProfileEditScreen), findsNothing, reason: 'closed after saving');
    expect(find.text('تم حفظ التغييرات'), findsOneWidget);
  });

  testWidgets('clearing the email sends null', (tester) async {
    final session = TestSession(user: userJson(email: 'sami@example.com'));
    session.api.on('PATCH', '/me', (_) => {'data': userJson()});
    await _open(tester, session);

    await tester.enterText(_emailField, '');
    await tester.pump();
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    expect(session.api.bodies.last, {'email': null});
  });

  testWidgets('a connection failure keeps what was typed and can be retried', (tester) async {
    final session = TestSession();
    var attempts = 0;
    session.api.on('PATCH', '/me', (_) {
      attempts++;
      if (attempts == 1) throw networkError();
      return {'data': userJson(fullName: 'سامي أحمد')};
    });
    final container = await _open(tester, session);

    await tester.enterText(_nameField, 'سامي أحمد');
    await tester.pump();
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذر الاتصال بالخادم'), findsOneWidget);
    expect(find.textContaining('ما كتبته محفوظ هنا'), findsOneWidget);
    expect(find.text('سامي أحمد'), findsOneWidget, reason: 'the input is kept');
    expect(find.byType(ProfileEditScreen), findsOneWidget, reason: 'the screen stays open');
    expect(container.read(authControllerProvider).value?.fullName, 'سامي خليل', reason: 'nothing changed locally');
    expect(_saveEnabled(tester), isTrue);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(container.read(authControllerProvider).value?.fullName, 'سامي أحمد');
    expect(find.byType(ProfileEditScreen), findsNothing);
  });

  testWidgets('an email used by another account is reported beside the email field', (tester) async {
    final session = TestSession();
    session.api.on('PATCH', '/me', (_) => throw apiError(409, 'EMAIL_IN_USE'));
    await _open(tester, session);

    await tester.enterText(_emailField, 'taken@example.com');
    await tester.pump();
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    expect(find.text('هذا البريد الإلكتروني مستخدم في حساب آخر'), findsOneWidget);
    expect(find.text('taken@example.com'), findsOneWidget);

    // editing the field clears the server's complaint
    await tester.enterText(_emailField, 'other@example.com');
    await tester.pump();
    expect(find.text('هذا البريد الإلكتروني مستخدم في حساب آخر'), findsNothing);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('leaving with unsaved changes asks first; leaving a clean form does not', (tester) async {
    final session = TestSession();
    await _open(tester, session);

    // nothing changed: back simply leaves
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsNothing);

    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField, 'اسم جديد');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('تجاهل التغييرات؟'), findsOneWidget);
    expect(find.byType(ProfileEditScreen), findsOneWidget);

    // keep editing: the dialog closes, the text is still there
    await tester.tap(find.text('متابعة التعديل'));
    await tester.pumpAndSettle();
    expect(find.text('تجاهل التغييرات؟'), findsNothing);
    expect(find.text('اسم جديد'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجاهل'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsNothing);
    expect(session.api.count('PATCH', '/me'), 0);
  });

  for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
    testWidgets('fits a small screen with large text and the keyboard open (${mode.name})', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(640, 1136) // 320 x 568
        ..viewInsets = const FakeViewPadding(bottom: 500);
      addTearDown(tester.view.reset);

      await _open(tester, TestSession(), themeMode: mode, textScale: 2);
      await tester.enterText(_nameField, 'اسم طويل جداً جداً جداً لاختبار اللف');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
