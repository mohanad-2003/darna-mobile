import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'property_repository.dart';

const _currencies = {'ILS': 'شيكل ₪', 'USD': r'دولار $', 'JOD': 'دينار'};
const _sorts = {'newest': 'الأحدث', 'price_asc': 'الأقل سعراً', 'price_desc': 'الأعلى سعراً'};

/// Filter sheet: property types, price range, rooms and sort. Returns the new filters
/// when the user applies them, or null if the sheet is dismissed.
Future<SearchFilters?> showFiltersSheet(BuildContext context, SearchFilters current) =>
    showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FiltersSheet(initial: current),
    );

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final Set<String> _types = {...widget.initial.propertyTypes};
  late String _currency = widget.initial.currency ?? 'ILS';
  late int? _bedrooms = widget.initial.minBedrooms;
  late String _sort = widget.initial.sort;
  late final _min = TextEditingController(text: widget.initial.minPrice);
  late final _max = TextEditingController(text: widget.initial.maxPrice);
  String? _error;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  void _apply() {
    final min = _clean(_min);
    final max = _clean(_max);
    final decimal = RegExp(r'^[0-9]+(\.[0-9]{1,2})?$');
    if ((min != null && !decimal.hasMatch(min)) || (max != null && !decimal.hasMatch(max))) {
      setState(() => _error = 'أدخل أرقاماً صحيحة في السعر');
      return;
    }
    if (min != null && max != null && double.parse(min) > double.parse(max)) {
      setState(() => _error = 'الحد الأدنى أكبر من الحد الأعلى');
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(SearchFilters(
      purpose: base.purpose,
      locationId: base.locationId,
      locationName: base.locationName,
      propertyTypes: _types,
      currency: _currency,
      minPrice: min,
      maxPrice: max,
      minBedrooms: _bedrooms,
      sort: _sort,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('نوع العقار', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final e in propertyTypeNames.entries)
                FilterChip(
                  label: Text(e.value),
                  selected: _types.contains(e.key),
                  onSelected: (on) => setState(() => on ? _types.add(e.key) : _types.remove(e.key)),
                ),
            ]),
            const SizedBox(height: 20),
            Text('السعر', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [for (final e in _currencies.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {_currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _priceField(_min, 'من')),
              const SizedBox(width: 12),
              Expanded(child: _priceField(_max, 'إلى')),
            ]),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: 20),
            Text('عدد الغرف (على الأقل)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('الكل'), selected: _bedrooms == null, onSelected: (_) => setState(() => _bedrooms = null)),
              for (final n in [1, 2, 3, 4, 5])
                ChoiceChip(label: Text('$n+'), selected: _bedrooms == n, onSelected: (_) => setState(() => _bedrooms = n)),
            ]),
            const SizedBox(height: 20),
            Text('الترتيب', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final e in _sorts.entries)
                ChoiceChip(label: Text(e.value), selected: _sort == e.key, onSelected: (_) => setState(() => _sort = e.key)),
            ]),
            if (_sort != 'newest')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('الترتيب بالسعر يقارن الإعلانات بالعملة المختارة أعلاه فقط.', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(widget.initial.clearedSheet()),
                  child: const Text('مسح الكل'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: FilledButton(onPressed: _apply, child: const Text('تطبيق'))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _priceField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );
}
