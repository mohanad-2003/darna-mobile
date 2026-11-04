import 'package:darna/app/theme.dart';
import 'package:darna/app/theme_mode.dart';
import 'package:darna/core/widgets/dark_svg_colors.dart';
import 'package:darna/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('theme mode', () {
    test('follows the device until the user chooses', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('restores the saved choice and saves new ones', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(themeModeProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await container.read(themeModeProvider.notifier).set(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect((await SharedPreferences.getInstance()).getString('theme_mode'), 'light');
    });

    test('ignores a stored value it does not know', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('themes', () {
    test('light keeps the exact brand teal; dark is a real dark scheme', () {
      expect(AppTheme.light().colorScheme.primary, brandTeal);
      final dark = AppTheme.dark().colorScheme;
      expect(dark.brightness, Brightness.dark);
      // Readable on dark surfaces: the primary must be lighter than the surface.
      expect(dark.primary.computeLuminance(), greaterThan(dark.surface.computeLuminance() + 0.1));
    });
  });

  group('empty-state illustrations in dark mode', () {
    test('pale fills become dark, teal is lifted, strokes on teal are untouched', () {
      const map = DarkSvgColors();
      Color sub(String attr, int argb) => map.substitute(null, 'path', attr, Color(argb));

      expect(sub('fill', 0xFFF0F6F3), isNot(const Color(0xFFF0F6F3)));
      expect(sub('fill', 0xFFF0F6F3).computeLuminance(), lessThan(0.05));
      expect(sub('fill', 0xFF0F766E), const Color(0xFF2A9D8F));
      expect(sub('stroke', 0xFFFAF6F1), const Color(0xFFFAF6F1)); // cream line on a teal shape
      expect(sub('fill', 0xFFFAF6F1), isNot(const Color(0xFFFAF6F1))); // cream paper is dimmed
      expect(sub('fill', 0xFF123456), const Color(0xFF123456)); // unknown colours pass through
    });

    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'} theme recolours only in dark', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const Scaffold(
            body: EmptyStateView(
              illustration: EmptyStateIllustration.favorites,
              title: 'لا شيء هنا',
              description: 'وصف',
            ),
          ),
        ));
        await tester.pump();
        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        final mapper = (picture.bytesLoader as SvgAssetLoader).colorMapper;
        expect(mapper != null, dark);
      });
    }
  });
}
