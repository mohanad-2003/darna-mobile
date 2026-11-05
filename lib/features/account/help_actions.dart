import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bidi.dart';
import '../../core/widgets/settings_widgets.dart';
import 'support_links.dart';

/// Opens [uri] outside the app, telling the user when nothing could handle it.
Future<void> openLink(BuildContext context, WidgetRef ref, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await ref.read(urlOpenerProvider)(uri);
  if (!opened) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز')),
      );
  }
}

/// The support channels that are configured, as a sheet of tappable rows.
Future<void> showSupportSheet(BuildContext context, WidgetRef ref) {
  final links = ref.read(supportLinksProvider);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Semantics(
                header: true,
                child: Text(
                  'الدعم والتواصل',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            SettingsGroup(
              title: 'تواصل معنا عبر',
              children: [
                if (links.whatsappUri != null)
                  SettingsTile(
                    icon: Icons.chat_outlined,
                    title: 'واتساب',
                    subtitle: ltrIsolate(links.whatsapp!),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      openLink(context, ref, links.whatsappUri!);
                    },
                  ),
                if (links.phoneUri != null)
                  SettingsTile(
                    icon: Icons.phone_outlined,
                    title: 'اتصال هاتفي',
                    subtitle: ltrIsolate(links.phone!),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      openLink(context, ref, links.phoneUri!);
                    },
                  ),
                if (links.emailUri != null)
                  SettingsTile(
                    icon: Icons.mail_outline,
                    title: 'البريد الإلكتروني',
                    subtitle: links.email,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      openLink(context, ref, links.emailUri!);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
