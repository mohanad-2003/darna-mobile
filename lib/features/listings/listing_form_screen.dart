import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../properties/format.dart';
import 'listing_models.dart';
import 'listing_repository.dart';
import 'location_picker.dart';

/// Create a listing (propertyId == null) or edit an existing one.
class ListingFormScreen extends ConsumerWidget {
  const ListingFormScreen({super.key, this.propertyId});

  final String? propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = propertyId;
    if (id == null) return const _ListingForm();

    final listing = ref.watch(ownerListingProvider(id));
    return listing.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e is ApiException ? e.message : 'تعذر تحميل الإعلان')),
      ),
      data: (l) => _ListingForm(initial: l),
    );
  }
}

const _currencies = {'ILS': 'شيكل ₪', 'USD': r'دولار $', 'JOD': 'دينار أردني'};
const _periods = {'MONTHLY': 'شهرياً', 'YEARLY': 'سنوياً', 'WEEKLY': 'أسبوعياً', 'DAILY': 'يومياً'};

class _ListingForm extends ConsumerStatefulWidget {
  const _ListingForm({this.initial});

  final OwnerListing? initial;

  @override
  ConsumerState<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends ConsumerState<_ListingForm> {
  // Three short steps instead of one long scroll. Every step's form stays built (IndexedStack),
  // so values are kept and the final save can validate all of them.
  final _stepKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];
  static const _stepTitles = ['الأساسيات', 'التفاصيل', 'التواصل'];
  int _step = 0;
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _price = TextEditingController(text: _trimZeros(widget.initial?.price));
  late final _area = TextEditingController(text: _trimZeros(widget.initial?.areaSqm));
  late final _bedrooms = TextEditingController(text: widget.initial?.bedrooms?.toString());
  late final _bathrooms = TextEditingController(text: widget.initial?.bathrooms?.toString());
  late final _floor = TextEditingController(text: widget.initial?.floorNumber?.toString());
  late final _address = TextEditingController(text: widget.initial?.addressText);
  late final _phone = TextEditingController(
      text: widget.initial?.contactPhone ?? ref.read(authControllerProvider).value?.phone);

  late String _purpose = widget.initial?.purpose ?? 'SALE';
  late String _type = widget.initial?.propertyType ?? 'APARTMENT';
  late String _currency = widget.initial?.currency ?? 'ILS';
  late String _rentPeriod = widget.initial?.rentPeriod ?? 'MONTHLY';
  late bool _furnished = widget.initial?.furnished ?? false;
  late bool _showPhone = widget.initial?.showPhone ?? true;
  late bool _allowWhatsapp = widget.initial?.allowWhatsapp ?? true;
  late String? _locationId = (widget.initial?.locationId.isEmpty ?? true) ? null : widget.initial!.locationId;
  late String _locationName = widget.initial?.locationName ?? '';
  bool _saving = false;
  bool _locationMissing = false;

  bool get _isLand => _type == 'LAND';
  bool get _isEdit => widget.initial != null;

  // "1500.00" -> "1500", "120.50" -> "120.5"
  static String? _trimZeros(String? v) {
    if (v == null) return null;
    return v.contains('.') ? v.replaceFirst(RegExp(r'\.?0+$'), '') : v;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _area, _bedrooms, _bathrooms, _floor, _address, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, {int min = 1, String? what}) =>
      (v == null || v.trim().length < min) ? (what ?? 'هذا الحقل مطلوب') : null;

  String? _decimal(String? v, {required bool required}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? 'هذا الحقل مطلوب' : null;
    if (!RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(s)) return 'أدخل رقماً صحيحاً (حتى منزلتين عشريتين)';
    if (double.parse(s) <= 0) return 'يجب أن يكون أكبر من صفر';
    return null;
  }

