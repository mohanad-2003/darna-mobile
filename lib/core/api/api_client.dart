import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config.dart';
import 'api_exception.dart';

typedef Json = Map<String, dynamic>;

/// Thin JSON client over Dio. Adds the access token, and when the backend answers 401
/// it rotates the refresh token once and retries the request.
class ApiClient {
  ApiClient(this._tokens, {required this.onSessionExpired})
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.accessToken;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        final req = error.requestOptions;
        final isAuthCall = req.path.startsWith('/auth/');
        if (error.response?.statusCode == 401 &&
            !isAuthCall &&
            req.extra['retried'] != true &&
            await _tokens.refreshToken != null) {
          if (await _refresh()) {
            req.extra['retried'] = true;
            try {
              handler.resolve(await _dio.fetch(req));
            } on DioException catch (e) {
              handler.next(e);
            }
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  final TokenStore _tokens;
  final Future<void> Function() onSessionExpired;
  final Dio _dio;

  // Concurrent 401s must share one refresh: the backend treats a reused refresh
  // token as theft and revokes the whole session.
  Future<bool>? _refreshing;

  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      // A bare Dio: this call must not go through the interceptor above.
      final res = await Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      )).post<Json>('/auth/refresh', data: {'refreshToken': refresh});
      final body = res.data!;
      await _tokens.save(
        access: body['accessToken'] as String,
        refresh: body['refreshToken'] as String,
      );
      return true;
    } on DioException catch (e) {
      // Only a definite rejection ends the session; a network blip keeps the tokens.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _tokens.clear();
        await onSessionExpired();
      }
      return false;
    }
  }

  Future<T> _run<T>(Future<Response<dynamic>> Function() call, T Function(dynamic data) parse) async {
    try {
      return parse((await call()).data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Json> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get<dynamic>(path, queryParameters: query), (d) => (d as Json?) ?? {});

  Future<Json> post(String path, {Object? body}) =>
      _run(() => _dio.post<dynamic>(path, data: body), (d) => d is Json ? d : {});

  Future<Json> patch(String path, {Object? body}) =>
      _run(() => _dio.patch<dynamic>(path, data: body), (d) => d is Json ? d : {});

  Future<void> put(String path, {Object? body}) =>
      _run(() => _dio.put<dynamic>(path, data: body), (_) {});

  Future<void> delete(String path, {Object? body}) =>
      _run(() => _dio.delete<dynamic>(path, data: body), (_) {});
}
