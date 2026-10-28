import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/time_ago.dart';
import '../auth/login_prompt.dart';
import '../../core/auth/auth_controller.dart';
import 'notifications_repository.dart';

IconData _iconFor(String type) => switch (type) {
      'PROPERTY_APPROVED' => Icons.check_circle_outline,
      'PROPERTY_REJECTED' => Icons.cancel_outlined,
      'PROPERTY_NEEDS_CHANGES' => Icons.edit_note,
      'PROPERTY_SUSPENDED' => Icons.block,
      'PROPERTY_EXPIRING' => Icons.schedule,
      'NEW_INQUIRY' || 'INQUIRY_UPDATE' => Icons.chat_bubble_outline,
      _ => Icons.notifications_none,
    };

Color _colorFor(String type) => switch (type) {
      'PROPERTY_APPROVED' => Colors.green,
      'PROPERTY_REJECTED' || 'PROPERTY_SUSPENDED' => Colors.red,
      'PROPERTY_NEEDS_CHANGES' || 'PROPERTY_EXPIRING' => Colors.orange,
      _ => Colors.blueGrey,
    };

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    if (!n.read) {
      // Fire and forget: opening the target must not wait for the network.
      ref.read(notificationsRepositoryProvider).markRead([n.id]).then((_) => _refresh(ref), onError: (_) {});
    }
    final propertyId = n.propertyId;
    if (n.type == 'NEW_INQUIRY' || n.type == 'INQUIRY_UPDATE') {
      context.push('/inquiries');
    } else if (n.type.startsWith('PROPERTY_') && propertyId != null) {
      context.push('/listing/$propertyId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider.select((a) => a.value != null));
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const LoginPrompt(message: 'سجّل الدخول لتصلك قرارات مراجعة إعلاناتك واستفسارات المهتمين'),
      );
    }

    final page = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if ((page.value?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: () async {
                await ref.read(notificationsRepositoryProvider).markAllRead();
                _refresh(ref);
              },
              child: const Text('تحديد الكل كمقروء'),
            ),
        ],
      ),
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e is ApiException ? e.message : 'تعذر التحميل'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _refresh(ref), child: const Text('إعادة المحاولة')),
          ]),
        ),
        data: (p) {
          if (p.items.isEmpty) {
            return const Center(child: Text('لا توجد إشعارات بعد'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              _refresh(ref);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.separated(
              itemCount: p.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = p.items[i];
                return ListTile(
                  tileColor: n.read ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  leading: CircleAvatar(
                    backgroundColor: _colorFor(n.type).withValues(alpha: 0.15),
                    child: Icon(_iconFor(n.type), color: _colorFor(n.type)),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: Text(timeAgoAr(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => _open(context, ref, n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
