import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_store.dart';
import '../config.dart';
import 'api_exception.dart';

typedef Json = Map<String, dynamic>;

/// True when the backend refused the access token itself (expired, or invalidated by a
/// sign-out), as opposed to a 401 about the request, like a wrong one-time code on
/// /me/account-deletion/confirm. Only the first kind is fixed by rotating the refresh
/// token; retrying the second would spend another attempt on the code.
bool isRejectedAccessToken(DioException error) {
  if (error.response?.statusCode != 401) return false;
  final data = error.response?.data;
  final code = data is Map && data['error'] is Map ? (data['error'] as Map)['code'] : null;
  return code == null || code == 'UNAUTHORIZED';
}

const _maxRetries = 2;

/// Only reads are repeated: repeating a POST could send an inquiry or a report twice.
/// 502/503/504 are what the host answers while a sleeping server is starting.
bool _shouldRetry(DioException e) {
  final req = e.requestOptions;
  if (req.method != 'GET') return false;
  if (((req.extra['attempt'] as int?) ?? 0) >= _maxRetries) return false;
  final status = e.response?.statusCode;
  return e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      status == 502 ||
      status == 503 ||
      status == 504;
}

/// Thin JSON client over Dio. Adds the access token, and when the backend answers 401
/// it rotates the refresh token once and retries the request.
class ApiClient {
  ApiClient(this._tokens, {required this.onSessionExpired})
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          // A sleeping server can take about a minute to answer the first request.
          receiveTimeout: const Duration(seconds: 75),
          headers: {'Accept': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.accessToken;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        options.extra['slowTimer'] = Timer(const Duration(seconds: 4), () {
          options.extra['slow'] = true;
          _slowCount++;
          isWaking.value = true;
        });
        handler.next(options);
      },
      onResponse: (response, handler) {
        _endSlow(response.requestOptions);
        handler.next(response);
      },
      onError: (error, handler) async {
        final req = error.requestOptions;
        _endSlow(req);

        if (_shouldRetry(error)) {
          final attempt = ((req.extra['attempt'] as int?) ?? 0) + 1;
          req.extra['attempt'] = attempt;
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          try {
            handler.resolve(await _dio.fetch(req));
          } on DioException catch (e) {
            handler.next(e);
          }
          return;
        }

        final isAuthCall = req.path.startsWith('/auth/');
        if (isRejectedAccessToken(error) &&
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

  /// True while at least one request has been waiting for more than a few seconds.
  /// The UI shows a "preparing the service" notice while this is set.
  final ValueNotifier<bool> isWaking = ValueNotifier(false);
  int _slowCount = 0;

  void _endSlow(RequestOptions o) {
    final timer = o.extra.remove('slowTimer');
    if (timer is Timer) timer.cancel();
    if (o.extra.remove('slow') == true && --_slowCount <= 0) {
      _slowCount = 0;
      isWaking.value = false;
    }
  }

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
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 75),
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
