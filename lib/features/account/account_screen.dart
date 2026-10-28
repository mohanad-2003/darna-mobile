import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../auth/login_prompt.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.value;

    if (auth.isLoading && me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (me == null) {
      return const Scaffold(
        body: LoginPrompt(message: 'سجّل الدخول لإدارة حسابك ومتابعة استفساراتك'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(me.fullName ?? 'بدون اسم'),
            subtitle: Directionality(textDirection: TextDirection.ltr, child: Text(me.phone)),
            trailing: switch (me.platformRole) {
              'ADMIN' => const Chip(label: Text('مدير')),
              'MODERATOR' => const Chip(label: Text('مشرف')),
              _ => null,
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('إعلاناتي'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/my-listings'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('الاستفسارات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/inquiries'),
          ),
          if (me.platformRole == 'MODERATOR' || me.platformRole == 'ADMIN')
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('مراجعة الإعلانات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.push('/admin/queue'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('تسجيل الخروج'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
