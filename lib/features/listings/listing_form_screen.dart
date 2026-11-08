import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../properties/format.dart';
import 'listing_local_store.dart';
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

class _ListingFormState extends ConsumerState<_ListingForm> with WidgetsBindingObserver {
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

  // ---- unsaved changes and the local draft (new listings only)
  late final ListingLocalStore _store;
  String? _accountId; // the account the draft belongs to; null when nobody is signed in
  late final String _initialSnapshot; // the form as it was when it opened
  String? _lastSavedSnapshot;
  bool _wasDirty = false;
  bool _saved = false; // the listing was sent: nothing is unsaved any more
  bool _discarded = false; // the user chose to throw the changes away
  Map<String, Object?>? _offeredDraft; // a stored draft waiting for "restore" or "delete"
  Timer? _draftTimer;

  bool get _isLand => _type == 'LAND';
  bool get _isEdit => widget.initial != null;

  // "1500.00" -> "1500", "120.50" -> "120.5"
  static String? _trimZeros(String? v) {
    if (v == null) return null;
    return v.contains('.') ? v.replaceFirst(RegExp(r'\.?0+$'), '') : v;
  }

  // Taken while the screen is alive. Unlike `ref`, it is still usable after dispose.
  late final ProviderContainer _container;

  List<TextEditingController> get _controllers =>
      [_title, _description, _price, _area, _bedrooms, _bathrooms, _floor, _address, _phone];

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _store = ref.read(listingLocalStoreProvider);
    _accountId = ref.read(authControllerProvider).value?.id;
    _initialSnapshot = _snapshotJson();
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
    WidgetsBinding.instance.addObserver(this);
    // The account may still be loading here: build() picks it up when it arrives.
    if (!_isEdit && _accountId != null) unawaited(_offerDraft());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Going to the background is when Android may end the app: write the draft now.
    if (state != AppLifecycleState.resumed) unawaited(_flushDraft());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    unawaited(_flushDraft()); // reads the fields before they are disposed just below
    for (final c in _controllers) {
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
      _set(() {
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
    if (_saving) return; // a second tap while the first save runs would create a duplicate
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
        _saved = true;
        _container.invalidate(ownerListingProvider(id));
        _container.invalidate(myListingsProvider);
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
        _saved = true;
        _draftTimer?.cancel();
        unawaited(_clearStoredDraft()); // the listing exists now: the draft has done its job
        _container.invalidate(myListingsProvider);
        if (!mounted) return;
        // Next: photos. Replace this screen so "back" does not return to a filled form.
        context.pushReplacement('/listing/${created.id}');
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('حدث خطأ غير متوقع، حاول مرة أخرى')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- unsaved changes and the draft

  /// Every value the user can change, as plain data. Also what a draft stores: only text and
  /// choices, no tokens and no photos (photos are sent after the listing exists).
  Map<String, Object?> _snapshotMap() => {
        'purpose': _purpose,
        'type': _type,
        'currency': _currency,
        'rentPeriod': _rentPeriod,
        'furnished': _furnished,
        'showPhone': _showPhone,
        'allowWhatsapp': _allowWhatsapp,
        'locationId': _locationId,
        'locationName': _locationName,
        'title': _title.text,
        'description': _description.text,
        'price': _price.text,
        'area': _area.text,
        'bedrooms': _bedrooms.text,
        'bathrooms': _bathrooms.text,
        'floor': _floor.text,
        'address': _address.text,
        'phone': _phone.text,
      };

  String _snapshotJson() => jsonEncode(_snapshotMap());

  bool get _dirty => _snapshotJson() != _initialSnapshot;

  bool get _canKeepDraft => !_isEdit && _accountId != null;

  /// A change of text, choice or location: refresh the unsaved-changes state and (for a new
  /// listing) write the draft shortly after the user stops typing.
  void _onChanged() {
    final dirty = _dirty;
    if (dirty != _wasDirty) {
      _wasDirty = dirty;
      if (mounted) setState(() {});
    }
    if (_canKeepDraft) {
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 800), () => unawaited(_flushDraft()));
    }
  }

  void _set(VoidCallback change) {
    setState(change);
    _onChanged();
  }

  Future<void> _flushDraft() async {
    _draftTimer?.cancel();
    final id = _accountId;
    // While an older draft is still being offered, writing would silently replace it.
    if (!_canKeepDraft || id == null || _saved || _discarded || _offeredDraft != null) return;
    final snapshot = _snapshotJson();
    if (snapshot == _lastSavedSnapshot) return;
    _lastSavedSnapshot = snapshot;
    if (snapshot == _initialSnapshot) {
      await _store.clearDraft(id); // back to a blank form: nothing worth keeping
    } else {
      await _store.saveDraft(id, {..._snapshotMap(), 'step': _step});
    }
  }

  Future<void> _clearStoredDraft() async {
    final id = _accountId;
    if (id != null) await _store.clearDraft(id);
  }

  Future<void> _offerDraft() async {
    final id = _accountId;
    if (id == null) return;
    final draft = await _store.loadDraft(id);
    if (draft == null || !mounted) return;
    final fields = {...draft}..remove('step');
    if (jsonEncode(fields) == _initialSnapshot) return; // nothing different from a blank form
    setState(() => _offeredDraft = draft);
  }

  void _restoreDraft() {
    final d = _offeredDraft;
    if (d == null) return;
    String text(String k) => d[k] is String ? d[k] as String : '';
    bool flag(String k, bool fallback) => d[k] is bool ? d[k] as bool : fallback;
    String choice(String k, Iterable<String> allowed, String fallback) =>
        allowed.contains(d[k]) ? d[k] as String : fallback;

    _title.text = text('title');
    _description.text = text('description');
    _price.text = text('price');
    _area.text = text('area');
    _bedrooms.text = text('bedrooms');
    _bathrooms.text = text('bathrooms');
    _floor.text = text('floor');
    _address.text = text('address');
    if (text('phone').isNotEmpty) _phone.text = text('phone');
    setState(() {
      _purpose = choice('purpose', const ['SALE', 'RENT'], _purpose);
      _type = choice('type', propertyTypeNames.keys, _type);
      _currency = choice('currency', _currencies.keys, _currency);
      _rentPeriod = choice('rentPeriod', _periods.keys, _rentPeriod);
      _furnished = flag('furnished', _furnished);
      _showPhone = flag('showPhone', _showPhone);
      _allowWhatsapp = flag('allowWhatsapp', _allowWhatsapp);
      final loc = d['locationId'];
      _locationId = loc is String && loc.isNotEmpty ? loc : null;
      _locationName = text('locationName');
      _locationMissing = false;
      final step = d['step'];
      _step = step is int && step >= 0 && step < _stepTitles.length ? step : 0;
      _offeredDraft = null;
    });
    _lastSavedSnapshot = _snapshotJson();
    _wasDirty = _dirty;
  }

  Future<void> _discardOffered() async {
    setState(() => _offeredDraft = null);
    await _clearStoredDraft();
  }

  Future<void> _confirmLeave() async {
    final choice = await showDialog<_Leave>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_isEdit ? 'تجاهل التعديلات؟' : 'حفظ الإعلان كمسودة؟'),
        content: Text(_isEdit
            ? 'لديك تعديلات لم تُحفظ.'
            : 'لديك بيانات لم تُرسل بعد. يمكن حفظ ما كتبته على هذا الجهاز لتكمله لاحقاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_Leave.stay),
            child: const Text('متابعة التعديل'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_Leave.discard),
            child: const Text('تجاهل'),
          ),
          if (_canKeepDraft)
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(_Leave.keep),
              child: const Text('حفظ ومغادرة'),
            ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == _Leave.stay) return;

