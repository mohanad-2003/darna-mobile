import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/time_ago.dart';

import '../../core/api/api_exception.dart';
import '../properties/format.dart';
import 'admin_repository.dart';

class AdminReviewScreen extends ConsumerStatefulWidget {
  const AdminReviewScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends ConsumerState<AdminReviewScreen> {
  bool _working = false;

  Future<void> _decide(ModerationView view, String decision) async {
    String? reason;
    // Rejecting or asking for changes needs a reason the owner can act on.
    if (decision != 'APPROVED') {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(
          title: decision == 'REJECTED' ? 'سبب الرفض' : 'ما المطلوب تعديله؟',
        ),
      );
      if (reason == null || !mounted) return;
    }

    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).review(
            widget.propertyId,
            decision: decision,
            expectedStatus: view.listing.status,
            reason: reason,
          );
      ref.invalidate(pendingQueueProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('تم تسجيل القرار: ${decisionNames[decision]}')));
      context.pop();
    } on ApiException catch (e) {
      final text = switch (e.code) {
        'FORBIDDEN' => 'لا يمكنك مراجعة إعلان تملكه أنت. اطلب من مشرف آخر.',
        'STATUS_CHANGED' => 'تغيّرت حالة الإعلان (ربما راجعه مشرف آخر). حدّث الصفحة.',
        _ => e.message,
      };
      messenger.showSnackBar(SnackBar(content: Text(text)));
      if (e.code == 'STATUS_CHANGED') ref.invalidate(moderationViewProvider(widget.propertyId));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(moderationViewProvider(widget.propertyId));
    return view.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e is ApiException ? e.message : 'تعذر التحميل')),
      ),
      data: (v) {
        final l = v.listing;
        final theme = Theme.of(context);
        final pending = l.status == 'PENDING_REVIEW';
        return Scaffold(
          appBar: AppBar(title: const Text('مراجعة إعلان')),
          body: ListView(
            children: [
              if (l.media.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: PageView(
                    children: [
                      for (final m in l.media)
                        CachedNetworkImage(
                          imageUrl: m.url,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
                        ),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد صور', style: TextStyle(color: Colors.red)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${NumberFormat('#,##0.##', 'en').format(double.parse(l.price))} ${l.currency}'
                    '${l.rentPeriod != null ? ' (${l.rentPeriod})' : ''}',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    Chip(label: Text(purposeName(l.purpose))),
                    Chip(label: Text(propertyTypeNames[l.propertyType] ?? l.propertyType)),
                    if (l.areaSqm != null) Chip(label: Text('${l.areaSqm} م²')),
                    if (l.bedrooms != null) Chip(label: Text('${l.bedrooms} غرف')),
                    if (l.bathrooms != null) Chip(label: Text('${l.bathrooms} حمامات')),
                  ]),
                  const Divider(height: 24),
                  _row('الموقع', l.locationName),
                  if (l.addressText != null) _row('العنوان', l.addressText!),
                  _row('رقم التواصل', l.contactPhone, ltr: true),
                  _row('إظهار الرقم', l.showPhone ? 'نعم' : 'لا (استفسارات فقط)'),
                  if (v.openReports > 0)
                    _row('بلاغات مفتوحة', '${v.openReports}', color: Colors.red),
                  const Divider(height: 24),
                  Text('الوصف', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(l.description),
                  if (v.reviews.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('سجل القرارات', style: theme.textTheme.titleMedium),
                    for (final r in v.reviews)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(decisionNames[r.decision] ?? r.decision),
                        subtitle: r.reason == null ? null : Text(r.reason!),
                        trailing: Text(formatDate(r.createdAt)),
                      ),
                  ],
                  const SizedBox(height: 96),
                ]),
              ),
            ],
          ),
          bottomNavigationBar: pending
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _working ? null : () => _decide(v, 'REJECTED'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('رفض'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _working ? null : () => _decide(v, 'NEEDS_CHANGES'),
                          child: const Text('تعديلات'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _working ? null : () => _decide(v, 'APPROVED'),
                          child: const Text('موافقة'),
                        ),
                      ),
                    ]),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('حالة الإعلان الآن: ${l.status} (لا يحتاج مراجعة)', textAlign: TextAlign.center),
                ),
        );
      },
    );
  }

  Widget _row(String label, String value, {bool ltr = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Directionality(
              textDirection: ltr ? TextDirection.ltr : Directionality.of(context),
              child: Text(value, textAlign: ltr ? TextAlign.right : null, style: TextStyle(color: color)),
            ),
          ),
        ]),
      );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _text,
          autofocus: true,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(
            helperText: 'يصل هذا الكلام لصاحب الإعلان',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = _text.text.trim();
              if (v.isNotEmpty) Navigator.of(context).pop(v);
            },
            child: const Text('تأكيد'),
          ),
        ],
      );
}
