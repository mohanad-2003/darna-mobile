import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import 'format.dart';
import 'models.dart';
import 'property_repository.dart';
import 'report_sheet.dart';

/// Sends a report about the listing (asks for login first).
Future<void> reportListing(BuildContext context, WidgetRef ref, String id) async {
  if (ref.read(authControllerProvider).value == null) {
    context.push('/login');
    return;
  }
  final input = await showReportSheet(context);
  if (input == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(propertyRepositoryProvider).report(id, input.reason, input.description);
    messenger.showSnackBar(const SnackBar(content: Text('شكراً لك، وصلنا بلاغك وسنراجعه')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.code == 'FORBIDDEN' ? 'لا يمكنك الإبلاغ عن إعلانك' : e.message),
    ));
  }
}

/// Always-visible bar at the bottom of the detail screen: the price, and the two ways to reach
/// the advertiser.
class ContactBar extends ConsumerWidget {
  const ContactBar({super.key, required this.detail});

  final PropertyDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      shadowColor: Colors.black54,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Flexible(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('السعر', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    formatPrice(detail.card),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            if (detail.canRevealPhone) ...[
              Flexible(
                flex: 5,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.phone, size: 20),
                  label: const Text('إظهار الرقم'),
                  onPressed: () => _reveal(context, ref),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              flex: 4,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                label: const Text('استفسار'),
                onPressed: () => _inquire(context, ref),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  bool _requireLogin(BuildContext context, WidgetRef ref) {
    if (ref.read(authControllerProvider).value != null) return true;
    context.push('/login');
    return false;
  }

  Future<void> _reveal(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final contact = await ref.read(propertyRepositoryProvider).revealContact(detail.card.id);
      if (!context.mounted) return;
      await showDialog<void>(context: context, builder: (_) => _ContactDialog(contact: contact));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _inquire(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _InquirySheet(),
    );
    if (message == null) return;
    try {
      await ref.read(propertyRepositoryProvider).sendInquiry(detail.card.id, message);
      messenger.showSnackBar(const SnackBar(content: Text('تم إرسال استفسارك')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ContactDialog extends StatelessWidget {
  const _ContactDialog({required this.contact});

  final ContactInfo contact;

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(contact.name ?? 'المعلن')),
      ]),
      content: Directionality(
        textDirection: TextDirection.ltr,
        child: SelectableText(contact.phone, style: theme.textTheme.headlineSmall),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (contact.whatsappUrl != null)
            OutlinedButton.icon(
              onPressed: () => _open(contact.whatsappUrl!),
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('واتساب'),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _open('tel:${contact.phone}'),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('اتصال'),
          ),
        ]),
      ],
    );
  }
}

class _InquirySheet extends StatefulWidget {
  const _InquirySheet();

  @override
  State<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends State<_InquirySheet> {
  final _text = TextEditingController(text: 'مرحباً، هل ما زال العقار متاحاً؟');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('أرسل استفساراً للمعلن', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          maxLines: 4,
          maxLength: 3000,
          decoration: const InputDecoration(labelText: 'رسالتك', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final text = _text.text.trim();
              if (text.isNotEmpty) Navigator.of(context).pop(text);
            },
            child: const Text('إرسال'),
          ),
        ),
      ]),
    );
  }
}
