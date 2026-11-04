import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'theme_mode';

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'تلقائي (حسب الجهاز)',
      ThemeMode.light => 'فاتح',
      ThemeMode.dark => 'داكن',
    };

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// The appearance the user picked. Follows the device until they choose, and remembers
/// the choice between launches.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final stored = (await SharedPreferences.getInstance()).getString(_key);
      final mode = ThemeMode.values.where((m) => m.name == stored).firstOrNull;
      if (mode != null && mode != state) state = mode;
    } catch (_) {
      // Storage unavailable: keep following the device.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}
