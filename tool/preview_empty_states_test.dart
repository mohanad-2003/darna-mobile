// Render a review sheet: flutter test tool/preview_empty_states_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:darna/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('export empty states review sheet', (tester) async {
    tester.view.physicalSize = const Size(1170, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fonts = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await fonts.load();
    final key = GlobalKey();
    const titles = [
      'إعلانك الأول يبدأ من هنا',
      'عقاراتك المفضلة تنتظرك',
      'لم نجد عقارات بهذه المواصفات',
      'لا توجد إشعارات بعد',
      'لم يصلك أي استفسار بعد',
      'لا توجد إعلانات بانتظار المراجعة',
    ];
    const descriptions = [
      'أضف صور عقارك وتفاصيله ليصل إلى المهتمين.',
      'اضغط على القلب بجانب أي عقار يعجبك لتعود إليه بسهولة.',
      'جرّب توسيع نطاق البحث أو إزالة بعض الفلاتر.',
      'ستظهر هنا تحديثات إعلاناتك واستفسارات المهتمين.',
      'عندما يتواصل معك المهتمون بإعلاناتك، ستجد استفساراتهم هنا.',
      'ستظهر هنا الإعلانات الجديدة عندما تُرسل للمراجعة.',
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'Tajawal',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF234457),
            primary: const Color(0xFF234457),
          ),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Column(
                children: List.generate(
                  2,
                  (row) => Expanded(
                    child: Row(
                      children: List.generate(3, (column) {
                        final index = row * 3 + column;
                        return Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFE3EBE6),
                              ),
                            ),
                            child: EmptyStateView(
                              illustration:
                                  EmptyStateIllustration.values[index],
                              title: titles[index],
                              description: descriptions[index],
                              actionLabel: index < 3
                                  ? [
                                      'أضف إعلانك الأول',
                                      'تصفح العقارات',
                                      'عرض كل العقارات',
                                    ][index]
                                  : null,
                              onAction: index < 3 ? () {} : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('design/empty_states_preview.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
