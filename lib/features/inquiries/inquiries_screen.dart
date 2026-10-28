import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/time_ago.dart';
import '../auth/login_prompt.dart';
import 'inquiries_repository.dart';

Color _statusColor(String status) => switch (status) {
      'NEW' => Colors.blue,
      'RESPONDED' => Colors.green,
      'SPAM' => Colors.red,
      _ => Colors.grey,
    };

class InquiriesScreen extends ConsumerWidget {
  const InquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider.select((a) => a.value != null));
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('الاستفسارات')),
        body: const LoginPrompt(message: 'سجّل الدخول لمتابعة الاستفسارات'),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الاستفسارات'),
          bottom: const TabBar(tabs: [Tab(text: 'المستلمة'), Tab(text: 'المرسلة')]),
        ),
        body: const TabBarView(children: [
          _InquiryList(received: true),
          _InquiryList(received: false),
        ]),
      ),
    );
  }
}

class _InquiryList extends ConsumerWidget {
  const _InquiryList({required this.received});

  final bool received;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = received ? receivedInquiriesProvider : sentInquiriesProvider;
    final inquiries = ref.watch(provider);

    return inquiries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(e is ApiException ? e.message : 'تعذر التحميل'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => ref.invalidate(provider), child: const Text('إعادة المحاولة')),
        ]),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                received ? 'لم يصلك أي استفسار بعد' : 'لم ترسل أي استفسار بعد',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(provider.future),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _InquiryTile(inquiry: items[i], received: received),
          ),
        );
      },
    );
  }
}

class _InquiryTile extends ConsumerWidget {
  const _InquiryTile({required this.inquiry, required this.received});

  final InquiryItem inquiry;
  final bool received;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew = received && inquiry.status == 'NEW';
    return ListTile(
      tileColor: isNew ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06) : null,
      title: Text(
        received ? (inquiry.senderName ?? 'مهتم') : inquiry.propertyTitle,
        style: TextStyle(fontWeight: isNew ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (received) Text(inquiry.propertyTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(inquiry.message, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(timeAgoAr(inquiry.createdAt), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(inquiryStatusNames[inquiry.status] ?? inquiry.status,
            style: TextStyle(color: _statusColor(inquiry.status), fontSize: 12)),
      ]),
      onTap: () => _open(context, ref),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(inquiriesRepositoryProvider);
    // Opening a new inquiry counts as reading it.
    if (received && inquiry.status == 'NEW') {
      repo.setStatus(inquiry.id, 'READ').then((_) => ref.invalidate(receivedInquiriesProvider), onError: (_) {});
    }
    final newStatus = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InquirySheet(inquiry: inquiry, received: received),
    );
    if (newStatus == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.setStatus(inquiry.id, newStatus);
      ref.invalidate(receivedInquiriesProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _InquirySheet extends StatelessWidget {
  const _InquirySheet({required this.inquiry, required this.received});

  final InquiryItem inquiry;
  final bool received;

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = inquiry.senderPhone;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(inquiry.propertyTitle, style: theme.textTheme.titleMedium),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/property/${inquiry.propertyId}');
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('عرض الإعلان'),
          ),
          if (received) Text('من: ${inquiry.senderName ?? 'مهتم'}', style: theme.textTheme.bodyMedium),
          Text(
            'طريقة التواصل المفضلة: ${contactPreferenceNames[inquiry.contactPreference] ?? ''}',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: 24),
          SelectableText(inquiry.message, style: theme.textTheme.bodyLarge),
          if (received && phone != null) ...[
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(phone, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open('tel:$phone'),
                  icon: const Icon(Icons.phone),
                  label: const Text('اتصال'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open('https://wa.me/${phone.replaceFirst('+', '')}'),
                  icon: const Icon(Icons.chat),
                  label: const Text('واتساب'),
                ),
              ),
            ]),
          ],
          if (received) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              for (final s in const ['RESPONDED', 'CLOSED', 'SPAM'])
                ChoiceChip(
                  label: Text(inquiryStatusNames[s]!),
                  selected: inquiry.status == s,
                  onSelected: (_) => Navigator.of(context).pop(s),
                ),
            ]),
          ] else
            Text('الحالة: ${inquiryStatusNames[inquiry.status] ?? inquiry.status}', style: theme.textTheme.bodyMedium),
        ]),
      ),
    );
  }
}
