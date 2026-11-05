import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/features/listings/listing_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Anon extends AuthController {
  @override
  Future<Me?> build() async => null;
}

Widget _app() => ProviderScope(
      overrides: [authControllerProvider.overrideWith(_Anon.new)],
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: const ListingFormScreen()),
      ),
    );

void main() {
  testWidgets('starts on the first of three steps with only "next" available', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('الأساسيات'), findsOneWidget);
    expect(find.text('التفاصيل'), findsOneWidget);
    expect(find.text('التواصل'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
    expect(find.text('السابق'), findsNothing);
  });

  testWidgets('does not move on while the step has problems', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('التالي'));
    await tester.pump();

    expect(find.text('العنوان قصير (5 أحرف على الأقل)'), findsOneWidget);
    expect(find.text('الوصف قصير (20 حرفاً على الأقل)'), findsOneWidget);
    expect(find.text('اختر الموقع'), findsOneWidget);
    expect(find.text('السابق'), findsNothing); // still on step one
  });

  testWidgets('later steps cannot be jumped to by tapping their headers', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('التواصل'));
    await tester.pump();
    expect(find.text('السابق'), findsNothing);
  });
}
