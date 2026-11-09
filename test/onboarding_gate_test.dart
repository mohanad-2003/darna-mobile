import 'package:darna/features/auth/login_screen.dart';
import 'package:darna/features/onboarding/onboarding_gate.dart';
import 'package:darna/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/account_harness.dart';

const _key = 'darna_onboarding_v1_completed';

Future<void> _launch(
  WidgetTester tester, {
  required bool onboarded,
  required bool signedIn,
}) async {
  SharedPreferences.setMockInitialValues({if (onboarded) _key: true});
  OnboardingGate.resetForTest();
  await tester.pumpWidget(testApp(
    screen: const SizedBox(),
    session: TestSession(signedIn: signedIn),
    home: const OnboardingGate(child: Scaffold(body: Text('app-home'))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first launch shows the slides, then the login screen', (tester) async {
    await _launch(tester, onboarded: false, signedIn: false);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('app-home'), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool(_key), true);
  });

  testWidgets('later launch skips the slides and opens the login screen', (tester) async {
    await _launch(tester, onboarded: true, signedIn: false);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('guest browsing continues into the app', (tester) async {
    await _launch(tester, onboarded: true, signedIn: false);
    await tester.tap(find.text('تصفح كزائر'));
    await tester.pumpAndSettle();
    expect(find.text('app-home'), findsOneWidget);
  });

  testWidgets('a stored session goes straight to the app after the slides were seen', (tester) async {
    await _launch(tester, onboarded: true, signedIn: true);
    expect(find.text('app-home'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('first launch with a stored session still shows the slides once', (tester) async {
    await _launch(tester, onboarded: false, signedIn: true);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.text('app-home'), findsOneWidget);
  });
}
