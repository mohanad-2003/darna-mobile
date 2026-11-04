import 'package:darna/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: TextDirection.rtl, child: child!),
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('each illustration loads and primary action runs', (
    tester,
  ) async {
    var actions = 0;
    for (final illustration in EmptyStateIllustration.values) {
      await tester.pumpWidget(
        app(
          EmptyStateView(
            illustration: illustration,
            title: 'لا توجد عناصر بعد',
            description: 'ستظهر العناصر هنا عندما تصبح متاحة.',
            actionLabel: 'تصفح العقارات',
            onAction: () => actions++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      await tester.tap(find.text('تصفح العقارات'));
      expect(tester.takeException(), isNull);
    }
    expect(actions, EmptyStateIllustration.values.length);
  });

  testWidgets('empty content supports pull to refresh', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      app(
        EmptyStateView(
          illustration: EmptyStateIllustration.notifications,
          title: 'لا توجد إشعارات بعد',
          description: 'ستظهر التحديثات هنا.',
          onRefresh: () async {
            refreshes++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  testWidgets('small viewport and large Arabic text can scroll to action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var actions = 0;
    await tester.pumpWidget(
      app(
        EmptyStateView(
          illustration: EmptyStateIllustration.listings,
          title: 'إعلانك الأول يبدأ من هنا',
          description:
              'لم تنشر أي إعلان بعد. أضف صور عقارك وتفاصيله ليصل إلى المهتمين.',
          actionLabel: 'أضف إعلانك الأول',
          onAction: () => actions++,
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    expect(actions, 1);
    expect(tester.takeException(), isNull);
  });
}