    if (choice == _Leave.keep) {
      setState(() => _offeredDraft = null); // what the user typed replaces the older draft
      await _flushDraft();
    } else {
      _discarded = true;
      _draftTimer?.cancel();
      // An older draft the user never answered stays; the autosaved copy of these edits goes.
      if (_canKeepDraft && _offeredDraft == null) await _clearStoredDraft();
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _stepTitles.length - 1;
    // The draft belongs to an account, so follow the account (it may load after this screen opens).
    final accountId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    if (accountId != _accountId) {
      _accountId = accountId;
      _offeredDraft = null;
      if (!_isEdit && accountId != null) unawaited(_offerDraft());
    }
    return PopScope(
      canPop: _saved || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _confirmLeave();
      },
      child: Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الإعلان' : 'إعلان جديد')),
      body: Column(children: [
        if (_offeredDraft != null) _DraftBanner(onRestore: _restoreDraft, onDiscard: _discardOffered),
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
            onSelectionChanged: (s) => _set(() => _purpose = s.first),
          ),
          _gap,
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'نوع العقار', border: OutlineInputBorder()),
            items: [
              for (final e in propertyTypeNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => _set(() => _type = v!),
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
              onChanged: (v) => _set(() => _currency = v!),
            ),
          ),
        ]),
        if (_purpose == 'RENT') ...[
          _gap,
          DropdownButtonFormField<String>(
            initialValue: _rentPeriod,
            decoration: const InputDecoration(labelText: 'مدة الإيجار', border: OutlineInputBorder()),
            items: [for (final e in _periods.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => _set(() => _rentPeriod = v!),
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
            onChanged: (v) => _set(() => _furnished = v),
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
          onChanged: (v) => _set(() => _showPhone = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('السماح بالتواصل عبر واتساب'),
          value: _allowWhatsapp,
          onChanged: _showPhone ? (v) => _set(() => _allowWhatsapp = v) : null,
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

enum _Leave { stay, discard, keep }

/// Shown above the steps when this account has an unfinished draft on the device.
class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.onRestore, required this.onDiscard});

  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'لديك مسودة إعلان غير مكتملة على هذا الجهاز.',
          style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
        ),
        Row(children: [
          TextButton(onPressed: onRestore, child: const Text('استعادة المسودة')),
          TextButton(onPressed: onDiscard, child: const Text('حذف المسودة')),
        ]),
      ]),
    );
  }
}
