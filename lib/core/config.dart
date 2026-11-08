import 'package:flutter/foundation.dart';

class AppConfig {
  /// Backend base URL.
  ///
  /// Debug and profile builds default to 10.0.2.2, the host machine as seen from the Android
  /// emulator. On a real device pass the computer's LAN address:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1
  ///
  /// Release builds have no default: they must be given a public `https://` address, e.g.
  ///   flutter build appbundle --dart-define=API_BASE_URL=https://api.example.com/api/v1
  /// ([ensureValid] stops a release build that was not, and the Android Gradle build checks the
  /// same rule before packaging).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? '' : 'http://10.0.2.2:3000/api/v1',
  );

  /// Throws if [apiBaseUrl] is not acceptable for the current build mode. Call it before the app starts.
  static void ensureValid() {
    final problem = validate(apiBaseUrl, release: kReleaseMode);
    if (problem != null) throw StateError('API_BASE_URL: $problem');
  }

  /// Returns why [url] cannot be used, or null when it can.
  ///
  /// Any build needs an absolute http(s) URL. A [release] build additionally needs `https` and a
  /// public host, so a production app can never ship pointing at an emulator, a local machine or a
  /// private network address, or send traffic in the clear.
  @visibleForTesting
  static String? validate(String url, {required bool release}) {
    final value = url.trim();
    if (value.isEmpty) {
      return release ? 'is required for release builds (pass --dart-define=API_BASE_URL=https://...)' : 'is empty';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return 'is not an absolute URL: $value';
    if (uri.scheme != 'http' && uri.scheme != 'https') return 'must use http or https: $value';
    if (!release) return null;
    if (uri.scheme != 'https') return 'must use https in release builds: $value';
    if (uri.userInfo.isNotEmpty) return 'must not contain credentials: $value';
    if (_isLocalHost(uri.host)) return 'points at a local or private address, not allowed in release builds: $value';
    return null;
  }

  static bool _isLocalHost(String rawHost) {
    final host = rawHost.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost') || host.endsWith('.local')) return true;
    if (host.contains(':')) {
      // IPv6 literal: loopback, unspecified, link-local and unique-local ranges.
      return host == '::1' || host == '::' || host.startsWith('fe80:') || host.startsWith('fc') || host.startsWith('fd');
    }
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
    final [a, b, _, _] = octets.cast<int>();
    return a == 0 || a == 10 || a == 127 || (a == 169 && b == 254) || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }
}
