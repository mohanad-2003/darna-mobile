import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import 'listing_models.dart';
import 'listing_repository.dart';

const _maxPhotos = 20;
const _maxBytes = 10 * 1024 * 1024;

class _UploadItem {
  _UploadItem(this.name);

  final String name;
  String? error;
}

/// One listing from its owner's side: status, photos, and the actions that apply.
class ManageListingScreen extends ConsumerStatefulWidget {
  const ManageListingScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<ManageListingScreen> createState() => _ManageListingScreenState();
}

class _ManageListingScreenState extends ConsumerState<ManageListingScreen> {
  final _picker = ImagePicker();
  final List<_UploadItem> _uploads = [];
  bool _working = false;

  String get _id => widget.propertyId;
  bool get _uploading => _uploads.any((u) => u.error == null);

  void _refresh() {
    ref.invalidate(ownerListingProvider(_id));
    ref.invalidate(myListingsProvider);
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _addPhotos(OwnerListing listing) async {
    final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2400, maxHeight: 2400);
    if (picked.isEmpty) return;

    final room = _maxPhotos - listing.media.length - _uploads.length;
    if (room <= 0) {
      _snack('وصلت إلى الحد الأقصى ($_maxPhotos صورة)');
      return;
    }
    if (picked.length > room) _snack('سيُرفع أول $room صور فقط (الحد الأقصى $_maxPhotos)');

    final repo = ref.read(listingRepositoryProvider);
    for (final file in picked.take(room)) {
      final item = _UploadItem(file.name);
      setState(() => _uploads.add(item));
      try {
        final bytes = await file.readAsBytes();
        final type = sniffImageType(bytes);
        if (type == null) throw ApiException(status: 0, code: 'TYPE', message: 'نوع الصورة غير مدعوم (JPG أو PNG أو WebP)');
        if (bytes.length > _maxBytes) throw ApiException(status: 0, code: 'SIZE', message: 'الصورة أكبر من 10 ميغابايت');

        final ticket = await repo.uploadTicket(_id, type, bytes.length);
        await repo.putToStorage(ticket, bytes);
        await repo.attach(_id, ticket.uploadId);
        ref.invalidate(ownerListingProvider(_id));
        if (mounted) setState(() => _uploads.remove(item));
      } on ApiException catch (e) {
        if (mounted) setState(() => item.error = e.message);
      }
    }
    ref.invalidate(myListingsProvider);
  }

  Future<void> _photoActions(ListingMedia m, bool isOnlyPhoto, OwnerListing listing) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!m.isCover)
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('جعلها صورة الغلاف'),
              onTap: () => Navigator.of(context).pop('cover'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('حذف الصورة'),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ]),
      ),
    );
    if (action == null) return;
    final repo = ref.read(listingRepositoryProvider);
    try {
      if (action == 'cover') await repo.setCover(_id, m.id);
      if (action == 'delete') await repo.deleteMedia(_id, m.id);
      _refresh();
    } on ApiException catch (e) {
      _snack(e.code == 'CONFLICT' ? 'لا يمكن حذف آخر صورة من إعلان منشور' : e.message);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('تأكيد')),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _working = true);
    try {
      await action();
      _refresh();
      if (done != null && mounted) _snack(done);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(ownerListingProvider(_id));
    final repo = ref.read(listingRepositoryProvider);

    return listingAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e is ApiException ? e.message : 'تعذر تحميل الإعلان'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
          ]),
        ),
      ),
      data: (l) {
        final info = statusInfo(l.status);
        final canEditPhotos = l.isEditable;
        return Scaffold(
          appBar: AppBar(
            title: const Text('إدارة الإعلان'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await context.push('/listing/$_id/edit');
                    _refresh();
                  } else if (v == 'pause') {
                    await _run(() => repo.pause(_id), done: 'تم إيقاف الإعلان مؤقتاً');
                  } else if (v == 'resume') {
                    await _run(() => repo.resume(_id), done: 'تم استئناف الإعلان');
                  } else if (v == 'renew') {
                    await _run(() => repo.renew(_id), done: 'تم تجديد الإعلان');
                  } else if (v == 'archive') {
                    if (await _confirm('أرشفة الإعلان', 'سيختفي الإعلان نهائياً من قائمتك ومن البحث. متأكد؟')) {
                      await _run(() => repo.archive(_id));
                      if (context.mounted) context.pop();
                    }
                  }
                },
                itemBuilder: (_) => [
                  if (l.isEditable) const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                  if (l.status == 'PUBLISHED') const PopupMenuItem(value: 'pause', child: Text('إيقاف مؤقت')),
                  if (l.status == 'PAUSED') const PopupMenuItem(value: 'resume', child: Text('استئناف')),
                  if (l.status == 'EXPIRED') const PopupMenuItem(value: 'renew', child: Text('تجديد')),
                  if (l.status != 'ARCHIVED') const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.title, style: Theme.of(context).textTheme.titleLarge),
              if (l.locationName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(l.locationName),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: info.color.withValues(alpha: 0.4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.label, style: TextStyle(color: info.color, fontWeight: FontWeight.bold)),
                  if (info.hint.isNotEmpty) Text(info.hint),
                  if (l.moderationReason != null && l.moderationReason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('ملاحظة المراجع: ${l.moderationReason}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
              if (l.status == 'PUBLISHED')
                TextButton.icon(
                  onPressed: () => context.push('/property/$_id'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('عرض كما يراه الزوار'),
                ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: Text('الصور (${l.media.length}/$_maxPhotos)', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (canEditPhotos)
                  OutlinedButton.icon(
                    onPressed: () => _addPhotos(l),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('إضافة صور'),
                  ),
              ]),
              const SizedBox(height: 12),
              if (l.media.isEmpty && _uploads.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('لم تضف صوراً بعد. الإعلان بالصور يحصل على اهتمام أكبر بكثير.')),
                ),
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final m in l.media)
                    GestureDetector(
                      onTap: canEditPhotos ? () => _photoActions(m, l.media.length == 1, l) : null,
                      child: Stack(fit: StackFit.expand, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: m.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const ColoredBox(color: Colors.black12),
                            errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        if (m.isCover)
                          PositionedDirectional(
                            top: 4,
                            start: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                              child: Text('الغلاف',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 11)),
                            ),
                          ),
                      ]),
                    ),
                  for (final u in _uploads)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: u.error == null
                          ? const Center(child: CircularProgressIndicator())
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              Text(u.error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10), maxLines: 3, overflow: TextOverflow.ellipsis),
                              InkWell(
                                onTap: () => setState(() => _uploads.remove(u)),
                                child: const Padding(padding: EdgeInsets.all(2), child: Text('إغلاق', style: TextStyle(fontSize: 11))),
                              ),
                            ]),
                    ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: l.canSubmit
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: (_working || _uploading || l.media.isEmpty)
                          ? null
                          : () async {
                              if (await _confirm('إرسال للمراجعة', 'سيُراجَع الإعلان قبل ظهوره للجميع. هل بياناته وصوره جاهزة؟')) {
                                await _run(() => repo.submit(_id), done: 'تم إرسال الإعلان للمراجعة');
                              }
                            },
                      child: Text(l.media.isEmpty ? 'أضف صورة واحدة على الأقل لتتمكن من الإرسال' : 'إرسال للمراجعة'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
