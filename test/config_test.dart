import 'package:darna/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.validate (release)', () {
    String? release(String url) => AppConfig.validate(url, release: true);

    test('accepts a public https address', () {
      expect(release('https://darna-api.onrender.com/api/v1'), isNull);
      expect(release('https://api.example.com:8443/api/v1'), isNull);
      expect(release('  https://api.example.com/api/v1  '), isNull);
    });

    test('rejects an empty address', () {
      expect(release(''), isNotNull);
      expect(release('   '), isNotNull);
    });

    test('rejects plain http, even for a public host', () {
      expect(release('http://api.example.com/api/v1'), isNotNull);
    });

    test('rejects the emulator, loopback and private network hosts', () {
      for (final host in [
        '10.0.2.2',
        '10.1.2.3',
        '127.0.0.1',
        '0.0.0.0',
        '192.168.1.20',
        '172.16.0.5',
        '172.31.255.1',
        '169.254.1.1',
        'localhost',
        'api.localhost',
        'darna.local',
        '[::1]',
        '[fe80::1]',
      ]) {
        expect(release('https://$host:3000/api/v1'), isNotNull, reason: host);
      }
    });

    test('does not mistake public lookalikes for private ranges', () {
      expect(release('https://172.32.0.1/api/v1'), isNull);
      expect(release('https://172.15.0.1/api/v1'), isNull);
      expect(release('https://11.0.0.1/api/v1'), isNull);
      expect(release('https://fcdn.example.com/api/v1'), isNull);
      expect(release('https://localhost.example.com/api/v1'), isNull);
    });

    test('rejects credentials in the address, other schemes and non-URLs', () {
      expect(release('https://user:pass@api.example.com/api/v1'), isNotNull);
      expect(release('ftp://api.example.com/api/v1'), isNotNull);
      expect(release('api.example.com/api/v1'), isNotNull);
      expect(release('https:///api/v1'), isNotNull);
    });
  });

  group('AppConfig.validate (debug and profile)', () {
    String? debug(String url) => AppConfig.validate(url, release: false);

    test('allows the emulator and LAN addresses over http', () {
      expect(debug('http://10.0.2.2:3000/api/v1'), isNull);
      expect(debug('http://192.168.1.20:3000/api/v1'), isNull);
      expect(debug('https://darna-api.onrender.com/api/v1'), isNull);
    });

    test('still needs an absolute http(s) URL', () {
      expect(debug(''), isNotNull);
      expect(debug('10.0.2.2:3000'), isNotNull);
      expect(debug('ftp://10.0.2.2/api'), isNotNull);
    });
  });

  test('the default address is the emulator one outside release builds', () {
    expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:3000/api/v1');
  });
}
