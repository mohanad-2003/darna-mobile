import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'router.dart';

/// Darna's teal, as in the logo and icon.
const _brandTeal = Color(0xFF0F766E);

class DarnaApp extends StatelessWidget {
  const DarnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'دارنا',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      // Arabic only for now; this also makes the whole UI right-to-left.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        colorScheme: ColorScheme.fromSeed(seedColor: _brandTeal, primary: _brandTeal, onPrimary: Colors.white),
        cardTheme: const CardThemeData(elevation: 1),
      ),
    );
  }
}
