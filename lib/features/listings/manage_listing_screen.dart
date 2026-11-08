import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/widgets/illustration.dart';
import 'listing_models.dart';
import 'listing_repository.dart';
import 'submitted_dialog.dart';

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
  ConsumerState<ManageListingScreen> createState() =>
      _ManageListingScreenState();
}

class _ManageListingScreenState extends ConsumerState<ManageListingScreen> {
  final _picker = ImagePicker();
  final List<_UploadItem> _uploads = [];
  bool _working = false;
  // The system picker allows one open window at a time; a second request while it is open
  // (a double tap) fails with "already_active".
  bool _picking = false;
  // Taken while the screen is alive. Unlike `ref`, it is still usable after dispose.
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  String get _id => widget.propertyId;
  bool get _uploading => _uploads.any((u) => u.error == null);

  void _refresh() {
    _container.invalidate(ownerListingProvider(_id));
    _container.invalidate(myListingsProvider);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addPhotos(OwnerListing listing) async {
    if (_picking) return;
    _picking = true;
    final List<XFile> picked;

    try {
      picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
      );
    } on PlatformException catch (e) {
      // "already_active": another picker window is still open, so there is nothing to report.
      if (e.code != 'already_active') {
        _snack('تعذر فتح معرض الصور، حاول مرة أخرى');
      }
      return;
    } finally {
      _picking = false;
    }
    if (picked.isEmpty || !mounted) return;

    final room = _maxPhotos - listing.media.length - _uploads.length;
    if (room <= 0) {
      _snack('وصلت إلى الحد الأقصى ($_maxPhotos صورة)');
      return;
    }
    if (picked.length > room) {
      _snack('سيُرفع أول $room صور فقط (الحد الأقصى $_maxPhotos)');
    }

    final repo = ref.read(listingRepositoryProvider);
    for (final file in picked.take(room)) {
      if (!mounted) return; // the user left: stop starting new uploads
      final item = _UploadItem(file.name);
      setState(() => _uploads.add(item));
      try {
        final bytes = await file.readAsBytes();
        final type = sniffImageType(bytes);
        if (type == null) {
          throw ApiException(
            status: 0,
            code: 'TYPE',
            message: 'نوع الصورة غير مدعوم (JPG أو PNG أو WebP)',
          );
        }
        if (bytes.length > _maxBytes) {
          throw ApiException(
            status: 0,
            code: 'SIZE',
            message: 'الصورة أكبر من 10 ميغابايت',
          );
        }

        final ticket = await repo.uploadTicket(_id, type, bytes.length);
        await repo.putToStorage(ticket, bytes);
        await repo.attach(_id, ticket.uploadId);
        _refresh();
        if (mounted) setState(() => _uploads.remove(item));
      } on ApiException catch (e) {
        if (mounted) setState(() => item.error = e.message);
      } catch (_) {
        // The file could not be read (removed, no permission) or something unexpected:
        // the picture must end in a visible error, never spin forever.
        if (mounted) {
          setState(() => item.error = 'تعذرت قراءة الصورة أو رفعها، حاول مرة أخرى');
        }
      }
    }
    _refresh();
  }