  String? _wholeNumber(String? v, {int min = 0, int max = 100}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null || n < min || n > max) return 'من $min إلى $max';
    return null;
  }

  int? _int(TextEditingController c) => c.text.trim().isEmpty ? null : int.parse(c.text.trim());
  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _chooseLocation() async {
    final picked = await pickLocation(context);
    if (picked != null) {
      setState(() {
        _locationId = picked.id;
        _locationName = picked.name;
        _locationMissing = false;
      });
    }
  }

  Json _body() => {
        'locationId': _locationId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'purpose': _purpose,
        'propertyType': _type,
        'price': _price.text.trim(),
        'currency': _currency,
        'rentPeriod': _purpose == 'RENT' ? _rentPeriod : null,
        'areaSqm': _text(_area),
        // Land has no rooms or floors; the backend rejects them.
        'bedrooms': _isLand ? null : _int(_bedrooms),
        'bathrooms': _isLand ? null : _int(_bathrooms),
        'floorNumber': _isLand ? null : _int(_floor),
        'furnished': _isLand ? null : _furnished,
        'contactPhone': _phone.text.trim(),
        'showPhone': _showPhone,
        'allowWhatsapp': _allowWhatsapp,
        'addressText': _text(_address),
      };

  bool _validateStep(int i) {
    var ok = _stepKeys[i].currentState?.validate() ?? true;
    if (i == 0) {
      setState(() => _locationMissing = _locationId == null);
      ok = ok && _locationId != null;
    }
    return ok;
  }

  void _next() {
    if (_validateStep(_step)) setState(() => _step += 1);
  }

  Future<void> _save() async {
    for (var i = 0; i < _stepKeys.length; i++) {
      if (!_validateStep(i)) {
        setState(() => _step = i); // show the first step with a problem
        return;
      }
    }

    setState(() => _saving = true);
    final repo = ref.read(listingRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEdit) {
        final id = widget.initial!.id;
        final saved = await repo.update(id, _body());
        ref.invalidate(ownerListingProvider(id));
        ref.invalidate(myListingsProvider);
        if (!mounted) return;
        if (saved.status == 'PENDING_REVIEW' && widget.initial!.status != 'PENDING_REVIEW') {
          messenger.showSnackBar(const SnackBar(
            content: Text('تم الحفظ. لأنك غيّرت بيانات أساسية سيُراجَع الإعلان من جديد قبل أن يظهر.'),
            duration: Duration(seconds: 6),
          ));
        }
        context.pop();
      } else {
        final created = await repo.create(_body());
        ref.invalidate(myListingsProvider);
        if (!mounted) return;
        // Next: photos. Replace this screen so "back" does not return to a filled form.
        context.pushReplacement('/listing/${created.id}');
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _stepTitles.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الإعلان' : 'إعلان جديد')),
      body: Column(children: [
        _StepHeader(
          titles: _stepTitles,
          current: _step,
          // Going back is free; going forward goes through "next" so each step is checked.
          onTap: (i) {
            if (i < _step) setState(() => _step = i);
          },
        ),
        Expanded(
          child: IndexedStack(index: _step, children: [_basicsStep(), _detailsStep(), _contactStep()]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _step -= 1),
                  child: const Text('السابق'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving ? null : (last ? _save : _next),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(last ? (_isEdit ? 'حفظ التعديلات' : 'التالي: إضافة الصور') : 'التالي'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static const _gap = SizedBox(height: 16);

  // ---- step 1: what and where

  Widget _basicsStep() => Form(
        key: _stepKeys[0],
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'SALE', label: Text('للبيع')),
              ButtonSegment(value: 'RENT', label: Text('للإيجار')),
            ],
            selected: {_purpose},
            onSelectionChanged: (s) => setState(() => _purpose = s.first),
          ),
          _gap,
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'نوع العقار', border: OutlineInputBorder()),
            items: [
              for (final e in propertyTypeNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          _gap,
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'الموقع',
              border: const OutlineInputBorder(),
              errorText: _locationMissing ? 'اختر الموقع' : null,
            ),
            child: InkWell(
              onTap: _chooseLocation,
              child: Row(children: [
                Expanded(child: Text(_locationName.isEmpty ? 'اضغط للاختيار' : _locationName)),
                const Icon(Icons.chevron_left),
              ]),
            ),
          ),
          _gap,
          TextFormField(
            controller: _title,
            maxLength: 180,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان', border: OutlineInputBorder()),
            validator: (v) => _required(v, min: 5, what: 'العنوان قصير (5 أحرف على الأقل)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            maxLines: 5,
            maxLength: 10000,
            decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder(), alignLabelWithHint: true),
            validator: (v) => _required(v, min: 20, what: 'الوصف قصير (20 حرفاً على الأقل)'),
          ),
        ]),
      );

  // ---- step 2: price and specifications

  Widget _detailsStep() {
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final whole = [FilteringTextInputFormatter.digitsOnly];
    return Form(
      key: _stepKeys[1],
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: digits,
              decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder()),
              validator: (v) => _decimal(v, required: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
              isExpanded: true,
              items: [for (final e in _currencies.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _currency = v!),
            ),
          ),
        ]),
        if (_purpose == 'RENT') ...[
          _gap,
          DropdownButtonFormField<String>(
            initialValue: _rentPeriod,
            decoration: const InputDecoration(labelText: 'مدة الإيجار', border: OutlineInputBorder()),
            items: [for (final e in _periods.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _rentPeriod = v!),
          ),
        ],
        _gap,
        TextFormField(
          controller: _area,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: digits,
          decoration: const InputDecoration(labelText: 'المساحة (م²)', border: OutlineInputBorder()),
          validator: (v) => _decimal(v, required: false),
        ),
        if (!_isLand) ...[
          _gap,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: _bedrooms,
                keyboardType: TextInputType.number,
                inputFormatters: whole,
                decoration: const InputDecoration(labelText: 'الغرف', border: OutlineInputBorder()),
                validator: _wholeNumber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _bathrooms,
                keyboardType: TextInputType.number,
                inputFormatters: whole,
                decoration: const InputDecoration(labelText: 'الحمامات', border: OutlineInputBorder()),
                validator: _wholeNumber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _floor,
                keyboardType: TextInputType.number,
                inputFormatters: whole,
                decoration: const InputDecoration(labelText: 'الطابق', border: OutlineInputBorder()),
                validator: (v) => _wholeNumber(v, max: 300),
              ),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('مفروش'),
            value: _furnished,
            onChanged: (v) => setState(() => _furnished = v),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: _address,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'العنوان التفصيلي (اختياري)',
            helperText: 'مثل اسم الحي أو الشارع. لا يظهر موقعك الدقيق على خريطة.',
            border: OutlineInputBorder(),
          ),
        ),
      ]),
    );
  }

  // ---- step 3: how people reach you

  Widget _contactStep() {
    final theme = Theme.of(context);
    return Form(
      key: _stepKeys[2],
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم التواصل لهذا الإعلان',
              helperText: 'بصيغة دولية، مثل +970599123456',
              border: OutlineInputBorder(),
            ),
            validator: (v) => RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(v?.trim() ?? '')
                ? null
                : 'أدخل الرقم بصيغة +970599123456',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('السماح بإظهار رقمي للمهتمين'),
          subtitle: const Text('عند الإيقاف يتواصل المهتمون عبر الاستفسارات داخل التطبيق فقط'),
          value: _showPhone,
          onChanged: (v) => setState(() => _showPhone = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('السماح بالتواصل عبر واتساب'),
          value: _allowWhatsapp,
          onChanged: _showPhone ? (v) => setState(() => _allowWhatsapp = v) : null,
        ),
        _gap,
        // A last look at what is about to be saved.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ملخص إعلانك', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(_title.text.trim().isEmpty ? '—' : _title.text.trim(), style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${_purpose == 'RENT' ? 'للإيجار' : 'للبيع'} · ${propertyTypeNames[_type] ?? ''}'
                '${_locationName.isEmpty ? '' : ' · $_locationName'}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_price.text.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${_price.text.trim()} ${_currencies[_currency] ?? _currency}',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              const SizedBox(height: 8),
              Text('بعد الحفظ تضيف الصور ثم ترسل الإعلان للمراجعة.', style: theme.textTheme.bodySmall),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Numbered steps with a line between them; finished steps show a check and can be tapped
/// to go back.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.titles, required this.current, required this.onTap});

  final List<String> titles;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(children: [
        for (var i = 0; i < titles.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= current ? scheme.primary : scheme.outlineVariant,
              ),
            ),
          InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? scheme.primary : scheme.surfaceContainerHighest,
                ),
                child: i < current
                    ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: i == current ? scheme.onPrimary : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                titles[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                  color: i == current ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
