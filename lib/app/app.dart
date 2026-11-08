import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/listings/pending_pick_gate.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_mode.dart';

class DarnaApp extends ConsumerWidget {
  const DarnaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // Takes the user back to the listing they were adding photos to if Android ended the app.
      builder: (context, child) => PendingPickGate(router: appRouter, child: child ?? const SizedBox.shrink()),
    );
  }
}
