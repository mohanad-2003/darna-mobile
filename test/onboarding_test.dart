import 'package:darna/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('walks through the three slides and finishes on the last', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: OnboardingScreen(onComplete: () async => finished++),
      ),
    ));
    await tester.pump();

    expect(find.text('دارك أقرب مما تتخيّل'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('احفظ ما يعجبك، وتواصل'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('اعرض عقارك بخطوات بسيطة'), findsOneWidget);
    expect(find.text('ابدأ الآن'), findsOneWidget);
    expect(finished, 0);

    await tester.tap(find.text('ابدأ الآن'));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('skip finishes immediately', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: OnboardingScreen(onComplete: () async => finished++),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });
}
