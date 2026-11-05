import 'package:darna/core/api/api_exception.dart';
import 'package:darna/core/widgets/illustration.dart';
import 'package:darna/features/listings/submitted_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)));

Finder _art(StateArt art) => find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == art.asset);

void main() {
  test('every illustration is bundled', () async {
    for (final art in StateArt.values) {
      final data = await rootBundle.load(art.asset);
      expect(data.lengthInBytes, greaterThan(1000), reason: art.asset);
      // They are shipped light: a regression to the 1 MB originals would bloat the app.
      expect(data.lengthInBytes, lessThan(200 * 1024), reason: art.asset);
    }
  });

  group('ErrorStateView.from', () {
    testWidgets('no connection: offline art and a retry button', (tester) async {
      var retried = 0;
      final error = ApiException(status: 0, code: 'NETWORK', message: 'تعذر الاتصال بالخادم');
      await tester.pumpWidget(_wrap(ErrorStateView.from(error, onRetry: () => retried++)));
      await tester.pump();

      expect(find.text('تعذر الاتصال بالخادم'), findsOneWidget);
      expect(_art(StateArt.offline), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, 1);
    });

    testWidgets('a listing that is gone: "unavailable" art, no pointless retry', (tester) async {
      var back = 0;
      final error = ApiException(status: 404, code: 'PROPERTY_NOT_FOUND', message: 'x');
      await tester.pumpWidget(_wrap(ErrorStateView.from(error, onRetry: () {}, onBack: () => back++)));
      await tester.pump();

      expect(_art(StateArt.unavailable), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
      await tester.tap(find.text('العودة'));
      expect(back, 1);
    });

    testWidgets('other server errors: the message and a retry, without art', (tester) async {
      final error = ApiException(status: 500, code: 'INTERNAL_ERROR', message: 'حدث خطأ في الخادم');
      await tester.pumpWidget(_wrap(ErrorStateView.from(error, onRetry: () {})));
      await tester.pump();

      expect(find.text('حدث خطأ في الخادم'), findsOneWidget);
      expect(find.byType(ClayIllustration), findsNothing);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('an unknown error is treated like a lost connection', (tester) async {
      await tester.pumpWidget(_wrap(ErrorStateView.from(StateError('boom'), onRetry: () {})));
      await tester.pump();
      expect(_art(StateArt.offline), findsOneWidget);
    });
  });

  testWidgets('the submitted dialog appears and closes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(child: TextButton(onPressed: () => showSubmittedDialog(context), child: const Text('open'))),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('تم إرسال إعلانك للمراجعة'), findsOneWidget);
    expect(_art(StateArt.submitted), findsOneWidget);

    await tester.tap(find.text('حسناً'));
    await tester.pumpAndSettle();
    expect(find.text('تم إرسال إعلانك للمراجعة'), findsNothing);
  });
}
