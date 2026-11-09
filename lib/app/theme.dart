import 'package:flutter/material.dart';

/// Shared Darna identity: deep blue, warm ivory and restrained terracotta.
const brandPrimary = Color(0xFF234457);
const brandIvory = Color(0xFFFAF7F2);
const brandTerracotta = Color(0xFFBD7962);

class AppTheme {
  const AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: brandIvory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPrimary,
          primary: brandPrimary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE8EEF1),
          onPrimaryContainer: const Color(0xFF1C3748),
          secondary: const Color(0xFF96523D),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFF4E0D8),
          onSecondaryContainer: const Color(0xFF4C2C22),
          tertiary: brandTerracotta,
          onTertiary: const Color(0xFF182230),
          tertiaryContainer: const Color(0xFFF4E0D8),
          onTertiaryContainer: const Color(0xFF4C2C22),
          surface: Colors.white,
          onSurface: const Color(0xFF202B36),
          onSurfaceVariant: const Color(0xFF5F6972),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: brandIvory,
          surfaceContainer: const Color(0xFFF3F0EB),
          surfaceContainerHigh: const Color(0xFFECE9E4),
          surfaceContainerHighest: const Color(0xFFE5E2DD),
          outline: const Color(0xFF7A828B),
          outlineVariant: const Color(0xFFE4E5E7),
          surfaceTint: brandPrimary,
        ),
        cardTheme: const CardThemeData(elevation: 1, color: Colors.white, surfaceTintColor: Colors.transparent),
      );

  /// Blue-grey surfaces with a lighter primary for legibility in dark mode.
  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: const Color(0xFF111923),
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPrimary,
          brightness: Brightness.dark,
          primary: const Color(0xFFA6C7DC),
          onPrimary: const Color(0xFF111923),
          primaryContainer: const Color(0xFF234457),
          onPrimaryContainer: const Color(0xFFE8EEF1),
          secondary: const Color(0xFFE4AF9A),
          onSecondary: const Color(0xFF352019),
          secondaryContainer: const Color(0xFF4C342C),
          onSecondaryContainer: const Color(0xFFF4E0D8),
          tertiary: const Color(0xFFDCA28C),
          onTertiary: const Color(0xFF352019),
          tertiaryContainer: const Color(0xFF4C342C),
          onTertiaryContainer: const Color(0xFFF4E0D8),
          surface: const Color(0xFF1B2735),
          onSurface: const Color(0xFFF1F4F8),
          onSurfaceVariant: const Color(0xFFB5C0CD),
          surfaceContainerLowest: const Color(0xFF111923),
          surfaceContainerLow: const Color(0xFF17222F),
          surfaceContainer: const Color(0xFF1B2735),
          surfaceContainerHigh: const Color(0xFF233141),
          surfaceContainerHighest: const Color(0xFF2B3B4D),
          outline: const Color(0xFF8795A5),
          outlineVariant: const Color(0xFF354253),
          surfaceTint: const Color(0xFFA6C7DC),
        ),
        cardTheme: const CardThemeData(elevation: 0, color: Color(0xFF1B2735)),
      );
}
