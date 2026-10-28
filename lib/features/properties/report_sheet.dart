import 'package:flutter/material.dart';

import '../admin/admin_repository.dart';

class ReportInput {
  ReportInput(this.reason, this.description);

  final String reason;
  final String? description;
}

/// Asks why a listing is being reported. Returns null if the user backs out.
Future<ReportInput?> showReportSheet(BuildContext context) => showModalBottomSheet<ReportInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReportSheet(),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (_reason == null) {
      setState(() => _error = 'اختر سبب البلاغ');
      return;
    }
    if (_reason == 'OTHER' && text.isEmpty) {
      setState(() => _error = 'اشرح السبب باختصار');
      return;
    }
    Navigator.of(context).pop(ReportInput(_reason!, text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('الإبلاغ عن الإعلان', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('ما المشكلة في هذا الإعلان؟'),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() {
                _reason = v;
                _error = null;
              }),
              child: Column(children: [
                for (final e in reportReasonNames.entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: e.key,
                    title: Text(e.value),
                  ),
              ]),
            ),
            TextField(
              controller: _text,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: _reason == 'OTHER' ? 'التفاصيل (مطلوبة)' : 'تفاصيل إضافية (اختياري)',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _send, child: const Text('إرسال البلاغ'))),
          ]),
        ),
      ),
    );
  }
}
