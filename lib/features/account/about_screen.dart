import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/darna_logo.dart';
import '../../core/widgets/settings_widgets.dart';
import 'help_actions.dart';
import 'support_links.dart';

/// "عن التطبيق": name, version, and the entries the project has actually been configured with.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = ref.watch(packageInfoProvider).value;
    final links = ref.watch(supportLinksProvider);
    final version = info == null
        ? null
        : 'الإصدار ${info.version} (${info.buildNumber})';
    final missing = <String>[
      if (links.privacyPolicy == null) 'PRIVACY_POLICY_URL',
      if (links.terms == null) 'TERMS_URL',
      if (!links.hasContact) 'SUPPORT_EMAIL / SUPPORT_PHONE / SUPPORT_WHATSAPP',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            const Center(child: DarnaLogo(height: 56)),
            const SizedBox(height: 16),
            Text(
              'دارنا',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (version != null) ...[
              const SizedBox(height: 4),
              Text(
                version,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'تصفّح العقارات للبيع والإيجار، وانشر إعلانك وتواصل مع المهتمين.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              title: 'معلومات',
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
                    onTap: () => showSupportSheet(context, ref),
                  ),
                SettingsTile(
                  icon: Icons.article_outlined,
                  title: 'تراخيص المكتبات',
                  subtitle: 'المكتبات مفتوحة المصدر المستخدمة في التطبيق',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'دارنا',
                    applicationVersion: info?.version,
                  ),
                ),
              ],
            ),
            // Only developers see this: it lists the build settings that are still empty.
            if (kDebugMode && missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: InlineMessage(
                  isError: false,
                  text:
                      'وضع التطوير: هذه الإعدادات غير مضبوطة فلا يظهر ما يخصها: ${missing.join('، ')}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
