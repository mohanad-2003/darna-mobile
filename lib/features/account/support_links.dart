import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login_screen.dart' show normalizePhone;

/// The privacy policy, terms and support channels shown under "المساعدة والمعلومات".
///
/// None of them is invented here: each comes from a build setting, and an entry that is
/// not set (or not valid) is simply not shown. Set them when building:
///
///   flutter build apk \
///     --dart-define=PRIVACY_POLICY_URL=https://example.org/privacy \
///     --dart-define=TERMS_URL=https://example.org/terms \
///     --dart-define=SUPPORT_EMAIL=help@example.org \
///     --dart-define=SUPPORT_PHONE=+970591234567 \
///     --dart-define=SUPPORT_WHATSAPP=+970591234567
class SupportLinks {
  const SupportLinks({
    this.privacyPolicy,
    this.terms,
    this.email,
    this.phone,
    this.whatsapp,
  });

  /// Reads raw settings, keeping only the values that are usable: https links, an email
  /// address, and phone numbers that normalise to E.164. Anything else is dropped.
  factory SupportLinks.parse({
    String privacy = '',
    String terms = '',
    String email = '',
    String phone = '',
    String whatsapp = '',
  }) {
    final phoneE164 = normalizePhone(phone.trim());
    final whatsappE164 = normalizePhone(whatsapp.trim());
    final mail = email.trim();
    return SupportLinks(
      privacyPolicy: _https(privacy),
      terms: _https(terms),
      email: _emailPattern.hasMatch(mail) ? mail : null,
      phone: phoneE164,
      whatsapp: whatsappE164,
    );
  }

  final Uri? privacyPolicy;
  final Uri? terms;
  final String? email;
  final String? phone;
  final String? whatsapp;

  bool get hasContact => email != null || phone != null || whatsapp != null;

  Uri? get emailUri =>
      email == null ? null : Uri(scheme: 'mailto', path: email);
  Uri? get phoneUri => phone == null ? null : Uri(scheme: 'tel', path: phone);
  Uri? get whatsappUri => whatsapp == null
      ? null
      : Uri.https('wa.me', '/${whatsapp!.substring(1)}');

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static Uri? _https(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }
}

final supportLinksProvider = Provider<SupportLinks>(
  (ref) => SupportLinks.parse(
    privacy: const String.fromEnvironment('PRIVACY_POLICY_URL'),
    terms: const String.fromEnvironment('TERMS_URL'),
    email: const String.fromEnvironment('SUPPORT_EMAIL'),
    phone: const String.fromEnvironment('SUPPORT_PHONE'),
    whatsapp: const String.fromEnvironment('SUPPORT_WHATSAPP'),
  ),
);

/// Opens a link in the browser or the matching app; false when nothing could handle it.
/// A provider so tests can record the links instead of launching them.
final urlOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);

/// Name and version of the installed build.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);
