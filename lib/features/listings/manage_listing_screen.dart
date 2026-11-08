import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/widgets/illustration.dart';
import 'listing_local_store.dart';
import 'listing_models.dart';
import 'listing_repository.dart';
import 'submitted_dialog.dart';

const _maxPhotos = 20;
const _maxBytes = 10 * 1024 * 1024;

enum _UploadState { waiting, uploading, done, failed }

/// One picture on its way to the server, with its own state.
class _UploadItem {
  _UploadItem(this.file);

  final XFile file;
  _UploadState state = _UploadState.waiting;
  String? error;

  /// Whether "retry" can help: not for a wrong file type or a file that cannot be read.
  bool retryable = true;

  /// The signed URL issued for this picture. Kept so a retry does not ask for (and reserve) a
  /// second image slot, and so a picture already in storage is only attached again.
  UploadTicket? ticket;
  bool inStorage = false;
  String? fingerprint;
}

/// A reason shown to the user for a picture that cannot be sent.
class _UploadFailure implements Exception {
  _UploadFailure(this.message);

  final String message;
}

/// Cheap and good enough to notice the same picture chosen twice: its size plus samples from
/// the start, the middle and the end.
String _fingerprint(Uint8List b) {
  const sample = 4096;
  int clamp(int v) => v < 0 ? 0 : (v > b.length ? b.length : v);
  Iterable<int> part(int from) => b.getRange(clamp(from), clamp(from + sample));
  return '${b.length}:${Object.hashAll([...part(0), ...part(b.length ~/ 2), ...part(b.length - sample)])}';
}

/// One listing from its owner's side: status, photos, and the actions that apply.
class ManageListingScreen extends ConsumerStatefulWidget {
  const ManageListingScreen({super.key, required this.propertyId, @visibleForTesting this.picker});

  final String propertyId;

  /// Only tests pass one, to stand in for the system picker.
  final ImagePicker? picker;

  @override
  ConsumerState<ManageListingScreen> createState() =>
      _ManageListingScreenState();
}

