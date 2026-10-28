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
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _save() async {
    setState(() => _locationMissing = _locationId == null);
    if (!_formKey.currentState!.validate() || _locationId == null) return;

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
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final whole = [FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الإعلان' : 'إعلان جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'SALE', label: Text('للبيع')),
                ButtonSegment(value: 'RENT', label: Text('للإيجار')),
              ],
              selected: {_purpose},
              onSelectionChanged: (s) => setState(() => _purpose = s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'نوع العقار', border: OutlineInputBorder()),
              items: [
                for (final e in propertyTypeNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _rentPeriod,
                decoration: const InputDecoration(labelText: 'مدة الإيجار', border: OutlineInputBorder()),
                items: [for (final e in _periods.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _rentPeriod = v!),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _area,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: digits,
              decoration: const InputDecoration(labelText: 'المساحة (م²)', border: OutlineInputBorder()),
              validator: (v) => _decimal(v, required: false),
            ),
            if (!_isLand) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            Text('التواصل', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'حفظ التعديلات' : 'التالي: إضافة الصور'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
