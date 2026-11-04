import 'package:flutter/material.dart';

/// Darna's teal, as in the logo and icon.
const brandTeal = Color(0xFF0F766E);

class AppTheme {
  const AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        colorScheme: ColorScheme.fromSeed(seedColor: brandTeal, primary: brandTeal, onPrimary: Colors.white),
        cardTheme: const CardThemeData(elevation: 1),
      );

  /// Dark surfaces tinted with the brand green. The primary is derived from the same seed
  /// but lighter, because the exact brand teal is too dim to read on a dark background.
  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        colorScheme: ColorScheme.fromSeed(seedColor: brandTeal, brightness: Brightness.dark),
        cardTheme: const CardThemeData(elevation: 0),
      );
}
