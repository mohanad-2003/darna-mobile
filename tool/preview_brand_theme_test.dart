// Render the actual onboarding and empty-state widgets in the approved palette.
// flutter test tool/preview_brand_theme_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:darna/app/theme.dart';
import 'package:darna/core/widgets/darna_logo.dart';
import 'package:darna/core/widgets/empty_state.dart';
import 'package:darna/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('export approved brand screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fonts = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await fonts.load();

    Future<void> capture(String name, ThemeData theme, Widget screen) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: key, child: screen),
        ),
      ));
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image, key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('design/$name.png').writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    await capture('palette-onboarding', AppTheme.light(), OnboardingScreen(onComplete: () async {}));
    for (final dark in [false, true]) {
      await capture('palette-${dark ? 'dark' : 'light'}', dark ? AppTheme.dark() : AppTheme.light(), Scaffold(
        appBar: AppBar(title: const DarnaLogo(height: 34)),
        body: const EmptyStateView(
          illustration: EmptyStateIllustration.favorites,
          title: 'عقاراتك المفضلة تنتظرك',
          description: 'احفظ العقارات التي تعجبك لتعود إليها بسهولة.',
          actionLabel: 'تصفّح العقارات',
          onAction: _noop,
        ),
      ));
    }
  });
}

void _noop() {}
