import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme_mode.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/bidi.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/settings_widgets.dart';
import 'help_actions.dart';
import 'support_links.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.value;

    if (auth.isLoading && me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('حسابي')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isStaff =
        me?.platformRole == 'MODERATOR' || me?.platformRole == 'ADMIN';
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (me == null) const _GuestCard() else _ProfileCard(me: me),
            const SizedBox(height: 24),
            if (me != null) ...[
              SettingsGroup(
                title: 'نشاطي',
                children: [
                  SettingsTile(
                    icon: Icons.list_alt_outlined,
                    title: 'إعلاناتي',
                    subtitle: 'تابع حالة إعلاناتك وعدّلها',
                    onTap: () => context.push('/my-listings'),
                  ),
                  SettingsTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'الاستفسارات',
                    subtitle: 'الرسائل المرسلة والواردة',
                    onTap: () => context.push('/inquiries'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (isStaff) ...[
                SettingsGroup(
                  title: 'أدوات الإشراف',
                  children: [
                    SettingsTile(
                      icon: Icons.fact_check_outlined,
                      title: 'مراجعة الإعلانات',
                      onTap: () => context.push('/admin/queue'),
                    ),
                    SettingsTile(
                      icon: Icons.flag_outlined,
                      title: 'البلاغات',
                      onTap: () => context.push('/admin/reports'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ],
            SettingsGroup(
              title: me == null ? 'الإعدادات' : 'إعدادات الحساب',
              children: [
                const _AppearanceTile(),
                if (me != null) ...[
                  SettingsTile(
                    icon: Icons.phone_android_outlined,
                    title: 'تغيير رقم الهاتف',
                    subtitle: ltrIsolate(me.phone),
                    onTap: () => context.push('/account/phone'),
                  ),
                  SettingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'حذف الحساب',
                    subtitle: 'حذف نهائي لحسابك وبياناتك',
                    destructive: true,
                    onTap: () => context.push('/account/delete'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const _HelpGroup(),
            if (me != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _VersionFooter(),
          ],
        ),
      ),
    );
  }
}

/// Who is signed in: avatar, name, number, role, and the way to edit the profile.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = me.fullName?.trim() ?? '';
    final role = switch (me.platformRole) {
      'ADMIN' => 'مدير',
      'MODERATOR' => 'مشرف',
      _ => null,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: name.isEmpty
                      ? const Icon(Icons.person, size: 30)
                      : Text(
                          name.characters.first,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'أضف اسمك' : name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: name.isEmpty
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        me.phone,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(role),
                        avatar: const Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/account/profile'),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('تعديل الملف الشخصي'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a visitor sees instead of the profile: an invitation to sign in.
class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: ClayIllustration(StateArt.welcome, size: 132)),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              'أهلاً بك في دارنا',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'سجّل الدخول لحفظ المفضلة، ونشر إعلاناتك، ومتابعة استفساراتك.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/login'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('تسجيل الدخول'),
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
    return SettingsTile(
      icon: Icons.brightness_6_outlined,
      title: 'المظهر',
      subtitle: themeModeLabel(mode),
      onTap: () async {
        final picked = await showModalBottomSheet<ThemeMode>(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (m) => Navigator.of(context).pop(m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: m,
                      title: Text(themeModeLabel(m)),
                    ),
                ],
              ),
            ),
          ),
        );
        if (picked != null) ref.read(themeModeProvider.notifier).set(picked);
      },
    );
  }
}

/// Privacy policy, terms and support appear only when the build has them configured.
class _HelpGroup extends ConsumerWidget {
  const _HelpGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(supportLinksProvider);
    return SettingsGroup(
      title: 'المساعدة والمعلومات',
      children: [
        if (links.privacyPolicy != null)
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            onTap: () => openLink(context, ref, links.privacyPolicy!),
          ),
        if (links.terms != null)
          SettingsTile(
            icon: Icons.description_outlined,
            title: 'شروط الاستخدام',
            onTap: () => openLink(context, ref, links.terms!),
          ),
        if (links.hasContact)
          SettingsTile(
            icon: Icons.support_agent_outlined,
            title: 'الدعم والتواصل',
            subtitle: 'نساعدك في أي مشكلة',
            onTap: () => showSupportSheet(context, ref),
          ),
        SettingsTile(
          icon: Icons.info_outline,
          title: 'عن التطبيق',
          onTap: () => context.push('/account/about'),
        ),
      ],
    );
  }
}

class _VersionFooter extends ConsumerWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    if (info == null) return const SizedBox.shrink();
    return Text(
      'دارنا · الإصدار ${info.version} (${info.buildNumber})',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
