import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/time_ago.dart';
import 'admin_repository.dart';

const _tabs = {
  'OPEN': 'مفتوحة',
  'UNDER_REVIEW': 'قيد المراجعة',
  'RESOLVED': 'محلولة',
  'DISMISSED': 'مرفوضة',
};

/// Reports from users, oldest first, for moderators.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _status = 'OPEN';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البلاغات')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final e in _tabs.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) => setState(() => _status = e.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _ReportList(status: _status)),
      ]),
    );
  }
}

class _ReportList extends ConsumerWidget {
  const _ReportList({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider(status));
    return reports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(e is ApiException ? e.message : 'تعذر التحميل'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => ref.invalidate(reportsProvider(status)), child: const Text('إعادة المحاولة')),
        ]),
      ),
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('لا توجد بلاغات هنا'));
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(reportsProvider(status).future),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = items[i];
              return ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(reportReasonNames[r.reason] ?? r.reason),
                subtitle: Text(r.propertyTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(timeAgoAr(r.createdAt), style: Theme.of(context).textTheme.bodySmall),
                onTap: () => _open(context, ref, r),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, ReportItem r) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReportSheet(report: r),
    );
    if (action == null || !context.mounted) return;

    if (action == 'view') {
      await context.push('/admin/review/${r.propertyId}');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    String? resolution;
    if (action == 'RESOLVED' || action == 'DISMISSED') {
      resolution = await showDialog<String>(
        context: context,
        builder: (_) => _ResolutionDialog(dismiss: action == 'DISMISSED'),
      );
      if (resolution == null) return; // backed out
    }
    try {
      await ref.read(adminRepositoryProvider).updateReport(
            r.id,
            action,
            resolution: (resolution == null || resolution.isEmpty) ? null : resolution,
          );
      // The report moves to another tab, so every tab's list is stale.
      for (final s in _tabs.keys) {
        ref.invalidate(reportsProvider(s));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.report});

  final ReportItem report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closed = report.status == 'RESOLVED' || report.status == 'DISMISSED';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(reportReasonNames[report.reason] ?? report.reason, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('الإعلان: ${report.propertyTitle}'),
          Text('حالة الإعلان: ${report.propertyStatus}', style: theme.textTheme.bodySmall),
          Text('المُبلِّغ: ${report.reporterName ?? 'مستخدم'}', style: theme.textTheme.bodySmall),
          if (report.description != null) ...[
            const Divider(height: 24),
            Text(report.description!, style: theme.textTheme.bodyLarge),
          ],
          if (closed && report.resolution != null) ...[
            const Divider(height: 24),
            Text('القرار: ${report.resolution}'),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop('view'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('عرض الإعلان ومراجعته'),
          ),
          if (!closed) ...[
            const SizedBox(height: 8),
            if (report.status == 'OPEN')
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop('UNDER_REVIEW'),
                child: const Text('استلام البلاغ (قيد المراجعة)'),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop('DISMISSED'),
                  child: const Text('رفض البلاغ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop('RESOLVED'),
                  child: const Text('تم الحل'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog({required this.dismiss});

  final bool dismiss;

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.dismiss ? 'سبب رفض البلاغ' : 'ماذا تم؟'),
        content: TextField(
          controller: _text,
          autofocus: true,
          maxLines: 3,
          maxLength: 2000,
          decoration: const InputDecoration(
            helperText: 'اختياري. يصل هذا الكلام لمن أبلغ.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_text.text.trim()), child: const Text('تأكيد')),
        ],
      );
}
