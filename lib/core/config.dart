class AppConfig {
  /// Backend base URL. 10.0.2.2 is the host machine as seen from the Android emulator.
  /// On a real device pass the computer's LAN address:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
}