  Future<void> _photoActions(
    ListingMedia m,
    bool isOnlyPhoto,
    OwnerListing listing,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.isCover)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('جعلها صورة الغلاف'),
                onTap: () => Navigator.of(sheetContext).pop('cover'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('حذف الصورة'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(listingRepositoryProvider);
    await _run(
      () => action == 'cover' ? repo.setCover(_id, m.id) : repo.deleteMedia(_id, m.id),
      errorText: (e) => e.code == 'CONFLICT' ? 'لا يمكن حذف آخر صورة من إعلان منشور' : e.message,
    );
  }

  Future<bool> _confirm(
    String title,
    String body, {
    String confirmLabel = 'تأكيد',
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  /// The owner removes the listing: it disappears from the app and from search. The server
  /// archives it (history is kept for moderation), so to the owner this is a deletion.
  Future<void> _deleteListing() async {
    final confirmed = await _confirm(
      'حذف الإعلان',
      'سيُحذف الإعلان ويختفي من التطبيق ومن بحث الآخرين، ولا يمكنك استرجاعه. هل أنت متأكد؟',
      confirmLabel: 'حذف الإعلان',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final repo = ref.read(listingRepositoryProvider);
    if (await _run(() => repo.archive(_id)) && mounted) {
      _snack('تم حذف الإعلان');
      context.pop();
    }
  }

  /// Runs an action with the busy state; returns whether it succeeded.
  Future<bool> _run(
    Future<void> Function() action, {
    String? done,
    String Function(ApiException e)? errorText,
  }) async {
    if (_working) return false; // a second tap while the first action is still running
    setState(() => _working = true);
    try {
      await action();
      _refresh();
      if (done != null) _snack(done);
      return true;
    } on ApiException catch (e) {
      _snack(errorText?.call(e) ?? e.message);
      return false;
    } catch (_) {
      _snack('حدث خطأ غير متوقع، حاول مرة أخرى');
      return false;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(ownerListingProvider(_id));
    final repo = ref.read(listingRepositoryProvider);

    return listingAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is ApiException ? e.message : 'تعذر تحميل الإعلان'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refresh,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
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
                    await _run(
                      () => repo.pause(_id),
                      done: 'تم إيقاف الإعلان مؤقتاً',
                    );
                  } else if (v == 'resume') {
                    await _run(
                      () => repo.resume(_id),
                      done: 'تم استئناف الإعلان',
                    );
                  } else if (v == 'renew') {
                    await _run(() => repo.renew(_id), done: 'تم تجديد الإعلان');
                  } else if (v == 'delete') {
                    await _deleteListing();
                  }
                },
                itemBuilder: (_) => [
                  if (l.isEditable)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('تعديل البيانات'),
                    ),
                  if (l.status == 'PUBLISHED')
                    const PopupMenuItem(
                      value: 'pause',
                      child: Text('إيقاف مؤقت'),
                    ),
                  if (l.status == 'PAUSED')
                    const PopupMenuItem(
                      value: 'resume',
                      child: Text('استئناف'),
                    ),
                  if (l.status == 'EXPIRED')
                    const PopupMenuItem(value: 'renew', child: Text('تجديد')),
                  if (l.status != 'ARCHIVED')
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'حذف الإعلان',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: TextStyle(
                        color: info.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (info.hint.isNotEmpty) Text(info.hint),
                    if (l.moderationReason != null &&
                        l.moderationReason!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'ملاحظة المراجع: ${l.moderationReason}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              if (l.status == 'PUBLISHED')
                TextButton.icon(
                  onPressed: () => context.push('/property/$_id'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('عرض كما يراه الزوار'),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'الصور (${l.media.length}/$_maxPhotos)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (canEditPhotos)
                    OutlinedButton.icon(
                      onPressed: () => _addPhotos(l),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('إضافة صور'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (l.media.isEmpty && _uploads.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      const ClayIllustration(StateArt.addPhotos, size: 170),
                      const SizedBox(height: 12),
                      const Text(
                        'لم تضف صوراً بعد. الإعلان بالصور يحصل على اهتمام أكبر بكثير.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
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
                      onTap: canEditPhotos
                          ? () => _photoActions(m, l.media.length == 1, l)
                          : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: m.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              errorWidget: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                          if (m.isCover)
                            PositionedDirectional(
                              top: 4,
                              start: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'الغلاف',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  for (final u in _uploads)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: u.error == null
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                ),
                                Text(
                                  u.error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                InkWell(
                                  onTap: () =>
                                      setState(() => _uploads.remove(u)),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Text(
                                      'إغلاق',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
              if (l.status != 'ARCHIVED') ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: _working ? null : _deleteListing,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف الإعلان'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error
                          .withValues(alpha: 0.6),
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
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
                              final ok = await _confirm(
                                'إرسال للمراجعة',
                                'سيُراجَع الإعلان قبل ظهوره للجميع. هل بياناته وصوره جاهزة؟',
                              );
                              if (!ok || !mounted) return;
                              if (await _run(() => repo.submit(_id)) && mounted) {
                                await showSubmittedDialog(this.context);
                              }
                            },
                      child: Text(
                        l.media.isEmpty
                            ? 'أضف صورة واحدة على الأقل لتتمكن من الإرسال'
                            : 'إرسال للمراجعة',
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