class _ManageListingScreenState extends ConsumerState<ManageListingScreen> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  final List<_UploadItem> _uploads = [];
  bool _working = false;
  // The system picker allows one open window at a time; a second request while it is open
  // (a double tap) fails with "already_active".
  bool _picking = false;
  // Taken while the screen is alive. Unlike `ref`, it is still usable after dispose.
  late final ProviderContainer _container;
  late final ListingLocalStore _store;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _store = ref.read(listingLocalStoreProvider);
    unawaited(_recoverLostPick());
  }

  String get _id => widget.propertyId;
  // The queue is worked by one loop at a time, so pictures are never uploaded twice at once.
  bool _draining = false;
  // Fingerprints of the pictures queued or sent from this screen: picking one again is ignored.
  final Set<String> _seen = {};

  // Waiting, being sent, or sent but not yet shown in the grid.
  bool get _uploading => _uploads.any((u) => u.state != _UploadState.failed);
  // Work the user would lose by leaving.
  bool get _hasPendingUploads => _uploads.any(
    (u) => u.state == _UploadState.waiting || u.state == _UploadState.uploading,
  );

  void _refresh() {
    _container.invalidate(ownerListingProvider(_id));
    _container.invalidate(myListingsProvider);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addPhotos() async {
    if (_picking) return;
    _picking = true;
    final List<XFile> picked;
    try {
      // Android may end the app while the system picker is open. Leave a note first, so the next
      // launch knows to look for the photos that were chosen (see _recoverLostPick).
      if (photoPickerCanLoseData) {
        final accountId = await _currentAccountId();
        if (accountId != null) {
          await _store.savePendingPick(PendingPick(accountId: accountId, propertyId: _id, at: DateTime.now()));
        }
      }
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
      unawaited(_store.clearPendingPick()); // the picker came back: nothing was lost
    }
    if (picked.isEmpty || !mounted) return;
    _enqueue(picked);
  }

  /// The signed-in account, waiting for it if it is still loading; null when nobody is signed in.
  Future<String?> _currentAccountId() async {
    try {
      return (await ref.read(authControllerProvider.future))?.id;
    } catch (_) {
      return null;
    }
  }

  /// If Android ended the app while the photo picker was open, the pictures the user chose are
  /// kept by the picker plugin until they are asked for. They go through [_enqueue] like any
  /// others, so the same limit, duplicate and file checks apply. Their temporary files may be gone
  /// by now; such a picture simply ends as a failed tile.
  Future<void> _recoverLostPick() async {
    if (!photoPickerCanLoseData) return;
    final pending = await _store.loadPendingPick();
    if (pending == null || pending.propertyId != _id) return; // none, or another listing's
    await _store.clearPendingPick(); // consumed, whatever happens next
    if (!mounted || pending.isStale()) return;

    final accountId = await _currentAccountId();
    if (!mounted || accountId != pending.accountId) return; // another account must not inherit these

    final LostDataResponse response;
    try {
      response = await _picker.retrieveLostData();
    } catch (_) {
      _snack('تعذر استعادة الصور المختارة، اخترها من جديد');
      return;
    }
    if (!mounted || response.isEmpty) return;
    if (response.exception != null) {
      _snack('تعذر استعادة الصور المختارة، اخترها من جديد');
      return;
    }
    final files = response.files ?? [if (response.file != null) response.file!];
    if (files.isEmpty) return;

    // The limit is checked against the listing as it is, so wait for it to be loaded.
    try {
      await _container.read(ownerListingProvider(_id).future);
    } catch (_) {}
    if (!mounted) return;
    _snack('استعدنا ${files.length} صور اخترتها، وسنرفعها الآن');
    _enqueue(files);
  }

  /// The one way pictures enter the queue (the picker today). The limit is checked here, against
  /// the listing as it is now, not as it was when the button was tapped.
  void _enqueue(List<XFile> files) {
    final onServer =
        ref.read(ownerListingProvider(_id)).value?.media.length ?? 0;
    final room = _maxPhotos - onServer - _uploads.length;
    if (room <= 0) {
      _snack('وصلت إلى الحد الأقصى ($_maxPhotos صورة)');
      return;
    }
    if (files.length > room) {
      _snack('سيُرفع أول $room صور فقط (الحد الأقصى $_maxPhotos)');
    }
    setState(() {
      for (final f in files.take(room)) {
        _uploads.add(_UploadItem(f));
      }
    });
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (mounted) {
        final next = _uploads
            .where((u) => u.state == _UploadState.waiting)
            .firstOrNull;
        if (next == null) break;
        await _process(next);
      }
    } finally {
      _draining = false;
    }
    _refresh();
  }

  Future<void> _process(_UploadItem item) async {
    final repo = ref.read(listingRepositoryProvider);
    setState(() {
      item.state = _UploadState.uploading;
      item.error = null;
    });
    try {
      // A ticket that is about to expire is useless: ask for a new one.
      final old = item.ticket;
      if (old != null && !old.isUsable) {
        item.ticket = null;
        item.inStorage = false;
      }

      if (!item.inStorage) {
        final bytes = await item.file.readAsBytes();
        final type = sniffImageType(bytes);
        if (type == null) {
          throw _UploadFailure('نوع الصورة غير مدعوم (JPG أو PNG أو WebP)');
        }
        if (bytes.length > _maxBytes) {
          throw _UploadFailure('الصورة أكبر من 10 ميغابايت');
        }

        if (item.fingerprint == null) {
          final fp = _fingerprint(bytes);
          if (!_seen.add(fp)) {
            // The same picture is already queued or sent: drop it quietly instead of uploading twice.
            if (mounted) {
              setState(() => _uploads.remove(item));
              _snack('تم تجاهل صورة مكررة');
            }
            return;
          }
          item.fingerprint = fp;
        }
        item.ticket ??= await repo.uploadTicket(_id, type, bytes.length);
        await repo.putToStorage(item.ticket!, bytes);
        item.inStorage = true;
      }

      await repo.attach(_id, item.ticket!.uploadId);
      if (!mounted) return;
      setState(() => item.state = _UploadState.done);
      _refresh();
      // Keep the "done" tile until the grid has the real picture, so nothing blinks out.
      try {
        await _container.read(ownerListingProvider(_id).future);
      } catch (_) {}
      if (mounted) setState(() => _uploads.remove(item));
    } on _UploadFailure catch (e) {
      _fail(item, e.message, retryable: false);
    } on ApiException catch (e) {
      if (e.code == 'UPLOAD_NOT_FOUND_OR_EXPIRED' ||
          e.code == 'UPLOAD_MISMATCH') {
        item.ticket =
            null; // that upload is gone: a retry starts again from the file
        item.inStorage = false;
      }
      _fail(item, e.message, retryable: _isRetryable(e));
    } catch (_) {
      // The file could not be read (removed, no permission) or something unexpected: the picture
      // must end in a visible error, never spin forever.
      _fail(item, 'تعذرت قراءة الصورة، اخترها من جديد', retryable: false);
    }
  }

  static bool _isRetryable(ApiException e) =>
      e.isNetwork ||
      e.status >= 500 ||
      const {
        'UPLOAD_FAILED',
        'UPLOAD_IN_PROGRESS',
        'UPLOAD_NOT_FOUND_OR_EXPIRED',
      }.contains(e.code);

  void _fail(_UploadItem item, String message, {required bool retryable}) {
    if (!mounted) return;
    setState(() {
      item.state = _UploadState.failed;
      item.error = message;
      item.retryable = retryable;
    });
  }

  void _retry(_UploadItem item) {
    setState(() {
      item.state = _UploadState.waiting;
      item.error = null;
    });
    unawaited(_drain());
  }

  void _dismiss(_UploadItem item) {
    final fp = item.fingerprint;
    if (fp != null) _seen.remove(fp);
    setState(() => _uploads.remove(item));
  }

  /// Leaving while pictures are still being sent stops the ones that have not started.
  Future<void> _confirmLeave(bool didPop, Object? result) async {
    if (didPop) return;
    final leave = await _confirm(
      'رفع الصور جارٍ',
      'إن غادرت الآن تتوقف الصور التي لم تُرفع بعد. هل تريد المغادرة؟',
      confirmLabel: 'مغادرة',
      destructive: true,
    );
    if (!leave || !mounted) return;
    setState(
      () => _uploads.removeWhere((u) => u.state == _UploadState.waiting),
    );
    context.pop();
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
      () => action == 'cover'
          ? repo.setCover(_id, m.id)
          : repo.deleteMedia(_id, m.id),
      errorText: (e) => e.code == 'CONFLICT'
          ? 'لا يمكن حذف آخر صورة من إعلان منشور'
          : e.message,
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
    if (_hasPendingUploads) {
      _snack('انتظر حتى ينتهي رفع الصور ثم احذف الإعلان');
      return;
    }
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
    if (_working) return false; // a second tap while the first action runs
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

    return PopScope(
      canPop: !_hasPendingUploads,
      onPopInvokedWithResult: _confirmLeave,
      child: listingAsync.when(
        // Keep the screen (and the pictures being sent) while the listing reloads after each upload.
        skipLoadingOnReload: true,
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
                      await _run(
                        () => repo.renew(_id),
                        done: 'تم تجديد الإعلان',
                      );
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
                    border: Border.all(
                      color: info.color.withValues(alpha: 0.4),
                    ),
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
                        onPressed: _addPhotos,
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
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
                      _UploadTile(
                        item: u,
                        onRetry: () => _retry(u),
                        onDismiss: () => _dismiss(u),
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
                                if (await _run(() => repo.submit(_id)) &&
                                    mounted) {
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
      ),
    );
  }
}

/// A picture that is not on the server yet: waiting, being sent, just done, or failed with a reason.
class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.item,
    required this.onRetry,
    required this.onDismiss,
  });

  final _UploadItem item;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget status(Widget icon, String label) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );

    final Widget content = switch (item.state) {
      _UploadState.waiting => status(
        Icon(Icons.schedule, color: scheme.onSurfaceVariant),
        'في الانتظار',
      ),
      _UploadState.uploading => status(
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        'جارٍ الرفع',
      ),
      _UploadState.done => status(
        Icon(Icons.check_circle, color: scheme.primary),
        'تم الرفع',
      ),
      _UploadState.failed => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: scheme.error, size: 20),
              Text(
                item.error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Wrap, not Row: two actions do not fit side by side in a small tile.
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (item.retryable)
                    _TileAction(label: 'إعادة', onTap: onRetry),
                  _TileAction(label: 'إزالة', onTap: onDismiss),
                ],
              ),
            ],
          ),
        ),
      ),
    };

    return Semantics(
      container: true,
      label: switch (item.state) {
        _UploadState.waiting => 'صورة في الانتظار',
        _UploadState.uploading => 'جارٍ رفع الصورة',
        _UploadState.done => 'تم رفع الصورة',
        _UploadState.failed => 'فشل رفع الصورة: ${item.error ?? ''}',
      },
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(6),
        child: Center(child: content),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
