import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme_mode.dart';
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
        body: Column(children: [
          Expanded(child: LoginPrompt(message: 'سجّل الدخول لإدارة حسابك ومتابعة استفساراتك')),
          SafeArea(top: false, child: _AppearanceTile()),
        ]),
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
          if (me.platformRole == 'MODERATOR' || me.platformRole == 'ADMIN')
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('البلاغات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.push('/admin/reports'),
            ),
          const _AppearanceTile(),
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

class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('المظهر'),
      subtitle: Text(themeModeLabel(mode)),
      trailing: const Icon(Icons.chevron_left),
      onTap: () async {
        final picked = await showModalBottomSheet<ThemeMode>(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (m) => Navigator.of(context).pop(m),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final m in ThemeMode.values)
                  RadioListTile<ThemeMode>(value: m, title: Text(themeModeLabel(m))),
              ]),
            ),
          ),
        );
        if (picked != null) ref.read(themeModeProvider.notifier).set(picked);
      },
    );
  }
}
