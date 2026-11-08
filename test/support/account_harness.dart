import 'dart:async';

import 'package:darna/core/api/api_client.dart';
import 'package:darna/core/api/api_exception.dart';
import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/core/auth/token_store.dart';
import 'package:darna/app/theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

/// An error the way the backend reports it, with the app's own Arabic message for [code].
ApiException apiError(int status, String code) => ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: {
            'error': {'code': code},
          },
        ),
      ),
    );

/// "Cannot reach the server".
ApiException networkError() => ApiException.fromDio(
      DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError),
    );

typedef Handler = FutureOr<Json> Function(Object? body);

/// Answers the app's API calls from a table, and remembers what was asked.
class FakeApi implements ApiClient {
  final _handlers = <String, Handler>{};
  final calls = <String>[];
  final bodies = <Object?>[];

  void on(String method, String path, Handler handler) => _handlers['$method $path'] = handler;

  int count(String method, String path) => calls.where((c) => c == '$method $path').length;

  Future<Json> _call(String method, String path, Object? body) async {
    final key = '$method $path';
    calls.add(key);
    bodies.add(body);
    final handler = _handlers[key];
    if (handler == null) throw StateError('unexpected API call: $key');
    return await handler(body);
  }

  @override
  Future<Json> get(String path, {Map<String, dynamic>? query}) => _call('GET', path, null);

  @override
  Future<Json> post(String path, {Object? body}) => _call('POST', path, body);

  @override
  Future<Json> patch(String path, {Object? body}) => _call('PATCH', path, body);

  @override
  Future<void> put(String path, {Object? body}) => _call('PUT', path, body);

  @override
  Future<void> delete(String path, {Object? body}) => _call('DELETE', path, body);

  @override
  Future<void> Function() get onSessionExpired => () async {};
}

/// Session tokens in memory instead of the device keystore.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore({this.access, this.refresh});

  String? access;
  String? refresh;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

Json userJson({
  String id = 'u1',
  String phone = '+970599111222',
  String? fullName = 'سامي خليل',
  String? email,
  String role = 'USER',
}) =>
    {'id': id, 'phone': phone, 'fullName': fullName, 'email': email, 'platformRole': role};

/// A signed-in app: the account is loaded from `GET /me` like at startup.
class TestSession {
  TestSession({Json? user, bool signedIn = true})
      : api = FakeApi(),
        tokens = MemoryTokenStore(refresh: signedIn ? 'refresh-1' : null, access: signedIn ? 'access-1' : null) {
    api.on('GET', '/me', (_) => {'data': user ?? userJson()});
  }

  final FakeApi api;
  final MemoryTokenStore tokens;

  List<Override> get overrides => [
        apiClientProvider.overrideWithValue(api),
        tokenStoreProvider.overrideWithValue(tokens),
      ];
}

/// Pumps [screen] pushed on top of a home page, so leaving it behaves like in the app.
/// `/` is the home page and `/login` etc. are placeholders for navigation the screens do.
Widget testApp({
  required Widget screen,
  required TestSession session,
  List<Override> extraOverrides = const [],
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  String screenPath = '/screen',
  GlobalKey<NavigatorState>? navigatorKey,
  List<RouteBase> extraRoutes = const [],
}) {
  Widget placeholder(String name) => Scaffold(body: Center(child: Text(name)));
  final router = GoRouter(
    navigatorKey: navigatorKey,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => context.push(screenPath), child: const Text('home')),
          ),
        ),
      ),
      GoRoute(path: screenPath, builder: (_, _) => screen),
      GoRoute(path: '/login', builder: (_, _) => placeholder('login-page')),
      GoRoute(path: '/account/phone', builder: (_, _) => placeholder('phone-page')),
      GoRoute(path: '/account/profile', builder: (_, _) => placeholder('profile-page')),
      GoRoute(path: '/account/delete', builder: (_, _) => placeholder('delete-page')),
      GoRoute(path: '/account/about', builder: (_, _) => placeholder('about-page')),
      GoRoute(path: '/my-listings', builder: (_, _) => placeholder('my-listings-page')),
      GoRoute(path: '/inquiries', builder: (_, _) => placeholder('inquiries-page')),
      GoRoute(path: '/admin/queue', builder: (_, _) => placeholder('queue-page')),
      GoRoute(path: '/admin/reports', builder: (_, _) => placeholder('reports-page')),
      ...extraRoutes,
    ],
  );
  return ProviderScope(
    overrides: [...session.overrides, ...extraOverrides],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}
