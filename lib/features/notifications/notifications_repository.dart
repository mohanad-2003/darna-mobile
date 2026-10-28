import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Json? data;
  final bool read;
  final DateTime createdAt;

  String? get propertyId => data?['propertyId'] as String?;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        data: j['data'] is Map ? (j['data'] as Map).cast<String, dynamic>() : null,
        read: j['readAt'] != null,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class NotificationsPage {
  NotificationsPage({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

final notificationsProvider = FutureProvider.autoDispose<NotificationsPage>((ref) {
  ref.watch(authControllerProvider.select((a) => a.value?.id));
  return ref.watch(notificationsRepositoryProvider).list();
});

/// For the bell badge. Zero (without a request) when signed out.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
  if (userId == null) return 0;
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationsPage> list() async {
    final res = await _api.get('/me/notifications', query: {'limit': 50});
    return NotificationsPage(
      items: (res['data'] as List).map((e) => AppNotification.fromJson(e as Json)).toList(),
      unreadCount: res['unreadCount'] as int,
    );
  }

  Future<int> unreadCount() async {
    final res = await _api.get('/me/notifications', query: {'limit': 1});
    return res['unreadCount'] as int;
  }

  Future<void> markRead(List<String> ids) => _api.post('/me/notifications/read', body: {'ids': ids});

  Future<void> markAllRead() => _api.post('/me/notifications/read', body: {'all': true});
}
