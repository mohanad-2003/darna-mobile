import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'token_store.dart';

class Me {
  Me({required this.id, required this.phone, this.fullName, this.email, required this.platformRole});

  final String id;
  final String phone;
  final String? fullName;
  final String? email;
  final String platformRole;

  factory Me.fromJson(Json j) => Me(
        id: j['id'] as String,
        phone: j['phone'] as String,
        fullName: j['fullName'] as String?,
        email: j['email'] as String?,
        platformRole: (j['platformRole'] as String?) ?? 'USER',
      );
}

class OtpChallenge {
  OtpChallenge({required this.challengeId, required this.expiresInSeconds, required this.resendAfterSeconds});

  final String challengeId;
  final int expiresInSeconds;
  final int resendAfterSeconds;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStoreProvider),
    // Looked up lazily: the auth controller itself depends on this client.
    onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
  );
});

/// The signed-in user, or null when browsing anonymously.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, Me?>(AuthController.new);

class AuthController extends AsyncNotifier<Me?> {
  @override
  Future<Me?> build() async {
    final tokens = ref.read(tokenStoreProvider);
    if (await tokens.refreshToken == null) return null;
    try {
      final res = await ref.read(apiClientProvider).get('/me');
      return Me.fromJson(res['data'] as Json);
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.status == 403) return null;
      // Offline at startup: stay anonymous but keep the tokens for the next launch.
      return null;
    }
  }

  Future<OtpChallenge> requestOtp(String phone) async {
    final res = await ref.read(apiClientProvider).post(
      '/auth/otp/request',
      body: {'phone': phone, 'purpose': 'AUTH', 'channel': 'SMS'},
    );
    return OtpChallenge(
      challengeId: res['challengeId'] as String,
      expiresInSeconds: res['expiresInSeconds'] as int,
      resendAfterSeconds: res['resendAfterSeconds'] as int,
    );
  }

  /// Returns true when the account was just created (the app then asks for a name).
  Future<bool> verifyOtp({required String phone, required String challengeId, required String code}) async {
    final res = await ref.read(apiClientProvider).post(
      '/auth/otp/verify',
      body: {'phone': phone, 'challengeId': challengeId, 'code': code},
    );
    await ref.read(tokenStoreProvider).save(
          access: res['accessToken'] as String,
          refresh: res['refreshToken'] as String,
        );
    state = AsyncData(Me.fromJson(res['user'] as Json));
    return res['isNewUser'] as bool;
  }

  Future<void> updateName(String fullName) async {
    final res = await ref.read(apiClientProvider).patch('/me', body: {'fullName': fullName});
    state = AsyncData(Me.fromJson(res['data'] as Json));
  }

  Future<void> logout() async {
    final tokens = ref.read(tokenStoreProvider);
    final refresh = await tokens.refreshToken;
    if (refresh != null) {
      try {
        await ref.read(apiClientProvider).post('/auth/logout', body: {'refreshToken': refresh});
      } on ApiException {
        // Signing out locally must not depend on the network.
      }
    }
    await tokens.clear();
    state = const AsyncData(null);
  }

  /// The backend rejected the refresh token: the session is over.
  Future<void> sessionExpired() async {
    state = const AsyncData(null);
  }
}
